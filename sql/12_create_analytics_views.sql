/*
Purpose:
    Create analytics schema views as a semantic layer for Power BI.
    These are intentionally lightweight skeleton views for the SQL-first phase.

Verify:
    Run the SELECT at the end to confirm all analytics views exist.
*/

USE [FabricFlowDB];
GO

CREATE OR ALTER VIEW analytics.vw_dim_sku
AS
SELECT
    pv.variant_id,
    pv.sku_code,
    pv.size,
    pv.color,
    pv.color_code,
    pv.selling_price,
    pv.current_price,
    p.product_id,
    p.product_name,
    p.base_price,
    p.cost_price,
    p.is_noos,
    c.collection_id,
    c.collection_name,
    c.season,
    c.[year] AS collection_year,
    c.launch_date,
    c.end_date,
    c.planned_units,
    cat.category_id,
    cat.category_name,
    cat.category_group,
    cat.target_gender,
    cat.target_age_group
FROM masterdata.product_variants AS pv
JOIN masterdata.products AS p
    ON pv.product_id = p.product_id
JOIN masterdata.collections AS c
    ON p.collection_id = c.collection_id
JOIN masterdata.categories AS cat
    ON p.category_id = cat.category_id;
GO

CREATE OR ALTER VIEW analytics.vw_dim_store
AS
SELECT
    s.store_id,
    s.store_code,
    s.store_name,
    s.store_type,
    s.area_sqm,
    s.demand_multiplier,
    s.supports_ship_from_store,
    r.region_id,
    r.region_code,
    r.region_name,
    r.city_name,
    w.warehouse_id,
    w.warehouse_code,
    w.warehouse_name
FROM masterdata.stores AS s
JOIN masterdata.regions AS r
    ON s.region_id = r.region_id
JOIN masterdata.warehouses AS w
    ON s.warehouse_id = w.warehouse_id;
GO

CREATE OR ALTER VIEW analytics.vw_dim_customer
AS
SELECT
    customer_id,
    customer_code,
    full_name,
    gender,
    age_group,
    member_status,
    preferred_channel,
    city_name,
    signup_date,
    is_active
FROM masterdata.customers;
GO

CREATE OR ALTER VIEW analytics.vw_fact_sales
AS
SELECT
    N'offline' AS sales_channel,
    so.order_id,
    CAST(so.order_datetime AS DATE) AS order_date,
    so.order_datetime,
    so.store_id,
    NULL AS fulfilled_store_id,
    NULL AS fulfilled_warehouse_id,
    so.customer_id,
    soi.variant_id,
    soi.quantity,
    soi.unit_price,
    soi.discount_pct,
    soi.line_total,
    soi.gross_profit
FROM sales_offline.store_orders AS so
JOIN sales_offline.store_order_items AS soi
    ON so.order_id = soi.order_id

UNION ALL

SELECT
    N'online' AS sales_channel,
    oo.order_id,
    CAST(oo.order_datetime AS DATE) AS order_date,
    oo.order_datetime,
    NULL AS store_id,
    ofu.store_id AS fulfilled_store_id,
    ofu.warehouse_id AS fulfilled_warehouse_id,
    oo.customer_id,
    ooi.variant_id,
    ooi.quantity,
    ooi.unit_price,
    ooi.discount_pct,
    ooi.line_total,
    ooi.gross_profit
FROM sales_online.online_orders AS oo
JOIN sales_online.online_order_items AS ooi
    ON oo.order_id = ooi.order_id
LEFT JOIN sales_online.online_fulfillments AS ofu
    ON oo.order_id = ofu.order_id;
GO

CREATE OR ALTER VIEW analytics.vw_inventory_status
AS
SELECT
    ic.inventory_current_id,
    ic.location_type,
    ic.store_id,
    ic.warehouse_id,
    ic.variant_id,
    ic.stock_quantity,
    ic.last_updated,
    DATEDIFF(DAY, c.launch_date, CAST(ic.last_updated AS DATE)) / 7.0 AS weeks_in_stock
FROM inventory.inventory_current AS ic
JOIN masterdata.product_variants AS pv
    ON ic.variant_id = pv.variant_id
JOIN masterdata.products AS p
    ON pv.product_id = p.product_id
JOIN masterdata.collections AS c
    ON p.collection_id = c.collection_id;
