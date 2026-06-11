from __future__ import annotations

import logging

import pandas as pd
from sqlalchemy import text
from sqlalchemy.engine import Engine


logger = logging.getLogger(__name__)


def _get_identity_columns(schema: str, table: str, engine: Engine) -> set[str]:
    query = text(
        """
        SELECT c.name
        FROM sys.columns AS c
        JOIN sys.tables AS t
            ON c.object_id = t.object_id
        JOIN sys.schemas AS s
            ON t.schema_id = s.schema_id
        WHERE s.name = :schema_name
          AND t.name = :table_name
          AND c.is_identity = 1;
        """
    )
    with engine.connect() as conn:
        rows = conn.execute(query, {"schema_name": schema, "table_name": table}).fetchall()
    return {row[0] for row in rows}


def load_table(
    df: pd.DataFrame,
    schema: str,
    table: str,
    engine: Engine,
    truncate: bool = True,
    chunksize: int = 1000,
) -> None:
    full_name = f"{schema}.{table}"
    identity_columns = _get_identity_columns(schema, table, engine)
    use_identity_insert = bool(identity_columns.intersection(df.columns))
    # SQL Server has a practical parameter ceiling around 2100 per statement.
    safe_chunksize = max(1, min(chunksize, 2000 // max(len(df.columns), 1)))

    try:
        with engine.begin() as conn:
            if truncate:
                conn.execute(text(f"DELETE FROM {full_name}"))
                logger.info("Cleared %s", full_name)

            before_count = conn.execute(text(f"SELECT COUNT(*) FROM {full_name}")).scalar_one()

            if use_identity_insert:
                conn.execute(text(f"SET IDENTITY_INSERT {full_name} ON"))

            try:
                df.to_sql(
                    name=table,
                    con=conn,
                    schema=schema,
                    if_exists="append",
                    index=False,
                    chunksize=safe_chunksize,
                    method="multi",
                )
            finally:
                if use_identity_insert:
                    conn.execute(text(f"SET IDENTITY_INSERT {full_name} OFF"))

            after_count = conn.execute(text(f"SELECT COUNT(*) FROM {full_name}")).scalar_one()

        logger.info(
            "Loaded %s rows into %s (before=%s, after=%s)",
            f"{len(df):,}",
            full_name,
            before_count,
            after_count,
        )
    except Exception as exc:
        logger.exception(
            "Failed loading %s. rows=%s truncate=%s chunksize=%s error=%s",
            full_name,
            len(df),
            truncate,
            safe_chunksize,
            exc,
        )
        raise RuntimeError(f"Failed loading {full_name}: {exc}") from exc
