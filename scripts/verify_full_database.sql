/*
Purpose:
    Final database-wide verification and reconciliation script for Omnichannel Fashion Analytics.

Usage:
    sqlcmd -S localhost -E -d FabricFlowDB -i scripts\verify_full_database.sql

Outputs:
    1. Row counts for all project tables grouped by schema
    2. PASS / FAIL verification sections with violation counts and notes
*/

USE [FabricFlowDB];
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID('tempdb..#dq_results') IS NOT NULL
    DROP TABLE #dq_results;
GO

CREATE TABLE #dq_results
(
    section_name    NVARCHAR(100) NOT NULL,
    check_name      NVARCHAR(200) NOT NULL,
    status          NVARCHAR(10) NOT NULL,
    violation_count INT NOT NULL,
    detail          NVARCHAR(400) NOT NULL
);
GO

PRINT 'SECTION 1 - ROW COUNTS BY SCHEMA';
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    SUM(CASE WHEN p.index_id IN (0, 1) THEN p.rows ELSE 0 END) AS row_count
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
JOIN sys.partitions AS p
    ON t.object_id = p.object_id
WHERE s.name IN (N'masterdata', N'sales_offline', N'sales_online', N'inventory', N'supply', N'marketing', N'staging')
GROUP BY s.name, t.name
ORDER BY s.name, t.name;
GO

INSERT INTO #dq_results
SELECT
    N'Masterdata',
    N'Duplicate SKU codes',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'product_variants.sku_code must be unique'
FROM
(
    SELECT sku_code
    FROM masterdata.product_variants
    GROUP BY sku_code
    HAVING COUNT(*) > 1
) AS d;

INSERT INTO #dq_results
SELECT
    N'Masterdata',
    N'Dim_date coverage',
    CASE
        WHEN MIN(full_date) = '2023-01-01'
         AND MAX(full_date) = '2026-12-31'
         AND COUNT(*) = 1461
            THEN N'PASS'
        ELSE N'FAIL'
    END,
    CASE
        WHEN MIN(full_date) = '2023-01-01'
         AND MAX(full_date) = '2026-12-31'
         AND COUNT(*) = 1461
            THEN 0
        ELSE 1
    END,
    CONCAT(
        N'min_date=', CONVERT(NVARCHAR(10), MIN(full_date), 23),
        N'; max_date=', CONVERT(NVARCHAR(10), MAX(full_date), 23),
        N'; row_count=', COUNT(*)
    )
FROM masterdata.dim_date;

INSERT INTO #dq_results
SELECT
    N'Foreign Keys',
    N'Stores -> regions / warehouses',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'stores must map to valid regions and warehouses'
FROM masterdata.stores AS s
LEFT JOIN masterdata.regions AS r
    ON s.region_id = r.region_id
LEFT JOIN masterdata.warehouses AS w
    ON s.warehouse_id = w.warehouse_id
WHERE r.region_id IS NULL
   OR w.warehouse_id IS NULL;

INSERT INTO #dq_results
SELECT
    N'Foreign Keys',
    N'Products -> collections / categories',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'products must map to valid collections and categories'
FROM masterdata.products AS p
LEFT JOIN masterdata.collections AS c
    ON p.collection_id = c.collection_id
LEFT JOIN masterdata.categories AS cat
    ON p.category_id = cat.category_id
WHERE c.collection_id IS NULL
   OR cat.category_id IS NULL;

INSERT INTO #dq_results
SELECT
    N'Foreign Keys',
    N'Product variants -> products',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'product_variants must map to valid products'
FROM masterdata.product_variants AS pv
LEFT JOIN masterdata.products AS p
    ON pv.product_id = p.product_id
WHERE p.product_id IS NULL;

INSERT INTO #dq_results
SELECT
    N'Foreign Keys',
    N'Supply and marketing bridge tables',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'factory_products, promotion_products, collection_events, store_targets must have valid parents'
