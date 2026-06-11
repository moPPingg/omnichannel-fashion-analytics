/*
Purpose:
    Create inventory tables for current stock, inventory history, policy, and transfer flows.

Assumption:
    store_id / warehouse_id dual-key design is used instead of a single polymorphic location_id
    so SQL Server can enforce real foreign keys.

Verify:
    Run the SELECT at the end to confirm all inventory tables exist.
*/

USE [FabricFlowDB];
GO

IF OBJECT_ID(N'inventory.inventory_current', N'U') IS NULL
BEGIN
    CREATE TABLE inventory.inventory_current
    (
        inventory_current_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_inventory_current PRIMARY KEY,
        location_type        NVARCHAR(20) NOT NULL,
        store_id             INT NULL,
        warehouse_id         INT NULL,
        variant_id           INT NOT NULL,
        stock_quantity       INT NOT NULL,
        last_updated         DATETIME2(0) NOT NULL CONSTRAINT DF_inventory_current_last_updated DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_inventory_current_stores FOREIGN KEY (store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT FK_inventory_current_warehouses FOREIGN KEY (warehouse_id) REFERENCES masterdata.warehouses(warehouse_id),
        CONSTRAINT FK_inventory_current_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT CK_inventory_current_location_type CHECK (location_type IN (N'store', N'warehouse')),
        CONSTRAINT CK_inventory_current_single_location CHECK (
            (store_id IS NOT NULL AND warehouse_id IS NULL AND location_type = N'store')
            OR
            (store_id IS NULL AND warehouse_id IS NOT NULL AND location_type = N'warehouse')
        ),
        CONSTRAINT CK_inventory_current_stock_quantity_nonnegative CHECK (stock_quantity >= 0),
        CONSTRAINT UQ_inventory_current_location_variant UNIQUE (store_id, warehouse_id, variant_id)
    );
END;
GO

IF OBJECT_ID(N'inventory.inventory_policy', N'U') IS NULL
BEGIN
    CREATE TABLE inventory.inventory_policy
    (
        inventory_policy_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_inventory_policy PRIMARY KEY,
        variant_id          INT NOT NULL,
        store_id            INT NULL,
        warehouse_id        INT NULL,
        safety_stock_qty    INT NOT NULL,
        reorder_point_qty   INT NOT NULL,
        target_cover_days   INT NULL,
        policy_type         NVARCHAR(30) NOT NULL,
        CONSTRAINT FK_inventory_policy_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT FK_inventory_policy_stores FOREIGN KEY (store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT FK_inventory_policy_warehouses FOREIGN KEY (warehouse_id) REFERENCES masterdata.warehouses(warehouse_id),
        CONSTRAINT CK_inventory_policy_single_location CHECK (
            (store_id IS NOT NULL AND warehouse_id IS NULL)
            OR
            (store_id IS NULL AND warehouse_id IS NOT NULL)
        ),
        CONSTRAINT CK_inventory_policy_safety_stock_nonnegative CHECK (safety_stock_qty >= 0),
        CONSTRAINT CK_inventory_policy_reorder_point_nonnegative CHECK (reorder_point_qty >= 0),
        CONSTRAINT CK_inventory_policy_target_cover_days_nonnegative CHECK (target_cover_days IS NULL OR target_cover_days >= 0),
        CONSTRAINT CK_inventory_policy_policy_type CHECK (policy_type IN (N'noos', N'seasonal')),
        CONSTRAINT UQ_inventory_policy_location_variant UNIQUE (variant_id, store_id, warehouse_id)
    );
END;
GO

IF OBJECT_ID(N'inventory.stock_transfers', N'U') IS NULL
BEGIN
    CREATE TABLE inventory.stock_transfers
    (
        stock_transfer_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_stock_transfers PRIMARY KEY,
        transfer_datetime        DATETIME2(0) NOT NULL,
        from_store_id            INT NULL,
        from_warehouse_id        INT NULL,
        to_store_id              INT NULL,
        to_warehouse_id          INT NULL,
        transfer_status          NVARCHAR(30) NOT NULL,
        transfer_reason          NVARCHAR(100) NOT NULL,
        related_online_order_id  INT NULL,
        CONSTRAINT FK_stock_transfers_from_store FOREIGN KEY (from_store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT FK_stock_transfers_from_warehouse FOREIGN KEY (from_warehouse_id) REFERENCES masterdata.warehouses(warehouse_id),
        CONSTRAINT FK_stock_transfers_to_store FOREIGN KEY (to_store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT FK_stock_transfers_to_warehouse FOREIGN KEY (to_warehouse_id) REFERENCES masterdata.warehouses(warehouse_id),
        CONSTRAINT FK_stock_transfers_online_orders FOREIGN KEY (related_online_order_id) REFERENCES sales_online.online_orders(order_id),
        CONSTRAINT CK_stock_transfers_from_single_source CHECK (
            (from_store_id IS NOT NULL AND from_warehouse_id IS NULL)
            OR
            (from_store_id IS NULL AND from_warehouse_id IS NOT NULL)
        ),
        CONSTRAINT CK_stock_transfers_to_single_target CHECK (
            (to_store_id IS NOT NULL AND to_warehouse_id IS NULL)
            OR
            (to_store_id IS NULL AND to_warehouse_id IS NOT NULL)
        )
    );
END;
GO

IF OBJECT_ID(N'inventory.stock_transfer_items', N'U') IS NULL
BEGIN
    CREATE TABLE inventory.stock_transfer_items
    (
        stock_transfer_item_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_stock_transfer_items PRIMARY KEY,
        stock_transfer_id      INT NOT NULL,
        variant_id             INT NOT NULL,
        quantity               INT NOT NULL,
        CONSTRAINT FK_stock_transfer_items_stock_transfers FOREIGN KEY (stock_transfer_id) REFERENCES inventory.stock_transfers(stock_transfer_id),
        CONSTRAINT FK_stock_transfer_items_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT CK_stock_transfer_items_quantity_positive CHECK (quantity > 0)
    );
END;
GO

IF OBJECT_ID(N'inventory.inventory_transactions', N'U') IS NULL
BEGIN
    CREATE TABLE inventory.inventory_transactions
    (
        inventory_transaction_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_inventory_transactions PRIMARY KEY,
        transaction_datetime     DATETIME2(0) NOT NULL,
        transaction_type         NVARCHAR(30) NOT NULL,
        store_id                 INT NULL,
        warehouse_id             INT NULL,
        variant_id               INT NOT NULL,
        quantity_change          INT NOT NULL,
        reference_order_id       INT NULL,
        reference_online_order_id INT NULL,
        reference_po_id          INT NULL,
        reference_transfer_id    INT NULL,
        reference_note           NVARCHAR(200) NULL,
        CONSTRAINT FK_inventory_transactions_stores FOREIGN KEY (store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT FK_inventory_transactions_warehouses FOREIGN KEY (warehouse_id) REFERENCES masterdata.warehouses(warehouse_id),
        CONSTRAINT FK_inventory_transactions_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT FK_inventory_transactions_store_orders FOREIGN KEY (reference_order_id) REFERENCES sales_offline.store_orders(order_id),
        CONSTRAINT FK_inventory_transactions_online_orders FOREIGN KEY (reference_online_order_id) REFERENCES sales_online.online_orders(order_id),
        CONSTRAINT FK_inventory_transactions_stock_transfers FOREIGN KEY (reference_transfer_id) REFERENCES inventory.stock_transfers(stock_transfer_id),
        CONSTRAINT CK_inventory_transactions_type CHECK (transaction_type IN (
            N'purchase_receipt',
            N'store_sale',
            N'online_sale',
            N'return_in',
            N'return_out',
            N'transfer_in',
            N'transfer_out',
            N'adjustment'
        )),
        CONSTRAINT CK_inventory_transactions_location_present CHECK (store_id IS NOT NULL OR warehouse_id IS NOT NULL),
        CONSTRAINT CK_inventory_transactions_quantity_change_nonzero CHECK (quantity_change <> 0)
    );
END;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'inventory'
ORDER BY t.name;
GO
