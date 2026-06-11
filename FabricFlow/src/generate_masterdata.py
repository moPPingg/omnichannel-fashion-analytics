from __future__ import annotations

import random
from pathlib import Path
from typing import Dict, List

import numpy as np
import pandas as pd
from faker import Faker

from fashion_rules import (
    CATEGORY_BLUEPRINT,
    REGION_BLUEPRINT,
    SEED,
    SIZE_DIST,
    STORE_BLUEPRINT,
    WAREHOUSE_BLUEPRINT,
    choose_product_colors,
    choose_style_gender,
    product_name_for_category,
    set_global_seeds,
    sizes_for_gender,
)


set_global_seeds(SEED)
fake = Faker("vi_VN")


BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def generate_regions() -> pd.DataFrame:
    rows: List[Dict] = []
    for idx, item in enumerate(REGION_BLUEPRINT, start=1):
        rows.append(
            {
                "region_id": idx,
                "region_code": item["region_code"],
                "region_name": item["region_name"],
                "city_name": item["city_name"],
                "is_active": 1,
            }
        )
    return pd.DataFrame(rows)


def generate_warehouses(regions_df: pd.DataFrame) -> pd.DataFrame:
    region_lookup = regions_df.set_index("region_code")["region_id"].to_dict()
    rows: List[Dict] = []
    for idx, item in enumerate(WAREHOUSE_BLUEPRINT, start=1):
        city = regions_df.loc[regions_df["region_code"] == item["region_code"], "city_name"].iloc[0]
        rows.append(
            {
                "warehouse_id": idx,
                "region_id": int(region_lookup[item["region_code"]]),
                "warehouse_code": item["warehouse_code"],
                "warehouse_name": item["warehouse_name"],
                "warehouse_type": item["warehouse_type"],
                "address_line": f"{fake.building_number()} {fake.street_name()}, {city}",
                "capacity_units": item["capacity_units"],
                "supports_online_fulfillment": 1,
                "is_active": 1,
            }
        )
    return pd.DataFrame(rows)


def generate_stores(regions_df: pd.DataFrame, warehouses_df: pd.DataFrame) -> pd.DataFrame:
    region_lookup = regions_df.set_index("region_code")["region_id"].to_dict()
    warehouse_lookup = {
        "RGN-NORTH": int(warehouses_df.loc[warehouses_df["warehouse_code"] == "WH-HN-01", "warehouse_id"].iloc[0]),
        "RGN-CENTRAL": int(warehouses_df.loc[warehouses_df["warehouse_code"] == "WH-HCM-01", "warehouse_id"].iloc[0]),
        "RGN-SOUTH": int(warehouses_df.loc[warehouses_df["warehouse_code"] == "WH-HCM-01", "warehouse_id"].iloc[0]),
        "RGN-MEKONG": int(warehouses_df.loc[warehouses_df["warehouse_code"] == "WH-HCM-01", "warehouse_id"].iloc[0]),
    }
    rows: List[Dict] = []
    for idx, item in enumerate(STORE_BLUEPRINT, start=1):
        region_city = regions_df.loc[regions_df["region_code"] == item["region_code"], "city_name"].iloc[0]
        is_mall = item["store_type"] == "mall"
        rows.append(
            {
                "store_id": idx,
                "region_id": int(region_lookup[item["region_code"]]),
                "warehouse_id": warehouse_lookup[item["region_code"]],
                "store_code": item["store_code"],
                "store_name": item["store_name"],
                "store_type": item["store_type"],
                "address_line": f"{fake.building_number()} {fake.street_name()}, {region_city}",
                "open_date": fake.date_between(start_date="-8y", end_date="-1y"),
                "area_sqm": round(random.uniform(180, 450) if is_mall else random.uniform(90, 180), 2),
                "demand_multiplier": round(random.uniform(1.10, 1.35) if is_mall else random.uniform(0.80, 1.00), 4),
                "supports_ship_from_store": 1 if is_mall else random.choice([0, 1]),
                "is_active": 1,
            }
        )
    return pd.DataFrame(rows)


def generate_collections() -> pd.DataFrame:
    rows: List[Dict] = []
    collection_specs = [
        ("SS23", "SS", 2023, "2023-03-01", "2023-08-31"),
        ("FW23", "FW", 2023, "2023-09-01", "2024-02-29"),
        ("SS24", "SS", 2024, "2024-03-01", "2024-08-31"),
        ("FW24", "FW", 2024, "2024-09-01", "2025-02-28"),
        ("SS25", "SS", 2025, "2025-03-01", "2025-08-31"),
        ("FW25", "FW", 2025, "2025-09-01", "2026-02-28"),
        ("SS26", "SS", 2026, "2026-03-01", "2026-08-31"),
        ("FW26", "FW", 2026, "2026-09-01", "2027-02-28"),
    ]
    for idx, (name, season, year, launch_date, end_date) in enumerate(collection_specs, start=1):
        rows.append(
            {
                "collection_id": idx,
                "collection_name": name,
                "season": season,
                "year": year,
                "launch_date": launch_date,
                "end_date": end_date,
                "planned_units": int(random.randrange(18000, 30001, 500)),
            }
        )
    return pd.DataFrame(rows)


