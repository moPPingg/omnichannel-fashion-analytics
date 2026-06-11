/*
Purpose:
    Verify online returns and online return items load.
*/

USE [FabricFlowDB];
GO

SELECT N'online_returns' AS table_name, COUNT(*) AS row_count
FROM sales_online.online_returns
UNION ALL
SELECT N'online_return_items', COUNT(*)
FROM sales_online.online_return_items;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS online_returns_status,
    COUNT(*) AS actual_online_returns
FROM sales_online.online_returns;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS online_return_items_status,
    COUNT(*) AS actual_online_return_items
FROM sales_online.online_return_items;
GO

SELECT
    orh.return_id,
    orh.order_id,
    orh.customer_id
FROM sales_online.online_returns AS orh
LEFT JOIN sales_online.online_orders AS oo
    ON orh.order_id = oo.order_id
LEFT JOIN masterdata.customers AS c
    ON orh.customer_id = c.customer_id
WHERE oo.order_id IS NULL
   OR (orh.customer_id IS NOT NULL AND c.customer_id IS NULL);
GO

SELECT
    ori.return_item_id,
    ori.return_id,
    ori.order_id,
    ori.variant_id
FROM sales_online.online_return_items AS ori
LEFT JOIN sales_online.online_returns AS orh
    ON ori.return_id = orh.return_id
LEFT JOIN sales_online.online_orders AS oo
    ON ori.order_id = oo.order_id
LEFT JOIN masterdata.product_variants AS pv
    ON ori.variant_id = pv.variant_id
WHERE orh.return_id IS NULL
   OR oo.order_id IS NULL
   OR pv.variant_id IS NULL;
GO

SELECT
    orh.return_id,
    orh.order_id,
    orh.return_datetime,
    ofu.delivered_at
FROM sales_online.online_returns AS orh
JOIN sales_online.online_fulfillments AS ofu
    ON orh.order_id = ofu.order_id
WHERE ofu.delivered_at IS NULL
   OR orh.return_datetime < ofu.delivered_at;
GO

SELECT
    return_item_id,
    quantity
FROM sales_online.online_return_items
WHERE quantity <= 0;
GO

WITH purchased_qty AS
(
    SELECT
        order_id,
        variant_id,
        SUM(quantity) AS purchased_quantity,
        SUM(line_total) AS purchased_amount
    FROM sales_online.online_order_items
    GROUP BY order_id, variant_id
),
returned_qty AS
(
    SELECT
        order_id,
        variant_id,
        SUM(quantity) AS returned_quantity,
        SUM(refund_amount) AS returned_amount
    FROM sales_online.online_return_items
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
    FROM sales_online.online_order_items
    GROUP BY order_id, variant_id
),
returned_qty AS
(
    SELECT
        order_id,
        variant_id,
        SUM(quantity) AS returned_quantity,
        SUM(refund_amount) AS returned_amount
    FROM sales_online.online_return_items
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
    FROM sales_online.online_return_items
    GROUP BY return_id
)
SELECT
    orh.return_id,
    orh.total_refund_amount,
    rt.item_refund_total
FROM sales_online.online_returns AS orh
JOIN return_totals AS rt
    ON orh.return_id = rt.return_id
WHERE ABS(orh.total_refund_amount - rt.item_refund_total) > 0.01;
GO

SELECT
    ori.return_item_id,
    ori.order_id,
    ori.variant_id
FROM sales_online.online_return_items AS ori
LEFT JOIN sales_online.online_order_items AS ooi
    ON ori.order_id = ooi.order_id
   AND ori.variant_id = ooi.variant_id
WHERE ooi.item_id IS NULL;
GO

SELECT
    return_id,
    return_reason,
    return_condition,
    refund_status
FROM sales_online.online_returns
WHERE return_reason NOT IN (N'size_issue', N'fit_issue', N'damaged_item', N'changed_mind', N'wrong_item', N'color_expectation')
   OR return_condition NOT IN (N'opened', N'unworn', N'damaged')
   OR refund_status NOT IN (N'refunded', N'partial_refunded');
GO

WITH online_rate AS
(
    SELECT CAST(COUNT(DISTINCT order_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM sales_online.online_orders), 0) AS DECIMAL(10,2)) AS online_return_rate_pct
    FROM sales_online.online_returns
),
offline_rate AS
(
    SELECT CAST(COUNT(DISTINCT order_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM sales_offline.store_orders), 0) AS DECIMAL(10,2)) AS offline_return_rate_pct
    FROM sales_offline.store_returns
)
SELECT
    onl.online_return_rate_pct,
    offl.offline_return_rate_pct
FROM online_rate AS onl
CROSS JOIN offline_rate AS offl;
GO

WITH online_rate AS
(
    SELECT CAST(COUNT(DISTINCT order_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM sales_online.online_orders), 0) AS DECIMAL(10,2)) AS online_return_rate_pct
    FROM sales_online.online_returns
),
offline_rate AS
(
    SELECT CAST(COUNT(DISTINCT order_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM sales_offline.store_orders), 0) AS DECIMAL(10,2)) AS offline_return_rate_pct
    FROM sales_offline.store_returns
)
SELECT
    CASE WHEN onl.online_return_rate_pct BETWEEN 20.00 AND 25.00 THEN N'PASS' ELSE N'FAIL' END AS online_rate_range_status,
    CASE WHEN onl.online_return_rate_pct > offl.offline_return_rate_pct THEN N'PASS' ELSE N'FAIL' END AS online_gt_offline_status
FROM online_rate AS onl
CROSS JOIN offline_rate AS offl;
GO
