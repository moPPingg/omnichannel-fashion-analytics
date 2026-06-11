from __future__ import annotations

import random
from typing import Dict, List, Tuple

import numpy as np
from faker import Faker


SEED = 42


def set_global_seeds(seed: int = SEED) -> None:
    random.seed(seed)
    np.random.seed(seed)
    Faker.seed(seed)


SIZE_DIST: Dict[str, Dict[str, float]] = {
    "male": {"XS": 0.04, "S": 0.15, "M": 0.32, "L": 0.30, "XL": 0.14, "XXL": 0.05},
    "female": {"XS": 0.08, "S": 0.25, "M": 0.35, "L": 0.22, "XL": 0.08, "XXL": 0.02},
    "kids": {"2": 0.08, "4": 0.20, "6": 0.28, "8": 0.25, "10": 0.14, "12": 0.05},
}


ONLINE_RETURN_RATE = {
    "Tops": 0.22,
    "Bottoms": 0.28,
    "Dresses": 0.25,
    "Outerwear": 0.15,
    "Accessories": 0.08,
    "Footwear": 0.30,
    "Kids": 0.12,
}


NEUTRAL_COLORS: List[Tuple[str, str]] = [
    ("Black", "#000000"),
    ("White", "#FFFFFF"),
    ("Beige", "#F5F5DC"),
]

TREND_COLORS: List[Tuple[str, str]] = [
    ("Cobalt Blue", "#0047AB"),
    ("Orange", "#FF8C00"),
]


OFFLINE_MONTH_FACTORS = {
    1: 0.88,
    2: 0.94,
    3: 1.12,
    4: 1.05,
    5: 1.00,
    6: 1.08,
    7: 1.04,
    8: 0.98,
    9: 1.15,
    10: 1.07,
    11: 1.13,
    12: 1.24,
}


OFFLINE_YEAR_FACTORS = {
    2023: 0.82,
    2024: 0.95,
    2025: 1.05,
    2026: 1.16,
}


CATEGORY_DEMAND_WEIGHTS = {
    "Tops": 1.25,
    "Bottoms": 1.18,
    "Dresses": 0.92,
    "Outerwear": 0.86,
    "Accessories": 0.78,
    "Footwear": 0.74,
    "Kids Tops": 0.88,
    "Kids Bottoms": 0.82,
}


CATEGORY_BLUEPRINT = [
    {"category_name": "Tops", "category_group": "Apparel", "target_gender": "unisex", "target_age_group": "adult"},
    {"category_name": "Bottoms", "category_group": "Apparel", "target_gender": "unisex", "target_age_group": "adult"},
    {"category_name": "Dresses", "category_group": "Apparel", "target_gender": "female", "target_age_group": "adult"},
    {"category_name": "Outerwear", "category_group": "Apparel", "target_gender": "unisex", "target_age_group": "adult"},
    {"category_name": "Accessories", "category_group": "Accessories", "target_gender": "unisex", "target_age_group": "all"},
    {"category_name": "Footwear", "category_group": "Footwear", "target_gender": "unisex", "target_age_group": "adult"},
    {"category_name": "Kids Tops", "category_group": "Apparel", "target_gender": "kids", "target_age_group": "kids"},
    {"category_name": "Kids Bottoms", "category_group": "Apparel", "target_gender": "kids", "target_age_group": "kids"},
]


REGION_BLUEPRINT = [
    {"region_code": "RGN-NORTH", "region_name": "North", "city_name": "Ha Noi"},
    {"region_code": "RGN-CENTRAL", "region_name": "Central", "city_name": "Da Nang"},
    {"region_code": "RGN-SOUTH", "region_name": "South", "city_name": "Ho Chi Minh City"},
    {"region_code": "RGN-MEKONG", "region_name": "Mekong", "city_name": "Can Tho"},
]


WAREHOUSE_BLUEPRINT = [
    {
        "warehouse_code": "WH-HN-01",
        "warehouse_name": "Ha Noi Distribution Center",
        "warehouse_type": "central",
        "region_code": "RGN-NORTH",
        "capacity_units": 180000,
    },
    {
        "warehouse_code": "WH-HCM-01",
        "warehouse_name": "Ho Chi Minh Distribution Center",
        "warehouse_type": "central",
        "region_code": "RGN-SOUTH",
        "capacity_units": 240000,
    },
]


