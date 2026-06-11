from __future__ import annotations

import random
from pathlib import Path
from typing import Dict, List

import numpy as np
import pandas as pd
from faker import Faker

from fashion_rules import (
    CATEGORY_DEMAND_WEIGHTS,
    OFFLINE_MONTH_FACTORS,
    OFFLINE_YEAR_FACTORS,
    SEED,
    collection_week_factor,
    offline_payment_weights,
    offline_upt_weights,
    set_global_seeds,
)


set_global_seeds(SEED)
fake = Faker("vi_VN")
rng = np.random.default_rng(SEED)

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"
START_DATE = pd.Timestamp("2023-03-01")
END_DATE = pd.Timestamp("2026-12-31")


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(table_name: str, parse_dates: List[str] | None = None) -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / f"{table_name}.csv", encoding="utf-8-sig", parse_dates=parse_dates or [])


def build_store_catalog() -> pd.DataFrame:
    stores_df = load_csv("stores")
    regions_df = load_csv("regions")
    inventory_policy_df = load_csv("inventory_policy")
    variants_df = load_csv("product_variants")
    products_df = load_csv("products")
    collections_df = load_csv("collections", parse_dates=["launch_date", "end_date"])
    categories_df = load_csv("categories")

    store_policy = inventory_policy_df[inventory_policy_df["store_id"].notna()].copy()
    store_policy["store_id"] = store_policy["store_id"].astype(int)

    catalog_df = (
        store_policy[["store_id", "variant_id", "policy_type"]]
        .merge(variants_df, on="variant_id", how="inner")
        .merge(products_df, on="product_id", how="inner")
        .merge(collections_df, on="collection_id", how="inner")
        .merge(categories_df[["category_id", "category_name", "target_gender"]], on="category_id", how="inner")
        .merge(stores_df[["store_id", "store_type", "demand_multiplier", "region_id"]], on="store_id", how="inner")
        .merge(regions_df[["region_id", "city_name"]], on="region_id", how="inner")
    )

    catalog_df["current_price"] = catalog_df["current_price"].astype(float)
    catalog_df["selling_price"] = catalog_df["selling_price"].astype(float)
    catalog_df["cost_price"] = catalog_df["cost_price"].astype(float)
    catalog_df["is_noos"] = catalog_df["is_noos"].astype(int)
    return catalog_df


def build_customer_pools() -> tuple[pd.DataFrame, Dict[str, np.ndarray], np.ndarray]:
    customers_df = load_csv("customers", parse_dates=["signup_date"])
    customers_df["signup_date"] = pd.to_datetime(customers_df["signup_date"])
    city_pools = {
        city_name: city_df["customer_id"].to_numpy(dtype=int)
        for city_name, city_df in customers_df.groupby("city_name", sort=False)
    }
    all_customer_ids = customers_df["customer_id"].to_numpy(dtype=int)
    return customers_df, city_pools, all_customer_ids


def build_promotion_lookup() -> Dict[int, List[Dict[str, object]]]:
    promotions_df = load_csv("promotions", parse_dates=["start_date", "end_date"])
    promotion_products_df = load_csv("promotion_products")
    promo_detail_df = promotion_products_df.merge(promotions_df, on="promotion_id", how="inner")

    lookup: Dict[int, List[Dict[str, object]]] = {}
    for _, row in promo_detail_df.iterrows():
        if row["channel_scope"] not in {"offline", "omnichannel"}:
            continue
        lookup.setdefault(int(row["variant_id"]), []).append(
            {
                "start_date": pd.Timestamp(row["start_date"]),
                "end_date": pd.Timestamp(row["end_date"]),
                "discount_rate": float(row["discount_rate_x"]),
            }
        )
    return lookup


def month_order_count(store_type: str, demand_multiplier: float, year: int, month: int) -> int:
    base_orders = 130 if store_type == "mall" else 82
    base = base_orders * demand_multiplier * OFFLINE_MONTH_FACTORS[month] * OFFLINE_YEAR_FACTORS[year]
    noise = random.uniform(0.94, 1.06)
    return max(28, int(round(base * noise)))


