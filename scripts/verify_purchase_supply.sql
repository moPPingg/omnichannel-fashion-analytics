/*
Purpose:
    Verify purchase supply load for purchase_orders, purchase_order_items, goods_receipts, and quality_checks.
*/

USE [FabricFlowDB];
GO

SELECT N'purchase_orders' AS table_name, COUNT(*) AS row_count FROM supply.purchase_orders
UNION ALL
SELECT N'purchase_order_items', COUNT(*) FROM supply.purchase_order_items
UNION ALL
SELECT N'goods_receipts', COUNT(*) FROM supply.goods_receipts
UNION ALL
SELECT N'quality_checks', COUNT(*) FROM supply.quality_checks;
GO

SELECT
    CASE WHEN COUNT(*) = 40 THEN N'PASS' ELSE N'FAIL' END AS purchase_orders_status,
    COUNT(*) AS actual_purchase_orders,
    40 AS expected_purchase_orders
FROM supply.purchase_orders;
GO

SELECT
    CASE WHEN COUNT(*) = 3600 THEN N'PASS' ELSE N'FAIL' END AS purchase_order_items_status,
    COUNT(*) AS actual_purchase_order_items,
    3600 AS expected_purchase_order_items
FROM supply.purchase_order_items;
GO

SELECT
    CASE WHEN COUNT(*) = 40 THEN N'PASS' ELSE N'FAIL' END AS goods_receipts_status,
    COUNT(*) AS actual_goods_receipts,
    40 AS expected_goods_receipts
FROM supply.goods_receipts;
GO

SELECT
    CASE WHEN COUNT(*) = 40 THEN N'PASS' ELSE N'FAIL' END AS quality_checks_status,
    COUNT(*) AS actual_quality_checks,
    40 AS expected_quality_checks
FROM supply.quality_checks;
GO

SELECT po.purchase_order_id, po.supplier_id, po.factory_id, po.collection_id
FROM supply.purchase_orders AS po
LEFT JOIN supply.suppliers AS s
    ON po.supplier_id = s.supplier_id
LEFT JOIN supply.factories AS f
    ON po.factory_id = f.factory_id
LEFT JOIN masterdata.collections AS c
    ON po.collection_id = c.collection_id
WHERE s.supplier_id IS NULL OR f.factory_id IS NULL OR c.collection_id IS NULL;
GO

SELECT poi.purchase_order_item_id, poi.purchase_order_id, poi.variant_id
FROM supply.purchase_order_items AS poi
LEFT JOIN supply.purchase_orders AS po
    ON poi.purchase_order_id = po.purchase_order_id
LEFT JOIN masterdata.product_variants AS pv
    ON poi.variant_id = pv.variant_id
WHERE po.purchase_order_id IS NULL OR pv.variant_id IS NULL;
GO

SELECT gr.goods_receipt_id, gr.purchase_order_id, gr.warehouse_id
FROM supply.goods_receipts AS gr
LEFT JOIN supply.purchase_orders AS po
    ON gr.purchase_order_id = po.purchase_order_id
LEFT JOIN masterdata.warehouses AS w
    ON gr.warehouse_id = w.warehouse_id
WHERE po.purchase_order_id IS NULL OR w.warehouse_id IS NULL;
GO

SELECT qc.quality_check_id, qc.goods_receipt_id
FROM supply.quality_checks AS qc
LEFT JOIN supply.goods_receipts AS gr
    ON qc.goods_receipt_id = gr.goods_receipt_id
WHERE gr.goods_receipt_id IS NULL;
GO

SELECT
    gr.goods_receipt_id,
    gr.received_qty,
    ordered_totals.ordered_qty
FROM supply.goods_receipts AS gr
JOIN (
    SELECT purchase_order_id, SUM(ordered_quantity) AS ordered_qty
    FROM supply.purchase_order_items
    GROUP BY purchase_order_id
) AS ordered_totals
    ON gr.purchase_order_id = ordered_totals.purchase_order_id
WHERE gr.received_qty > ordered_totals.ordered_qty;
GO

SELECT
    qc.quality_check_id,
    qc.accepted_qty,
    qc.rejected_qty,
    gr.received_qty
FROM supply.quality_checks AS qc
JOIN supply.goods_receipts AS gr
    ON qc.goods_receipt_id = gr.goods_receipt_id
WHERE qc.accepted_qty + qc.rejected_qty > gr.received_qty;
GO

SELECT
    po.purchase_order_id,
    po.planned_delivery_date,
    gr.actual_delivery_date,
    ABS(DATEDIFF(DAY, po.planned_delivery_date, gr.actual_delivery_date)) AS delivery_variance_days
FROM supply.purchase_orders AS po
JOIN supply.goods_receipts AS gr
    ON po.purchase_order_id = gr.purchase_order_id
WHERE ABS(DATEDIFF(DAY, po.planned_delivery_date, gr.actual_delivery_date)) > 10;
GO

SELECT
    po.purchase_order_id,
    po.factory_id,
    po.supplier_id,
    f.supplier_id AS factory_supplier_id
FROM supply.purchase_orders AS po
JOIN supply.factories AS f
    ON po.factory_id = f.factory_id
WHERE po.supplier_id <> f.supplier_id;
GO
