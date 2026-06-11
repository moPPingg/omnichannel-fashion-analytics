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

SUPPLIER_BLUEPRINT = [
    ("SUP001", "VietFabric Sourcing", "premium", 4),
    ("SUP002", "Saigon Textile Partners", "core", 5),
    ("SUP003", "Hanoi Apparel Supply", "core", 6),
    ("SUP004", "Mekong Material House", "value", 7),
    ("SUP005", "Pacific Fashion Materials", "premium", 8),
    ("SUP006", "Lotus Garment Inputs", "core", 5),
]

FACTORY_BLUEPRINT = [
    ("FAC001", "Ho Chi Minh Sewing Hub", "Vietnam", 1, 32000, 0.0180, 120),
    ("FAC002", "Binh Duong Apparel Works", "Vietnam", 2, 28000, 0.0220, 150),
    ("FAC003", "Da Nang Fashion Makers", "Vietnam", 3, 18000, 0.0200, 100),
    ("FAC004", "Phnom Penh Cut & Sew", "Cambodia", 4, 26000, 0.0280, 180),
    ("FAC005", "Shenzhen Trend Manufacturing", "China", 5, 35000, 0.0300, 200),
    ("FAC006", "Guangzhou Footwear Lab", "China", 5, 22000, 0.0260, 160),
    ("FAC007", "Dhaka Kids Knit Unit", "Bangladesh", 6, 30000, 0.0340, 220),
    ("FAC008", "Can Tho Accessories Studio", "Vietnam", 4, 12000, 0.0150, 80),
]


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_products() -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / "products.csv", encoding="utf-8-sig")


def load_categories() -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / "categories.csv", encoding="utf-8-sig")


def generate_suppliers() -> pd.DataFrame:
    rows: List[Dict] = []
    for supplier_id, (supplier_code, supplier_name, quality_tier, lead_time_weeks) in enumerate(SUPPLIER_BLUEPRINT, start=1):
        rows.append(
            {
                "supplier_id": supplier_id,
                "supplier_code": supplier_code,
                "supplier_name": supplier_name,
                "quality_tier": quality_tier,
                "lead_time_weeks": lead_time_weeks,
                "is_active": 1,
            }
        )
    return pd.DataFrame(rows)


def generate_factories() -> pd.DataFrame:
    rows: List[Dict] = []
    for factory_id, (factory_code, factory_name, country_name, supplier_id, capacity_units_per_month, defect_rate, moq_units) in enumerate(
        FACTORY_BLUEPRINT, start=1
    ):
        rows.append(
            {
                "factory_id": factory_id,
                "supplier_id": supplier_id,
                "factory_code": factory_code,
                "factory_name": factory_name,
                "country_name": country_name,
                "capacity_units_per_month": capacity_units_per_month,
                "defect_rate": round(defect_rate, 4),
                "moq_units": moq_units,
                "is_active": 1,
            }
        )
    return pd.DataFrame(rows)


def _candidate_factories(category_name: str) -> List[int]:
    if category_name == "Footwear":
        return [6, 5]
    if category_name == "Accessories":
        return [8, 1]
    if category_name.startswith("Kids"):
        return [7, 4]
    if category_name == "Outerwear":
        return [5, 1]
    return [1, 2, 3, 4, 5]


def generate_factory_products(products_df: pd.DataFrame, categories_df: pd.DataFrame) -> pd.DataFrame:
    category_lookup = categories_df.set_index("category_id")["category_name"].to_dict()
    rows: List[Dict] = []
    factory_product_id = 1

    for _, product in products_df.iterrows():
        category_name = category_lookup[int(product["category_id"])]
        candidates = _candidate_factories(category_name)
        selected = candidates[:2] if len(candidates) >= 2 else candidates
        base_cost = float(product["cost_price"])
        for idx, factory_id in enumerate(selected):
            multiplier = 0.94 if idx == 0 else 1.02
            lead_time = 4 + ((factory_id + int(product["product_id"])) % 5)
            moq_units = 120 + (((int(product["product_id"]) * (idx + 1)) + factory_id) % 9) * 40
            rows.append(
                {
                    "factory_product_id": factory_product_id,
                    "factory_id": factory_id,
                    "product_id": int(product["product_id"]),
                    "production_cost": round(base_cost * multiplier, 2),
                    "lead_time_weeks": lead_time,
                    "moq_units": moq_units,
                    "is_primary_factory": 1 if idx == 0 else 0,
                }
            )
            factory_product_id += 1

    return pd.DataFrame(rows)


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    products_df = load_products()
    categories_df = load_categories()

    suppliers_df = generate_suppliers()
    factories_df = generate_factories()
    factory_products_df = generate_factory_products(products_df, categories_df)

    save_csv(suppliers_df, "suppliers")
    save_csv(factories_df, "factories")
    save_csv(factory_products_df, "factory_products")

    summary = pd.DataFrame(
        {
            "table_name": ["suppliers", "factories", "factory_products"],
            "row_count": [len(suppliers_df), len(factories_df), len(factory_products_df)],
        }
    )
    save_csv(summary, "_supply_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
