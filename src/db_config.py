from __future__ import annotations

import logging
import os

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


SQL_SERVER = os.getenv("FABRICFLOW_SQL_SERVER", "localhost")
SQL_DATABASE = os.getenv("FABRICFLOW_SQL_DATABASE", "FabricFlowDB")
SQL_DRIVER = os.getenv("FABRICFLOW_SQL_DRIVER", "ODBC Driver 18 for SQL Server")

CONN_STR = (
    f"mssql+pyodbc://{SQL_SERVER}/{SQL_DATABASE}"
    f"?driver={SQL_DRIVER.replace(' ', '+')}"
    "&trusted_connection=yes"
    "&TrustServerCertificate=yes"
)


def get_engine() -> Engine:
    try:
        engine = create_engine(CONN_STR, fast_executemany=True)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        logger.info("DB connection OK: %s / %s", SQL_SERVER, SQL_DATABASE)
        return engine
    except Exception as exc:
        logger.error("Cannot connect to SQL Server: %s", exc)
        raise


if __name__ == "__main__":
    get_engine()
