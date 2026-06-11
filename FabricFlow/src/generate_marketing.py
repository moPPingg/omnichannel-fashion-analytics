from __future__ import annotations

import random
from pathlib import Path
from typing import Dict, List

import pandas as pd
from faker import Faker

from fashion_rules import SEED, set_global_seeds


set_global_seeds(SEED)
fake = Faker("vi_VN")

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(table_name: str) -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / f"{table_name}.csv", encoding="utf-8-sig")


def generate_promotions(collections_df: pd.DataFrame) -> pd.DataFrame:
    rows: List[Dict] = []
    promotion_id = 1

    for _, collection in collections_df.iterrows():
        launch_start = pd.to_datetime(collection["launch_date"]).date()
        launch_end = pd.to_datetime(collection["launch_date"]).date() + pd.Timedelta(days=13)
        end_date = pd.to_datetime(collection["end_date"]).date()
        markdown_start = end_date - pd.Timedelta(days=45)
        rows.append(
            {
                "promotion_id": promotion_id,
                "promotion_name": f"{collection['collection_name']} Launch Campaign",
                "promotion_type": "new_launch",
                "start_date": launch_start,
                "end_date": launch_end,
                "channel_scope": "omnichannel",
                "discount_rate": 10.00,
            }
        )
        promotion_id += 1
        rows.append(
            {
                "promotion_id": promotion_id,
                "promotion_name": f"{collection['collection_name']} End Season Markdown",
                "promotion_type": "end_of_season",
                "start_date": markdown_start,
                "end_date": end_date,
                "channel_scope": "omnichannel",
                "discount_rate": 30.00 if collection["season"] == "SS" else 40.00,
            }
        )
        promotion_id += 1

    extra_promotions = [
        ("Member Day Q1", "member_day", "2026-03-15", "2026-03-17", "omnichannel", 15.00),
        ("Summer Flash Sale", "flash_sale", "2026-06-20", "2026-06-22", "online", 25.00),
        ("Member Day Q3", "member_day", "2026-09-12", "2026-09-14", "omnichannel", 15.00),
        ("Year End Flash Sale", "flash_sale", "2026-12-20", "2026-12-24", "online", 35.00),
    ]
    for name, promo_type, start_date, end_date, channel_scope, discount_rate in extra_promotions:
        rows.append(
            {
                "promotion_id": promotion_id,
                "promotion_name": name,
                "promotion_type": promo_type,
                "start_date": start_date,
                "end_date": end_date,
                "channel_scope": channel_scope,
                "discount_rate": discount_rate,
            }
        )
        promotion_id += 1

    return pd.DataFrame(rows)


def generate_promotion_products(promotions_df: pd.DataFrame, variants_df: pd.DataFrame, products_df: pd.DataFrame) -> pd.DataFrame:
    product_collection = products_df.set_index("product_id")["collection_id"].to_dict()
    variants_df = variants_df.copy()
    variants_df["collection_id"] = variants_df["product_id"].map(product_collection)

    rows: List[Dict] = []
    promotion_product_id = 1

    for _, promotion in promotions_df.iterrows():
        promotion_name = promotion["promotion_name"]
        discount_rate = float(promotion["discount_rate"])
        if "Launch Campaign" in promotion_name:
            # Use variants_df directly after matching collection name through collection_id map.
            collection_variants = variants_df[variants_df["collection_id"] == _promotion_collection_id(promotion_name, promotions_df, products_df)]
            selected = collection_variants.sample(n=90, random_state=SEED + int(promotion["promotion_id"]))
        elif "End Season Markdown" in promotion_name:
            collection_variants = variants_df[variants_df["collection_id"] == _promotion_collection_id(promotion_name, promotions_df, products_df)]
            selected = collection_variants.sample(n=120, random_state=SEED + int(promotion["promotion_id"]))
        else:
            selected = variants_df.sample(n=80, random_state=SEED + int(promotion["promotion_id"]))

        for _, variant in selected.iterrows():
            rows.append(
                {
                    "promotion_product_id": promotion_product_id,
                    "promotion_id": int(promotion["promotion_id"]),
                    "variant_id": int(variant["variant_id"]),
                    "discount_rate": round(discount_rate, 2),
                }
            )
            promotion_product_id += 1

    return pd.DataFrame(rows)


