from __future__ import annotations

import logging
import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import text


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = PROJECT_ROOT / "src"
RAW_DIR = PROJECT_ROOT / "data" / "raw"

if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from db_config import get_engine  # noqa: E402
from utils import load_table  # noqa: E402


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


LOAD_ORDER = [
    ("sales_online", "online_orders"),
    ("sales_online", "online_order_items"),
    ("sales_online", "online_payments"),
    ("sales_online", "online_fulfillments"),
]

DELETE_ORDER = list(reversed(LOAD_ORDER))
DEPENDENT_DELETE_ORDER = [
    ("sales_online", "online_return_items"),
    ("sales_online", "online_returns"),
]

DATETIME_COLUMNS = {
    "online_orders": ["order_datetime"],
    "online_payments": ["payment_datetime"],
    "online_fulfillments": ["shipped_at", "delivered_at"],
}


def read_csv(table_name: str) -> pd.DataFrame:
    csv_path = RAW_DIR / f"{table_name}.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Missing CSV file: {csv_path}")

    parse_dates = DATETIME_COLUMNS.get(table_name, [])
    df = pd.read_csv(csv_path, encoding="utf-8-sig", parse_dates=parse_dates)

    for col in parse_dates:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col])

    logger.info("Read %s rows from %s", f"{len(df):,}", csv_path)
    return df


def clear_tables(engine) -> None:
    with engine.begin() as conn:
        for schema, table in DEPENDENT_DELETE_ORDER:
            full_name = f"{schema}.{table}"
            conn.execute(text(f"IF OBJECT_ID(N'{full_name}', N'U') IS NOT NULL DELETE FROM {full_name}"))
            logger.info("Cleared dependent %s before reload", full_name)
        for schema, table in DELETE_ORDER:
            full_name = f"{schema}.{table}"
            conn.execute(text(f"DELETE FROM {full_name}"))
            logger.info("Cleared %s before reload", full_name)


def main() -> None:
    engine = get_engine()
    clear_tables(engine)

    for schema, table in LOAD_ORDER:
        df = read_csv(table)
        load_table(df=df, schema=schema, table=table, engine=engine, truncate=False, chunksize=1000)

    logger.info("Online sales load completed successfully.")


if __name__ == "__main__":
    main()
