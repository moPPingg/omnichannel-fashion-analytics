/*
Purpose:
    Create supply chain tables for suppliers, factories, purchase orders, receipts, and quality checks.

Assumption:
    purchase_orders carries supplier_id, factory_id, and collection_id to support buying by collection and vendor/factory performance.

Verify:
    Run the SELECT at the end to confirm all supply tables exist.
*/

USE [FabricFlowDB];
GO

IF OBJECT_ID(N'supply.suppliers', N'U') IS NULL
BEGIN
    CREATE TABLE supply.suppliers
    (
        supplier_id       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_suppliers PRIMARY KEY,
        supplier_code     NVARCHAR(20) NOT NULL,
        supplier_name     NVARCHAR(150) NOT NULL,
        quality_tier      NVARCHAR(30) NOT NULL,
        lead_time_weeks   INT NOT NULL,
        is_active         BIT NOT NULL CONSTRAINT DF_suppliers_is_active DEFAULT (1),
        CONSTRAINT UQ_suppliers_supplier_code UNIQUE (supplier_code),
        CONSTRAINT CK_suppliers_lead_time_weeks_nonnegative CHECK (lead_time_weeks >= 0)
    );
END;
GO

IF OBJECT_ID(N'supply.factories', N'U') IS NULL
BEGIN
    CREATE TABLE supply.factories
    (
        factory_id                 INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_factories PRIMARY KEY,
        supplier_id                INT NULL,
        factory_code               NVARCHAR(20) NOT NULL,
        factory_name               NVARCHAR(150) NOT NULL,
        country_name               NVARCHAR(100) NOT NULL,
        capacity_units_per_month   INT NOT NULL,
        defect_rate                DECIMAL(8,4) NOT NULL,
        moq_units                  INT NOT NULL,
        is_active                  BIT NOT NULL CONSTRAINT DF_factories_is_active DEFAULT (1),
        CONSTRAINT UQ_factories_factory_code UNIQUE (factory_code),
        CONSTRAINT FK_factories_suppliers FOREIGN KEY (supplier_id) REFERENCES supply.suppliers(supplier_id),
        CONSTRAINT CK_factories_capacity_nonnegative CHECK (capacity_units_per_month >= 0),
        CONSTRAINT CK_factories_defect_rate_range CHECK (defect_rate BETWEEN 0 AND 1),
        CONSTRAINT CK_factories_moq_units_nonnegative CHECK (moq_units >= 0)
    );
END;
GO

IF OBJECT_ID(N'supply.factory_products', N'U') IS NULL
BEGIN
    CREATE TABLE supply.factory_products
    (
        factory_product_id    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_factory_products PRIMARY KEY,
        factory_id            INT NOT NULL,
        product_id            INT NOT NULL,
        production_cost       DECIMAL(10,2) NOT NULL,
        lead_time_weeks       INT NOT NULL,
        moq_units             INT NOT NULL,
        is_primary_factory    BIT NOT NULL CONSTRAINT DF_factory_products_is_primary_factory DEFAULT (0),
        CONSTRAINT FK_factory_products_factories FOREIGN KEY (factory_id) REFERENCES supply.factories(factory_id),
        CONSTRAINT FK_factory_products_products FOREIGN KEY (product_id) REFERENCES masterdata.products(product_id),
        CONSTRAINT CK_factory_products_production_cost_nonnegative CHECK (production_cost >= 0),
        CONSTRAINT CK_factory_products_lead_time_weeks_nonnegative CHECK (lead_time_weeks >= 0),
        CONSTRAINT CK_factory_products_moq_units_nonnegative CHECK (moq_units >= 0),
        CONSTRAINT UQ_factory_products_factory_product UNIQUE (factory_id, product_id)
    );
END;
GO

