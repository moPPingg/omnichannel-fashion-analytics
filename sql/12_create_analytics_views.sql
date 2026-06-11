/*
Purpose:
    Create reporting-ready analytics views for Power BI.
    These views unify offline and online facts and expose fashion-specific KPIs.

Verify:
    Run the SELECT at the end to confirm all required analytics views exist.
*/

USE [FabricFlowDB];
GO

CREATE OR ALTER VIEW analytics.vw_dim_sku
AS
SELECT
    pv.variant_id,
    pv.sku_code,
    p.product_id,
    p.product_name,
    cat.category_name AS category,
    c.collection_name AS collection,
    c.season,
    pv.size,
    pv.color,
    pv.selling_price,
    pv.current_price,
    p.is_noos
FROM masterdata.product_variants AS pv
JOIN masterdata.products AS p
    ON pv.product_id = p.product_id
JOIN masterdata.categories AS cat
    ON p.category_id = cat.category_id
JOIN masterdata.collections AS c
    ON p.collection_id = c.collection_id;
GO

CREATE OR ALTER VIEW analytics.vw_fact_sales
AS
SELECT
    N'offline' AS channel,
    so.order_id,
    CAST(so.order_datetime AS DATE) AS order_date,
    so.order_datetime,
    so.customer_id,
    so.store_id,
    soi.variant_id,
    soi.quantity,
    CAST(soi.quantity * soi.unit_price AS DECIMAL(12,2)) AS gross_sales,
    CAST(soi.quantity * soi.unit_price * soi.discount_pct / 100.0 AS DECIMAL(12,2)) AS discount_amount,
    CAST(soi.line_total AS DECIMAL(12,2)) AS net_sales,
    CAST(soi.gross_profit AS DECIMAL(12,2)) AS gross_profit
FROM sales_offline.store_orders AS so
JOIN sales_offline.store_order_items AS soi
    ON so.order_id = soi.order_id

UNION ALL

SELECT
    N'online' AS channel,
    oo.order_id,
    CAST(oo.order_datetime AS DATE) AS order_date,
    oo.order_datetime,
    oo.customer_id,
    ofu.store_id,
    ooi.variant_id,
    ooi.quantity,
    CAST(ooi.quantity * ooi.unit_price AS DECIMAL(12,2)) AS gross_sales,
    CAST(ooi.quantity * ooi.unit_price * ooi.discount_pct / 100.0 AS DECIMAL(12,2)) AS discount_amount,
    CAST(ooi.line_total AS DECIMAL(12,2)) AS net_sales,
    CAST(ooi.gross_profit AS DECIMAL(12,2)) AS gross_profit
FROM sales_online.online_orders AS oo
JOIN sales_online.online_order_items AS ooi
    ON oo.order_id = ooi.order_id
LEFT JOIN sales_online.online_fulfillments AS ofu
    ON oo.order_id = ofu.order_id;
GO

CREATE OR ALTER VIEW analytics.vw_inventory_status
AS
WITH variant_daily_sales AS
(
    SELECT
        fs.variant_id,
        CAST(SUM(fs.quantity) * 1.0 / NULLIF(COUNT(DISTINCT CAST(fs.order_datetime AS DATE)), 0) AS DECIMAL(18,4)) AS avg_daily_units_sold
    FROM analytics.vw_fact_sales AS fs
    GROUP BY fs.variant_id
)
SELECT
    ic.variant_id,
    ic.store_id,
    ic.warehouse_id,
    ic.stock_quantity,
    ip.safety_stock_qty,
    ip.reorder_point_qty,
    CASE
        WHEN ic.stock_quantity <= 0 THEN N'stockout'
        WHEN ic.stock_quantity < ip.safety_stock_qty THEN N'below_safety_stock'
        WHEN ic.stock_quantity < ip.reorder_point_qty THEN N'below_reorder_point'
        ELSE N'healthy'
    END AS stock_status,
    CAST(
        CASE
            WHEN COALESCE(vds.avg_daily_units_sold, 0) > 0
                THEN ic.stock_quantity * 1.0 / vds.avg_daily_units_sold
            ELSE NULL
        END
        AS DECIMAL(18,2)
    ) AS days_left
