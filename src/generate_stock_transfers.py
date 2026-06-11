from __future__ import annotations

from pathlib import Path
from typing import Dict, List

import pandas as pd
from faker import Faker

from fashion_rules import SEED, set_global_seeds


set_global_seeds(SEED)
fake = Faker("vi_VN")

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"
PRIMARY_STORE_IDS = [1, 3, 4, 6, 8, 9]


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(table_name: str, parse_dates: List[str] | None = None) -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / f"{table_name}.csv", encoding="utf-8-sig", parse_dates=parse_dates or [])


def generate_stock_transfers() -> Dict[str, pd.DataFrame]:
    stores_df = load_csv("stores")
    inventory_policy_df = load_csv("inventory_policy")
    inventory_current_df = load_csv("inventory_current", parse_dates=["last_updated"])

    store_lookup = stores_df.set_index("store_id").to_dict("index")

    store_policy = inventory_policy_df[inventory_policy_df["store_id"].notna()].copy()
    store_policy["store_id"] = store_policy["store_id"].astype(int)
    warehouse_policy = inventory_policy_df[inventory_policy_df["warehouse_id"].notna()].copy()
    warehouse_policy["warehouse_id"] = warehouse_policy["warehouse_id"].astype(int)

    store_current = inventory_current_df[inventory_current_df["store_id"].notna()].copy()
    store_current["store_id"] = store_current["store_id"].astype(int)
    warehouse_current = inventory_current_df[inventory_current_df["warehouse_id"].notna()].copy()
    warehouse_current["warehouse_id"] = warehouse_current["warehouse_id"].astype(int)

    store_metrics = store_current.merge(
        store_policy[["variant_id", "store_id", "safety_stock_qty", "reorder_point_qty", "policy_type"]],
        on=["variant_id", "store_id"],
        how="inner",
    )
    store_metrics["need_score"] = store_metrics["stock_quantity"] - store_metrics["reorder_point_qty"]

    warehouse_metrics = warehouse_current.merge(
        warehouse_policy[["variant_id", "warehouse_id", "safety_stock_qty", "reorder_point_qty"]],
        on=["variant_id", "warehouse_id"],
        how="inner",
    )

    transfer_rows: List[Dict] = []
    transfer_item_rows: List[Dict] = []
    stock_transfer_id = 1
    stock_transfer_item_id = 1

    base_dates = pd.date_range("2024-02-15", "2026-11-15", periods=6)

    # Warehouse -> Store replenishment
    for store_id in stores_df["store_id"].astype(int).tolist():
        home_warehouse_id = int(store_lookup[store_id]["warehouse_id"])
        candidate_items = store_metrics[store_metrics["store_id"] == store_id].sort_values(
            by=["need_score", "variant_id"], ascending=[True, True]
        )

        transfer_dates = [d + pd.Timedelta(days=store_id % 5) for d in base_dates]
        for idx, transfer_date in enumerate(transfer_dates):
            selected = candidate_items.iloc[idx * 5 : (idx + 1) * 5]
            if selected.empty:
                continue

            transfer_rows.append(
                {
                    "stock_transfer_id": stock_transfer_id,
                    "transfer_datetime": transfer_date.to_pydatetime().replace(hour=9, minute=0, second=0),
                    "from_store_id": None,
                    "from_warehouse_id": home_warehouse_id,
                    "to_store_id": store_id,
                    "to_warehouse_id": None,
                    "transfer_status": "completed",
                    "transfer_reason": "replenishment",
                    "related_online_order_id": None,
                }
            )

            for _, row in selected.iterrows():
                warehouse_stock_row = warehouse_metrics[
                    (warehouse_metrics["warehouse_id"] == home_warehouse_id)
                    & (warehouse_metrics["variant_id"] == row["variant_id"])
                ].iloc[0]
                qty = max(2, min(12, int(row["reorder_point_qty"] - row["stock_quantity"] + 6)))
                qty = min(qty, max(2, int(warehouse_stock_row["stock_quantity"] // 12)))

                transfer_item_rows.append(
                    {
                        "stock_transfer_item_id": stock_transfer_item_id,
                        "stock_transfer_id": stock_transfer_id,
                        "variant_id": int(row["variant_id"]),
                        "quantity": int(qty),
                    }
                )
                stock_transfer_item_id += 1

            stock_transfer_id += 1

    # Store -> Store balancing / ship-from-store preparation
    balancing_pairs = [
        (1, 2),
        (3, 5),
        (6, 7),
        (8, 10),
        (9, 5),
        (4, 2),
    ]
    balancing_dates = pd.date_range("2024-06-10", "2026-10-10", periods=len(balancing_pairs) * 2)

    pair_index = 0
    for source_store_id, dest_store_id in balancing_pairs:
        source_items = store_metrics[store_metrics["store_id"] == source_store_id].sort_values(
            by=["stock_quantity", "variant_id"], ascending=[False, True]
        )
        selected = source_items.head(4)
        for reason in ["stock_balancing", "ship_from_store_preparation"]:
            transfer_rows.append(
                {
                    "stock_transfer_id": stock_transfer_id,
                    "transfer_datetime": pd.Timestamp(balancing_dates[pair_index]).floor("s").to_pydatetime().replace(
                        hour=14, minute=0, second=0
                    ),
                    "from_store_id": source_store_id,
                    "from_warehouse_id": None,
                    "to_store_id": dest_store_id,
                    "to_warehouse_id": None,
                    "transfer_status": "completed",
                    "transfer_reason": reason,
                    "related_online_order_id": None,
                }
            )

            for offset, (_, row) in enumerate(selected.iterrows(), start=1):
                qty = max(1, min(6, int(row["stock_quantity"] // (10 + offset))))
                transfer_item_rows.append(
                    {
                        "stock_transfer_item_id": stock_transfer_item_id,
                        "stock_transfer_id": stock_transfer_id,
                        "variant_id": int(row["variant_id"]),
                        "quantity": int(qty),
                    }
                )
                stock_transfer_item_id += 1

            stock_transfer_id += 1
            pair_index += 1

    return {
        "stock_transfers": pd.DataFrame(transfer_rows),
        "stock_transfer_items": pd.DataFrame(transfer_item_rows),
    }


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    outputs = generate_stock_transfers()

    for table_name, df in outputs.items():
        save_csv(df, table_name)

    summary = pd.DataFrame(
        {
            "table_name": list(outputs.keys()),
            "row_count": [len(df) for df in outputs.values()],
        }
    )
    save_csv(summary, "_stock_transfer_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
