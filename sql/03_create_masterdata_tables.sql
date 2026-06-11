/*
Purpose:
    Create master data tables for the FabricFlow fashion domain.
    product_variants is the core SKU-level table used by sales and inventory.

Assumption:
    Blueprint gives exact columns for collections/products/product_variants and role-based descriptions for the rest.
    The additional columns below are the minimum needed to support omnichannel fashion reporting and required FKs.

Verify:
    Run the SELECT at the end to confirm all masterdata tables exist.
*/

USE [FabricFlowDB];
GO

IF OBJECT_ID(N'masterdata.regions', N'U') IS NULL
BEGIN
    CREATE TABLE masterdata.regions
    (
        region_id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_regions PRIMARY KEY,
        region_code      NVARCHAR(20) NOT NULL,
        region_name      NVARCHAR(100) NOT NULL,
        city_name        NVARCHAR(100) NOT NULL,
        is_active        BIT NOT NULL CONSTRAINT DF_regions_is_active DEFAULT (1),
        CONSTRAINT UQ_regions_region_code UNIQUE (region_code)
    );
END;
GO

IF OBJECT_ID(N'masterdata.warehouses', N'U') IS NULL
BEGIN
    CREATE TABLE masterdata.warehouses
    (
        warehouse_id               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_warehouses PRIMARY KEY,
        region_id                  INT NOT NULL,
        warehouse_code             NVARCHAR(20) NOT NULL,
        warehouse_name             NVARCHAR(150) NOT NULL,
        warehouse_type             NVARCHAR(30) NOT NULL,
        address_line               NVARCHAR(250) NULL,
        capacity_units             INT NULL,
        supports_online_fulfillment BIT NOT NULL CONSTRAINT DF_warehouses_supports_online_fulfillment DEFAULT (1),
        is_active                  BIT NOT NULL CONSTRAINT DF_warehouses_is_active DEFAULT (1),
        CONSTRAINT UQ_warehouses_warehouse_code UNIQUE (warehouse_code),
        CONSTRAINT FK_warehouses_regions FOREIGN KEY (region_id) REFERENCES masterdata.regions(region_id),
        CONSTRAINT CK_warehouses_capacity_units_nonnegative CHECK (capacity_units IS NULL OR capacity_units >= 0)
    );
END;
GO

IF OBJECT_ID(N'masterdata.stores', N'U') IS NULL
BEGIN
    CREATE TABLE masterdata.stores
    (
        store_id               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_stores PRIMARY KEY,
        region_id              INT NOT NULL,
        warehouse_id           INT NOT NULL,
        store_code             NVARCHAR(20) NOT NULL,
        store_name             NVARCHAR(150) NOT NULL,
        store_type             NVARCHAR(30) NOT NULL,
        address_line           NVARCHAR(250) NULL,
        open_date              DATE NULL,
        area_sqm               DECIMAL(10,2) NULL,
        demand_multiplier      DECIMAL(8,4) NOT NULL CONSTRAINT DF_stores_demand_multiplier DEFAULT (1.0000),
        supports_ship_from_store BIT NOT NULL CONSTRAINT DF_stores_supports_ship_from_store DEFAULT (0),
        is_active              BIT NOT NULL CONSTRAINT DF_stores_is_active DEFAULT (1),
        CONSTRAINT UQ_stores_store_code UNIQUE (store_code),
        CONSTRAINT FK_stores_regions FOREIGN KEY (region_id) REFERENCES masterdata.regions(region_id),
        CONSTRAINT FK_stores_warehouses FOREIGN KEY (warehouse_id) REFERENCES masterdata.warehouses(warehouse_id),
        CONSTRAINT CK_stores_area_sqm_nonnegative CHECK (area_sqm IS NULL OR area_sqm >= 0),
        CONSTRAINT CK_stores_demand_multiplier_positive CHECK (demand_multiplier > 0)
    );
END;
GO

IF OBJECT_ID(N'masterdata.collections', N'U') IS NULL
BEGIN
    CREATE TABLE masterdata.collections
    (
        collection_id   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_collections PRIMARY KEY,
        collection_name NVARCHAR(100) NOT NULL,
        season          NVARCHAR(10) NOT NULL,
        [year]          INT NOT NULL,
        launch_date     DATE NOT NULL,
        end_date        DATE NOT NULL,
        planned_units   INT NOT NULL,
        CONSTRAINT CK_collections_season CHECK (season IN (N'SS', N'FW')),
        CONSTRAINT CK_collections_year CHECK ([year] BETWEEN 2020 AND 2100),
        CONSTRAINT CK_collections_date_range CHECK (end_date >= launch_date),
        CONSTRAINT CK_collections_planned_units_nonnegative CHECK (planned_units >= 0)
    );
END;
GO

IF OBJECT_ID(N'masterdata.categories', N'U') IS NULL
BEGIN
    CREATE TABLE masterdata.categories
    (
        category_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_categories PRIMARY KEY,
        category_name    NVARCHAR(100) NOT NULL,
        category_group   NVARCHAR(100) NULL,
        target_gender    NVARCHAR(20) NOT NULL,
        target_age_group NVARCHAR(20) NULL,
        is_active        BIT NOT NULL CONSTRAINT DF_categories_is_active DEFAULT (1),
        CONSTRAINT UQ_categories_category_name UNIQUE (category_name),
        CONSTRAINT CK_categories_target_gender CHECK (target_gender IN (N'male', N'female', N'kids', N'unisex'))
    );