FROM inventory.inventory_current AS ic
JOIN inventory.inventory_policy AS ip
    ON ic.variant_id = ip.variant_id
   AND ISNULL(ic.store_id, -1) = ISNULL(ip.store_id, -1)
   AND ISNULL(ic.warehouse_id, -1) = ISNULL(ip.warehouse_id, -1)
LEFT JOIN variant_daily_sales AS vds
    ON ic.variant_id = vds.variant_id;
GO

CREATE OR ALTER VIEW analytics.vw_return_analysis
AS
SELECT
    N'offline' AS channel,
    sr.return_id,
    sr.order_id,
    CAST(sr.return_datetime AS DATE) AS return_date,
    sri.variant_id,
    sri.quantity AS return_quantity,
    CAST(sri.refund_amount AS DECIMAL(12,2)) AS refund_amount,
    sr.return_reason,
    sr.return_datetime
FROM sales_offline.store_returns AS sr
JOIN sales_offline.store_return_items AS sri
    ON sr.return_id = sri.return_id

UNION ALL

SELECT
    N'online' AS channel,
    orh.return_id,
    orh.order_id,
    CAST(orh.return_datetime AS DATE) AS return_date,
    ori.variant_id,
    ori.quantity AS return_quantity,
    CAST(ori.refund_amount AS DECIMAL(12,2)) AS refund_amount,
    orh.return_reason,
    orh.return_datetime
FROM sales_online.online_returns AS orh
JOIN sales_online.online_return_items AS ori
    ON orh.return_id = ori.return_id;
GO

CREATE OR ALTER VIEW analytics.vw_channel_performance
AS
WITH sales_summary AS
(
    SELECT
        fs.channel,
        COUNT(DISTINCT fs.order_id) AS orders,
        SUM(fs.quantity) AS units_sold,
        CAST(SUM(fs.net_sales) AS DECIMAL(18,2)) AS revenue
    FROM analytics.vw_fact_sales AS fs
    GROUP BY fs.channel
),
return_summary AS
(
    SELECT
        ra.channel,
        COUNT(DISTINCT ra.order_id) AS returned_orders
    FROM analytics.vw_return_analysis AS ra
    GROUP BY ra.channel
)
SELECT
    s.channel,
    s.revenue,
    s.orders,
    s.units_sold,
    CAST(s.units_sold * 1.0 / NULLIF(s.orders, 0) AS DECIMAL(18,2)) AS upt,
    CAST(s.revenue * 1.0 / NULLIF(s.orders, 0) AS DECIMAL(18,2)) AS atv,
    CAST(COALESCE(r.returned_orders, 0) * 100.0 / NULLIF(s.orders, 0) AS DECIMAL(18,2)) AS return_rate
FROM sales_summary AS s
LEFT JOIN return_summary AS r
    ON s.channel = r.channel;
GO

CREATE OR ALTER VIEW analytics.vw_sell_through
AS
WITH sold_units AS
(
    SELECT
        fs.variant_id,
        SUM(fs.quantity) AS sold_units
    FROM analytics.vw_fact_sales AS fs
    GROUP BY fs.variant_id
),
purchased_units AS
(
    SELECT
        poi.variant_id,
        SUM(poi.ordered_quantity) AS purchased_units
    FROM supply.purchase_order_items AS poi
    GROUP BY poi.variant_id
)
SELECT
    sku.collection,
    sku.product_id,
    sku.product_name,
    sku.variant_id,
    sku.sku_code,
    COALESCE(su.sold_units, 0) AS sold_units,
    COALESCE(pu.purchased_units, 0) AS purchased_units,
    c.planned_units,
    CAST(
        CASE
            WHEN COALESCE(pu.purchased_units, 0) > 0
                THEN COALESCE(su.sold_units, 0) * 100.0 / pu.purchased_units
            ELSE NULL
        END
        AS DECIMAL(18,2)
    ) AS sell_through_rate
