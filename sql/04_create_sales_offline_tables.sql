/*
Purpose:
    Create offline store sales and returns tables.

Verify:
    Run the SELECT at the end to confirm all sales_offline tables exist.
*/

USE [FabricFlowDB];
GO

IF OBJECT_ID(N'sales_offline.store_orders', N'U') IS NULL
BEGIN
    CREATE TABLE sales_offline.store_orders
    (
        order_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_store_orders PRIMARY KEY,
        store_id         INT NOT NULL,
        customer_id      INT NOT NULL,
        staff_id         NVARCHAR(30) NULL,
        order_datetime   DATETIME2(0) NOT NULL,
        total_amount     DECIMAL(12,2) NOT NULL,
        discount_amount  DECIMAL(12,2) NOT NULL CONSTRAINT DF_store_orders_discount_amount DEFAULT (0),
        CONSTRAINT FK_store_orders_stores FOREIGN KEY (store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT FK_store_orders_customers FOREIGN KEY (customer_id) REFERENCES masterdata.customers(customer_id),
        CONSTRAINT CK_store_orders_total_amount_nonnegative CHECK (total_amount >= 0),
        CONSTRAINT CK_store_orders_discount_amount_nonnegative CHECK (discount_amount >= 0)
    );
END;
GO

IF OBJECT_ID(N'sales_offline.store_order_items', N'U') IS NULL
BEGIN
    CREATE TABLE sales_offline.store_order_items
    (
        item_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_store_order_items PRIMARY KEY,
        order_id        INT NOT NULL,
        variant_id      INT NOT NULL,
        quantity        INT NOT NULL,
        unit_price      DECIMAL(10,2) NOT NULL,
        discount_pct    DECIMAL(5,2) NOT NULL CONSTRAINT DF_store_order_items_discount_pct DEFAULT (0),
        line_total      DECIMAL(12,2) NOT NULL,
        gross_profit    DECIMAL(12,2) NOT NULL,
        CONSTRAINT FK_store_order_items_store_orders FOREIGN KEY (order_id) REFERENCES sales_offline.store_orders(order_id),
        CONSTRAINT FK_store_order_items_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT CK_store_order_items_quantity_positive CHECK (quantity > 0),
        CONSTRAINT CK_store_order_items_unit_price_nonnegative CHECK (unit_price >= 0),
        CONSTRAINT CK_store_order_items_discount_pct_range CHECK (discount_pct BETWEEN 0 AND 100),
        CONSTRAINT CK_store_order_items_line_total_nonnegative CHECK (line_total >= 0)
    );
END;
GO

IF OBJECT_ID(N'sales_offline.store_payments', N'U') IS NULL
BEGIN
    CREATE TABLE sales_offline.store_payments
    (
        payment_id       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_store_payments PRIMARY KEY,
        order_id         INT NOT NULL,
        payment_datetime DATETIME2(0) NOT NULL,
        payment_method   NVARCHAR(30) NOT NULL,
        amount_paid      DECIMAL(12,2) NOT NULL,
        CONSTRAINT FK_store_payments_store_orders FOREIGN KEY (order_id) REFERENCES sales_offline.store_orders(order_id),
        CONSTRAINT CK_store_payments_method CHECK (payment_method IN (N'cash', N'card', N'e-wallet')),
        CONSTRAINT CK_store_payments_amount_paid_nonnegative CHECK (amount_paid >= 0)
    );
END;
GO

IF OBJECT_ID(N'sales_offline.store_returns', N'U') IS NULL
BEGIN
    CREATE TABLE sales_offline.store_returns
    (
        return_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_store_returns PRIMARY KEY,
        order_id          INT NOT NULL,
        store_id          INT NOT NULL,
        customer_id       INT NULL,
        return_datetime   DATETIME2(0) NOT NULL,
        return_reason     NVARCHAR(100) NOT NULL,
        refund_method     NVARCHAR(30) NOT NULL,
        total_refund_amount DECIMAL(12,2) NOT NULL,
        CONSTRAINT FK_store_returns_store_orders FOREIGN KEY (order_id) REFERENCES sales_offline.store_orders(order_id),
        CONSTRAINT FK_store_returns_stores FOREIGN KEY (store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT FK_store_returns_customers FOREIGN KEY (customer_id) REFERENCES masterdata.customers(customer_id),
        CONSTRAINT CK_store_returns_total_refund_amount_nonnegative CHECK (total_refund_amount >= 0)
    );
END;
GO

IF OBJECT_ID(N'sales_offline.store_return_items', N'U') IS NULL
BEGIN
    CREATE TABLE sales_offline.store_return_items
    (
        return_item_id    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_store_return_items PRIMARY KEY,
        return_id         INT NOT NULL,
        order_id          INT NOT NULL,
        variant_id        INT NOT NULL,
        quantity          INT NOT NULL,
        refund_amount     DECIMAL(12,2) NOT NULL,
        return_condition  NVARCHAR(30) NULL,
        CONSTRAINT FK_store_return_items_store_returns FOREIGN KEY (return_id) REFERENCES sales_offline.store_returns(return_id),
        CONSTRAINT FK_store_return_items_store_orders FOREIGN KEY (order_id) REFERENCES sales_offline.store_orders(order_id),
        CONSTRAINT FK_store_return_items_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT CK_store_return_items_quantity_positive CHECK (quantity > 0),
        CONSTRAINT CK_store_return_items_refund_amount_nonnegative CHECK (refund_amount >= 0)
    );
END;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'sales_offline'
ORDER BY t.name;
GO
