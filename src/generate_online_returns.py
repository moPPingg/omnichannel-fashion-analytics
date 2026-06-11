from __future__ import annotations

import random
from pathlib import Path
from typing import Dict, List

import numpy as np
import pandas as pd
from faker import Faker

from fashion_rules import ONLINE_RETURN_RATE, SEED, set_global_seeds


set_global_seeds(SEED)
fake = Faker("vi_VN")
rng = np.random.default_rng(SEED + 303)

PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "data" / "raw"
RETURN_REASONS = [
    "size_issue",
    "fit_issue",
    "damaged_item",
    "changed_mind",
    "wrong_item",
    "color_expectation",
]
RETURN_REASON_WEIGHTS = [0.30, 0.22, 0.10, 0.16, 0.08, 0.14]
RETURN_CONDITIONS = {
    "size_issue": "opened",
    "fit_issue": "opened",
    "damaged_item": "damaged",
    "changed_mind": "unworn",
    "wrong_item": "opened",
    "color_expectation": "opened",
}


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(table_name: str, parse_dates: List[str] | None = None) -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / f"{table_name}.csv", encoding="utf-8-sig", parse_dates=parse_dates or [])


def build_order_context() -> pd.DataFrame:
    orders_df = load_csv("online_orders", parse_dates=["order_datetime"])
    items_df = load_csv("online_order_items")
    fulfillments_df = load_csv("online_fulfillments", parse_dates=["shipped_at", "delivered_at"])
    variants_df = load_csv("product_variants")
    products_df = load_csv("products")
    categories_df = load_csv("categories")

    item_context_df = (
        items_df.merge(variants_df[["variant_id", "product_id"]], on="variant_id", how="inner")
        .merge(products_df[["product_id", "category_id"]], on="product_id", how="inner")
        .merge(categories_df[["category_id", "category_name"]], on="category_id", how="inner")
    )

    def map_return_rate(category_name: str) -> float:
        if category_name in ONLINE_RETURN_RATE:
            return float(ONLINE_RETURN_RATE[category_name])
        if str(category_name).startswith("Kids"):
            return float(ONLINE_RETURN_RATE["Kids"])
        return 0.22

    order_rate_df = (
        item_context_df.groupby("order_id")
        .agg(
            avg_category_return_rate=("category_name", lambda s: float(np.mean([map_return_rate(v) for v in s]))),
            item_count=("item_id", "count"),
        )
        .reset_index()
    )

    return (
        orders_df.merge(order_rate_df, on="order_id", how="inner")
        .merge(fulfillments_df[["order_id", "delivered_at"]], on="order_id", how="inner")
    )


def choose_return_orders(order_context_df: pd.DataFrame) -> pd.DataFrame:
    eligible_df = order_context_df[order_context_df["delivered_at"].notna()].copy()
    weighted_scores = eligible_df["avg_category_return_rate"].to_numpy(dtype=float)
    weighted_scores = weighted_scores / weighted_scores.sum()
    target_return_orders = int(round(len(eligible_df) * 0.225))
    chosen_indices = rng.choice(eligible_df.index.to_numpy(), size=target_return_orders, replace=False, p=weighted_scores)
    return eligible_df.loc[chosen_indices].sort_values("order_id").reset_index(drop=True)


def sample_return_reason() -> str:
    return random.choices(RETURN_REASONS, weights=RETURN_REASON_WEIGHTS, k=1)[0]


def refund_status_for_reason(reason: str) -> str:
    return "partial_refunded" if reason in {"damaged_item", "wrong_item"} and random.random() < 0.18 else "refunded"


