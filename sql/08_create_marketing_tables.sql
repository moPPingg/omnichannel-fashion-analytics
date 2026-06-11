/*
Purpose:
    Create marketing and target-setting tables for fashion campaigns and store goals.

Assumption:
    promotion_products is modeled at variant level because markdown and sell-through analysis usually happens at SKU level.

Verify:
    Run the SELECT at the end to confirm all marketing tables exist.
*/

USE [FabricFlowDB];
GO

IF OBJECT_ID(N'marketing.promotions', N'U') IS NULL
BEGIN
    CREATE TABLE marketing.promotions
    (
        promotion_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_promotions PRIMARY KEY,
        promotion_name    NVARCHAR(150) NOT NULL,
        promotion_type    NVARCHAR(50) NOT NULL,
        start_date        DATE NOT NULL,
        end_date          DATE NOT NULL,
        channel_scope     NVARCHAR(20) NOT NULL,
        discount_rate     DECIMAL(5,2) NOT NULL,
        CONSTRAINT CK_promotions_date_range CHECK (end_date >= start_date),
        CONSTRAINT CK_promotions_channel_scope CHECK (channel_scope IN (N'offline', N'online', N'omnichannel')),
        CONSTRAINT CK_promotions_discount_rate CHECK (discount_rate BETWEEN 0 AND 100)
    );
END;
GO

IF OBJECT_ID(N'marketing.promotion_products', N'U') IS NULL
BEGIN
    CREATE TABLE marketing.promotion_products
    (
        promotion_product_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_promotion_products PRIMARY KEY,
        promotion_id         INT NOT NULL,
        variant_id           INT NOT NULL,
        discount_rate        DECIMAL(5,2) NOT NULL,
        CONSTRAINT FK_promotion_products_promotions FOREIGN KEY (promotion_id) REFERENCES marketing.promotions(promotion_id),
        CONSTRAINT FK_promotion_products_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT CK_promotion_products_discount_rate CHECK (discount_rate BETWEEN 0 AND 100),
        CONSTRAINT UQ_promotion_products UNIQUE (promotion_id, variant_id)
    );
END;
GO

IF OBJECT_ID(N'marketing.collection_events', N'U') IS NULL
BEGIN
    CREATE TABLE marketing.collection_events
    (
        collection_event_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_collection_events PRIMARY KEY,
        collection_id       INT NOT NULL,
        event_name          NVARCHAR(150) NOT NULL,
        event_type          NVARCHAR(50) NOT NULL,
        event_date          DATE NOT NULL,
        budget_amount       DECIMAL(12,2) NULL,
        notes               NVARCHAR(300) NULL,
        CONSTRAINT FK_collection_events_collections FOREIGN KEY (collection_id) REFERENCES masterdata.collections(collection_id),
        CONSTRAINT CK_collection_events_budget_amount_nonnegative CHECK (budget_amount IS NULL OR budget_amount >= 0)
    );
END;
GO

IF OBJECT_ID(N'marketing.store_targets', N'U') IS NULL
BEGIN
    CREATE TABLE marketing.store_targets
    (
        store_target_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_store_targets PRIMARY KEY,
        store_id                INT NOT NULL,
        target_year             INT NOT NULL,
        target_month            INT NOT NULL,
        revenue_target          DECIMAL(14,2) NOT NULL,
        sell_through_target_pct DECIMAL(5,2) NOT NULL,
        upt_target              DECIMAL(8,2) NOT NULL,
        CONSTRAINT FK_store_targets_stores FOREIGN KEY (store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT CK_store_targets_target_month CHECK (target_month BETWEEN 1 AND 12),
        CONSTRAINT CK_store_targets_revenue_target_nonnegative CHECK (revenue_target >= 0),
        CONSTRAINT CK_store_targets_sell_through_target_pct CHECK (sell_through_target_pct BETWEEN 0 AND 100),
        CONSTRAINT CK_store_targets_upt_target_nonnegative CHECK (upt_target >= 0),
        CONSTRAINT UQ_store_targets_store_period UNIQUE (store_id, target_year, target_month)
    );
END;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'marketing'
ORDER BY t.name;
GO