END;
GO

IF OBJECT_ID(N'masterdata.products', N'U') IS NULL
BEGIN
    CREATE TABLE masterdata.products
    (
        product_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_products PRIMARY KEY,
        collection_id   INT NOT NULL,
        category_id     INT NOT NULL,
        product_name    NVARCHAR(200) NOT NULL,
        base_price      DECIMAL(10,2) NOT NULL,
        cost_price      DECIMAL(10,2) NOT NULL,
        is_noos         BIT NOT NULL CONSTRAINT DF_products_is_noos DEFAULT (0),
        CONSTRAINT FK_products_collections FOREIGN KEY (collection_id) REFERENCES masterdata.collections(collection_id),
        CONSTRAINT FK_products_categories FOREIGN KEY (category_id) REFERENCES masterdata.categories(category_id),
        CONSTRAINT CK_products_base_price_positive CHECK (base_price >= 0),
        CONSTRAINT CK_products_cost_price_positive CHECK (cost_price >= 0),
        CONSTRAINT CK_products_margin_logic CHECK (base_price >= cost_price)
    );
END;
GO

IF OBJECT_ID(N'masterdata.product_variants', N'U') IS NULL
BEGIN
    CREATE TABLE masterdata.product_variants
    (
        variant_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_product_variants PRIMARY KEY,
        product_id      INT NOT NULL,
        sku_code        NVARCHAR(50) NOT NULL,
        size            NVARCHAR(10) NOT NULL,
        color           NVARCHAR(50) NOT NULL,
        color_code      NVARCHAR(10) NULL,
        selling_price   DECIMAL(10,2) NOT NULL,
        current_price   DECIMAL(10,2) NOT NULL,
        is_active       BIT NOT NULL CONSTRAINT DF_product_variants_is_active DEFAULT (1),
        CONSTRAINT UQ_product_variants_sku_code UNIQUE (sku_code),
        CONSTRAINT FK_product_variants_products FOREIGN KEY (product_id) REFERENCES masterdata.products(product_id),
        CONSTRAINT CK_product_variants_selling_price_nonnegative CHECK (selling_price >= 0),
        CONSTRAINT CK_product_variants_current_price_nonnegative CHECK (current_price >= 0),
        CONSTRAINT CK_product_variants_markdown_logic CHECK (current_price <= selling_price)
    );
END;
GO

IF OBJECT_ID(N'masterdata.customers', N'U') IS NULL
BEGIN
    CREATE TABLE masterdata.customers
    (
        customer_id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_customers PRIMARY KEY,
        customer_code       NVARCHAR(30) NOT NULL,
        full_name           NVARCHAR(150) NOT NULL,
        gender              NVARCHAR(20) NULL,
        age_group           NVARCHAR(20) NULL,
        member_status       NVARCHAR(30) NOT NULL,
        preferred_channel   NVARCHAR(20) NOT NULL,
        city_name           NVARCHAR(100) NULL,
        signup_date         DATE NULL,
        is_active           BIT NOT NULL CONSTRAINT DF_customers_is_active DEFAULT (1),
        CONSTRAINT UQ_customers_customer_code UNIQUE (customer_code),
        CONSTRAINT CK_customers_gender CHECK (gender IS NULL OR gender IN (N'male', N'female', N'other')),
        CONSTRAINT CK_customers_preferred_channel CHECK (preferred_channel IN (N'offline', N'online', N'omnichannel'))
    );
END;
GO

IF OBJECT_ID(N'masterdata.dim_date', N'U') IS NULL
BEGIN
    CREATE TABLE masterdata.dim_date
    (
        date_key          INT NOT NULL CONSTRAINT PK_dim_date PRIMARY KEY,
        full_date         DATE NOT NULL,
        [year]            INT NOT NULL,
        quarter           INT NOT NULL,
        [month]           INT NOT NULL,
        month_name        NVARCHAR(20) NOT NULL,
        month_name_vn     NVARCHAR(20) NOT NULL,
        week_of_year      INT NOT NULL,
        day_of_week       INT NOT NULL,
        day_name          NVARCHAR(20) NOT NULL,
        is_weekend        BIT NOT NULL CONSTRAINT DF_dim_date_is_weekend DEFAULT (0),
        is_weekday        BIT NOT NULL CONSTRAINT DF_dim_date_is_weekday DEFAULT (0),
        fashion_season    NVARCHAR(10) NOT NULL,
        is_tet_holiday    BIT NOT NULL CONSTRAINT DF_dim_date_is_tet_holiday DEFAULT (0),
        is_public_holiday BIT NOT NULL CONSTRAINT DF_dim_date_is_public_holiday DEFAULT (0),
        fiscal_year       INT NOT NULL,
        fiscal_quarter    INT NOT NULL,
        year_month        NVARCHAR(7) NOT NULL,
        quarter_label     NVARCHAR(10) NOT NULL,
        CONSTRAINT UQ_dim_date_full_date UNIQUE (full_date),
        CONSTRAINT CK_dim_date_quarter CHECK (quarter BETWEEN 1 AND 4),
        CONSTRAINT CK_dim_date_month CHECK ([month] BETWEEN 1 AND 12),
        CONSTRAINT CK_dim_date_day_of_week CHECK (day_of_week BETWEEN 1 AND 7),
        CONSTRAINT CK_dim_date_fashion_season CHECK (fashion_season IN (N'SS', N'FW'))
    );
END;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'masterdata'
ORDER BY t.name;
GO