FROM analytics.vw_dim_sku AS sku
JOIN masterdata.products AS p
    ON sku.product_id = p.product_id
JOIN masterdata.collections AS c
    ON p.collection_id = c.collection_id
LEFT JOIN sold_units AS su
    ON sku.variant_id = su.variant_id
LEFT JOIN purchased_units AS pu
    ON sku.variant_id = pu.variant_id;
GO

CREATE OR ALTER VIEW analytics.vw_markdown_analysis
AS
WITH sold_units AS
(
    SELECT
        variant_id,
        SUM(quantity) AS sold_units
    FROM analytics.vw_fact_sales
    GROUP BY variant_id
),
remaining_stock AS
(
    SELECT
        variant_id,
        SUM(stock_quantity) AS remaining_stock
    FROM inventory.inventory_current
    GROUP BY variant_id
)
SELECT
    sku.product_id,
    sku.product_name,
    sku.variant_id,
    sku.sku_code,
    sku.collection,
    sku.season,
    sku.selling_price,
    sku.current_price,
    CAST(
        CASE
            WHEN sku.selling_price > 0
                THEN (sku.selling_price - sku.current_price) * 100.0 / sku.selling_price
            ELSE NULL
        END
        AS DECIMAL(18,2)
    ) AS markdown_pct,
    COALESCE(su.sold_units, 0) AS sold_units,
    COALESCE(rs.remaining_stock, 0) AS remaining_stock
FROM analytics.vw_dim_sku AS sku
LEFT JOIN sold_units AS su
    ON sku.variant_id = su.variant_id
LEFT JOIN remaining_stock AS rs
    ON sku.variant_id = rs.variant_id;
GO

CREATE OR ALTER VIEW analytics.vw_supplier_performance
AS
WITH po_received AS
(
    SELECT
        po.purchase_order_id,
        po.supplier_id,
        po.factory_id,
        gr.received_qty,
        qc.accepted_qty,
        qc.rejected_qty,
        DATEDIFF(DAY, po.planned_delivery_date, gr.actual_delivery_date) AS delivery_variance_days
    FROM supply.purchase_orders AS po
    LEFT JOIN supply.goods_receipts AS gr
        ON po.purchase_order_id = gr.purchase_order_id
    LEFT JOIN supply.quality_checks AS qc
        ON gr.goods_receipt_id = qc.goods_receipt_id
)
SELECT
    s.supplier_id,
    s.supplier_name,
    f.factory_id,
    f.factory_name,
    COUNT(DISTINCT pr.purchase_order_id) AS purchase_orders,
    COALESCE(SUM(pr.received_qty), 0) AS received_quantity,
    COALESCE(SUM(pr.accepted_qty), 0) AS accepted_quantity,
    COALESCE(SUM(pr.rejected_qty), 0) AS rejected_quantity,
    CAST(AVG(CAST(pr.delivery_variance_days AS DECIMAL(18,2))) AS DECIMAL(18,2)) AS delivery_variance
FROM supply.suppliers AS s
JOIN supply.factories AS f
    ON s.supplier_id = f.supplier_id
LEFT JOIN po_received AS pr
    ON f.factory_id = pr.factory_id
GROUP BY
    s.supplier_id,
    s.supplier_name,
    f.factory_id,
    f.factory_name;
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

