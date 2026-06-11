/*
Purpose:
    Final setup verification for database objects, schema table counts, and foreign keys.

Verify:
    Review each result set. Counts should match expected values.
*/

USE [FabricFlowDB];
GO

/* Verify 1: table count by schema. Expected total tables = 38 based on the explicit blueprint table list. */
SELECT
    s.name AS schema_name,
    COUNT(*) AS table_count
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name IN (N'masterdata', N'sales_offline', N'sales_online', N'inventory', N'supply', N'marketing', N'staging')
GROUP BY s.name
ORDER BY s.name;
GO

SELECT COUNT(*) AS total_table_count
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name IN (N'masterdata', N'sales_offline', N'sales_online', N'inventory', N'supply', N'marketing', N'staging');
GO

/* Verify 2: analytics views */
SELECT
    s.name AS schema_name,
    COUNT(*) AS view_count
FROM sys.views AS v
JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = N'analytics'
GROUP BY s.name;
GO

/* Verify 3: all foreign keys */
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
GO

/* Verify 4: required key objects */
SELECT
    OBJECT_ID(N'masterdata.product_variants', N'U') AS product_variants_object_id,
    OBJECT_ID(N'masterdata.dim_date', N'U') AS dim_date_object_id,
    OBJECT_ID(N'analytics.vw_fact_sales', N'V') AS vw_fact_sales_object_id,
    OBJECT_ID(N'analytics.vw_sell_through', N'V') AS vw_sell_through_object_id;
GO