GO

CREATE OR ALTER VIEW analytics.vw_sell_through
AS
WITH sold_units AS
(
    SELECT
        v.collection_id,
        v.category_id,
        v.product_id,
        v.variant_id,
        SUM(fs.quantity) AS sold_units
    FROM analytics.vw_fact_sales AS fs
    JOIN analytics.vw_dim_sku AS v
        ON fs.variant_id = v.variant_id
    GROUP BY
        v.collection_id,
        v.category_id,
        v.product_id,
        v.variant_id
),
planned_units AS
(
    SELECT
        collection_id,
        planned_units
    FROM masterdata.collections
)
SELECT
    d.collection_id,
    d.collection_name,
    d.category_id,
    d.category_name,
    d.product_id,
    d.product_name,
    d.variant_id,
    d.sku_code,
    COALESCE(s.sold_units, 0) AS sold_units,
    p.planned_units,
    CASE
        WHEN p.planned_units > 0
            THEN CAST(COALESCE(s.sold_units, 0) * 100.0 / p.planned_units AS DECIMAL(10,2))
        ELSE NULL
    END AS sell_through_rate_pct
FROM analytics.vw_dim_sku AS d
LEFT JOIN sold_units AS s
    ON d.variant_id = s.variant_id
LEFT JOIN planned_units AS p
    ON d.collection_id = p.collection_id;
GO

CREATE OR ALTER VIEW analytics.vw_markdown_analysis
AS
SELECT
    d.collection_id,
    d.collection_name,
    d.product_id,
    d.product_name,
    d.variant_id,
    d.sku_code,
    d.selling_price,
    d.current_price,
    CAST(
        CASE
            WHEN d.selling_price > 0
                THEN (d.selling_price - d.current_price) * 100.0 / d.selling_price
            ELSE NULL
        END
        AS DECIMAL(10,2)
    ) AS markdown_rate_pct,
    i.stock_quantity,
    i.weeks_in_stock
FROM analytics.vw_dim_sku AS d
LEFT JOIN analytics.vw_inventory_status AS i
    ON d.variant_id = i.variant_id;
GO

CREATE OR ALTER VIEW analytics.vw_channel_performance
AS
SELECT
    sales_channel,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(quantity) AS units_sold,
    SUM(line_total) AS revenue,
    SUM(gross_profit) AS gross_profit
FROM analytics.vw_fact_sales
GROUP BY sales_channel;
GO

CREATE OR ALTER VIEW analytics.vw_return_analysis
AS
SELECT
    N'offline' AS return_channel,
    sri.variant_id,
    SUM(sri.quantity) AS return_units,
    SUM(sri.refund_amount) AS refund_amount
FROM sales_offline.store_return_items AS sri
GROUP BY sri.variant_id

UNION ALL

SELECT
    N'online' AS return_channel,
    ori.variant_id,
    SUM(ori.quantity) AS return_units,
    SUM(ori.refund_amount) AS refund_amount
FROM sales_online.online_return_items AS ori
GROUP BY ori.variant_id;
GO

CREATE OR ALTER VIEW analytics.vw_supplier_performance
AS
SELECT
    s.supplier_id,
    s.supplier_name,
    f.factory_id,
    f.factory_name,
    COUNT(DISTINCT po.purchase_order_id) AS po_count,
    SUM(COALESCE(qc.rejected_qty, 0)) AS total_rejected_qty,
    AVG(CAST(f.defect_rate AS DECIMAL(10,4))) AS avg_factory_defect_rate
FROM supply.suppliers AS s
JOIN supply.factories AS f
    ON s.supplier_id = f.supplier_id
LEFT JOIN supply.purchase_orders AS po
    ON f.factory_id = po.factory_id
LEFT JOIN supply.goods_receipts AS gr
    ON po.purchase_order_id = gr.purchase_order_id
LEFT JOIN supply.quality_checks AS qc
    ON gr.goods_receipt_id = qc.goods_receipt_id
GROUP BY
    s.supplier_id,
    s.supplier_name,
    f.factory_id,
    f.factory_name;
GO

SELECT
    s.name AS schema_name,
    v.name AS view_name
FROM sys.views AS v
JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
WHERE s.name = N'analytics'
ORDER BY v.name;
GO
