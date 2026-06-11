/*
Purpose:
    Verify FabricFlow supporting groups load for supply, marketing, and inventory setup tables.

Checks:
    - Row counts
    - FK orphan checks
    - SKU promo uniqueness
    - NOOS vs seasonal policy alignment
    - Inventory location consistency
    - Non-negative stock and stock above safety stock
*/

USE [FabricFlowDB];
GO

SELECT N'suppliers' AS table_name, COUNT(*) AS row_count FROM supply.suppliers
UNION ALL
SELECT N'factories', COUNT(*) FROM supply.factories
UNION ALL
SELECT N'factory_products', COUNT(*) FROM supply.factory_products
UNION ALL
SELECT N'promotions', COUNT(*) FROM marketing.promotions
UNION ALL
SELECT N'promotion_products', COUNT(*) FROM marketing.promotion_products
UNION ALL
SELECT N'collection_events', COUNT(*) FROM marketing.collection_events
UNION ALL
SELECT N'store_targets', COUNT(*) FROM marketing.store_targets
UNION ALL
SELECT N'inventory_policy', COUNT(*) FROM inventory.inventory_policy
UNION ALL
SELECT N'inventory_current', COUNT(*) FROM inventory.inventory_current;
GO

SELECT
    CASE WHEN COUNT(*) = 6 THEN N'PASS' ELSE N'FAIL' END AS suppliers_status,
    COUNT(*) AS actual_suppliers,
    6 AS expected_suppliers
FROM supply.suppliers;
GO

SELECT
    CASE WHEN COUNT(*) = 8 THEN N'PASS' ELSE N'FAIL' END AS factories_status,
    COUNT(*) AS actual_factories,
    8 AS expected_factories
FROM supply.factories;
GO

SELECT
    CASE WHEN COUNT(*) = 400 THEN N'PASS' ELSE N'FAIL' END AS factory_products_status,
    COUNT(*) AS actual_factory_products,
    400 AS expected_factory_products
FROM supply.factory_products;
GO

SELECT
    CASE WHEN COUNT(*) = 20 THEN N'PASS' ELSE N'FAIL' END AS promotions_status,
    COUNT(*) AS actual_promotions,
    20 AS expected_promotions
FROM marketing.promotions;
GO

SELECT
    CASE WHEN COUNT(*) = 2000 THEN N'PASS' ELSE N'FAIL' END AS promotion_products_status,
    COUNT(*) AS actual_promotion_products,
    2000 AS expected_promotion_products
FROM marketing.promotion_products;
GO

SELECT
    CASE WHEN COUNT(*) = 16 THEN N'PASS' ELSE N'FAIL' END AS collection_events_status,
    COUNT(*) AS actual_collection_events,
    16 AS expected_collection_events
FROM marketing.collection_events;
GO

SELECT
    CASE WHEN COUNT(*) = 120 THEN N'PASS' ELSE N'FAIL' END AS store_targets_status,
    COUNT(*) AS actual_store_targets,
    120 AS expected_store_targets
FROM marketing.store_targets;
GO

SELECT
    CASE WHEN COUNT(*) = 31680 THEN N'PASS' ELSE N'FAIL' END AS inventory_policy_status,
    COUNT(*) AS actual_inventory_policy,
    31680 AS expected_inventory_policy
FROM inventory.inventory_policy;
GO

SELECT
    CASE WHEN COUNT(*) = 31680 THEN N'PASS' ELSE N'FAIL' END AS inventory_current_status,
    COUNT(*) AS actual_inventory_current,
    31680 AS expected_inventory_current
FROM inventory.inventory_current;
GO

SELECT fp.factory_product_id, fp.factory_id, fp.product_id
FROM supply.factory_products AS fp
LEFT JOIN supply.factories AS f
    ON fp.factory_id = f.factory_id
LEFT JOIN masterdata.products AS p
    ON fp.product_id = p.product_id
WHERE f.factory_id IS NULL OR p.product_id IS NULL;
GO

SELECT pp.promotion_product_id, pp.promotion_id, pp.variant_id
FROM marketing.promotion_products AS pp
LEFT JOIN marketing.promotions AS pr
    ON pp.promotion_id = pr.promotion_id
LEFT JOIN masterdata.product_variants AS pv
    ON pp.variant_id = pv.variant_id
WHERE pr.promotion_id IS NULL OR pv.variant_id IS NULL;
GO

SELECT ip.inventory_policy_id, ip.variant_id, ip.store_id, ip.warehouse_id
FROM inventory.inventory_policy AS ip
LEFT JOIN masterdata.product_variants AS pv
    ON ip.variant_id = pv.variant_id
LEFT JOIN masterdata.stores AS s
    ON ip.store_id = s.store_id
LEFT JOIN masterdata.warehouses AS w
    ON ip.warehouse_id = w.warehouse_id
WHERE pv.variant_id IS NULL
   OR (ip.store_id IS NOT NULL AND s.store_id IS NULL)
   OR (ip.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL);
GO

SELECT ic.inventory_current_id, ic.variant_id, ic.store_id, ic.warehouse_id
FROM inventory.inventory_current AS ic
LEFT JOIN masterdata.product_variants AS pv
    ON ic.variant_id = pv.variant_id
LEFT JOIN masterdata.stores AS s
    ON ic.store_id = s.store_id
LEFT JOIN masterdata.warehouses AS w
    ON ic.warehouse_id = w.warehouse_id
WHERE pv.variant_id IS NULL
   OR (ic.store_id IS NOT NULL AND s.store_id IS NULL)
   OR (ic.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL);
GO

SELECT promotion_id, variant_id, COUNT(*) AS duplicate_count
FROM marketing.promotion_products
GROUP BY promotion_id, variant_id
HAVING COUNT(*) > 1;
GO

SELECT
    ip.inventory_policy_id,
    ip.policy_type,
    p.is_noos,
    ip.variant_id
FROM inventory.inventory_policy AS ip
JOIN masterdata.product_variants AS pv
    ON ip.variant_id = pv.variant_id
JOIN masterdata.products AS p
    ON pv.product_id = p.product_id
WHERE (p.is_noos = 1 AND ip.policy_type <> N'noos')
   OR (p.is_noos = 0 AND ip.policy_type <> N'seasonal');
GO

SELECT
    inventory_current_id,
    location_type,
    store_id,
    warehouse_id
FROM inventory.inventory_current
WHERE NOT (
    (location_type = N'store' AND store_id IS NOT NULL AND warehouse_id IS NULL)
    OR
    (location_type = N'warehouse' AND store_id IS NULL AND warehouse_id IS NOT NULL)
);
GO

SELECT inventory_current_id, stock_quantity
FROM inventory.inventory_current
WHERE stock_quantity < 0;
GO

SELECT
    ic.inventory_current_id,
    ic.variant_id,
    ic.store_id,
    ic.warehouse_id,
    ic.stock_quantity,
    ip.safety_stock_qty
FROM inventory.inventory_current AS ic
JOIN inventory.inventory_policy AS ip
    ON ic.variant_id = ip.variant_id
   AND ISNULL(ic.store_id, -1) = ISNULL(ip.store_id, -1)
   AND ISNULL(ic.warehouse_id, -1) = ISNULL(ip.warehouse_id, -1)
WHERE ic.stock_quantity < ip.safety_stock_qty;
GO
