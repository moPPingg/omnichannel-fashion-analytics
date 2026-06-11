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


def read_csv() -> pd.DataFrame:
    csv_path = RAW_DIR / "inventory_transactions.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Missing CSV file: {csv_path}")

    df = pd.read_csv(csv_path, encoding="utf-8-sig", parse_dates=["transaction_datetime"])
    if "transaction_datetime" in df.columns:
        df["transaction_datetime"] = pd.to_datetime(df["transaction_datetime"])

    logger.info("Read %s rows from %s", f"{len(df):,}", csv_path)
    return df


def clear_table(engine) -> None:
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM inventory.inventory_transactions"))
        logger.info("Cleared inventory.inventory_transactions before reload")


def main() -> None:
    engine = get_engine()
    clear_table(engine)
    df = read_csv()
    load_table(
        df=df,
        schema="inventory",
        table="inventory_transactions",
        engine=engine,
        truncate=False,
        chunksize=1000,
    )
    logger.info("Inventory transactions load completed successfully.")


if __name__ == "__main__":
    main()
