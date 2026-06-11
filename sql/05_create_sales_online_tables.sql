/*
Purpose:
    Create online channel sales, fulfillment, and return tables.

Assumption:
    online_fulfillments uses nullable store_id / warehouse_id plus a CHECK to enforce one source per fulfillment.
    This keeps hard FKs in SQL Server for ship-from-store and warehouse routing.

Verify:
    Run the SELECT at the end to confirm all sales_online tables exist.
*/

USE [FabricFlowDB];
GO

IF OBJECT_ID(N'sales_online.online_orders', N'U') IS NULL
BEGIN
    CREATE TABLE sales_online.online_orders
    (
        order_id            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_online_orders PRIMARY KEY,
        customer_id         INT NOT NULL,
        order_datetime      DATETIME2(0) NOT NULL,
        channel             NVARCHAR(20) NOT NULL,
        shipping_address    NVARCHAR(300) NOT NULL,
        payment_method      NVARCHAR(30) NOT NULL,
        order_status        NVARCHAR(30) NOT NULL,
        subtotal_amount     DECIMAL(12,2) NOT NULL,
        shipping_fee        DECIMAL(12,2) NOT NULL CONSTRAINT DF_online_orders_shipping_fee DEFAULT (0),
        discount_amount     DECIMAL(12,2) NOT NULL CONSTRAINT DF_online_orders_discount_amount DEFAULT (0),
        total_amount        DECIMAL(12,2) NOT NULL,
        CONSTRAINT FK_online_orders_customers FOREIGN KEY (customer_id) REFERENCES masterdata.customers(customer_id),
        CONSTRAINT CK_online_orders_channel CHECK (channel IN (N'web', N'app')),
        CONSTRAINT CK_online_orders_payment_method CHECK (payment_method IN (N'cod', N'prepaid', N'installment')),
        CONSTRAINT CK_online_orders_subtotal_amount_nonnegative CHECK (subtotal_amount >= 0),
        CONSTRAINT CK_online_orders_shipping_fee_nonnegative CHECK (shipping_fee >= 0),
        CONSTRAINT CK_online_orders_discount_amount_nonnegative CHECK (discount_amount >= 0),
        CONSTRAINT CK_online_orders_total_amount_nonnegative CHECK (total_amount >= 0)
    );
END;
GO

IF OBJECT_ID(N'sales_online.online_order_items', N'U') IS NULL
BEGIN
    CREATE TABLE sales_online.online_order_items
    (
        item_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_online_order_items PRIMARY KEY,
        order_id        INT NOT NULL,
        variant_id      INT NOT NULL,
        quantity        INT NOT NULL,
        unit_price      DECIMAL(10,2) NOT NULL,
        discount_pct    DECIMAL(5,2) NOT NULL CONSTRAINT DF_online_order_items_discount_pct DEFAULT (0),
        line_total      DECIMAL(12,2) NOT NULL,
        gross_profit    DECIMAL(12,2) NOT NULL,
        CONSTRAINT FK_online_order_items_online_orders FOREIGN KEY (order_id) REFERENCES sales_online.online_orders(order_id),
        CONSTRAINT FK_online_order_items_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT CK_online_order_items_quantity_positive CHECK (quantity > 0),
        CONSTRAINT CK_online_order_items_discount_pct_range CHECK (discount_pct BETWEEN 0 AND 100),
        CONSTRAINT CK_online_order_items_unit_price_nonnegative CHECK (unit_price >= 0),
        CONSTRAINT CK_online_order_items_line_total_nonnegative CHECK (line_total >= 0)
    );
END;
GO

IF OBJECT_ID(N'sales_online.online_payments', N'U') IS NULL
BEGIN
    CREATE TABLE sales_online.online_payments
    (
        payment_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_online_payments PRIMARY KEY,
        order_id          INT NOT NULL,
        payment_datetime  DATETIME2(0) NOT NULL,
        payment_method    NVARCHAR(30) NOT NULL,
        payment_status    NVARCHAR(30) NOT NULL,
        amount_paid       DECIMAL(12,2) NOT NULL,
        CONSTRAINT FK_online_payments_online_orders FOREIGN KEY (order_id) REFERENCES sales_online.online_orders(order_id),
        CONSTRAINT CK_online_payments_method CHECK (payment_method IN (N'cod', N'prepaid', N'installment')),
        CONSTRAINT CK_online_payments_amount_paid_nonnegative CHECK (amount_paid >= 0)
    );