CREATE OR ALTER VIEW analytics.vw_dim_date
AS
WITH base_dates AS
(
    SELECT
        date_key,
        full_date,
        [year],
        quarter,
        [month],
        month_name,
        month_name_vn,
        week_of_year,
        day_of_week,
        day_name,
        is_weekend,
        is_weekday,
        fashion_season,
        is_tet_holiday,
        is_public_holiday,
        fiscal_year,
        fiscal_quarter,
        year_month,
        quarter_label
    FROM masterdata.dim_date
),
extra_dates AS
(
    SELECT DISTINCT CAST(orh.return_datetime AS DATE) AS full_date
    FROM sales_online.online_returns AS orh
    WHERE CAST(orh.return_datetime AS DATE) NOT IN (SELECT full_date FROM masterdata.dim_date)

    UNION

    SELECT DISTINCT CAST(sr.return_datetime AS DATE) AS full_date
    FROM sales_offline.store_returns AS sr
    WHERE CAST(sr.return_datetime AS DATE) NOT IN (SELECT full_date FROM masterdata.dim_date)
)
SELECT
    date_key,
    full_date,
    [year],
    quarter,
    [month],
    month_name,
    month_name_vn,
    week_of_year,
    day_of_week,
    day_name,
    is_weekend,
    is_weekday,
    fashion_season,
    is_tet_holiday,
    is_public_holiday,
    fiscal_year,
    fiscal_quarter,
    year_month,
    quarter_label
FROM base_dates

UNION ALL

SELECT
    YEAR(ed.full_date) * 10000 + MONTH(ed.full_date) * 100 + DAY(ed.full_date) AS date_key,
    ed.full_date,
    YEAR(ed.full_date) AS [year],
    DATEPART(QUARTER, ed.full_date) AS quarter,
    MONTH(ed.full_date) AS [month],
    DATENAME(MONTH, ed.full_date) AS month_name,
    N'Thang ' + CAST(MONTH(ed.full_date) AS NVARCHAR(2)) AS month_name_vn,
    DATEPART(ISO_WEEK, ed.full_date) AS week_of_year,
    ((DATEDIFF(DAY, '19000101', ed.full_date) % 7) + 1) AS day_of_week,
    DATENAME(WEEKDAY, ed.full_date) AS day_name,
    CASE WHEN DATENAME(WEEKDAY, ed.full_date) IN (N'Saturday', N'Sunday') THEN 1 ELSE 0 END AS is_weekend,
    CASE WHEN DATENAME(WEEKDAY, ed.full_date) IN (N'Saturday', N'Sunday') THEN 0 ELSE 1 END AS is_weekday,
    CASE WHEN MONTH(ed.full_date) BETWEEN 3 AND 8 THEN N'SS' ELSE N'FW' END AS fashion_season,
    CAST(0 AS BIT) AS is_tet_holiday,
    CAST(0 AS BIT) AS is_public_holiday,
    YEAR(ed.full_date) AS fiscal_year,
    DATEPART(QUARTER, ed.full_date) AS fiscal_quarter,
    CONVERT(CHAR(7), ed.full_date, 120) AS year_month,
    CONCAT(N'Q', DATEPART(QUARTER, ed.full_date), N'-', YEAR(ed.full_date)) AS quarter_label
FROM extra_dates AS ed;
GO

CREATE OR ALTER VIEW analytics.vw_dim_supplier
AS
SELECT
    f.factory_id,
    f.factory_code,
    f.factory_name,
    f.country_name,
    f.capacity_units_per_month,
    f.defect_rate,
    f.moq_units,
    f.is_active AS factory_is_active,
    s.supplier_id,
    s.supplier_code,
    s.supplier_name,
    s.quality_tier,
    s.lead_time_weeks,
    s.is_active,
    COUNT(DISTINCT fp.product_id) AS product_count
FROM supply.factories AS f
LEFT JOIN supply.suppliers AS s
    ON f.supplier_id = s.supplier_id
LEFT JOIN supply.factory_products AS fp
    ON f.factory_id = fp.factory_id
GROUP BY
    f.factory_id,
    f.factory_code,
    f.factory_name,
    f.country_name,
    f.capacity_units_per_month,
    f.defect_rate,
    f.moq_units,
    f.is_active,
    s.supplier_id,
    s.supplier_code,
    s.supplier_name,
    s.quality_tier,
    s.lead_time_weeks,
    s.is_active;
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