FROM
(
    SELECT fp.factory_product_id AS issue_id
    FROM supply.factory_products AS fp
    LEFT JOIN supply.factories AS f
        ON fp.factory_id = f.factory_id
    LEFT JOIN masterdata.products AS p
        ON fp.product_id = p.product_id
    WHERE f.factory_id IS NULL OR p.product_id IS NULL

    UNION ALL

    SELECT pp.promotion_product_id
    FROM marketing.promotion_products AS pp
    LEFT JOIN marketing.promotions AS pr
        ON pp.promotion_id = pr.promotion_id
    LEFT JOIN masterdata.product_variants AS pv
        ON pp.variant_id = pv.variant_id
    WHERE pr.promotion_id IS NULL OR pv.variant_id IS NULL

    UNION ALL

    SELECT ce.collection_event_id
    FROM marketing.collection_events AS ce
    LEFT JOIN masterdata.collections AS c
        ON ce.collection_id = c.collection_id
    WHERE c.collection_id IS NULL

    UNION ALL

    SELECT st.store_target_id
    FROM marketing.store_targets AS st
    LEFT JOIN masterdata.stores AS s
        ON st.store_id = s.store_id
    WHERE s.store_id IS NULL
) AS fk_issues;

INSERT INTO #dq_results
SELECT
    N'Foreign Keys',
    N'Purchase supply chain',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'purchase orders, items, receipts, and quality checks must map to valid parents'
FROM
(
    SELECT po.purchase_order_id AS issue_id
    FROM supply.purchase_orders AS po
    LEFT JOIN supply.suppliers AS s
        ON po.supplier_id = s.supplier_id
    LEFT JOIN supply.factories AS f
        ON po.factory_id = f.factory_id
    LEFT JOIN masterdata.collections AS c
        ON po.collection_id = c.collection_id
    WHERE s.supplier_id IS NULL OR f.factory_id IS NULL OR c.collection_id IS NULL

    UNION ALL

    SELECT poi.purchase_order_item_id
    FROM supply.purchase_order_items AS poi
    LEFT JOIN supply.purchase_orders AS po
        ON poi.purchase_order_id = po.purchase_order_id
    LEFT JOIN masterdata.product_variants AS pv
        ON poi.variant_id = pv.variant_id
    WHERE po.purchase_order_id IS NULL OR pv.variant_id IS NULL

    UNION ALL

    SELECT gr.goods_receipt_id
    FROM supply.goods_receipts AS gr
    LEFT JOIN supply.purchase_orders AS po
        ON gr.purchase_order_id = po.purchase_order_id
    LEFT JOIN masterdata.warehouses AS w
        ON gr.warehouse_id = w.warehouse_id
    WHERE po.purchase_order_id IS NULL OR w.warehouse_id IS NULL

    UNION ALL

    SELECT qc.quality_check_id
    FROM supply.quality_checks AS qc
    LEFT JOIN supply.goods_receipts AS gr
        ON qc.goods_receipt_id = gr.goods_receipt_id
    WHERE gr.goods_receipt_id IS NULL
) AS fk_issues;

INSERT INTO #dq_results
SELECT
    N'Foreign Keys',
    N'Inventory facts',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'inventory_current, inventory_policy, inventory_transactions, transfers must map to valid parents'
