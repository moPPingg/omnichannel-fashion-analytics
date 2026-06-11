/*
Purpose:
    Verify online orders, items, payments, and fulfillments load.
*/

USE [FabricFlowDB];
GO

SELECT N'online_orders' AS table_name, COUNT(*) AS row_count
FROM sales_online.online_orders
UNION ALL
SELECT N'online_order_items', COUNT(*)
FROM sales_online.online_order_items
UNION ALL
SELECT N'online_payments', COUNT(*)
FROM sales_online.online_payments
UNION ALL
SELECT N'online_fulfillments', COUNT(*)
FROM sales_online.online_fulfillments;
GO

SELECT CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS online_orders_status, COUNT(*) AS actual_online_orders
FROM sales_online.online_orders;
GO

SELECT CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS online_order_items_status, COUNT(*) AS actual_online_order_items
FROM sales_online.online_order_items;
GO

SELECT CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS online_payments_status, COUNT(*) AS actual_online_payments
FROM sales_online.online_payments;
GO

SELECT CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS online_fulfillments_status, COUNT(*) AS actual_online_fulfillments
FROM sales_online.online_fulfillments;
GO

SELECT
    oo.order_id,
    oo.customer_id
FROM sales_online.online_orders AS oo
LEFT JOIN masterdata.customers AS c
    ON oo.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
GO

SELECT
    ooi.item_id,
    ooi.order_id,
    ooi.variant_id
FROM sales_online.online_order_items AS ooi
LEFT JOIN sales_online.online_orders AS oo
    ON ooi.order_id = oo.order_id
LEFT JOIN masterdata.product_variants AS pv
    ON ooi.variant_id = pv.variant_id
WHERE oo.order_id IS NULL
   OR pv.variant_id IS NULL;
GO

SELECT
    op.payment_id,
    op.order_id
FROM sales_online.online_payments AS op
LEFT JOIN sales_online.online_orders AS oo
    ON op.order_id = oo.order_id
WHERE oo.order_id IS NULL;
GO

SELECT
    ofu.fulfillment_id,
    ofu.order_id,
    ofu.store_id,
    ofu.warehouse_id
FROM sales_online.online_fulfillments AS ofu
LEFT JOIN sales_online.online_orders AS oo
    ON ofu.order_id = oo.order_id
LEFT JOIN masterdata.stores AS s
    ON ofu.store_id = s.store_id
LEFT JOIN masterdata.warehouses AS w
    ON ofu.warehouse_id = w.warehouse_id
WHERE oo.order_id IS NULL
   OR (ofu.store_id IS NOT NULL AND s.store_id IS NULL)
   OR (ofu.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL);
GO

SELECT
    item_id,
    quantity
FROM sales_online.online_order_items
WHERE quantity <= 0;
GO

SELECT
    item_id,
    line_total
FROM sales_online.online_order_items
WHERE line_total < 0;
GO

WITH item_totals AS
(
    SELECT
        order_id,
        ROUND(SUM(quantity * unit_price), 2) AS item_subtotal_amount,
        ROUND(SUM(quantity * unit_price * discount_pct / 100.0), 2) AS item_discount_amount,
        ROUND(SUM(line_total), 2) AS item_total_amount
    FROM sales_online.online_order_items
    GROUP BY order_id
)
SELECT
    oo.order_id,
    oo.subtotal_amount,
    it.item_subtotal_amount,
    oo.discount_amount,
    it.item_discount_amount,
    oo.total_amount,
    CAST(ROUND(it.item_total_amount + oo.shipping_fee, 2) AS DECIMAL(12,2)) AS expected_total_amount
FROM sales_online.online_orders AS oo
JOIN item_totals AS it
    ON oo.order_id = it.order_id
WHERE ABS(oo.subtotal_amount - it.item_subtotal_amount) > 0.01
   OR ABS(oo.discount_amount - it.item_discount_amount) > 0.01
   OR ABS(oo.total_amount - ROUND(it.item_total_amount + oo.shipping_fee, 2)) > 0.01;
GO

WITH payment_totals AS
(
    SELECT
        order_id,
        ROUND(SUM(amount_paid), 2) AS payment_total
    FROM sales_online.online_payments
    GROUP BY order_id
)
SELECT
    oo.order_id,
    oo.total_amount,
    pt.payment_total
FROM sales_online.online_orders AS oo
JOIN payment_totals AS pt
    ON oo.order_id = pt.order_id
WHERE ABS(oo.total_amount - pt.payment_total) > 0.01;
GO

SELECT
    fulfillment_id,
    order_id,
    fulfilled_from,
    store_id,
    warehouse_id
FROM sales_online.online_fulfillments
WHERE NOT (
    (fulfilled_from = N'store' AND store_id IS NOT NULL AND warehouse_id IS NULL)
    OR
    (fulfilled_from = N'warehouse' AND store_id IS NULL AND warehouse_id IS NOT NULL)
);
GO

SELECT
    ofu.fulfillment_id,
    oo.order_datetime,
    ofu.shipped_at,
    ofu.delivered_at
FROM sales_online.online_fulfillments AS ofu
JOIN sales_online.online_orders AS oo
    ON ofu.order_id = oo.order_id
WHERE ofu.shipped_at < oo.order_datetime
   OR (ofu.delivered_at IS NOT NULL AND ofu.shipped_at IS NOT NULL AND ofu.delivered_at < ofu.shipped_at);
GO

SELECT
    order_id,
    order_datetime
FROM sales_online.online_orders
WHERE CAST(order_datetime AS DATE) NOT BETWEEN '2023-01-01' AND '2026-12-31';
GO

WITH offline_metrics AS
(
    SELECT
        CAST(SUM(soi.quantity) * 1.0 / NULLIF(COUNT(DISTINCT so.order_id), 0) AS DECIMAL(10,2)) AS offline_upt
    FROM sales_offline.store_orders AS so
    JOIN sales_offline.store_order_items AS soi
        ON so.order_id = soi.order_id
),
online_metrics AS
(
    SELECT
        CAST(SUM(ooi.quantity) * 1.0 / NULLIF(COUNT(DISTINCT oo.order_id), 0) AS DECIMAL(10,2)) AS online_upt
    FROM sales_online.online_orders AS oo
    JOIN sales_online.online_order_items AS ooi
        ON oo.order_id = ooi.order_id
)
SELECT
    offm.offline_upt,
    onlm.online_upt,
    CASE WHEN onlm.online_upt > offm.offline_upt THEN N'PASS' ELSE N'FAIL' END AS upt_comparison_status
FROM offline_metrics AS offm
CROSS JOIN online_metrics AS onlm;
GO

SELECT
    CAST(AVG(oo.total_amount) AS DECIMAL(12,2)) AS online_aov,
    CAST((SELECT AVG(total_amount) FROM sales_offline.store_orders) AS DECIMAL(12,2)) AS offline_aov
FROM sales_online.online_orders AS oo;
GO