END;
GO

IF OBJECT_ID(N'sales_online.online_fulfillments', N'U') IS NULL
BEGIN
    CREATE TABLE sales_online.online_fulfillments
    (
        fulfillment_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_online_fulfillments PRIMARY KEY,
        order_id            INT NOT NULL,
        fulfilled_from      NVARCHAR(20) NOT NULL,
        store_id            INT NULL,
        warehouse_id        INT NULL,
        fulfillment_status  NVARCHAR(30) NOT NULL,
        shipped_at          DATETIME2(0) NULL,
        delivered_at        DATETIME2(0) NULL,
        shipping_carrier    NVARCHAR(50) NULL,
        tracking_number     NVARCHAR(100) NULL,
        CONSTRAINT FK_online_fulfillments_online_orders FOREIGN KEY (order_id) REFERENCES sales_online.online_orders(order_id),
        CONSTRAINT FK_online_fulfillments_stores FOREIGN KEY (store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT FK_online_fulfillments_warehouses FOREIGN KEY (warehouse_id) REFERENCES masterdata.warehouses(warehouse_id),
        CONSTRAINT CK_online_fulfillments_source CHECK (fulfilled_from IN (N'store', N'warehouse')),
        CONSTRAINT CK_online_fulfillments_single_source CHECK (
            (store_id IS NOT NULL AND warehouse_id IS NULL AND fulfilled_from = N'store')
            OR
            (store_id IS NULL AND warehouse_id IS NOT NULL AND fulfilled_from = N'warehouse')
        ),
        CONSTRAINT CK_online_fulfillments_timeline CHECK (delivered_at IS NULL OR shipped_at IS NULL OR delivered_at >= shipped_at)
    );
END;
GO

IF OBJECT_ID(N'sales_online.online_returns', N'U') IS NULL
BEGIN
    CREATE TABLE sales_online.online_returns
    (
        return_id             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_online_returns PRIMARY KEY,
        order_id              INT NOT NULL,
        customer_id           INT NULL,
        return_datetime       DATETIME2(0) NOT NULL,
        return_reason         NVARCHAR(100) NOT NULL,
        return_condition      NVARCHAR(50) NOT NULL,
        refund_status         NVARCHAR(30) NOT NULL,
        total_refund_amount   DECIMAL(12,2) NOT NULL,
        CONSTRAINT FK_online_returns_online_orders FOREIGN KEY (order_id) REFERENCES sales_online.online_orders(order_id),
        CONSTRAINT FK_online_returns_customers FOREIGN KEY (customer_id) REFERENCES masterdata.customers(customer_id),
        CONSTRAINT CK_online_returns_total_refund_amount_nonnegative CHECK (total_refund_amount >= 0)
    );
END;
GO

IF OBJECT_ID(N'sales_online.online_return_items', N'U') IS NULL
BEGIN
    CREATE TABLE sales_online.online_return_items
    (
        return_item_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_online_return_items PRIMARY KEY,
        return_id           INT NOT NULL,
        order_id            INT NOT NULL,
        variant_id          INT NOT NULL,
        quantity            INT NOT NULL,
        refund_amount       DECIMAL(12,2) NOT NULL,
        return_condition    NVARCHAR(50) NULL,
        CONSTRAINT FK_online_return_items_online_returns FOREIGN KEY (return_id) REFERENCES sales_online.online_returns(return_id),
        CONSTRAINT FK_online_return_items_online_orders FOREIGN KEY (order_id) REFERENCES sales_online.online_orders(order_id),
        CONSTRAINT FK_online_return_items_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT CK_online_return_items_quantity_positive CHECK (quantity > 0),
        CONSTRAINT CK_online_return_items_refund_amount_nonnegative CHECK (refund_amount >= 0)
    );
END;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'sales_online'
ORDER BY t.name;
GO
