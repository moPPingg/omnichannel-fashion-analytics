/*
Purpose:
    Verify Power BI dimension views and relationship readiness for Omnichannel Fashion Analytics.
*/

USE [FabricFlowDB];
GO

SET NOCOUNT ON;
GO

PRINT 'SECTION 1 - DIMENSION VIEW EXISTENCE';
SELECT
    s.name AS schema_name,
    v.name AS view_name
FROM sys.views AS v
JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = N'analytics'
  AND v.name IN
  (
      N'vw_dim_date',
      N'vw_dim_store',
      N'vw_dim_customer',
      N'vw_dim_supplier'
  )
ORDER BY v.name;
GO

PRINT 'SECTION 2 - DIMENSION ROW COUNTS';
SELECT N'vw_dim_date' AS view_name, COUNT(*) AS row_count FROM analytics.vw_dim_date
UNION ALL
SELECT N'vw_dim_store', COUNT(*) FROM analytics.vw_dim_store
UNION ALL
SELECT N'vw_dim_customer', COUNT(*) FROM analytics.vw_dim_customer
UNION ALL
SELECT N'vw_dim_supplier', COUNT(*) FROM analytics.vw_dim_supplier;
GO

PRINT 'SECTION 3 - KEY UNIQUENESS AND NULL CHECKS';
SELECT
    N'vw_dim_date[full_date]' AS key_name,
    CASE WHEN COUNT(*) = COUNT(DISTINCT full_date) AND SUM(CASE WHEN full_date IS NULL THEN 1 ELSE 0 END) = 0 THEN N'PASS' ELSE N'FAIL' END AS status,
    COUNT(*) - COUNT(DISTINCT full_date) AS duplicate_count,
    SUM(CASE WHEN full_date IS NULL THEN 1 ELSE 0 END) AS null_key_count
FROM analytics.vw_dim_date
UNION ALL
SELECT
    N'vw_dim_store[store_id]',
    CASE WHEN COUNT(*) = COUNT(DISTINCT store_id) AND SUM(CASE WHEN store_id IS NULL THEN 1 ELSE 0 END) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*) - COUNT(DISTINCT store_id),
    SUM(CASE WHEN store_id IS NULL THEN 1 ELSE 0 END)
FROM analytics.vw_dim_store
UNION ALL
SELECT
    N'vw_dim_customer[customer_id]',
    CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) AND SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*) - COUNT(DISTINCT customer_id),
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END)
FROM analytics.vw_dim_customer
UNION ALL
SELECT
    N'vw_dim_supplier[factory_id]',
    CASE WHEN COUNT(*) = COUNT(DISTINCT factory_id) AND SUM(CASE WHEN factory_id IS NULL THEN 1 ELSE 0 END) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*) - COUNT(DISTINCT factory_id),
    SUM(CASE WHEN factory_id IS NULL THEN 1 ELSE 0 END)
FROM analytics.vw_dim_supplier;
GO

PRINT 'SECTION 4 - FACT TO DIMENSION JOIN READINESS';
SELECT
    N'vw_fact_sales -> vw_dim_sku' AS relationship_name,
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END AS status,
    COUNT(*) AS unmatched_rows
FROM analytics.vw_fact_sales AS fs
LEFT JOIN analytics.vw_dim_sku AS sku
    ON fs.variant_id = sku.variant_id
WHERE sku.variant_id IS NULL
UNION ALL
SELECT
    N'vw_return_analysis -> vw_dim_sku',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_return_analysis AS ra
LEFT JOIN analytics.vw_dim_sku AS sku
    ON ra.variant_id = sku.variant_id
WHERE sku.variant_id IS NULL
UNION ALL
SELECT
    N'vw_inventory_status -> vw_dim_sku',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_inventory_status AS inv
LEFT JOIN analytics.vw_dim_sku AS sku
    ON inv.variant_id = sku.variant_id
WHERE sku.variant_id IS NULL
UNION ALL
SELECT
    N'vw_sell_through -> vw_dim_sku',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_sell_through AS st
LEFT JOIN analytics.vw_dim_sku AS sku
    ON st.variant_id = sku.variant_id
WHERE sku.variant_id IS NULL
UNION ALL
SELECT
    N'vw_markdown_analysis -> vw_dim_sku',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_markdown_analysis AS md
LEFT JOIN analytics.vw_dim_sku AS sku
    ON md.variant_id = sku.variant_id
WHERE sku.variant_id IS NULL
UNION ALL
SELECT
    N'vw_fact_sales -> vw_dim_customer',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_fact_sales AS fs
LEFT JOIN analytics.vw_dim_customer AS dc
    ON fs.customer_id = dc.customer_id
WHERE dc.customer_id IS NULL
UNION ALL
SELECT
    N'vw_fact_sales -> vw_dim_store (non-null stores only)',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_fact_sales AS fs
LEFT JOIN analytics.vw_dim_store AS ds
    ON fs.store_id = ds.store_id
WHERE fs.store_id IS NOT NULL
  AND ds.store_id IS NULL
UNION ALL
SELECT
    N'vw_inventory_status -> vw_dim_store (non-null stores only)',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_inventory_status AS inv
LEFT JOIN analytics.vw_dim_store AS ds
    ON inv.store_id = ds.store_id
WHERE inv.store_id IS NOT NULL
  AND ds.store_id IS NULL
UNION ALL
SELECT
    N'vw_fact_sales order_date -> vw_dim_date',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_fact_sales AS fs
LEFT JOIN analytics.vw_dim_date AS dd
    ON fs.order_date = dd.full_date
WHERE dd.full_date IS NULL
UNION ALL
SELECT
    N'vw_return_analysis return_date -> vw_dim_date',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_return_analysis AS ra
LEFT JOIN analytics.vw_dim_date AS dd
    ON ra.return_date = dd.full_date
WHERE dd.full_date IS NULL
UNION ALL
SELECT
    N'vw_supplier_performance -> vw_dim_supplier',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*)
FROM analytics.vw_supplier_performance AS sp
LEFT JOIN analytics.vw_dim_supplier AS ds
    ON sp.factory_id = ds.factory_id
WHERE ds.factory_id IS NULL;
GO
