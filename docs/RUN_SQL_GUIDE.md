# Run SQL Guide

This guide is for the current Omnichannel Fashion Analytics SQL bundle. It does not create fake data, Python ETL, Faker loaders, or any RetailPulse/FMCG objects.

## Required SQL Server Setup

- SQL Server 2022 instance installed and running
- `sqlcmd` available in PATH
- Windows authentication enabled if you want to use the provided batch file as-is
- Permission to create databases, schemas, tables, views, indexes, and constraints

The current local environment already exposes:

- Service: `MSSQLSERVER`
- `sqlcmd`: `SQLCMD.EXE`

## Editing `run_all_sql.bat`

Open [run_all_sql.bat](</d:/Fashion analytics/sql/run_all_sql.bat>) and use the correct `SQLCMD_SERVER` value.

Default block:

```bat
if "%SQLCMD_SERVER%"=="" set SQLCMD_SERVER=localhost
if "%SQLCMD_DATABASE%"=="" set SQLCMD_DATABASE=master
```

Common options:

- `localhost`
  - Use when the default SQL Server instance listens on the local machine
  - Example:
    ```bat
    set SQLCMD_SERVER=localhost
    ```

- `.\SQLEXPRESS`
  - Use when SQL Server Express is installed as the named instance `SQLEXPRESS`
  - Example:
    ```bat
    set SQLCMD_SERVER=.\SQLEXPRESS
    ```

- Custom named instance
  - Use format `MACHINE_NAME\INSTANCE_NAME` or `.\INSTANCE_NAME`
  - Example:
    ```bat
    set SQLCMD_SERVER=.\FABRICFLOW2022
    ```

If you prefer not to edit the file, you can set the variable before running:

```bat
set SQLCMD_SERVER=.\SQLEXPRESS
sql\run_all_sql.bat
```

## Manual Run Order

Run the files in this exact order:

1. `01_create_database.sql`
2. `02_create_schemas.sql`
3. `03_create_masterdata_tables.sql`
4. `04_create_sales_offline_tables.sql`
5. `05_create_sales_online_tables.sql`
6. `06_create_inventory_tables.sql`
7. `07_create_supply_tables.sql`
8. `08_create_marketing_tables.sql`
9. `09_create_staging_tables.sql`
10. `10_create_calendar_table.sql`
11. `11_create_indexes.sql`
12. `12_create_analytics_views.sql`
13. `13_data_quality_checks.sql`
14. `99_verify_setup.sql`

## Example `sqlcmd` Commands

Run one file:

```bat
sqlcmd -S localhost -d FabricFlowDB -E -b -i "D:\Fashion analytics\sql\03_create_masterdata_tables.sql"
```

Run the full batch:

```bat
cd /d "D:\Fashion analytics"
sql\run_all_sql.bat
```

## Verification Queries

### Verify table count by schema

Expected total table count: `38`

```sql
SELECT
    s.name AS schema_name,
    COUNT(*) AS table_count
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name IN (N'masterdata', N'sales_offline', N'sales_online', N'inventory', N'supply', N'marketing', N'staging')
GROUP BY s.name
ORDER BY s.name;

SELECT COUNT(*) AS total_table_count
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name IN (N'masterdata', N'sales_offline', N'sales_online', N'inventory', N'supply', N'marketing', N'staging');
```

### Verify foreign keys

```sql
SELECT
    fk.name AS foreign_key_name,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS parent_schema,
    OBJECT_NAME(fk.parent_object_id) AS parent_table,
    pc.name AS parent_column,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS referenced_schema,
    OBJECT_NAME(fk.referenced_object_id) AS referenced_table,
    rc.name AS referenced_column
FROM sys.foreign_keys AS fk
JOIN sys.foreign_key_columns AS fkc
    ON fk.object_id = fkc.constraint_object_id
JOIN sys.columns AS pc
    ON fkc.parent_object_id = pc.object_id
   AND fkc.parent_column_id = pc.column_id
JOIN sys.columns AS rc
    ON fkc.referenced_object_id = rc.object_id
   AND fkc.referenced_column_id = rc.column_id
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) IN (
    N'masterdata', N'sales_offline', N'sales_online', N'inventory', N'supply', N'marketing', N'staging'
)
ORDER BY parent_schema, parent_table, foreign_key_name, fkc.constraint_column_id;
```

### Verify analytics views

```sql
SELECT
    s.name AS schema_name,
    COUNT(*) AS view_count
FROM sys.views AS v
JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = N'analytics'
GROUP BY s.name;
```

### Verify `dim_date` range

Expected date range: `2023-01-01` to `2026-12-31`

```sql
SELECT
    COUNT(*) AS row_count,
    MIN(full_date) AS min_full_date,
    MAX(full_date) AS max_full_date
FROM masterdata.dim_date;
```
