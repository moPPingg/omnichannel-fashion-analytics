from __future__ import annotations

from pathlib import Path
from typing import Dict, List

import numpy as np
import pandas as pd
from faker import Faker

from fashion_rules import SEED, set_global_seeds


set_global_seeds(SEED)
fake = Faker("vi_VN")

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"


def ensure_output_dir() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)


def load_csv(table_name: str, parse_dates: List[str] | None = None) -> pd.DataFrame:
    return pd.read_csv(RAW_DIR / f"{table_name}.csv", encoding="utf-8-sig", parse_dates=parse_dates or [])


def allocate_quantities(ordered_quantities: List[int], accepted_total: int) -> List[int]:
    ordered = np.array(ordered_quantities, dtype=float)
    total_ordered = int(ordered.sum())
    if total_ordered <= 0 or accepted_total <= 0:
        return [0] * len(ordered_quantities)

    raw = (ordered / total_ordered) * accepted_total
    allocated = np.floor(raw).astype(int)
    remainder = int(accepted_total - allocated.sum())

    if remainder > 0:
        order = np.argsort(-(raw - allocated))
        for idx in order[:remainder]:
            allocated[idx] += 1

    return allocated.tolist()


def generate_inventory_transactions() -> pd.DataFrame:
    purchase_orders_df = load_csv("purchase_orders", parse_dates=["po_date", "planned_delivery_date"])
    purchase_order_items_df = load_csv("purchase_order_items")
    goods_receipts_df = load_csv("goods_receipts", parse_dates=["receipt_date", "actual_delivery_date"])
    quality_checks_df = load_csv("quality_checks", parse_dates=["check_date"])

    receipt_lookup = goods_receipts_df.set_index("purchase_order_id").to_dict("index")
    qc_lookup = quality_checks_df.set_index("goods_receipt_id").to_dict("index")

    rows: List[Dict] = []
    inventory_transaction_id = 1

    for purchase_order_id, po_items in purchase_order_items_df.groupby("purchase_order_id", sort=True):
        purchase_order_id = int(purchase_order_id)
        receipt = receipt_lookup[purchase_order_id]
        goods_receipt_id = int(receipt["goods_receipt_id"])
        qc = qc_lookup[goods_receipt_id]
        accepted_total = int(qc["accepted_qty"])

        ordered_quantities = po_items["ordered_quantity"].astype(int).tolist()
        allocated_quantities = allocate_quantities(ordered_quantities, accepted_total)

        transaction_datetime = pd.to_datetime(receipt["actual_delivery_date"]) + pd.Timedelta(hours=10)
        warehouse_id = int(receipt["warehouse_id"])

        for (_, po_item), accepted_qty in zip(po_items.iterrows(), allocated_quantities):
            if accepted_qty <= 0:
                continue

            rows.append(
                {
                    "inventory_transaction_id": inventory_transaction_id,
                    "transaction_datetime": transaction_datetime,
                    "transaction_type": "purchase_receipt",
                    "store_id": None,
                    "warehouse_id": warehouse_id,
                    "variant_id": int(po_item["variant_id"]),
                    "quantity_change": int(accepted_qty),
                    "reference_order_id": None,
                    "reference_online_order_id": None,
                    "reference_po_id": purchase_order_id,
                    "reference_transfer_id": None,
                    "reference_note": f"goods_receipt_id={goods_receipt_id};quality_check_id={int(qc['quality_check_id'])}",
                }
            )
            inventory_transaction_id += 1

    return pd.DataFrame(rows)


def save_csv(df: pd.DataFrame, table_name: str) -> None:
    df.to_csv(RAW_DIR / f"{table_name}.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    ensure_output_dir()
    inventory_transactions_df = generate_inventory_transactions()

    save_csv(inventory_transactions_df, "inventory_transactions")

    summary = pd.DataFrame(
        {
            "table_name": ["inventory_transactions"],
            "row_count": [len(inventory_transactions_df)],
        }
    )
    save_csv(summary, "_inventory_transactions_summary")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