FROM
(
    SELECT ic.inventory_current_id AS issue_id
    FROM inventory.inventory_current AS ic
    LEFT JOIN masterdata.product_variants AS pv
        ON ic.variant_id = pv.variant_id
    LEFT JOIN masterdata.stores AS s
        ON ic.store_id = s.store_id
    LEFT JOIN masterdata.warehouses AS w
        ON ic.warehouse_id = w.warehouse_id
    WHERE pv.variant_id IS NULL
       OR (ic.store_id IS NOT NULL AND s.store_id IS NULL)
       OR (ic.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL)

    UNION ALL

    SELECT ip.inventory_policy_id
    FROM inventory.inventory_policy AS ip
    LEFT JOIN masterdata.product_variants AS pv
        ON ip.variant_id = pv.variant_id
    LEFT JOIN masterdata.stores AS s
        ON ip.store_id = s.store_id
    LEFT JOIN masterdata.warehouses AS w
        ON ip.warehouse_id = w.warehouse_id
    WHERE pv.variant_id IS NULL
       OR (ip.store_id IS NOT NULL AND s.store_id IS NULL)
       OR (ip.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL)

    UNION ALL

    SELECT it.inventory_transaction_id
    FROM inventory.inventory_transactions AS it
    LEFT JOIN masterdata.product_variants AS pv
        ON it.variant_id = pv.variant_id
    LEFT JOIN masterdata.stores AS s
        ON it.store_id = s.store_id
    LEFT JOIN masterdata.warehouses AS w
        ON it.warehouse_id = w.warehouse_id
    LEFT JOIN supply.purchase_orders AS po
        ON it.reference_po_id = po.purchase_order_id
    LEFT JOIN inventory.stock_transfers AS st
        ON it.reference_transfer_id = st.stock_transfer_id
    WHERE pv.variant_id IS NULL
       OR (it.store_id IS NOT NULL AND s.store_id IS NULL)
       OR (it.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL)
       OR (it.reference_po_id IS NOT NULL AND po.purchase_order_id IS NULL)
       OR (it.reference_transfer_id IS NOT NULL AND st.stock_transfer_id IS NULL)

    UNION ALL

    SELECT st.stock_transfer_id
    FROM inventory.stock_transfers AS st
    LEFT JOIN masterdata.stores AS fs
        ON st.from_store_id = fs.store_id
    LEFT JOIN masterdata.warehouses AS fw
        ON st.from_warehouse_id = fw.warehouse_id
    LEFT JOIN masterdata.stores AS ts
        ON st.to_store_id = ts.store_id
    LEFT JOIN masterdata.warehouses AS tw
        ON st.to_warehouse_id = tw.warehouse_id
    WHERE (st.from_store_id IS NOT NULL AND fs.store_id IS NULL)
       OR (st.from_warehouse_id IS NOT NULL AND fw.warehouse_id IS NULL)
       OR (st.to_store_id IS NOT NULL AND ts.store_id IS NULL)
       OR (st.to_warehouse_id IS NOT NULL AND tw.warehouse_id IS NULL)

    UNION ALL

    SELECT sti.stock_transfer_item_id
    FROM inventory.stock_transfer_items AS sti
    LEFT JOIN inventory.stock_transfers AS st
        ON sti.stock_transfer_id = st.stock_transfer_id
    LEFT JOIN masterdata.product_variants AS pv
        ON sti.variant_id = pv.variant_id
    WHERE st.stock_transfer_id IS NULL OR pv.variant_id IS NULL
) AS fk_issues;

INSERT INTO #dq_results
SELECT
    N'Foreign Keys',
    N'Offline sales and returns',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'store sales and returns tables must map to valid customers, stores, orders, and variants'
FROM
(
    SELECT so.order_id AS issue_id
    FROM sales_offline.store_orders AS so
    LEFT JOIN masterdata.stores AS s
        ON so.store_id = s.store_id
    LEFT JOIN masterdata.customers AS c
        ON so.customer_id = c.customer_id
    WHERE s.store_id IS NULL OR c.customer_id IS NULL

    UNION ALL

    SELECT soi.item_id
    FROM sales_offline.store_order_items AS soi
    LEFT JOIN sales_offline.store_orders AS so
        ON soi.order_id = so.order_id
    LEFT JOIN masterdata.product_variants AS pv
        ON soi.variant_id = pv.variant_id
    WHERE so.order_id IS NULL OR pv.variant_id IS NULL

    UNION ALL

    SELECT sp.payment_id
    FROM sales_offline.store_payments AS sp
    LEFT JOIN sales_offline.store_orders AS so
        ON sp.order_id = so.order_id
    WHERE so.order_id IS NULL

    UNION ALL

    SELECT sr.return_id
    FROM sales_offline.store_returns AS sr
    LEFT JOIN sales_offline.store_orders AS so
        ON sr.order_id = so.order_id
    LEFT JOIN masterdata.stores AS s
        ON sr.store_id = s.store_id
    LEFT JOIN masterdata.customers AS c
        ON sr.customer_id = c.customer_id
    WHERE so.order_id IS NULL
       OR s.store_id IS NULL
       OR (sr.customer_id IS NOT NULL AND c.customer_id IS NULL)

    UNION ALL

    SELECT sri.return_item_id
    FROM sales_offline.store_return_items AS sri
    LEFT JOIN sales_offline.store_returns AS sr
        ON sri.return_id = sr.return_id
    LEFT JOIN sales_offline.store_orders AS so
        ON sri.order_id = so.order_id
    LEFT JOIN masterdata.product_variants AS pv
        ON sri.variant_id = pv.variant_id
    WHERE sr.return_id IS NULL OR so.order_id IS NULL OR pv.variant_id IS NULL
) AS fk_issues;

