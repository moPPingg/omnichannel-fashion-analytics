from __future__ import annotations

import random
from pathlib import Path
from typing import Dict, List

import pandas as pd
from faker import Faker

from fashion_rules import SEED, SIZE_DIST, set_global_seeds


set_global_seeds(SEED)
fake = Faker("vi_VN")

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"

DEFECT_TYPES = ["stitch_issue", "shade_variation", "measurement_issue", "packaging_damage", None]


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(table_name: str) -> pd.DataFrame:
    parse_dates = ["launch_date", "end_date"] if table_name == "collections" else []
    return pd.read_csv(RAW_DIR / f"{table_name}.csv", encoding="utf-8-sig", parse_dates=parse_dates)


def size_weight(size_value: str) -> float:
    if str(size_value).isdigit():
        return SIZE_DIST["kids"][str(size_value)]
    adult_weights = {"XS": 0.06, "S": 0.20, "M": 0.335, "L": 0.26, "XL": 0.11, "XXL": 0.035}
    return adult_weights[str(size_value)]


def generate_purchase_supply() -> Dict[str, pd.DataFrame]:
    collections_df = load_csv("collections")
    products_df = load_csv("products")
    variants_df = load_csv("product_variants")
    factories_df = load_csv("factories")
    factory_products_df = load_csv("factory_products")
    warehouses_df = load_csv("warehouses")

    collection_lookup = collections_df.set_index("collection_id").to_dict("index")
    product_lookup = products_df.set_index("product_id").to_dict("index")
    factory_lookup = factories_df.set_index("factory_id").to_dict("index")
    primary_factory_df = factory_products_df[factory_products_df["is_primary_factory"] == 1].copy()
    primary_factory_lookup = primary_factory_df.set_index("product_id").to_dict("index")
    warehouse_ids = warehouses_df["warehouse_id"].tolist()

    variants_enriched = variants_df.copy()
    variants_enriched["collection_id"] = variants_enriched["product_id"].map(lambda pid: int(product_lookup[int(pid)]["collection_id"]))
    variants_enriched["primary_factory_id"] = variants_enriched["product_id"].map(
        lambda pid: int(primary_factory_lookup[int(pid)]["factory_id"])
    )
    variants_enriched["unit_cost"] = variants_enriched["product_id"].map(
        lambda pid: float(primary_factory_lookup[int(pid)]["production_cost"])
    )

    grouped = variants_enriched.groupby(["collection_id", "primary_factory_id"], sort=True)

    po_rows: List[Dict] = []
    poi_rows: List[Dict] = []
    gr_rows: List[Dict] = []
    qc_rows: List[Dict] = []

    purchase_order_id = 1
    purchase_order_item_id = 1
    goods_receipt_id = 1
    quality_check_id = 1

    for (collection_id, factory_id), group in grouped:
        collection = collection_lookup[int(collection_id)]
        factory = factory_lookup[int(factory_id)]
        supplier_id = int(factory["supplier_id"])
        launch_date = pd.to_datetime(collection["launch_date"]).date()
        po_date = launch_date - pd.Timedelta(days=70 + (int(factory_id) % 14))
        planned_delivery_date = launch_date - pd.Timedelta(days=14 - (int(factory_id) % 6))

        total_order_amount = 0.0
        total_ordered_qty = 0

        for _, variant in group.sort_values("variant_id").iterrows():
            weight = size_weight(str(variant["size"]))
            ordered_quantity = max(18, int(round(220 * weight)))
            ordered_quantity += int(variant["variant_id"]) % 7
            unit_cost = round(float(variant["unit_cost"]), 2)
            line_amount = round(ordered_quantity * unit_cost, 2)
            total_order_amount += line_amount
            total_ordered_qty += ordered_quantity

            poi_rows.append(
                {
                    "purchase_order_item_id": purchase_order_item_id,
                    "purchase_order_id": purchase_order_id,
                    "variant_id": int(variant["variant_id"]),
                    "ordered_quantity": ordered_quantity,
                    "unit_cost": unit_cost,
                    "line_amount": line_amount,
                }
            )
            purchase_order_item_id += 1

        po_rows.append(
            {
                "purchase_order_id": purchase_order_id,
                "supplier_id": supplier_id,
                "factory_id": int(factory_id),
                "collection_id": int(collection_id),
                "po_date": po_date,
                "planned_delivery_date": planned_delivery_date,
                "po_status": "received",
                "total_order_amount": round(total_order_amount, 2),
            }
        )

        receipt_variance_days = (int(factory_id) % 5) - 1
        actual_delivery_date = planned_delivery_date + pd.Timedelta(days=receipt_variance_days)
        receipt_date = actual_delivery_date
        received_qty = max(int(total_ordered_qty * 0.94), total_ordered_qty - (8 + int(factory_id)))
        received_qty = min(received_qty, total_ordered_qty)
        warehouse_id = warehouse_ids[(int(collection_id) + int(factory_id)) % len(warehouse_ids)]

        gr_rows.append(
            {
                "goods_receipt_id": goods_receipt_id,
                "purchase_order_id": purchase_order_id,
                "warehouse_id": int(warehouse_id),
                "receipt_date": receipt_date,
                "actual_delivery_date": actual_delivery_date,
                "received_qty": int(received_qty),
                "receipt_status": "received",
            }
        )

        factory_defect_rate = float(factory["defect_rate"])
        rejected_qty = int(round(received_qty * factory_defect_rate))
        accepted_qty = int(received_qty - rejected_qty)
        defect_type = DEFECT_TYPES[int(factory_id) % len(DEFECT_TYPES)] if rejected_qty > 0 else None

        qc_rows.append(
            {
                "quality_check_id": quality_check_id,
                "goods_receipt_id": goods_receipt_id,
                "check_date": receipt_date + pd.Timedelta(days=1),
                "accepted_qty": accepted_qty,
                "rejected_qty": rejected_qty,
                "defect_type": defect_type,
                "quality_status": "accepted_with_minor_defect" if rejected_qty > 0 else "accepted",
            }
        )

        purchase_order_id += 1
        goods_receipt_id += 1
        quality_check_id += 1

    return {
        "purchase_orders": pd.DataFrame(po_rows),
        "purchase_order_items": pd.DataFrame(poi_rows),
        "goods_receipts": pd.DataFrame(gr_rows),
        "quality_checks": pd.DataFrame(qc_rows),
    }


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    outputs = generate_purchase_supply()

    for table_name, df in outputs.items():
        save_csv(df, table_name)

    summary = pd.DataFrame(
        {
            "table_name": list(outputs.keys()),
            "row_count": [len(df) for df in outputs.values()],
        }
    )
    save_csv(summary, "_purchase_supply_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
