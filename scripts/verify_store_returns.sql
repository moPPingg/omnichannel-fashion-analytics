/*
Purpose:
    Verify offline store returns load for store_returns and store_return_items.
*/

USE [FabricFlowDB];
GO

SELECT N'store_returns' AS table_name, COUNT(*) AS row_count
FROM sales_offline.store_returns
UNION ALL
SELECT N'store_return_items', COUNT(*)
FROM sales_offline.store_return_items;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS store_returns_status,
    COUNT(*) AS actual_store_returns
FROM sales_offline.store_returns;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS store_return_items_status,
    COUNT(*) AS actual_store_return_items
FROM sales_offline.store_return_items;
GO

SELECT
    sr.return_id,
    sr.order_id,
    sr.store_id,
    sr.customer_id
FROM sales_offline.store_returns AS sr
LEFT JOIN sales_offline.store_orders AS so
    ON sr.order_id = so.order_id
LEFT JOIN masterdata.stores AS s
    ON sr.store_id = s.store_id
LEFT JOIN masterdata.customers AS c
    ON sr.customer_id = c.customer_id
WHERE so.order_id IS NULL
   OR s.store_id IS NULL
   OR (sr.customer_id IS NOT NULL AND c.customer_id IS NULL);
GO

SELECT
    sri.return_item_id,
    sri.return_id,
    sri.order_id,
    sri.variant_id
FROM sales_offline.store_return_items AS sri
LEFT JOIN sales_offline.store_returns AS sr
    ON sri.return_id = sr.return_id
LEFT JOIN sales_offline.store_orders AS so
    ON sri.order_id = so.order_id
LEFT JOIN masterdata.product_variants AS pv
    ON sri.variant_id = pv.variant_id
WHERE sr.return_id IS NULL
   OR so.order_id IS NULL
   OR pv.variant_id IS NULL;
GO

SELECT
    sr.return_id,
    sr.order_id,
    sr.return_datetime,
    so.order_datetime
FROM sales_offline.store_returns AS sr
JOIN sales_offline.store_orders AS so
    ON sr.order_id = so.order_id
WHERE sr.return_datetime < so.order_datetime;
GO

SELECT
    return_item_id,
    quantity
FROM sales_offline.store_return_items
WHERE quantity <= 0;
GO

WITH purchased_qty AS
(
    SELECT
        order_id,
        variant_id,
        SUM(quantity) AS purchased_quantity,
        SUM(line_total) AS purchased_amount
    FROM sales_offline.store_order_items
    GROUP BY order_id, variant_id
),
returned_qty AS
(
    SELECT
        order_id,
        variant_id,
        SUM(quantity) AS returned_quantity,
        SUM(refund_amount) AS returned_amount
    FROM sales_offline.store_return_items
    GROUP BY order_id, variant_id
)
SELECT
    rq.order_id,
    rq.variant_id,
    rq.returned_quantity,
    pq.purchased_quantity
FROM returned_qty AS rq
JOIN purchased_qty AS pq
    ON rq.order_id = pq.order_id
   AND rq.variant_id = pq.variant_id
WHERE rq.returned_quantity > pq.purchased_quantity;
GO

WITH purchased_qty AS
(
    SELECT
        order_id,
        variant_id,
        SUM(quantity) AS purchased_quantity,
        SUM(line_total) AS purchased_amount
    FROM sales_offline.store_order_items
    GROUP BY order_id, variant_id
),
returned_qty AS
(
    SELECT
        order_id,
        variant_id,
        SUM(quantity) AS returned_quantity,
        SUM(refund_amount) AS returned_amount
    FROM sales_offline.store_return_items
    GROUP BY order_id, variant_id
)
SELECT
    rq.order_id,
    rq.variant_id,
    rq.returned_amount,
    CAST(ROUND(pq.purchased_amount * rq.returned_quantity * 1.0 / NULLIF(pq.purchased_quantity, 0), 2) AS DECIMAL(12,2)) AS expected_refund_amount
FROM returned_qty AS rq
JOIN purchased_qty AS pq
    ON rq.order_id = pq.order_id
   AND rq.variant_id = pq.variant_id
WHERE ABS(
    rq.returned_amount
    - ROUND(pq.purchased_amount * rq.returned_quantity * 1.0 / NULLIF(pq.purchased_quantity, 0), 2)
) > 0.01;
GO

WITH return_totals AS
(
    SELECT
        return_id,
        ROUND(SUM(refund_amount), 2) AS item_refund_total
    FROM sales_offline.store_return_items
    GROUP BY return_id
)
SELECT
    sr.return_id,
    sr.total_refund_amount,
    rt.item_refund_total
FROM sales_offline.store_returns AS sr
JOIN return_totals AS rt
    ON sr.return_id = rt.return_id
WHERE ABS(sr.total_refund_amount - rt.item_refund_total) > 0.01;
GO

SELECT
    sri.return_item_id,
    sri.order_id,
    sri.variant_id
FROM sales_offline.store_return_items AS sri
LEFT JOIN sales_offline.store_order_items AS soi
    ON sri.order_id = soi.order_id
   AND sri.variant_id = soi.variant_id
WHERE soi.item_id IS NULL;
GO

SELECT
    CAST(COUNT(DISTINCT sr.order_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM sales_offline.store_orders), 0) AS DECIMAL(10,2)) AS offline_return_rate_pct
FROM sales_offline.store_returns AS sr;
GO

SELECT
    CASE
        WHEN CAST(COUNT(DISTINCT sr.order_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM sales_offline.store_orders), 0) AS DECIMAL(10,2)) BETWEEN 5.00 AND 8.00
            THEN N'PASS'
        ELSE N'FAIL'
    END AS return_rate_status
FROM sales_offline.store_returns AS sr;
GO
