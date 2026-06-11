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
    ("masterdata", "regions"),
    ("masterdata", "warehouses"),
    ("masterdata", "stores"),
    ("masterdata", "collections"),
    ("masterdata", "categories"),
    ("masterdata", "products"),
    ("masterdata", "product_variants"),
    ("masterdata", "customers"),
]

DELETE_ORDER = list(reversed(LOAD_ORDER))

DATE_COLUMNS = {
    "stores": ["open_date"],
    "collections": ["launch_date", "end_date"],
    "customers": ["signup_date"],
}


def read_csv(table_name: str) -> pd.DataFrame:
    csv_path = RAW_DIR / f"{table_name}.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Missing CSV file: {csv_path}")

    parse_dates = DATE_COLUMNS.get(table_name, [])
    df = pd.read_csv(csv_path, encoding="utf-8-sig", parse_dates=parse_dates)

    for col in parse_dates:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col]).dt.date

    logger.info("Read %s rows from %s", f"{len(df):,}", csv_path)
    return df


def clear_masterdata_tables(engine) -> None:
    with engine.begin() as conn:
        for schema, table in DELETE_ORDER:
            full_name = f"{schema}.{table}"
            deleted = conn.execute(text(f"DELETE FROM {full_name}"))
            logger.info("Cleared %s before reload", full_name)


def main() -> None:
    if not RAW_DIR.exists():
        raise FileNotFoundError(f"Raw data folder not found: {RAW_DIR}")

    engine = get_engine()
    clear_masterdata_tables(engine)

    for schema, table in LOAD_ORDER:
        df = read_csv(table)
        load_table(df=df, schema=schema, table=table, engine=engine, truncate=False, chunksize=1000)

    logger.info("Master data load completed successfully.")


if __name__ == "__main__":
    main()