IF OBJECT_ID(N'supply.purchase_orders', N'U') IS NULL
BEGIN
    CREATE TABLE supply.purchase_orders
    (
        purchase_order_id       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_purchase_orders PRIMARY KEY,
        supplier_id             INT NOT NULL,
        factory_id              INT NOT NULL,
        collection_id           INT NOT NULL,
        po_date                 DATE NOT NULL,
        planned_delivery_date   DATE NOT NULL,
        po_status               NVARCHAR(30) NOT NULL,
        total_order_amount      DECIMAL(14,2) NOT NULL,
        CONSTRAINT FK_purchase_orders_suppliers FOREIGN KEY (supplier_id) REFERENCES supply.suppliers(supplier_id),
        CONSTRAINT FK_purchase_orders_factories FOREIGN KEY (factory_id) REFERENCES supply.factories(factory_id),
        CONSTRAINT FK_purchase_orders_collections FOREIGN KEY (collection_id) REFERENCES masterdata.collections(collection_id),
        CONSTRAINT CK_purchase_orders_date_range CHECK (planned_delivery_date >= po_date),
        CONSTRAINT CK_purchase_orders_total_order_amount_nonnegative CHECK (total_order_amount >= 0)
    );
END;
GO

IF OBJECT_ID(N'supply.purchase_order_items', N'U') IS NULL
BEGIN
    CREATE TABLE supply.purchase_order_items
    (
        purchase_order_item_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_purchase_order_items PRIMARY KEY,
        purchase_order_id      INT NOT NULL,
        variant_id             INT NOT NULL,
        ordered_quantity       INT NOT NULL,
        unit_cost              DECIMAL(10,2) NOT NULL,
        line_amount            DECIMAL(14,2) NOT NULL,
        CONSTRAINT FK_purchase_order_items_purchase_orders FOREIGN KEY (purchase_order_id) REFERENCES supply.purchase_orders(purchase_order_id),
        CONSTRAINT FK_purchase_order_items_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT CK_purchase_order_items_ordered_quantity_positive CHECK (ordered_quantity > 0),
        CONSTRAINT CK_purchase_order_items_unit_cost_nonnegative CHECK (unit_cost >= 0),
        CONSTRAINT CK_purchase_order_items_line_amount_nonnegative CHECK (line_amount >= 0)
    );
END;
GO

IF OBJECT_ID(N'supply.goods_receipts', N'U') IS NULL
BEGIN
    CREATE TABLE supply.goods_receipts
    (
        goods_receipt_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_goods_receipts PRIMARY KEY,
        purchase_order_id       INT NOT NULL,
        warehouse_id            INT NOT NULL,
        receipt_date            DATE NOT NULL,
        actual_delivery_date    DATE NOT NULL,
        received_qty            INT NOT NULL,
        receipt_status          NVARCHAR(30) NOT NULL,
        CONSTRAINT FK_goods_receipts_purchase_orders FOREIGN KEY (purchase_order_id) REFERENCES supply.purchase_orders(purchase_order_id),
        CONSTRAINT FK_goods_receipts_warehouses FOREIGN KEY (warehouse_id) REFERENCES masterdata.warehouses(warehouse_id),
        CONSTRAINT CK_goods_receipts_received_qty_nonnegative CHECK (received_qty >= 0)
    );
END;
GO

IF OBJECT_ID(N'supply.quality_checks', N'U') IS NULL
BEGIN
    CREATE TABLE supply.quality_checks
    (
        quality_check_id    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_quality_checks PRIMARY KEY,
        goods_receipt_id    INT NOT NULL,
        check_date          DATE NOT NULL,
        accepted_qty        INT NOT NULL,
        rejected_qty        INT NOT NULL,
        defect_type         NVARCHAR(100) NULL,
        quality_status      NVARCHAR(30) NOT NULL,
        CONSTRAINT FK_quality_checks_goods_receipts FOREIGN KEY (goods_receipt_id) REFERENCES supply.goods_receipts(goods_receipt_id),
        CONSTRAINT CK_quality_checks_accepted_qty_nonnegative CHECK (accepted_qty >= 0),
        CONSTRAINT CK_quality_checks_rejected_qty_nonnegative CHECK (rejected_qty >= 0)
    );
END;
GO

IF OBJECT_ID(N'inventory.inventory_transactions', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1
       FROM sys.foreign_keys
       WHERE name = N'FK_inventory_transactions_purchase_orders'
         AND parent_object_id = OBJECT_ID(N'inventory.inventory_transactions')
   )
BEGIN
    ALTER TABLE inventory.inventory_transactions
    ADD CONSTRAINT FK_inventory_transactions_purchase_orders
        FOREIGN KEY (reference_po_id) REFERENCES supply.purchase_orders(purchase_order_id);
END;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'supply'
ORDER BY t.name;
GO