INSERT INTO #dq_results
SELECT
    N'Foreign Keys',
    N'Online sales and returns',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'online sales, fulfillments, and returns tables must map to valid parents'
FROM
(
    SELECT oo.order_id AS issue_id
    FROM sales_online.online_orders AS oo
    LEFT JOIN masterdata.customers AS c
        ON oo.customer_id = c.customer_id
    WHERE c.customer_id IS NULL

    UNION ALL

    SELECT ooi.item_id
    FROM sales_online.online_order_items AS ooi
    LEFT JOIN sales_online.online_orders AS oo
        ON ooi.order_id = oo.order_id
    LEFT JOIN masterdata.product_variants AS pv
        ON ooi.variant_id = pv.variant_id
    WHERE oo.order_id IS NULL OR pv.variant_id IS NULL

    UNION ALL

    SELECT op.payment_id
    FROM sales_online.online_payments AS op
    LEFT JOIN sales_online.online_orders AS oo
        ON op.order_id = oo.order_id
    WHERE oo.order_id IS NULL

    UNION ALL

    SELECT ofu.fulfillment_id
    FROM sales_online.online_fulfillments AS ofu
    LEFT JOIN sales_online.online_orders AS oo
        ON ofu.order_id = oo.order_id
    LEFT JOIN masterdata.stores AS s
        ON ofu.store_id = s.store_id
    LEFT JOIN masterdata.warehouses AS w
        ON ofu.warehouse_id = w.warehouse_id
    WHERE oo.order_id IS NULL
       OR (ofu.store_id IS NOT NULL AND s.store_id IS NULL)
       OR (ofu.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL)

    UNION ALL

    SELECT orh.return_id
    FROM sales_online.online_returns AS orh
    LEFT JOIN sales_online.online_orders AS oo
        ON orh.order_id = oo.order_id
    LEFT JOIN masterdata.customers AS c
        ON orh.customer_id = c.customer_id
    WHERE oo.order_id IS NULL
       OR (orh.customer_id IS NOT NULL AND c.customer_id IS NULL)

    UNION ALL

    SELECT ori.return_item_id
    FROM sales_online.online_return_items AS ori
    LEFT JOIN sales_online.online_returns AS orh
        ON ori.return_id = orh.return_id
    LEFT JOIN sales_online.online_orders AS oo
        ON ori.order_id = oo.order_id
    LEFT JOIN masterdata.product_variants AS pv
        ON ori.variant_id = pv.variant_id
    WHERE orh.return_id IS NULL OR oo.order_id IS NULL OR pv.variant_id IS NULL
) AS fk_issues;

INSERT INTO #dq_results
SELECT
    N'Reconciliation',
    N'Offline order totals align with items and payments',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'store_orders.total_amount and discount_amount must align with items and payments'
