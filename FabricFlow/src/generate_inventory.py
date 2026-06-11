from __future__ import annotations

import random
from pathlib import Path
from typing import Dict, List, Tuple

import pandas as pd
from faker import Faker

from fashion_rules import SEED, SIZE_DIST, set_global_seeds


set_global_seeds(SEED)
fake = Faker("vi_VN")

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"
PRIMARY_STORE_IDS = [1, 3, 4, 6, 8, 9]
MALL_STORE_IDS = [1, 3, 4, 6, 8, 9]


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(table_name: str) -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / f"{table_name}.csv", encoding="utf-8-sig")


def size_weight(size_value: str) -> float:
    if size_value.isdigit():
        return SIZE_DIST["kids"][size_value]
    adult_weights = {"XS": 0.06, "S": 0.20, "M": 0.335, "L": 0.26, "XL": 0.11, "XXL": 0.035}
    return adult_weights[size_value]


def generate_inventory_policy(products_df: pd.DataFrame, variants_df: pd.DataFrame, stores_df: pd.DataFrame, warehouses_df: pd.DataFrame) -> pd.DataFrame:
    product_noos = products_df.set_index("product_id")["is_noos"].to_dict()
    store_ids = stores_df["store_id"].tolist()
    warehouse_ids = warehouses_df["warehouse_id"].tolist()
    rows: List[Dict] = []
    policy_id = 1

    for _, variant in variants_df.iterrows():
        variant_id = int(variant["variant_id"])
        is_noos = bool(product_noos[int(variant["product_id"])])
        policy_type = "noos" if is_noos else "seasonal"
        size_factor = size_weight(str(variant["size"]))

        for warehouse_id in warehouse_ids:
            base_units = 120 if is_noos else 80
            safety_stock = max(15, int(round(base_units * size_factor * 2.0)))
            reorder_point = safety_stock + (25 if is_noos else 15)
            rows.append(
                {
                    "inventory_policy_id": policy_id,
                    "variant_id": variant_id,
                    "store_id": None,
                    "warehouse_id": warehouse_id,
                    "safety_stock_qty": safety_stock,
                    "reorder_point_qty": reorder_point,
                    "target_cover_days": 45 if is_noos else 28,
                    "policy_type": policy_type,
                }
            )
            policy_id += 1

        target_store_ids = store_ids if is_noos else PRIMARY_STORE_IDS
        for store_id in target_store_ids:
            base_units = 40 if is_noos else 24
            safety_stock = max(4, int(round(base_units * size_factor * 2.0)))
            reorder_point = safety_stock + (10 if is_noos else 6)
            rows.append(
                {
                    "inventory_policy_id": policy_id,
                    "variant_id": variant_id,
                    "store_id": store_id,
                    "warehouse_id": None,
                    "safety_stock_qty": safety_stock,
                    "reorder_point_qty": reorder_point,
                    "target_cover_days": 30 if is_noos else 21,
                    "policy_type": policy_type,
                }
            )
            policy_id += 1

    return pd.DataFrame(rows)


def generate_inventory_current(inventory_policy_df: pd.DataFrame) -> pd.DataFrame:
    rows: List[Dict] = []
    inventory_current_id = 1
    last_updated = pd.Timestamp("2026-06-10 09:00:00")

    for _, policy in inventory_policy_df.iterrows():
        is_store = pd.notna(policy["store_id"])
        stock_floor = int(policy["safety_stock_qty"])
        stock_buffer = 18 if policy["policy_type"] == "noos" else 12
        stock_qty = stock_floor + stock_buffer + (inventory_current_id % 9)

        rows.append(
            {
                "inventory_current_id": inventory_current_id,
                "location_type": "store" if is_store else "warehouse",
                "store_id": int(policy["store_id"]) if pd.notna(policy["store_id"]) else None,
                "warehouse_id": int(policy["warehouse_id"]) if pd.notna(policy["warehouse_id"]) else None,
                "variant_id": int(policy["variant_id"]),
                "stock_quantity": stock_qty,
                "last_updated": last_updated,
            }
        )
        inventory_current_id += 1

    return pd.DataFrame(rows)


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    products_df = load_csv("products")
    variants_df = load_csv("product_variants")
    stores_df = load_csv("stores")
    warehouses_df = load_csv("warehouses")

    inventory_policy_df = generate_inventory_policy(products_df, variants_df, stores_df, warehouses_df)
    inventory_current_df = generate_inventory_current(inventory_policy_df)

    save_csv(inventory_policy_df, "inventory_policy")
    save_csv(inventory_current_df, "inventory_current")

    summary = pd.DataFrame(
        {
            "table_name": ["inventory_policy", "inventory_current"],
            "row_count": [len(inventory_policy_df), len(inventory_current_df)],
        }
    )
    save_csv(summary, "_inventory_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
