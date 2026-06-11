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
    ("supply", "suppliers"),
    ("supply", "factories"),
    ("supply", "factory_products"),
    ("marketing", "promotions"),
    ("marketing", "promotion_products"),
    ("marketing", "collection_events"),
    ("marketing", "store_targets"),
    ("inventory", "inventory_policy"),
    ("inventory", "inventory_current"),
]

DELETE_ORDER = list(reversed(LOAD_ORDER))

DATE_COLUMNS = {
    "promotions": ["start_date", "end_date"],
    "collection_events": ["event_date"],
    "inventory_current": ["last_updated"],
}


def read_csv(table_name: str) -> pd.DataFrame:
    csv_path = RAW_DIR / f"{table_name}.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Missing CSV file: {csv_path}")

    parse_dates = DATE_COLUMNS.get(table_name, [])
    df = pd.read_csv(csv_path, encoding="utf-8-sig", parse_dates=parse_dates)

    for col in parse_dates:
        if col in df.columns:
            if table_name == "inventory_current":
                df[col] = pd.to_datetime(df[col])
            else:
                df[col] = pd.to_datetime(df[col]).dt.date

    logger.info("Read %s rows from %s", f"{len(df):,}", csv_path)
    return df


def clear_tables(engine) -> None:
    with engine.begin() as conn:
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

    logger.info("Supporting groups load completed successfully.")


if __name__ == "__main__":
    main()
