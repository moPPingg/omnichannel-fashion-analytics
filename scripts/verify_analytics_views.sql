/*
Purpose:
    Verify analytics views for Power BI semantic layer readiness.
*/

USE [FabricFlowDB];
GO

SET NOCOUNT ON;
GO

SELECT
    s.name AS schema_name,
    v.name AS view_name
FROM sys.views AS v
JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = N'analytics'
  AND v.name IN
  (
      N'vw_fact_sales',
      N'vw_dim_date',
      N'vw_dim_customer',
      N'vw_dim_sku',
      N'vw_dim_store',
      N'vw_dim_supplier',
      N'vw_inventory_status',
      N'vw_return_analysis',
      N'vw_channel_performance',
      N'vw_sell_through',
      N'vw_markdown_analysis',
      N'vw_supplier_performance'
  )
ORDER BY v.name;
GO

SELECT
    N'vw_fact_sales' AS view_name,
    COUNT(*) AS row_count
FROM analytics.vw_fact_sales
UNION ALL
SELECT N'vw_dim_date', COUNT(*) FROM analytics.vw_dim_date
UNION ALL
SELECT N'vw_dim_customer', COUNT(*) FROM analytics.vw_dim_customer
UNION ALL
SELECT N'vw_dim_sku', COUNT(*) FROM analytics.vw_dim_sku
UNION ALL
SELECT N'vw_dim_store', COUNT(*) FROM analytics.vw_dim_store
UNION ALL
SELECT N'vw_dim_supplier', COUNT(*) FROM analytics.vw_dim_supplier
UNION ALL
SELECT N'vw_inventory_status', COUNT(*) FROM analytics.vw_inventory_status
UNION ALL
SELECT N'vw_return_analysis', COUNT(*) FROM analytics.vw_return_analysis
UNION ALL
SELECT N'vw_channel_performance', COUNT(*) FROM analytics.vw_channel_performance
UNION ALL
SELECT N'vw_sell_through', COUNT(*) FROM analytics.vw_sell_through
UNION ALL
SELECT N'vw_markdown_analysis', COUNT(*) FROM analytics.vw_markdown_analysis
UNION ALL
SELECT N'vw_supplier_performance', COUNT(*) FROM analytics.vw_supplier_performance;
GO

SELECT
    CASE WHEN COUNT(*) = ((SELECT COUNT(*) FROM sales_offline.store_order_items) + (SELECT COUNT(*) FROM sales_online.online_order_items))
        THEN N'PASS' ELSE N'FAIL' END AS fact_sales_rowcount_status,
    COUNT(*) AS actual_view_rows,
    (SELECT COUNT(*) FROM sales_offline.store_order_items) + (SELECT COUNT(*) FROM sales_online.online_order_items) AS expected_rows
FROM analytics.vw_fact_sales;
GO

SELECT
    CASE WHEN COUNT(*) = ((SELECT COUNT(*) FROM sales_offline.store_return_items) + (SELECT COUNT(*) FROM sales_online.online_return_items))
        THEN N'PASS' ELSE N'FAIL' END AS return_analysis_rowcount_status,
    COUNT(*) AS actual_view_rows,
    (SELECT COUNT(*) FROM sales_offline.store_return_items) + (SELECT COUNT(*) FROM sales_online.online_return_items) AS expected_rows
FROM analytics.vw_return_analysis;
GO

SELECT
    channel,
    COUNT(*) AS invalid_count
FROM analytics.vw_fact_sales
WHERE channel NOT IN (N'offline', N'online')
GROUP BY channel;
GO

SELECT
    channel,
    COUNT(*) AS invalid_count
FROM analytics.vw_return_analysis
WHERE channel NOT IN (N'offline', N'online')
GROUP BY channel;
GO

SELECT
    order_id,
    variant_id,
    net_sales
FROM analytics.vw_fact_sales
WHERE net_sales < 0
   OR gross_sales < 0
   OR discount_amount < 0;
GO

SELECT
    return_id,
    variant_id,
    refund_amount
FROM analytics.vw_return_analysis
WHERE refund_amount < 0;
GO

SELECT
    fs.order_id,
    fs.variant_id
FROM analytics.vw_fact_sales AS fs
LEFT JOIN analytics.vw_dim_sku AS sku
    ON fs.variant_id = sku.variant_id
WHERE sku.variant_id IS NULL;
GO

SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM analytics.vw_dim_customer
GROUP BY customer_id
HAVING COUNT(*) > 1;
GO

SELECT
    store_id,
    COUNT(*) AS duplicate_count
FROM analytics.vw_dim_store
GROUP BY store_id
HAVING COUNT(*) > 1;
GO

SELECT
    supplier_id,
    COUNT(*) AS duplicate_count
FROM analytics.vw_dim_supplier
GROUP BY supplier_id
HAVING COUNT(*) > 1;
GO

SELECT
    date_key,
    COUNT(*) AS duplicate_count
FROM analytics.vw_dim_date
GROUP BY date_key
HAVING COUNT(*) > 1;
GO

SELECT
    full_date,
    COUNT(*) AS duplicate_count
FROM analytics.vw_dim_date
GROUP BY full_date
HAVING COUNT(*) > 1;
GO

SELECT
    ra.return_id,
    ra.variant_id
FROM analytics.vw_return_analysis AS ra
LEFT JOIN analytics.vw_dim_sku AS sku
    ON ra.variant_id = sku.variant_id
WHERE sku.variant_id IS NULL;
GO