def generate_categories() -> pd.DataFrame:
    rows: List[Dict] = []
    for idx, item in enumerate(CATEGORY_BLUEPRINT, start=1):
        rows.append(
            {
                "category_id": idx,
                "category_name": item["category_name"],
                "category_group": item["category_group"],
                "target_gender": item["target_gender"],
                "target_age_group": item["target_age_group"],
                "is_active": 1,
            }
        )
    return pd.DataFrame(rows)


def generate_products(collections_df: pd.DataFrame, categories_df: pd.DataFrame, product_count: int = 200) -> pd.DataFrame:
    products_per_category = product_count // len(categories_df)
    collection_ids = collections_df["collection_id"].tolist()
    rows: List[Dict] = []
    product_id = 1
    noos_product_ids = set(random.sample(range(1, product_count + 1), int(product_count * 0.20)))

    for _, category in categories_df.iterrows():
        category_name = category["category_name"]
        target_gender = category["target_gender"]
        for _ in range(products_per_category):
            style_gender = choose_style_gender(category_name, target_gender)
            product_name = product_name_for_category(category_name, style_gender)
            base_price = float(random.randrange(249000, 1599001, 50000))
            cost_price = round(base_price * random.uniform(0.42, 0.58), 2)
            rows.append(
                {
                    "product_id": product_id,
                    "collection_id": int(collection_ids[(product_id - 1) % len(collection_ids)]),
                    "category_id": int(category["category_id"]),
                    "product_name": f"{product_name} {product_id:03d}",
                    "base_price": round(base_price, 2),
                    "cost_price": round(cost_price, 2),
                    "is_noos": 1 if product_id in noos_product_ids else 0,
                    "style_gender": style_gender,
                }
            )
            product_id += 1

    return pd.DataFrame(rows)


def generate_product_variants(products_df: pd.DataFrame) -> pd.DataFrame:
    rows: List[Dict] = []
    variant_id = 1

    for _, product in products_df.iterrows():
        style_gender = product["style_gender"]
        sizes = sizes_for_gender(style_gender)
        colors = choose_product_colors(bool(product["is_noos"]))
        for color_name, color_code in colors:
            for size in sizes:
                sku_code = f"SKU-{product['product_id']:04d}-{color_name[:2].upper().replace(' ', '')}-{size}"
                rows.append(
                    {
                        "variant_id": variant_id,
                        "product_id": int(product["product_id"]),
                        "sku_code": sku_code,
                        "size": size,
                        "color": color_name,
                        "color_code": color_code,
                        "selling_price": round(float(product["base_price"]), 2),
                        "current_price": round(float(product["base_price"]), 2),
                        "is_active": 1,
                    }
                )
                variant_id += 1

    return pd.DataFrame(rows)


def generate_customers(customer_count: int = 15000) -> pd.DataFrame:
    city_pool = [item["city_name"] for item in REGION_BLUEPRINT]
    member_statuses = ["Non-member", "Silver", "Gold", "Platinum"]
    age_groups = ["Gen Z", "Millennial", "Gen X", "Family"]
    preferred_channels = ["offline", "online", "omnichannel"]
    gender_values = ["male", "female", "other"]
    rows: List[Dict] = []

    for customer_id in range(1, customer_count + 1):
        rows.append(
            {
                "customer_id": customer_id,
                "customer_code": f"CUS{customer_id:06d}",
                "full_name": fake.name(),
                "gender": random.choices(gender_values, weights=[0.45, 0.50, 0.05], k=1)[0],
                "age_group": random.choices(age_groups, weights=[0.22, 0.42, 0.21, 0.15], k=1)[0],
                "member_status": random.choices(member_statuses, weights=[0.30, 0.35, 0.25, 0.10], k=1)[0],
                "preferred_channel": random.choices(preferred_channels, weights=[0.28, 0.27, 0.45], k=1)[0],
                "city_name": random.choice(city_pool),
                "signup_date": fake.date_between(start_date="-5y", end_date="today"),
                "is_active": 1,
            }
        )

    return pd.DataFrame(rows)


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()

    regions_df = generate_regions()
    warehouses_df = generate_warehouses(regions_df)
    stores_df = generate_stores(regions_df, warehouses_df)
    collections_df = generate_collections()
    categories_df = generate_categories()
    products_df = generate_products(collections_df, categories_df, product_count=200)
    variants_df = generate_product_variants(products_df)
    customers_df = generate_customers(customer_count=15000)

    export_products_df = products_df.drop(columns=["style_gender"])

    save_csv(regions_df, "regions")
    save_csv(warehouses_df, "warehouses")
    save_csv(stores_df, "stores")
    save_csv(collections_df, "collections")
    save_csv(categories_df, "categories")
    save_csv(export_products_df, "products")
    save_csv(variants_df, "product_variants")
    save_csv(customers_df, "customers")

    summary = pd.DataFrame(
        {
            "table_name": [
                "regions",
                "warehouses",
                "stores",
                "collections",
                "categories",
                "products",
                "product_variants",
                "customers",
            ],
            "row_count": [
                len(regions_df),
                len(warehouses_df),
                len(stores_df),
                len(collections_df),
                len(categories_df),
                len(export_products_df),
                len(variants_df),
                len(customers_df),
            ],
        }
    )
    save_csv(summary, "_masterdata_summary")
    print(summary.to_string(index=False))
    print(f"CSV files written to: {RAW_DIR}")


if __name__ == "__main__":
    main()