FROM
(
    SELECT so.order_id
    FROM sales_offline.store_orders AS so
    JOIN
    (
        SELECT
            order_id,
            ROUND(SUM(line_total), 2) AS item_total_amount,
            ROUND(SUM(quantity * unit_price * discount_pct / 100.0), 2) AS item_discount_amount
        FROM sales_offline.store_order_items
        GROUP BY order_id
    ) AS it
        ON so.order_id = it.order_id
    JOIN
    (
        SELECT order_id, ROUND(SUM(amount_paid), 2) AS payment_total
        FROM sales_offline.store_payments
        GROUP BY order_id
    ) AS pt
        ON so.order_id = pt.order_id
    WHERE ABS(so.total_amount - it.item_total_amount) > 0.01
       OR ABS(so.discount_amount - it.item_discount_amount) > 0.01
       OR ABS(so.total_amount - pt.payment_total) > 0.01
) AS issues;

INSERT INTO #dq_results
SELECT
    N'Reconciliation',
    N'Online order totals align with items and payments',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'online_orders subtotal, discount, total, and payments must align'
FROM
(
    SELECT oo.order_id
    FROM sales_online.online_orders AS oo
    JOIN
    (
        SELECT
            order_id,
            ROUND(SUM(quantity * unit_price), 2) AS item_subtotal_amount,
            ROUND(SUM(quantity * unit_price * discount_pct / 100.0), 2) AS item_discount_amount,
            ROUND(SUM(line_total), 2) AS item_total_amount
        FROM sales_online.online_order_items
        GROUP BY order_id
    ) AS it
        ON oo.order_id = it.order_id
    JOIN
    (
        SELECT order_id, ROUND(SUM(amount_paid), 2) AS payment_total
        FROM sales_online.online_payments
        GROUP BY order_id
    ) AS pt
        ON oo.order_id = pt.order_id
    WHERE ABS(oo.subtotal_amount - it.item_subtotal_amount) > 0.01
       OR ABS(oo.discount_amount - it.item_discount_amount) > 0.01
       OR ABS(oo.total_amount - ROUND(it.item_total_amount + oo.shipping_fee, 2)) > 0.01
       OR ABS(oo.total_amount - pt.payment_total) > 0.01
) AS issues;

INSERT INTO #dq_results
SELECT
    N'Reconciliation',
    N'Offline return refunds align with returned items',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'store_returns.total_refund_amount must equal sum of store_return_items.refund_amount'
FROM
(
    SELECT sr.return_id
    FROM sales_offline.store_returns AS sr
    JOIN
    (
        SELECT return_id, ROUND(SUM(refund_amount), 2) AS item_refund_total
        FROM sales_offline.store_return_items
        GROUP BY return_id
    ) AS rt
        ON sr.return_id = rt.return_id
    WHERE ABS(sr.total_refund_amount - rt.item_refund_total) > 0.01
) AS issues;

INSERT INTO #dq_results
SELECT
    N'Reconciliation',
    N'Online return refunds align with returned items',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'online_returns.total_refund_amount must equal sum of online_return_items.refund_amount'
FROM
(
    SELECT orh.return_id
    FROM sales_online.online_returns AS orh
    JOIN
    (
        SELECT return_id, ROUND(SUM(refund_amount), 2) AS item_refund_total
        FROM sales_online.online_return_items
        GROUP BY return_id
    ) AS rt
        ON orh.return_id = rt.return_id
    WHERE ABS(orh.total_refund_amount - rt.item_refund_total) > 0.01
) AS issues;

INSERT INTO #dq_results
SELECT
    N'KPI Logic',
    N'Online return rate > offline return rate',
    CASE WHEN onl.online_return_rate_pct > offl.offline_return_rate_pct THEN N'PASS' ELSE N'FAIL' END,
    CASE WHEN onl.online_return_rate_pct > offl.offline_return_rate_pct THEN 0 ELSE 1 END,
    CONCAT(
        N'online=', CAST(onl.online_return_rate_pct AS NVARCHAR(30)),
        N'%; offline=', CAST(offl.offline_return_rate_pct AS NVARCHAR(30)), N'%'
    )