def generate_online_returns() -> Dict[str, pd.DataFrame]:
    orders_df = load_csv("online_orders", parse_dates=["order_datetime"])
    items_df = load_csv("online_order_items")
    order_context_df = build_order_context()
    selected_returns_df = choose_return_orders(order_context_df)

    items_by_order = {int(order_id): group.copy() for order_id, group in items_df.groupby("order_id", sort=True)}
    order_lookup = orders_df.set_index("order_id").to_dict("index")

    return_rows: List[Dict] = []
    return_item_rows: List[Dict] = []
    return_id = 1
    return_item_id = 1

    for _, order in selected_returns_df.iterrows():
        order_id = int(order["order_id"])
        order_row = order_lookup[order_id]
        delivered_at = pd.Timestamp(order["delivered_at"])
        order_items = items_by_order[order_id].copy().sort_values("item_id")

        reason = sample_return_reason()
        return_condition = RETURN_CONDITIONS[reason]
        refund_status = refund_status_for_reason(reason)

        item_return_weights = []
        for _, item in order_items.iterrows():
            base_weight = float(item["line_total"])
            if reason in {"size_issue", "fit_issue", "color_expectation"}:
                base_weight *= 1.18
            if reason in {"damaged_item", "wrong_item"}:
                base_weight *= 0.95
            item_return_weights.append(base_weight)

        item_return_weights = np.array(item_return_weights, dtype=float)
        item_return_weights = item_return_weights / item_return_weights.sum()

        item_count = len(order_items)
        return_item_target = random.choices([1, 2, 3], weights=[0.52, 0.34, 0.14], k=1)[0]
        return_item_target = min(return_item_target, item_count)

        chosen_item_positions = rng.choice(order_items.index.to_numpy(), size=return_item_target, replace=False, p=item_return_weights)
        selected_items = order_items.loc[chosen_item_positions].sort_values("item_id")

        total_refund_amount = 0.0
        for _, item in selected_items.iterrows():
            purchased_qty = int(item["quantity"])
            if purchased_qty == 1:
                return_qty = 1
            else:
                partial_return_prob = 0.46 if reason in {"changed_mind", "color_expectation"} else 0.32
                if random.random() < partial_return_prob:
                    return_qty = int(rng.integers(1, purchased_qty))
                else:
                    return_qty = purchased_qty

            refund_amount = round(float(item["line_total"]) * (return_qty / purchased_qty), 2)
            total_refund_amount += refund_amount

            return_item_rows.append(
                {
                    "return_item_id": return_item_id,
                    "return_id": return_id,
                    "order_id": order_id,
                    "variant_id": int(item["variant_id"]),
                    "quantity": return_qty,
                    "refund_amount": refund_amount,
                    "return_condition": return_condition,
                }
            )
            return_item_id += 1

        return_date = delivered_at.normalize() + pd.Timedelta(days=int(rng.integers(1, 31)))
        return_datetime = return_date + pd.Timedelta(
            hours=int(rng.integers(9, 22)),
            minutes=int(rng.integers(0, 60)),
            seconds=int(rng.integers(0, 60)),
        )
        if return_datetime <= delivered_at:
            return_datetime = delivered_at + pd.Timedelta(hours=4)
        return_datetime = return_datetime.floor("s")
        if return_datetime <= delivered_at:
            return_datetime = (delivered_at + pd.Timedelta(hours=1)).floor("s")

        return_rows.append(
            {
                "return_id": return_id,
                "order_id": order_id,
                "customer_id": int(order_row["customer_id"]),
                "return_datetime": return_datetime,
                "return_reason": reason,
                "return_condition": return_condition,
                "refund_status": refund_status,
                "total_refund_amount": round(total_refund_amount, 2),
            }
        )
        return_id += 1

    return {
        "online_returns": pd.DataFrame(return_rows),
        "online_return_items": pd.DataFrame(return_item_rows),
    }


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    outputs = generate_online_returns()

    for table_name, df in outputs.items():
        save_csv(df, table_name)

    summary = pd.DataFrame(
        {
            "table_name": list(outputs.keys()),
            "row_count": [len(df) for df in outputs.values()],
        }
    )
    save_csv(summary, "_online_returns_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
