/*
Purpose:
    Verify inventory_transactions load for inbound purchase receipt transactions only.
*/

USE [FabricFlowDB];
GO

SELECT N'inventory_transactions' AS table_name, COUNT(*) AS row_count
FROM inventory.inventory_transactions;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS row_count_status,
    COUNT(*) AS actual_row_count
FROM inventory.inventory_transactions;
GO

SELECT
    it.inventory_transaction_id,
    it.variant_id,
    it.warehouse_id,
    it.store_id,
    it.reference_po_id
FROM inventory.inventory_transactions AS it
LEFT JOIN masterdata.product_variants AS pv
    ON it.variant_id = pv.variant_id
LEFT JOIN masterdata.warehouses AS w
    ON it.warehouse_id = w.warehouse_id
LEFT JOIN masterdata.stores AS s
    ON it.store_id = s.store_id
LEFT JOIN supply.purchase_orders AS po
    ON it.reference_po_id = po.purchase_order_id
WHERE pv.variant_id IS NULL
   OR (it.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL)
   OR (it.store_id IS NOT NULL AND s.store_id IS NULL)
   OR (it.reference_po_id IS NOT NULL AND po.purchase_order_id IS NULL);
GO

SELECT
    inventory_transaction_id,
    transaction_type,
    quantity_change
FROM inventory.inventory_transactions
WHERE transaction_type = N'purchase_receipt'
  AND quantity_change <= 0;
GO

SELECT
    inventory_transaction_id,
    transaction_type
FROM inventory.inventory_transactions
WHERE transaction_type <> N'purchase_receipt';
GO

SELECT
    inventory_transaction_id,
    warehouse_id,
    store_id
FROM inventory.inventory_transactions
WHERE warehouse_id IS NULL
   OR store_id IS NOT NULL;
GO

WITH accepted_by_po AS
(
    SELECT
        gr.purchase_order_id,
        SUM(qc.accepted_qty) AS accepted_qty
    FROM supply.goods_receipts AS gr
    JOIN supply.quality_checks AS qc
        ON gr.goods_receipt_id = qc.goods_receipt_id
    GROUP BY gr.purchase_order_id
),
txn_by_po AS
(
    SELECT
        reference_po_id AS purchase_order_id,
        SUM(quantity_change) AS transaction_qty
    FROM inventory.inventory_transactions
    WHERE transaction_type = N'purchase_receipt'
    GROUP BY reference_po_id
)
SELECT
    a.purchase_order_id,
    a.accepted_qty,
    t.transaction_qty
FROM accepted_by_po AS a
LEFT JOIN txn_by_po AS t
    ON a.purchase_order_id = t.purchase_order_id
WHERE ISNULL(a.accepted_qty, 0) <> ISNULL(t.transaction_qty, 0);
GO

SELECT
    COUNT(DISTINCT reference_po_id) AS po_count_with_transactions,
    MIN(transaction_datetime) AS min_transaction_datetime,
    MAX(transaction_datetime) AS max_transaction_datetime
FROM inventory.inventory_transactions
WHERE transaction_type = N'purchase_receipt';
GO
