/*
Purpose:
    Verify offline store sales load for store_orders, store_order_items, and store_payments.
*/

USE [FabricFlowDB];
GO

SELECT N'store_orders' AS table_name, COUNT(*) AS row_count
FROM sales_offline.store_orders
UNION ALL
SELECT N'store_order_items', COUNT(*)
FROM sales_offline.store_order_items
UNION ALL
SELECT N'store_payments', COUNT(*)
FROM sales_offline.store_payments;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS store_orders_status,
    COUNT(*) AS actual_store_orders
FROM sales_offline.store_orders;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS store_order_items_status,
    COUNT(*) AS actual_store_order_items
FROM sales_offline.store_order_items;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS store_payments_status,
    COUNT(*) AS actual_store_payments
FROM sales_offline.store_payments;
GO

SELECT
    so.order_id,
    so.store_id,
    so.customer_id
FROM sales_offline.store_orders AS so
LEFT JOIN masterdata.stores AS s
    ON so.store_id = s.store_id
LEFT JOIN masterdata.customers AS c
    ON so.customer_id = c.customer_id
WHERE s.store_id IS NULL
   OR c.customer_id IS NULL;
GO

SELECT
    soi.item_id,
    soi.order_id,
    soi.variant_id
FROM sales_offline.store_order_items AS soi
LEFT JOIN sales_offline.store_orders AS so
    ON soi.order_id = so.order_id
LEFT JOIN masterdata.product_variants AS pv
    ON soi.variant_id = pv.variant_id
WHERE so.order_id IS NULL
   OR pv.variant_id IS NULL;
GO

SELECT
    sp.payment_id,
    sp.order_id
FROM sales_offline.store_payments AS sp
LEFT JOIN sales_offline.store_orders AS so
    ON sp.order_id = so.order_id
WHERE so.order_id IS NULL;
GO

SELECT
    item_id,
    quantity
FROM sales_offline.store_order_items
WHERE quantity <= 0;
GO

SELECT
    item_id,
    line_total
FROM sales_offline.store_order_items
WHERE line_total < 0;
GO

SELECT
    item_id,
    gross_profit
FROM sales_offline.store_order_items
WHERE gross_profit < 0;
GO

WITH item_totals AS
(
    SELECT
        order_id,
        ROUND(SUM(line_total), 2) AS item_total_amount,
        ROUND(SUM(quantity * unit_price * discount_pct / 100.0), 2) AS item_discount_amount
    FROM sales_offline.store_order_items
    GROUP BY order_id
)
SELECT
    so.order_id,
    so.total_amount,
    it.item_total_amount,
    so.discount_amount,
    it.item_discount_amount
FROM sales_offline.store_orders AS so
JOIN item_totals AS it
    ON so.order_id = it.order_id
WHERE ABS(so.total_amount - it.item_total_amount) > 0.01
   OR ABS(so.discount_amount - it.item_discount_amount) > 0.01;
GO

WITH payment_totals AS
(
    SELECT
        order_id,
        ROUND(SUM(amount_paid), 2) AS payment_total
    FROM sales_offline.store_payments
    GROUP BY order_id
)
SELECT
    so.order_id,
    so.total_amount,
    pt.payment_total
FROM sales_offline.store_orders AS so
JOIN payment_totals AS pt
    ON so.order_id = pt.order_id
WHERE ABS(so.total_amount - pt.payment_total) > 0.01;
GO

SELECT
    order_id,
    order_datetime
FROM sales_offline.store_orders
WHERE CAST(order_datetime AS DATE) NOT BETWEEN '2023-01-01' AND '2026-12-31';
GO

SELECT
    payment_id,
    payment_method
FROM sales_offline.store_payments
WHERE payment_method NOT IN (N'cash', N'card', N'e-wallet');
GO

SELECT
    COUNT(DISTINCT so.order_id) AS distinct_orders,
    SUM(soi.quantity) AS total_units_sold,
    CAST(SUM(soi.quantity) * 1.0 / NULLIF(COUNT(DISTINCT so.order_id), 0) AS DECIMAL(10,2)) AS actual_upt,
    MIN(so.order_datetime) AS min_order_datetime,
    MAX(so.order_datetime) AS max_order_datetime
FROM sales_offline.store_orders AS so
JOIN sales_offline.store_order_items AS soi
    ON so.order_id = soi.order_id;
GO
