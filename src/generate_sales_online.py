from __future__ import annotations

import random
from pathlib import Path
from typing import Dict, List

import numpy as np
import pandas as pd
from faker import Faker

from fashion_rules import CATEGORY_DEMAND_WEIGHTS, SEED, collection_week_factor, set_global_seeds


set_global_seeds(SEED)
fake = Faker("vi_VN")
rng = np.random.default_rng(SEED + 202)

PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "data" / "raw"
START_DATE = pd.Timestamp("2023-03-01")
END_DATE = pd.Timestamp("2026-12-31 23:59:59")
ONLINE_MONTH_FACTORS = {
    1: 0.92,
    2: 0.98,
    3: 1.10,
    4: 1.04,
    5: 1.03,
    6: 1.12,
    7: 1.08,
    8: 1.01,
    9: 1.16,
    10: 1.09,
    11: 1.22,
    12: 1.32,
}
ONLINE_YEAR_FACTORS = {2023: 0.86, 2024: 0.98, 2025: 1.09, 2026: 1.22}
CARRIER_POOL = ["GHN", "GHTK", "J&T Express", "Viettel Post"]


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(table_name: str, parse_dates: List[str] | None = None) -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / f"{table_name}.csv", encoding="utf-8-sig", parse_dates=parse_dates or [])


def online_upt_weights(month: int) -> Dict[int, float]:
    if month in {6, 9, 11, 12}:
        return {1: 0.10, 2: 0.28, 3: 0.34, 4: 0.20, 5: 0.08}
    return {1: 0.12, 2: 0.34, 3: 0.32, 4: 0.16, 5: 0.06}


def online_payment_weights(year: int) -> Dict[str, float]:
    if year <= 2024:
        return {"cod": 0.48, "prepaid": 0.42, "installment": 0.10}
    if year == 2025:
        return {"cod": 0.40, "prepaid": 0.48, "installment": 0.12}
    return {"cod": 0.34, "prepaid": 0.52, "installment": 0.14}


def build_catalog() -> pd.DataFrame:
    variants_df = load_csv("product_variants")
    products_df = load_csv("products")
    collections_df = load_csv("collections", parse_dates=["launch_date", "end_date"])
    categories_df = load_csv("categories")
    inventory_current_df = load_csv("inventory_current", parse_dates=["last_updated"])
    stores_df = load_csv("stores")

    store_inventory_df = inventory_current_df[inventory_current_df["store_id"].notna()].copy()
    store_inventory_df["store_id"] = store_inventory_df["store_id"].astype(int)

    catalog_df = (
        variants_df.merge(products_df, on="product_id", how="inner")
        .merge(collections_df, on="collection_id", how="inner")
        .merge(categories_df[["category_id", "category_name"]], on="category_id", how="inner")
    )
    catalog_df["avg_store_stock"] = catalog_df["variant_id"].map(
        store_inventory_df.groupby("variant_id")["stock_quantity"].mean().to_dict()
    ).fillna(0.0)
    catalog_df["current_price"] = catalog_df["current_price"].astype(float)
    catalog_df["selling_price"] = catalog_df["selling_price"].astype(float)
    catalog_df["cost_price"] = catalog_df["cost_price"].astype(float)
    catalog_df["is_noos"] = catalog_df["is_noos"].astype(int)

    ship_from_store_df = stores_df[stores_df["supports_ship_from_store"] == 1][["store_id", "region_id", "store_type"]].copy()
    ship_from_store_df["store_id"] = ship_from_store_df["store_id"].astype(int)
    return catalog_df, ship_from_store_df


def build_customer_context() -> tuple[pd.DataFrame, Dict[str, np.ndarray], np.ndarray]:
    customers_df = load_csv("customers", parse_dates=["signup_date"])
    customers_df["signup_date"] = pd.to_datetime(customers_df["signup_date"])
    city_lookup = {
        city_name: city_df["customer_id"].to_numpy(dtype=int)
        for city_name, city_df in customers_df.groupby("city_name", sort=False)
    }
    return customers_df, city_lookup, customers_df["customer_id"].to_numpy(dtype=int)


