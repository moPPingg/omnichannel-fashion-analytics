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
    ("inventory", "stock_transfers"),
    ("inventory", "stock_transfer_items"),
]

DELETE_ORDER = list(reversed(LOAD_ORDER))


def read_csv(table_name: str) -> pd.DataFrame:
    csv_path = RAW_DIR / f"{table_name}.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Missing CSV file: {csv_path}")

    if table_name == "stock_transfers":
        df = pd.read_csv(csv_path, encoding="utf-8-sig", parse_dates=["transfer_datetime"])
        df["transfer_datetime"] = pd.to_datetime(df["transfer_datetime"])
    else:
        df = pd.read_csv(csv_path, encoding="utf-8-sig")

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

    logger.info("Stock transfers load completed successfully.")


if __name__ == "__main__":
    main()