def _promotion_collection_id(promotion_name: str, promotions_df: pd.DataFrame, products_df: pd.DataFrame) -> int:
    collection_name = promotion_name.replace(" Launch Campaign", "").replace(" End Season Markdown", "")
    # collections are loaded separately in generator scope through promotions order.
    # Map SS23..FW26 names to numeric ids.
    collection_names = ["SS23", "FW23", "SS24", "FW24", "SS25", "FW25", "SS26", "FW26"]
    return collection_names.index(collection_name) + 1


def generate_collection_events(collections_df: pd.DataFrame) -> pd.DataFrame:
    rows: List[Dict] = []
    event_id = 1

    for _, collection in collections_df.iterrows():
        launch_date = pd.to_datetime(collection["launch_date"]).date()
        rows.append(
            {
                "collection_event_id": event_id,
                "collection_id": int(collection["collection_id"]),
                "event_name": f"{collection['collection_name']} Launch Event",
                "event_type": "launch_event",
                "event_date": launch_date,
                "budget_amount": 18000000 if collection["season"] == "SS" else 22000000,
                "notes": "Main seasonal collection launch",
            }
        )
        event_id += 1
        rows.append(
            {
                "collection_event_id": event_id,
                "collection_id": int(collection["collection_id"]),
                "event_name": f"{collection['collection_name']} Influencer Seeding",
                "event_type": "influencer_seeding",
                "event_date": launch_date + pd.Timedelta(days=7),
                "budget_amount": 9000000,
                "notes": "Social buzz amplification",
            }
        )
        event_id += 1

    return pd.DataFrame(rows)


def generate_store_targets(stores_df: pd.DataFrame) -> pd.DataFrame:
    rows: List[Dict] = []
    store_target_id = 1
    month_factors = {1: 0.90, 2: 0.95, 3: 1.10, 4: 1.05, 5: 1.00, 6: 1.08, 7: 1.02, 8: 0.98, 9: 1.12, 10: 1.06, 11: 1.15, 12: 1.25}

    for _, store in stores_df.iterrows():
        is_mall = store["store_type"] == "mall"
        base_revenue = 2200000000 if is_mall else 1200000000
        base_sell_through = 72.0 if is_mall else 64.0
        base_upt = 2.1 if is_mall else 1.8

        for month in range(1, 13):
            factor = month_factors[month]
            rows.append(
                {
                    "store_target_id": store_target_id,
                    "store_id": int(store["store_id"]),
                    "target_year": 2026,
                    "target_month": month,
                    "revenue_target": round(base_revenue * factor, 2),
                    "sell_through_target_pct": round(min(base_sell_through + (factor - 1.0) * 10, 85.0), 2),
                    "upt_target": round(base_upt + (0.10 if month in (3, 9, 12) else 0.00), 2),
                }
            )
            store_target_id += 1

    return pd.DataFrame(rows)


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    collections_df = load_csv("collections")
    stores_df = load_csv("stores")
    products_df = load_csv("products")
    variants_df = load_csv("product_variants")

    promotions_df = generate_promotions(collections_df)
    promotion_products_df = generate_promotion_products(promotions_df, variants_df, products_df)
    collection_events_df = generate_collection_events(collections_df)
    store_targets_df = generate_store_targets(stores_df)

    save_csv(promotions_df, "promotions")
    save_csv(promotion_products_df, "promotion_products")
    save_csv(collection_events_df, "collection_events")
    save_csv(store_targets_df, "store_targets")

    summary = pd.DataFrame(
        {
            "table_name": ["promotions", "promotion_products", "collection_events", "store_targets"],
            "row_count": [len(promotions_df), len(promotion_products_df), len(collection_events_df), len(store_targets_df)],
        }
    )
    save_csv(summary, "_marketing_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
