/*
Purpose:
    Verify FabricFlow masterdata load results after running scripts/load_masterdata.py.

Checks:
    - Row counts for each loaded masterdata table
    - product_variants = 3600
    - customers = 15000
    - sku_code uniqueness
    - product_variants.product_id orphan check
*/

USE [FabricFlowDB];
GO

SELECT N'regions' AS table_name, COUNT(*) AS row_count FROM masterdata.regions
UNION ALL
SELECT N'warehouses', COUNT(*) FROM masterdata.warehouses
UNION ALL
SELECT N'stores', COUNT(*) FROM masterdata.stores
UNION ALL
SELECT N'collections', COUNT(*) FROM masterdata.collections
UNION ALL
SELECT N'categories', COUNT(*) FROM masterdata.categories
UNION ALL
SELECT N'products', COUNT(*) FROM masterdata.products
UNION ALL
SELECT N'product_variants', COUNT(*) FROM masterdata.product_variants
UNION ALL
SELECT N'customers', COUNT(*) FROM masterdata.customers;
GO

SELECT
    CASE WHEN COUNT(*) = 3600 THEN N'PASS' ELSE N'FAIL' END AS status,
    COUNT(*) AS actual_product_variants,
    3600 AS expected_product_variants
FROM masterdata.product_variants;
GO

SELECT
    CASE WHEN COUNT(*) = 15000 THEN N'PASS' ELSE N'FAIL' END AS status,
    COUNT(*) AS actual_customers,
    15000 AS expected_customers
FROM masterdata.customers;
GO

SELECT
    sku_code,
    COUNT(*) AS duplicate_count
FROM masterdata.product_variants
GROUP BY sku_code
HAVING COUNT(*) > 1;
GO

SELECT
    pv.variant_id,
    pv.product_id,
    pv.sku_code
FROM masterdata.product_variants AS pv
LEFT JOIN masterdata.products AS p
    ON pv.product_id = p.product_id
WHERE p.product_id IS NULL;
GO
