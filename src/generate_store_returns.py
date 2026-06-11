from __future__ import annotations

import random
from pathlib import Path
from typing import Dict, List

import numpy as np
import pandas as pd
from faker import Faker

from fashion_rules import SEED, set_global_seeds


set_global_seeds(SEED)
fake = Faker("vi_VN")
rng = np.random.default_rng(SEED + 101)

PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "data" / "raw"
TARGET_RETURN_RATE = 0.065
MAX_RETURN_DATETIME = pd.Timestamp("2026-12-31 20:30:00")
RETURN_REASONS = [
    "size_issue",
    "fit_not_as_expected",
    "color_not_as_expected",
    "changed_mind",
    "quality_issue",
]
RETURN_REASON_WEIGHTS = [0.28, 0.22, 0.14, 0.21, 0.15]
RETURN_CONDITIONS = {
    "size_issue": "unworn",
    "fit_not_as_expected": "unworn",
    "color_not_as_expected": "opened",
    "changed_mind": "unworn",
    "quality_issue": "defective",
}


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(table_name: str, parse_dates: List[str] | None = None) -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / f"{table_name}.csv", encoding="utf-8-sig", parse_dates=parse_dates or [])


def build_order_context() -> pd.DataFrame:
    orders_df = load_csv("store_orders", parse_dates=["order_datetime"])
    items_df = load_csv("store_order_items")
    variants_df = load_csv("product_variants")
    products_df = load_csv("products")
    categories_df = load_csv("categories")

    item_context_df = (
        items_df.merge(variants_df[["variant_id", "product_id"]], on="variant_id", how="inner")
        .merge(products_df[["product_id", "category_id"]], on="product_id", how="inner")
        .merge(categories_df[["category_id", "category_name"]], on="category_id", how="inner")
    )
    item_context_df["net_unit_price"] = item_context_df["line_total"] / item_context_df["quantity"]

    category_return_rate = {
        "Tops": 0.060,
        "Bottoms": 0.067,
        "Dresses": 0.071,
        "Outerwear": 0.054,
        "Accessories": 0.041,
        "Footwear": 0.078,
        "Kids Tops": 0.052,
        "Kids Bottoms": 0.050,
    }

    order_rate_df = (
        item_context_df.groupby("order_id")
        .agg(
            avg_category_return_rate=("category_name", lambda s: float(np.mean([category_return_rate.get(v, 0.06) for v in s]))),
            item_count=("item_id", "count"),
        )
        .reset_index()
    )

    order_context_df = orders_df.merge(order_rate_df, on="order_id", how="inner")
    return order_context_df


def choose_return_orders(order_context_df: pd.DataFrame) -> pd.DataFrame:
    target_return_orders = int(round(len(order_context_df) * TARGET_RETURN_RATE))
    weighted_scores = order_context_df["avg_category_return_rate"].to_numpy(dtype=float)
    weighted_scores = weighted_scores / weighted_scores.sum()
    chosen_indices = rng.choice(order_context_df.index.to_numpy(), size=target_return_orders, replace=False, p=weighted_scores)
    chosen_df = order_context_df.loc[chosen_indices].sort_values("order_id").reset_index(drop=True)
    return chosen_df


def sample_return_reason() -> str:
    return random.choices(RETURN_REASONS, weights=RETURN_REASON_WEIGHTS, k=1)[0]


def sample_refund_method(payment_method: str | None) -> str:
    if payment_method in {"cash", "card", "e-wallet"}:
        return str(payment_method)
    return random.choice(["cash", "card", "e-wallet"])


def generate_store_returns() -> Dict[str, pd.DataFrame]:
    orders_df = load_csv("store_orders", parse_dates=["order_datetime"])
    items_df = load_csv("store_order_items")
    payments_df = load_csv("store_payments")
    order_context_df = build_order_context()
    selected_returns_df = choose_return_orders(order_context_df)

    payment_lookup = payments_df.drop_duplicates("order_id").set_index("order_id")["payment_method"].to_dict()
    items_by_order = {int(order_id): group.copy() for order_id, group in items_df.groupby("order_id", sort=True)}
    order_lookup = orders_df.set_index("order_id").to_dict("index")

    return_rows: List[Dict] = []
    return_item_rows: List[Dict] = []
    return_id = 1
    return_item_id = 1

    for _, order in selected_returns_df.iterrows():
        order_id = int(order["order_id"])
        order_row = order_lookup[order_id]
        order_datetime = pd.Timestamp(order_row["order_datetime"])
        order_items = items_by_order[order_id].copy().sort_values("item_id")

        reason = sample_return_reason()
        condition = RETURN_CONDITIONS[reason]
        payment_method = payment_lookup.get(order_id)

        item_return_weights = []
        for _, item in order_items.iterrows():
            base_weight = float(item["line_total"])
            if reason in {"size_issue", "fit_not_as_expected"}:
                base_weight *= 1.15
            if reason == "quality_issue":
                base_weight *= 0.90
            item_return_weights.append(base_weight)

        item_return_weights = np.array(item_return_weights, dtype=float)
        item_return_weights = item_return_weights / item_return_weights.sum()

        item_count = len(order_items)
        return_item_target = 1 if item_count == 1 else random.choices([1, 2], weights=[0.78, 0.22], k=1)[0]
        return_item_target = min(return_item_target, item_count)

        chosen_item_positions = rng.choice(order_items.index.to_numpy(), size=return_item_target, replace=False, p=item_return_weights)
        selected_items = order_items.loc[chosen_item_positions].sort_values("item_id")

        total_refund_amount = 0.0
        for _, item in selected_items.iterrows():
            purchased_qty = int(item["quantity"])
            if purchased_qty == 1:
                return_qty = 1
            else:
                partial_return_prob = 0.34 if reason in {"changed_mind", "color_not_as_expected"} else 0.22
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
                    "return_condition": condition,
                }
            )
            return_item_id += 1

        return_date = order_datetime.normalize() + pd.Timedelta(days=int(rng.integers(1, 25)))
        return_datetime = return_date + pd.Timedelta(
            hours=int(rng.integers(10, 21)),
            minutes=int(rng.integers(0, 60)),
            seconds=int(rng.integers(0, 60)),
        )
        return_datetime = min(return_datetime, MAX_RETURN_DATETIME)

        return_rows.append(
            {
                "return_id": return_id,
                "order_id": order_id,
                "store_id": int(order_row["store_id"]),
                "customer_id": int(order_row["customer_id"]),
                "return_datetime": return_datetime.floor("s"),
                "return_reason": reason,
                "refund_method": sample_refund_method(payment_method),
                "total_refund_amount": round(total_refund_amount, 2),
            }
        )
        return_id += 1

    return {
        "store_returns": pd.DataFrame(return_rows),
        "store_return_items": pd.DataFrame(return_item_rows),
    }


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    outputs = generate_store_returns()

    for table_name, df in outputs.items():
        save_csv(df, table_name)

    summary = pd.DataFrame(
        {
            "table_name": list(outputs.keys()),
            "row_count": [len(df) for df in outputs.values()],
        }
    )
    save_csv(summary, "_store_returns_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