STORE_BLUEPRINT = [
    {"store_code": "STR-HN-01", "store_name": "FabricFlow Vincom Ba Trieu", "region_code": "RGN-NORTH", "store_type": "mall"},
    {"store_code": "STR-HN-02", "store_name": "FabricFlow Xuan Thuy", "region_code": "RGN-NORTH", "store_type": "street"},
    {"store_code": "STR-HN-03", "store_name": "FabricFlow Aeon Long Bien", "region_code": "RGN-NORTH", "store_type": "mall"},
    {"store_code": "STR-DN-01", "store_name": "FabricFlow Vincom Da Nang", "region_code": "RGN-CENTRAL", "store_type": "mall"},
    {"store_code": "STR-DN-02", "store_name": "FabricFlow Nguyen Van Linh", "region_code": "RGN-CENTRAL", "store_type": "street"},
    {"store_code": "STR-HCM-01", "store_name": "FabricFlow Crescent Mall", "region_code": "RGN-SOUTH", "store_type": "mall"},
    {"store_code": "STR-HCM-02", "store_name": "FabricFlow Le Van Sy", "region_code": "RGN-SOUTH", "store_type": "street"},
    {"store_code": "STR-HCM-03", "store_name": "FabricFlow Landmark 81", "region_code": "RGN-SOUTH", "store_type": "mall"},
    {"store_code": "STR-CT-01", "store_name": "FabricFlow Sense City Can Tho", "region_code": "RGN-MEKONG", "store_type": "mall"},
    {"store_code": "STR-CT-02", "store_name": "FabricFlow 30 Thang 4", "region_code": "RGN-MEKONG", "store_type": "street"},
]


MALE_STYLE_WORDS = ["Urban", "Classic", "Relaxed", "Tailored", "Essential", "Modern"]
FEMALE_STYLE_WORDS = ["Soft", "Chic", "Flowy", "Minimal", "Elegant", "Modern"]
KIDS_STYLE_WORDS = ["Play", "Happy", "Bright", "Soft", "Active", "Mini"]

CATEGORY_PRODUCT_TERMS = {
    "Tops": ["Tee", "Shirt", "Polo", "Sweater", "Blouse"],
    "Bottoms": ["Jeans", "Trousers", "Shorts", "Skirt", "Pants"],
    "Dresses": ["Midi Dress", "Mini Dress", "Maxi Dress", "Wrap Dress"],
    "Outerwear": ["Jacket", "Coat", "Blazer", "Bomber", "Cardigan"],
    "Accessories": ["Cap", "Scarf", "Belt", "Bag", "Wallet"],
    "Footwear": ["Sneaker", "Loafer", "Sandals", "Boots"],
    "Kids Tops": ["Kids Tee", "Kids Polo", "Kids Hoodie", "Kids Shirt"],
    "Kids Bottoms": ["Kids Shorts", "Kids Jeans", "Kids Joggers", "Kids Skirt"],
}


def collection_week_factor(weeks_since_launch: int) -> float:
    if weeks_since_launch <= 2:
        return 1.8
    if weeks_since_launch <= 6:
        return 1.3
    if weeks_since_launch <= 12:
        return 1.0
    if weeks_since_launch <= 18:
        return 0.7
    if weeks_since_launch <= 22:
        return 0.5
    return 1.2


def get_markdown_pct(sell_through_rate: float, weeks_to_end_season: int) -> float:
    if sell_through_rate >= 0.80:
        return 0.0
    if sell_through_rate >= 0.65:
        return 0.20 if weeks_to_end_season <= 4 else 0.0
    if sell_through_rate >= 0.50:
        return 0.30
    if sell_through_rate >= 0.35:
        return 0.40
    return 0.50


def offline_upt_weights(store_type: str, month: int) -> Dict[int, float]:
    if store_type == "mall":
        if month in {3, 9, 12}:
            return {1: 0.14, 2: 0.50, 3: 0.27, 4: 0.09}
        return {1: 0.18, 2: 0.54, 3: 0.22, 4: 0.06}
    if month in {3, 9, 12}:
        return {1: 0.22, 2: 0.56, 3: 0.18, 4: 0.04}
    return {1: 0.27, 2: 0.56, 3: 0.14, 4: 0.03}


def offline_payment_weights(year: int) -> Dict[str, float]:
    if year <= 2024:
        return {"cash": 0.34, "card": 0.46, "e-wallet": 0.20}
    if year == 2025:
        return {"cash": 0.25, "card": 0.47, "e-wallet": 0.28}
    return {"cash": 0.18, "card": 0.48, "e-wallet": 0.34}


def sizes_for_gender(style_gender: str) -> List[str]:
    return list(SIZE_DIST[style_gender].keys())


def choose_style_gender(category_name: str, target_gender: str) -> str:
    if target_gender in {"female", "kids"}:
        return target_gender
    if category_name == "Dresses":
        return "female"
    return random.choice(["male", "female"])


def choose_product_colors(is_noos: bool) -> List[Tuple[str, str]]:
    if is_noos:
        return list(NEUTRAL_COLORS)
    return [random.choice(NEUTRAL_COLORS), *TREND_COLORS]


def product_name_for_category(category_name: str, style_gender: str) -> str:
    if style_gender == "male":
        prefix = random.choice(MALE_STYLE_WORDS)
    elif style_gender == "female":
        prefix = random.choice(FEMALE_STYLE_WORDS)
    else:
        prefix = random.choice(KIDS_STYLE_WORDS)
    noun = random.choice(CATEGORY_PRODUCT_TERMS[category_name])
    return f"{prefix} {noun}"


set_global_seeds()