FROM
(
    SELECT CAST(COUNT(DISTINCT order_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM sales_online.online_orders), 0) AS DECIMAL(10,2)) AS online_return_rate_pct
    FROM sales_online.online_returns
) AS onl
CROSS JOIN
(
    SELECT CAST(COUNT(DISTINCT order_id) * 100.0 / NULLIF((SELECT COUNT(*) FROM sales_offline.store_orders), 0) AS DECIMAL(10,2)) AS offline_return_rate_pct
    FROM sales_offline.store_returns
) AS offl;

INSERT INTO #dq_results
SELECT
    N'KPI Logic',
    N'Online UPT > offline UPT',
    CASE WHEN onl.online_upt > offl.offline_upt THEN N'PASS' ELSE N'FAIL' END,
    CASE WHEN onl.online_upt > offl.offline_upt THEN 0 ELSE 1 END,
    CONCAT(
        N'online=', CAST(onl.online_upt AS NVARCHAR(30)),
        N'; offline=', CAST(offl.offline_upt AS NVARCHAR(30))
    )
FROM
(
    SELECT CAST(SUM(ooi.quantity) * 1.0 / NULLIF(COUNT(DISTINCT oo.order_id), 0) AS DECIMAL(10,2)) AS online_upt
    FROM sales_online.online_orders AS oo
    JOIN sales_online.online_order_items AS ooi
        ON oo.order_id = ooi.order_id
) AS onl
CROSS JOIN
(
    SELECT CAST(SUM(soi.quantity) * 1.0 / NULLIF(COUNT(DISTINCT so.order_id), 0) AS DECIMAL(10,2)) AS offline_upt
    FROM sales_offline.store_orders AS so
    JOIN sales_offline.store_order_items AS soi
        ON so.order_id = soi.order_id
) AS offl;

INSERT INTO #dq_results
SELECT
    N'Quantities',
    N'No negative or zero-invalid quantities',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'sales, returns, inventory, transactions, and transfers must have valid non-negative quantities'
FROM
(
    SELECT item_id AS issue_id
    FROM sales_offline.store_order_items
    WHERE quantity <= 0

    UNION ALL

    SELECT return_item_id
    FROM sales_offline.store_return_items
    WHERE quantity <= 0

    UNION ALL

    SELECT item_id
    FROM sales_online.online_order_items
    WHERE quantity <= 0

    UNION ALL

    SELECT return_item_id
    FROM sales_online.online_return_items
    WHERE quantity <= 0

    UNION ALL

    SELECT inventory_current_id
    FROM inventory.inventory_current
    WHERE stock_quantity < 0

    UNION ALL

    SELECT inventory_transaction_id
    FROM inventory.inventory_transactions
    WHERE quantity_change < 0

    UNION ALL

    SELECT stock_transfer_item_id
    FROM inventory.stock_transfer_items
    WHERE quantity <= 0
) AS quantity_issues;

INSERT INTO #dq_results
SELECT
    N'Dates',
    N'Offline returns after order',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'store_returns.return_datetime must be >= store_orders.order_datetime'
FROM sales_offline.store_returns AS sr
JOIN sales_offline.store_orders AS so
    ON sr.order_id = so.order_id
WHERE sr.return_datetime < so.order_datetime;

INSERT INTO #dq_results
SELECT
    N'Dates',
    N'Online fulfillments after order and before delivery',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'online_fulfillments shipped_at >= order_datetime and delivered_at >= shipped_at'
FROM sales_online.online_fulfillments AS ofu
JOIN sales_online.online_orders AS oo
    ON ofu.order_id = oo.order_id
WHERE ofu.shipped_at < oo.order_datetime
   OR (ofu.delivered_at IS NOT NULL AND ofu.shipped_at IS NOT NULL AND ofu.delivered_at < ofu.shipped_at);

INSERT INTO #dq_results
SELECT
    N'Dates',
    N'Online returns after delivery',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'online_returns.return_datetime must be >= online_fulfillments.delivered_at'
FROM sales_online.online_returns AS orh
JOIN sales_online.online_fulfillments AS ofu
    ON orh.order_id = ofu.order_id
WHERE ofu.delivered_at IS NULL
   OR orh.return_datetime < ofu.delivered_at;