def build_promotion_lookup() -> Dict[int, List[Dict[str, object]]]:
    promotions_df = load_csv("promotions", parse_dates=["start_date", "end_date"])
    promotion_products_df = load_csv("promotion_products")
    promo_detail_df = promotion_products_df.merge(promotions_df, on="promotion_id", how="inner")

    lookup: Dict[int, List[Dict[str, object]]] = {}
    for _, row in promo_detail_df.iterrows():
        if row["channel_scope"] not in {"online", "omnichannel"}:
            continue
        lookup.setdefault(int(row["variant_id"]), []).append(
            {
                "start_date": pd.Timestamp(row["start_date"]),
                "end_date": pd.Timestamp(row["end_date"]),
                "discount_rate": float(row["discount_rate_x"]),
            }
        )
    return lookup


def month_order_count(year: int, month: int) -> int:
    base_orders = 150
    noise = random.uniform(0.95, 1.07)
    return max(50, int(round(base_orders * ONLINE_MONTH_FACTORS[month] * ONLINE_YEAR_FACTORS[year] * noise)))


def build_month_variant_pool(catalog_df: pd.DataFrame, month_start: pd.Timestamp) -> Dict[str, np.ndarray]:
    weights: List[float] = []
    variant_ids: List[int] = []
    month_mid = month_start + pd.offsets.Day(14)

    for _, row in catalog_df.iterrows():
        launch_date = pd.Timestamp(row["launch_date"])
        end_date = pd.Timestamp(row["end_date"])
        category_weight = CATEGORY_DEMAND_WEIGHTS.get(str(row["category_name"]), 1.0)
        price_weight = 1.0 + min(float(row["current_price"]) / 2000000.0, 0.35)
        stock_weight = 1.0 + min(float(row["avg_store_stock"]) / 60.0, 0.30)

        if int(row["is_noos"]) == 1:
            weeks_since_launch = max(0, int((month_mid - launch_date).days // 7))
            demand_weight = 0.75 + min(collection_week_factor(weeks_since_launch), 1.2) * 0.28
        elif launch_date <= month_mid <= end_date:
            weeks_since_launch = max(0, int((month_mid - launch_date).days // 7))
            demand_weight = collection_week_factor(weeks_since_launch) * 1.08
        elif end_date < month_mid <= end_date + pd.Timedelta(days=45):
            weeks_since_launch = max(0, int((month_mid - launch_date).days // 7))
            demand_weight = max(0.55, collection_week_factor(weeks_since_launch))
        else:
            demand_weight = 0.0

        if demand_weight <= 0:
            continue

        variant_ids.append(int(row["variant_id"]))
        weights.append(demand_weight * category_weight * price_weight * stock_weight)

    weight_array = np.array(weights, dtype=float)
    weight_array = weight_array / weight_array.sum()
    return {"variant_ids": np.array(variant_ids, dtype=int), "weights": weight_array}


def choose_customer_id(
    customers_df: pd.DataFrame,
    city_lookup: Dict[str, np.ndarray],
    all_customer_ids: np.ndarray,
    order_date: pd.Timestamp,
) -> int:
    if random.random() < 0.55:
        preferred_city = random.choice(list(city_lookup.keys()))
        candidate_ids = city_lookup[preferred_city]
    else:
        candidate_ids = all_customer_ids

    sample_size = min(240, len(candidate_ids))
    sampled_ids = rng.choice(candidate_ids, size=sample_size, replace=False)
    sampled_customers = customers_df.loc[customers_df["customer_id"].isin(sampled_ids), ["customer_id", "signup_date"]]
    eligible = sampled_customers[sampled_customers["signup_date"] <= order_date]
    if not eligible.empty:
        return int(rng.choice(eligible["customer_id"].to_numpy(dtype=int)))
    return int(rng.choice(all_customer_ids))


def promotion_discount_pct(promotion_lookup: Dict[int, List[Dict[str, object]]], variant_id: int, order_date: pd.Timestamp) -> float:
    active_discounts = []
    for promo in promotion_lookup.get(variant_id, []):
        if pd.Timestamp(promo["start_date"]) <= order_date <= pd.Timestamp(promo["end_date"]):
            active_discounts.append(float(promo["discount_rate"]))
    return max(active_discounts) if active_discounts else 0.0


def sample_order_time(order_date: pd.Timestamp) -> pd.Timestamp:
    hour = random.choices([0, 8, 10, 12, 14, 16, 18, 20, 21, 22], weights=[1, 2, 4, 4, 5, 5, 6, 5, 4, 2], k=1)[0]
    minute = random.randint(0, 59)
    second = random.randint(0, 59)
    return order_date.replace(hour=hour, minute=minute, second=second)


def sample_channel() -> str:
    return random.choices(["web", "app"], weights=[0.42, 0.58], k=1)[0]


def sample_payment_method(year: int) -> str:
    weights = online_payment_weights(year)
    return random.choices(list(weights.keys()), weights=list(weights.values()), k=1)[0]


def sample_shipping_fee(subtotal_amount: float, payment_method: str) -> float:
    if subtotal_amount >= 1200000:
        return 0.0
    base_fee = 32000.0 if subtotal_amount < 600000 else 22000.0
    if payment_method == "installment":
        base_fee += 8000.0
    return base_fee


def choose_fulfillment_source(
    ship_from_store_df: pd.DataFrame,
    warehouse_ids: List[int],
    store_variant_stock: Dict[tuple[int, int], float],
    warehouse_variant_stock: Dict[tuple[int, int], float],
    order_variant_ids: List[int],
) -> Dict[str, object]:
    store_scores = []
    for _, store in ship_from_store_df.iterrows():
        store_stock = sum(store_variant_stock.get((int(store["store_id"]), variant_id), 0.0) for variant_id in order_variant_ids)
        if store_stock <= 0:
            continue
        score = float(store_stock) + (14 if store["store_type"] == "mall" else 7)
        store_scores.append((int(store["store_id"]), score))

    use_store = bool(store_scores) and random.random() < 0.32
    if use_store:
        store_scores.sort(key=lambda x: (-x[1], x[0]))
        return {"fulfilled_from": "store", "store_id": store_scores[0][0], "warehouse_id": None}

    warehouse_scores = []
    for warehouse_id in warehouse_ids:
        warehouse_stock = sum(warehouse_variant_stock.get((int(warehouse_id), variant_id), 0.0) for variant_id in order_variant_ids)
        warehouse_scores.append((int(warehouse_id), float(warehouse_stock)))

    warehouse_scores.sort(key=lambda x: (-x[1], x[0]))
    return {"fulfilled_from": "warehouse", "store_id": None, "warehouse_id": warehouse_scores[0][0]}


def generate_sales_online() -> Dict[str, pd.DataFrame]:
    catalog_df, ship_from_store_df = build_catalog()
    customers_df, city_lookup, all_customer_ids = build_customer_context()
    promotion_lookup = build_promotion_lookup()
    customer_lookup = customers_df.set_index("customer_id").to_dict("index")
    warehouses_df = load_csv("warehouses")
    inventory_current_df = load_csv("inventory_current", parse_dates=["last_updated"])
    warehouse_ids = warehouses_df["warehouse_id"].astype(int).tolist()
    store_inventory_df = inventory_current_df[inventory_current_df["store_id"].notna()].copy()
    store_inventory_df["store_id"] = store_inventory_df["store_id"].astype(int)
    warehouse_inventory_df = inventory_current_df[inventory_current_df["warehouse_id"].notna()].copy()
    warehouse_inventory_df["warehouse_id"] = warehouse_inventory_df["warehouse_id"].astype(int)
    store_variant_stock = {
        (int(row["store_id"]), int(row["variant_id"])): float(row["stock_quantity"])
        for _, row in store_inventory_df.iterrows()
    }
    warehouse_variant_stock = {
        (int(row["warehouse_id"]), int(row["variant_id"])): float(row["stock_quantity"])
        for _, row in warehouse_inventory_df.iterrows()
    }

    variant_lookup = catalog_df.drop_duplicates("variant_id").set_index("variant_id").to_dict("index")

    order_rows: List[Dict] = []
    item_rows: List[Dict] = []
    payment_rows: List[Dict] = []
    fulfillment_rows: List[Dict] = []

    order_id = 1
    item_id = 1
    payment_id = 1
    fulfillment_id = 1

    for month_start in pd.date_range(START_DATE, END_DATE, freq="MS"):
        month_end = min(month_start + pd.offsets.MonthEnd(1), END_DATE)
        variant_pool = build_month_variant_pool(catalog_df, month_start)
        variant_ids = variant_pool["variant_ids"]
        weights = variant_pool["weights"]
        order_count = month_order_count(month_start.year, month_start.month)

        for _ in range(order_count):
            day_offset = int(rng.integers(0, (month_end - month_start).days + 1))
            order_date = month_start + pd.Timedelta(days=day_offset)
            order_datetime = sample_order_time(order_date)
            customer_id = choose_customer_id(customers_df, city_lookup, all_customer_ids, order_date)
            customer_row = customer_lookup[customer_id]

            upt_weights = online_upt_weights(month_start.month)
            upt = random.choices(list(upt_weights.keys()), weights=list(upt_weights.values()), k=1)[0]
            sampled_units = rng.choice(variant_ids, size=upt, replace=True, p=weights)
            unit_counts = pd.Series(sampled_units).value_counts().sort_index()

            subtotal_amount = 0.0
            discount_amount = 0.0
            order_item_variant_ids: List[int] = []

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
                subtotal_amount += gross_sales
                discount_amount += gross_sales - line_total
                order_item_variant_ids.append(int(variant_id))

            subtotal_amount = round(subtotal_amount, 2)
            discount_amount = round(discount_amount, 2)
            payment_method = sample_payment_method(order_datetime.year)
            shipping_fee = round(sample_shipping_fee(subtotal_amount, payment_method), 2)
            total_amount = round(subtotal_amount - discount_amount + shipping_fee, 2)
            channel = sample_channel()

            order_rows.append(
                {
                    "order_id": order_id,
                    "customer_id": customer_id,
                    "order_datetime": order_datetime,
                    "channel": channel,
                    "shipping_address": f"{fake.building_number()} {fake.street_name()}, {customer_row['city_name']}",
                    "payment_method": payment_method,
                    "order_status": "delivered",
                    "subtotal_amount": subtotal_amount,
                    "shipping_fee": shipping_fee,
                    "discount_amount": discount_amount,
                    "total_amount": total_amount,
                }
            )

            source = choose_fulfillment_source(
                ship_from_store_df=ship_from_store_df,
                warehouse_ids=warehouse_ids,
                store_variant_stock=store_variant_stock,
                warehouse_variant_stock=warehouse_variant_stock,
                order_variant_ids=order_item_variant_ids,
            )
            shipped_at = (order_datetime + pd.Timedelta(hours=int(rng.integers(8, 49)))).floor("s")
            delivered_at = (
                shipped_at + pd.Timedelta(days=int(rng.integers(1, 6)), hours=int(rng.integers(1, 13)))
            ).floor("s")

            payment_rows.append(
                {
                    "payment_id": payment_id,
                    "order_id": order_id,
                    "payment_datetime": delivered_at if payment_method == "cod" else order_datetime + pd.Timedelta(minutes=int(rng.integers(1, 31))),
                    "payment_method": payment_method,
                    "payment_status": "paid",
                    "amount_paid": total_amount,
                }
            )
            payment_id += 1

            fulfillment_rows.append(
                {
                    "fulfillment_id": fulfillment_id,
                    "order_id": order_id,
                    "fulfilled_from": source["fulfilled_from"],
                    "store_id": source["store_id"],
                    "warehouse_id": source["warehouse_id"],
                    "fulfillment_status": "delivered",
                    "shipped_at": shipped_at.floor("s"),
                    "delivered_at": delivered_at.floor("s"),
                    "shipping_carrier": random.choice(CARRIER_POOL),
                    "tracking_number": f"TRK{order_id:08d}",
                }
            )
            fulfillment_id += 1
            order_id += 1

    return {
        "online_orders": pd.DataFrame(order_rows),
        "online_order_items": pd.DataFrame(item_rows),
        "online_payments": pd.DataFrame(payment_rows),
        "online_fulfillments": pd.DataFrame(fulfillment_rows),
    }


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    outputs = generate_sales_online()

    for table_name, df in outputs.items():
        save_csv(df, table_name)

    summary = pd.DataFrame(
        {
            "table_name": list(outputs.keys()),
            "row_count": [len(df) for df in outputs.values()],
        }
    )
    save_csv(summary, "_sales_online_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
