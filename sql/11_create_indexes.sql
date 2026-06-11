/*
Purpose:
    Create secondary indexes to support foreign key joins and common analytics filters.

Verify:
    Run the SELECT at the end to confirm nonclustered indexes exist.
*/

USE [FabricFlowDB];
GO

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_stores_region_id' AND object_id = OBJECT_ID(N'masterdata.stores'))
    CREATE INDEX IX_stores_region_id ON masterdata.stores(region_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_stores_warehouse_id' AND object_id = OBJECT_ID(N'masterdata.stores'))
    CREATE INDEX IX_stores_warehouse_id ON masterdata.stores(warehouse_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_products_collection_id' AND object_id = OBJECT_ID(N'masterdata.products'))
    CREATE INDEX IX_products_collection_id ON masterdata.products(collection_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_products_category_id' AND object_id = OBJECT_ID(N'masterdata.products'))
    CREATE INDEX IX_products_category_id ON masterdata.products(category_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_product_variants_product_id' AND object_id = OBJECT_ID(N'masterdata.product_variants'))
    CREATE INDEX IX_product_variants_product_id ON masterdata.product_variants(product_id);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_store_orders_store_id_order_datetime' AND object_id = OBJECT_ID(N'sales_offline.store_orders'))
    CREATE INDEX IX_store_orders_store_id_order_datetime ON sales_offline.store_orders(store_id, order_datetime);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_store_orders_customer_id' AND object_id = OBJECT_ID(N'sales_offline.store_orders'))
    CREATE INDEX IX_store_orders_customer_id ON sales_offline.store_orders(customer_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_store_order_items_order_id' AND object_id = OBJECT_ID(N'sales_offline.store_order_items'))
    CREATE INDEX IX_store_order_items_order_id ON sales_offline.store_order_items(order_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_store_order_items_variant_id' AND object_id = OBJECT_ID(N'sales_offline.store_order_items'))
    CREATE INDEX IX_store_order_items_variant_id ON sales_offline.store_order_items(variant_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_store_returns_order_id' AND object_id = OBJECT_ID(N'sales_offline.store_returns'))
    CREATE INDEX IX_store_returns_order_id ON sales_offline.store_returns(order_id);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_online_orders_customer_id_order_datetime' AND object_id = OBJECT_ID(N'sales_online.online_orders'))
    CREATE INDEX IX_online_orders_customer_id_order_datetime ON sales_online.online_orders(customer_id, order_datetime);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_online_order_items_order_id' AND object_id = OBJECT_ID(N'sales_online.online_order_items'))
    CREATE INDEX IX_online_order_items_order_id ON sales_online.online_order_items(order_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_online_order_items_variant_id' AND object_id = OBJECT_ID(N'sales_online.online_order_items'))
    CREATE INDEX IX_online_order_items_variant_id ON sales_online.online_order_items(variant_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_online_fulfillments_order_id' AND object_id = OBJECT_ID(N'sales_online.online_fulfillments'))
    CREATE INDEX IX_online_fulfillments_order_id ON sales_online.online_fulfillments(order_id);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_current_variant_id' AND object_id = OBJECT_ID(N'inventory.inventory_current'))
    CREATE INDEX IX_inventory_current_variant_id ON inventory.inventory_current(variant_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_current_store_id' AND object_id = OBJECT_ID(N'inventory.inventory_current'))
    CREATE INDEX IX_inventory_current_store_id ON inventory.inventory_current(store_id) WHERE store_id IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_current_warehouse_id' AND object_id = OBJECT_ID(N'inventory.inventory_current'))
    CREATE INDEX IX_inventory_current_warehouse_id ON inventory.inventory_current(warehouse_id) WHERE warehouse_id IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_transactions_variant_datetime' AND object_id = OBJECT_ID(N'inventory.inventory_transactions'))
    CREATE INDEX IX_inventory_transactions_variant_datetime ON inventory.inventory_transactions(variant_id, transaction_datetime);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_policy_variant_id' AND object_id = OBJECT_ID(N'inventory.inventory_policy'))
    CREATE INDEX IX_inventory_policy_variant_id ON inventory.inventory_policy(variant_id);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_purchase_orders_collection_id' AND object_id = OBJECT_ID(N'supply.purchase_orders'))
    CREATE INDEX IX_purchase_orders_collection_id ON supply.purchase_orders(collection_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_purchase_orders_supplier_id' AND object_id = OBJECT_ID(N'supply.purchase_orders'))
    CREATE INDEX IX_purchase_orders_supplier_id ON supply.purchase_orders(supplier_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_purchase_order_items_po_id' AND object_id = OBJECT_ID(N'supply.purchase_order_items'))
    CREATE INDEX IX_purchase_order_items_po_id ON supply.purchase_order_items(purchase_order_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_purchase_order_items_variant_id' AND object_id = OBJECT_ID(N'supply.purchase_order_items'))
    CREATE INDEX IX_purchase_order_items_variant_id ON supply.purchase_order_items(variant_id);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_promotion_products_promotion_id' AND object_id = OBJECT_ID(N'marketing.promotion_products'))
    CREATE INDEX IX_promotion_products_promotion_id ON marketing.promotion_products(promotion_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_promotion_products_variant_id' AND object_id = OBJECT_ID(N'marketing.promotion_products'))
    CREATE INDEX IX_promotion_products_variant_id ON marketing.promotion_products(variant_id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_store_targets_store_period' AND object_id = OBJECT_ID(N'marketing.store_targets'))
    CREATE INDEX IX_store_targets_store_period ON marketing.store_targets(store_id, target_year, target_month);
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    i.name AS index_name
FROM sys.indexes AS i
JOIN sys.tables AS t
    ON i.object_id = t.object_id
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE i.type_desc = N'NONCLUSTERED'
  AND s.name IN (N'masterdata', N'sales_offline', N'sales_online', N'inventory', N'supply', N'marketing')
ORDER BY s.name, t.name, i.name;
GO