INSERT INTO #dq_results
SELECT
    N'Dates',
    N'Purchase receipt dates close to plan',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'goods_receipts.actual_delivery_date should be within 10 days of planned_delivery_date'
FROM supply.purchase_orders AS po
JOIN supply.goods_receipts AS gr
    ON po.purchase_order_id = gr.purchase_order_id
WHERE ABS(DATEDIFF(DAY, po.planned_delivery_date, gr.actual_delivery_date)) > 10;

INSERT INTO #dq_results
SELECT
    N'Uniqueness',
    N'No duplicate promotion_id + variant_id',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'marketing.promotion_products must be unique by promotion_id + variant_id'
FROM
(
    SELECT promotion_id, variant_id
    FROM marketing.promotion_products
    GROUP BY promotion_id, variant_id
    HAVING COUNT(*) > 1
) AS d;

INSERT INTO #dq_results
SELECT
    N'Uniqueness',
    N'No duplicate stock_transfer_id + variant_id',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'inventory.stock_transfer_items must be unique by stock_transfer_id + variant_id'
FROM
(
    SELECT stock_transfer_id, variant_id
    FROM inventory.stock_transfer_items
    GROUP BY stock_transfer_id, variant_id
    HAVING COUNT(*) > 1
) AS d;

INSERT INTO #dq_results
SELECT
    N'Inventory',
    N'Inventory current stock is non-negative',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'inventory_current.stock_quantity must be >= 0'
FROM inventory.inventory_current
WHERE stock_quantity < 0;

INSERT INTO #dq_results
SELECT
    N'Inventory',
    N'Safety stock rules pass',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'inventory_current.stock_quantity must be >= inventory_policy.safety_stock_qty'
FROM inventory.inventory_current AS ic
JOIN inventory.inventory_policy AS ip
    ON ic.variant_id = ip.variant_id
   AND ISNULL(ic.store_id, -1) = ISNULL(ip.store_id, -1)
   AND ISNULL(ic.warehouse_id, -1) = ISNULL(ip.warehouse_id, -1)
WHERE ic.stock_quantity < ip.safety_stock_qty;

INSERT INTO #dq_results
SELECT
    N'Inventory',
    N'Purchase receipt quantities align with quality accepted quantities',
    CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END,
    COUNT(*),
    N'purchase_receipt inventory transactions must sum to accepted quality check quantities per PO'
FROM
(
    SELECT a.purchase_order_id
    FROM
    (
        SELECT
            gr.purchase_order_id,
            SUM(qc.accepted_qty) AS accepted_qty
        FROM supply.goods_receipts AS gr
        JOIN supply.quality_checks AS qc
            ON gr.goods_receipt_id = qc.goods_receipt_id
        GROUP BY gr.purchase_order_id
    ) AS a
    LEFT JOIN
    (
        SELECT
            reference_po_id AS purchase_order_id,
            SUM(quantity_change) AS transaction_qty
        FROM inventory.inventory_transactions
        WHERE transaction_type = N'purchase_receipt'
        GROUP BY reference_po_id
    ) AS t
        ON a.purchase_order_id = t.purchase_order_id
    WHERE ISNULL(a.accepted_qty, 0) <> ISNULL(t.transaction_qty, 0)
) AS issues;

PRINT 'SECTION 2 - PASS / FAIL CHECK RESULTS';
SELECT
    section_name,
    check_name,
    status,
    violation_count,
    detail
FROM #dq_results
ORDER BY
    CASE status WHEN N'FAIL' THEN 0 ELSE 1 END,
    section_name,
    check_name;
GO

PRINT 'SECTION 3 - SUMMARY';
SELECT
    SUM(CASE WHEN status = N'PASS' THEN 1 ELSE 0 END) AS pass_count,
    SUM(CASE WHEN status = N'FAIL' THEN 1 ELSE 0 END) AS fail_count,
    COUNT(*) AS total_checks
FROM #dq_results;
GO

DROP TABLE #dq_results;
GO
