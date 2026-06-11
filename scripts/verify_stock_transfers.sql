/*
Purpose:
    Verify stock_transfers and stock_transfer_items load.
*/

USE [FabricFlowDB];
GO

SELECT N'stock_transfers' AS table_name, COUNT(*) AS row_count
FROM inventory.stock_transfers
UNION ALL
SELECT N'stock_transfer_items', COUNT(*)
FROM inventory.stock_transfer_items;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS stock_transfers_status,
    COUNT(*) AS actual_stock_transfers
FROM inventory.stock_transfers;
GO

SELECT
    CASE WHEN COUNT(*) > 0 THEN N'PASS' ELSE N'FAIL' END AS stock_transfer_items_status,
    COUNT(*) AS actual_stock_transfer_items
FROM inventory.stock_transfer_items;
GO

SELECT
    st.stock_transfer_id,
    st.from_store_id,
    st.from_warehouse_id,
    st.to_store_id,
    st.to_warehouse_id
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
   OR (st.to_warehouse_id IS NOT NULL AND tw.warehouse_id IS NULL);
GO

SELECT
    sti.stock_transfer_item_id,
    sti.stock_transfer_id,
    sti.variant_id
FROM inventory.stock_transfer_items AS sti
LEFT JOIN inventory.stock_transfers AS st
    ON sti.stock_transfer_id = st.stock_transfer_id
LEFT JOIN masterdata.product_variants AS pv
    ON sti.variant_id = pv.variant_id
WHERE st.stock_transfer_id IS NULL
   OR pv.variant_id IS NULL;
GO

SELECT
    stock_transfer_item_id,
    quantity
FROM inventory.stock_transfer_items
WHERE quantity <= 0;
GO

SELECT
    stock_transfer_id,
    variant_id,
    COUNT(*) AS duplicate_count
FROM inventory.stock_transfer_items
GROUP BY stock_transfer_id, variant_id
HAVING COUNT(*) > 1;
GO

SELECT
    stock_transfer_id,
    transfer_status
FROM inventory.stock_transfers
WHERE transfer_status NOT IN (N'completed');
GO

SELECT
    stock_transfer_id,
    transfer_datetime
FROM inventory.stock_transfers
WHERE CAST(transfer_datetime AS DATE) NOT BETWEEN '2023-01-01' AND '2026-12-31';
GO

SELECT
    stock_transfer_id,
    from_store_id,
    from_warehouse_id,
    to_store_id,
    to_warehouse_id
FROM inventory.stock_transfers
WHERE NOT (
    (
        from_store_id IS NULL
        AND from_warehouse_id IS NOT NULL
        AND to_store_id IS NOT NULL
        AND to_warehouse_id IS NULL
    )
    OR
    (
        from_store_id IS NOT NULL
        AND from_warehouse_id IS NULL
        AND to_store_id IS NOT NULL
        AND to_warehouse_id IS NULL
    )
);
GO

SELECT
    transfer_reason,
    COUNT(*) AS transfer_count
FROM inventory.stock_transfers
GROUP BY transfer_reason
ORDER BY transfer_reason;
GO