def choose_customer_id(
    customers_df: pd.DataFrame,
    city_pools: Dict[str, np.ndarray],
    all_customer_ids: np.ndarray,
    city_name: str,
    order_date: pd.Timestamp,
) -> int:
    if city_name in city_pools and random.random() < 0.72:
        candidate_ids = city_pools[city_name]
    else:
        candidate_ids = all_customer_ids

    sample_size = min(200, len(candidate_ids))
    sampled_ids = rng.choice(candidate_ids, size=sample_size, replace=False)
    sampled_customers = customers_df.loc[customers_df["customer_id"].isin(sampled_ids), ["customer_id", "signup_date"]]
    eligible = sampled_customers[sampled_customers["signup_date"] <= order_date]
    if not eligible.empty:
        return int(rng.choice(eligible["customer_id"].to_numpy(dtype=int)))
    return int(rng.choice(all_customer_ids))


def build_month_variant_pool(store_catalog_df: pd.DataFrame, month_start: pd.Timestamp) -> Dict[int, Dict[str, np.ndarray]]:
    pool_lookup: Dict[int, Dict[str, np.ndarray]] = {}
    month_mid = month_start + pd.offsets.Day(14)

    for store_id, store_df in store_catalog_df.groupby("store_id", sort=True):
        weights: List[float] = []
        variant_ids: List[int] = []

        for _, row in store_df.iterrows():
            launch_date = pd.Timestamp(row["launch_date"])
            end_date = pd.Timestamp(row["end_date"])
            category_weight = CATEGORY_DEMAND_WEIGHTS.get(str(row["category_name"]), 1.0)

            if int(row["is_noos"]) == 1:
                weeks_since_launch = max(0, int((month_mid - launch_date).days // 7))
                demand_weight = 0.55 + min(collection_week_factor(weeks_since_launch), 1.2) * 0.20
            elif launch_date <= month_mid <= end_date:
                weeks_since_launch = max(0, int((month_mid - launch_date).days // 7))
                demand_weight = collection_week_factor(weeks_since_launch)
            elif end_date < month_mid <= end_date + pd.Timedelta(days=45):
                weeks_since_launch = max(0, int((month_mid - launch_date).days // 7))
                demand_weight = max(0.45, collection_week_factor(weeks_since_launch))
            else:
                demand_weight = 0.0

            if demand_weight <= 0:
                continue

            variant_ids.append(int(row["variant_id"]))
            weights.append(demand_weight * category_weight)

        if not variant_ids:
            fallback_df = store_df[store_df["is_noos"] == 1]
            variant_ids = fallback_df["variant_id"].astype(int).tolist()
            weights = [1.0] * len(variant_ids)

        weight_array = np.array(weights, dtype=float)
        weight_array = weight_array / weight_array.sum()
        pool_lookup[int(store_id)] = {
            "variant_ids": np.array(variant_ids, dtype=int),
            "weights": weight_array,
        }

    return pool_lookup


def promotion_discount_pct(promotion_lookup: Dict[int, List[Dict[str, object]]], variant_id: int, order_date: pd.Timestamp) -> float:
    active_discounts = []
    for promo in promotion_lookup.get(variant_id, []):
        if pd.Timestamp(promo["start_date"]) <= order_date <= pd.Timestamp(promo["end_date"]):
            active_discounts.append(float(promo["discount_rate"]))
    return max(active_discounts) if active_discounts else 0.0


def sample_order_time(order_date: pd.Timestamp) -> pd.Timestamp:
    hour = random.choices([10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], weights=[3, 4, 5, 4, 4, 5, 6, 6, 7, 5, 2], k=1)[0]
    minute = random.randint(0, 59)
    second = random.randint(0, 59)
    return order_date.replace(hour=hour, minute=minute, second=second)


def sample_upt(store_type: str, month: int) -> int:
    weights = offline_upt_weights(store_type, month)
    values = list(weights.keys())
    probs = list(weights.values())
    return random.choices(values, weights=probs, k=1)[0]


def sample_payment_method(order_datetime: pd.Timestamp) -> str:
    weights = offline_payment_weights(order_datetime.year)
    return random.choices(list(weights.keys()), weights=list(weights.values()), k=1)[0]


def generate_sales_offline() -> Dict[str, pd.DataFrame]:
    store_catalog_df = build_store_catalog()
    customers_df, city_pools, all_customer_ids = build_customer_pools()
    promotion_lookup = build_promotion_lookup()

    variant_lookup = store_catalog_df.drop_duplicates("variant_id").set_index("variant_id").to_dict("index")
    store_lookup = store_catalog_df[["store_id", "store_type", "demand_multiplier", "city_name"]].drop_duplicates("store_id")

    order_rows: List[Dict] = []
    item_rows: List[Dict] = []
    payment_rows: List[Dict] = []

    order_id = 1
    item_id = 1
    payment_id = 1

    for month_start in pd.date_range(START_DATE, END_DATE, freq="MS"):
        month_end = min(month_start + pd.offsets.MonthEnd(1), END_DATE)
        month_pool_lookup = build_month_variant_pool(store_catalog_df, month_start)

        for _, store in store_lookup.sort_values("store_id").iterrows():
            store_id = int(store["store_id"])
            store_type = str(store["store_type"])
            demand_multiplier = float(store["demand_multiplier"])
            order_count = month_order_count(store_type, demand_multiplier, month_start.year, month_start.month)

            variant_ids = month_pool_lookup[store_id]["variant_ids"]
            weights = month_pool_lookup[store_id]["weights"]

            for _ in range(order_count):
                day_offset = int(rng.integers(0, (month_end - month_start).days + 1))
                order_date = month_start + pd.Timedelta(days=day_offset)
                order_datetime = sample_order_time(order_date)

                customer_id = choose_customer_id(
                    customers_df=customers_df,
                    city_pools=city_pools,
                    all_customer_ids=all_customer_ids,
                    city_name=str(store["city_name"]),
                    order_date=order_date,
                )

                upt = sample_upt(store_type, month_start.month)
                sampled_units = rng.choice(variant_ids, size=upt, replace=True, p=weights)
                unit_counts = pd.Series(sampled_units).value_counts().sort_index()

                order_subtotal = 0.0
                order_total = 0.0

                for variant_id, quantity in unit_counts.items():
                    variant = variant_lookup[int(variant_id)]
                    unit_price = round(float(variant["current_price"] or variant["selling_price"]), 2)
                    discount_pct = round(promotion_discount_pct(promotion_lookup, int(variant_id), order_date), 2)
                    gross_sales = round(unit_price * int(quantity), 2)
                    line_total = round(gross_sales * (1 - (discount_pct / 100.0)), 2)
                    gross_profit = round(line_total - (float(variant["cost_price"]) * int(quantity)), 2)

                    item_rows.append(
                        {
                            "item_id": item_id,
                            "order_id": order_id,
                            "variant_id": int(variant_id),
                            "quantity": int(quantity),
                            "unit_price": unit_price,
                            "discount_pct": discount_pct,
                            "line_total": line_total,
                            "gross_profit": gross_profit,
                        }
                    )
                    item_id += 1
                    order_subtotal += gross_sales
                    order_total += line_total

                discount_amount = round(order_subtotal - order_total, 2)
                total_amount = round(order_total, 2)

                order_rows.append(
                    {
                        "order_id": order_id,
                        "store_id": store_id,
                        "customer_id": customer_id,
                        "staff_id": f"STR{store_id:02d}-STAFF-{random.randint(1, 24):03d}",
                        "order_datetime": order_datetime,
                        "total_amount": total_amount,
                        "discount_amount": discount_amount,
                    }
                )

                payment_rows.append(
                    {
                        "payment_id": payment_id,
                        "order_id": order_id,
                        "payment_datetime": order_datetime + pd.Timedelta(minutes=random.randint(0, 8)),
                        "payment_method": sample_payment_method(order_datetime),
                        "amount_paid": total_amount,
                    }
                )

                payment_id += 1
                order_id += 1

    return {
        "store_orders": pd.DataFrame(order_rows),
        "store_order_items": pd.DataFrame(item_rows),
        "store_payments": pd.DataFrame(payment_rows),
    }


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    outputs = generate_sales_offline()

    for table_name, df in outputs.items():
        save_csv(df, table_name)

    summary = pd.DataFrame(
        {
            "table_name": list(outputs.keys()),
            "row_count": [len(df) for df in outputs.values()],
        }
    )
    save_csv(summary, "_sales_offline_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
