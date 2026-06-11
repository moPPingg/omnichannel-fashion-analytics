/*
Purpose:
    Provide data quality verification queries for FabricFlow.
    This script does not change data; it only surfaces potential issues.

Verify:
    Review each result set. Zero-row issue result sets indicate pass conditions.
*/

USE [FabricFlowDB];
GO

/* Check 1: duplicate SKU codes */
SELECT
    sku_code,
    COUNT(*) AS duplicate_count
FROM masterdata.product_variants
GROUP BY sku_code
HAVING COUNT(*) > 1;
GO

/* Check 2: null critical foreign keys in sales line tables */
SELECT N'store_order_items.variant_id' AS check_name, COUNT(*) AS issue_count
FROM sales_offline.store_order_items
WHERE variant_id IS NULL
UNION ALL
SELECT N'online_order_items.variant_id', COUNT(*)
FROM sales_online.online_order_items
WHERE variant_id IS NULL;
GO

/* Check 3: FK orphan detection for offline and online order items */
SELECT
    N'store_order_items_orphan_variant' AS check_name,
    COUNT(*) AS issue_count
FROM sales_offline.store_order_items AS soi
LEFT JOIN masterdata.product_variants AS pv
    ON soi.variant_id = pv.variant_id
WHERE pv.variant_id IS NULL
UNION ALL
SELECT
    N'online_order_items_orphan_variant',
    COUNT(*)
FROM sales_online.online_order_items AS ooi
LEFT JOIN masterdata.product_variants AS pv
    ON ooi.variant_id = pv.variant_id
WHERE pv.variant_id IS NULL;
GO

/* Check 4: negative values */
SELECT N'inventory_current_negative_stock' AS check_name, COUNT(*) AS issue_count
FROM inventory.inventory_current
WHERE stock_quantity < 0
UNION ALL
SELECT N'store_order_items_negative_line_total', COUNT(*)
FROM sales_offline.store_order_items
WHERE line_total < 0
UNION ALL
SELECT N'online_order_items_negative_line_total', COUNT(*)
FROM sales_online.online_order_items
WHERE line_total < 0;
GO

/* Check 5: date range outside blueprint window */
SELECT N'store_orders_out_of_range' AS check_name, COUNT(*) AS issue_count
FROM sales_offline.store_orders
WHERE CAST(order_datetime AS DATE) NOT BETWEEN '2023-01-01' AND '2026-12-31'
UNION ALL
SELECT N'online_orders_out_of_range', COUNT(*)
FROM sales_online.online_orders
WHERE CAST(order_datetime AS DATE) NOT BETWEEN '2023-01-01' AND '2026-12-31';
GO

/* Check 6: pricing anomaly */
SELECT
    variant_id,
    sku_code,
    selling_price,
    current_price
FROM masterdata.product_variants
WHERE current_price > selling_price;
GO

/* Check 7: sell-through over 100% by collection */
WITH sold_units AS
(
    SELECT
        d.collection_id,
        SUM(fs.quantity) AS sold_units
    FROM analytics.vw_fact_sales AS fs
    JOIN analytics.vw_dim_sku AS d
        ON fs.variant_id = d.variant_id
    GROUP BY d.collection_id
)
SELECT
    c.collection_id,
    c.collection_name,
    c.planned_units,
    COALESCE(s.sold_units, 0) AS sold_units
FROM masterdata.collections AS c
LEFT JOIN sold_units AS s
    ON c.collection_id = s.collection_id
WHERE COALESCE(s.sold_units, 0) > c.planned_units;
GO

/* Check 8: return quantity greater than sold quantity by variant and channel */
WITH sold AS
(
    SELECT N'offline' AS channel_name, variant_id, SUM(quantity) AS sold_qty
    FROM sales_offline.store_order_items
    GROUP BY variant_id
    UNION ALL
    SELECT N'online', variant_id, SUM(quantity)
    FROM sales_online.online_order_items
    GROUP BY variant_id
),
returned AS
(
    SELECT N'offline' AS channel_name, variant_id, SUM(quantity) AS return_qty
    FROM sales_offline.store_return_items
    GROUP BY variant_id
    UNION ALL
    SELECT N'online', variant_id, SUM(quantity)
    FROM sales_online.online_return_items
    GROUP BY variant_id
)
SELECT
    r.channel_name,
    r.variant_id,
    s.sold_qty,
    r.return_qty
FROM returned AS r
LEFT JOIN sold AS s
    ON r.channel_name = s.channel_name
   AND r.variant_id = s.variant_id
WHERE r.return_qty > COALESCE(s.sold_qty, 0);
GO

/* Check 9: fulfillment source without stock row */
SELECT
    ofu.fulfillment_id,
    ofu.order_id,
    ofu.fulfilled_from,
    ofu.store_id,
    ofu.warehouse_id
FROM sales_online.online_fulfillments AS ofu
LEFT JOIN inventory.inventory_current AS ic
    ON ofu.store_id = ic.store_id
    OR ofu.warehouse_id = ic.warehouse_id
WHERE ic.inventory_current_id IS NULL;
GO

/* Check 10: dim_date completeness */
SELECT
    COUNT(*) AS row_count,
    MIN(full_date) AS min_full_date,
    MAX(full_date) AS max_full_date
FROM masterdata.dim_date;
GO
