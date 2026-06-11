/*
Purpose:
    Business analysis query pack for Omnichannel Fashion Analytics.
    These queries are written for learning, validation, and future Power BI design.

Usage:
    Run one query block at a time, or run the full file in SQL Server Management Studio / sqlcmd.
*/

USE [FabricFlowDB];
GO

SET NOCOUNT ON;
GO

/* 1. Business Question: Which channel generates more revenue overall? */
SELECT
    channel,
    SUM(net_sales) AS revenue
FROM analytics.vw_fact_sales
GROUP BY channel
ORDER BY revenue DESC;
GO

/* 2. Business Question: How does revenue trend by month over time? */
SELECT
    channel,
    CONVERT(CHAR(7), order_datetime, 120) AS year_month,
    SUM(net_sales) AS revenue
FROM analytics.vw_fact_sales
GROUP BY
    channel,
    CONVERT(CHAR(7), order_datetime, 120)
ORDER BY
    year_month,
    channel;
GO

/* 3. Business Question: Which 10 products bring the most revenue? */
SELECT TOP (10)
    sku.product_id,
    sku.product_name,
    SUM(fs.net_sales) AS revenue,
    SUM(fs.quantity) AS units_sold
FROM analytics.vw_fact_sales AS fs
JOIN analytics.vw_dim_sku AS sku
    ON fs.variant_id = sku.variant_id
GROUP BY
    sku.product_id,
    sku.product_name
ORDER BY revenue DESC;
GO

/* 4. Business Question: Which 10 variants sell the most units? */
SELECT TOP (10)
    sku.variant_id,
    sku.sku_code,
    sku.product_name,
    sku.size,
    sku.color,
    SUM(fs.quantity) AS units_sold
FROM analytics.vw_fact_sales AS fs
JOIN analytics.vw_dim_sku AS sku
    ON fs.variant_id = sku.variant_id
GROUP BY
    sku.variant_id,
    sku.sku_code,
    sku.product_name,
    sku.size,
    sku.color
ORDER BY units_sold DESC;
GO

/* 5. Business Question: Which collections have the highest and lowest sell-through rate? */
SELECT
    collection,
    SUM(sold_units) AS sold_units,
    SUM(purchased_units) AS purchased_units,
    CAST(
        CASE
            WHEN SUM(purchased_units) > 0
                THEN SUM(sold_units) * 100.0 / SUM(purchased_units)
            ELSE NULL
        END
        AS DECIMAL(18,2)
    ) AS sell_through_rate
FROM analytics.vw_sell_through
GROUP BY collection
ORDER BY sell_through_rate DESC;
GO

/* 6. Business Question: Which size and color combinations sell through best? */
SELECT
    sku.size,
    sku.color,
    SUM(st.sold_units) AS sold_units,
    SUM(st.purchased_units) AS purchased_units,
    CAST(
        CASE
            WHEN SUM(st.purchased_units) > 0
                THEN SUM(st.sold_units) * 100.0 / SUM(st.purchased_units)
            ELSE NULL
        END
        AS DECIMAL(18,2)
    ) AS sell_through_rate
FROM analytics.vw_sell_through AS st
JOIN analytics.vw_dim_sku AS sku
    ON st.variant_id = sku.variant_id
GROUP BY
    sku.size,
    sku.color
ORDER BY sell_through_rate DESC, sold_units DESC;
GO

/* 7. Business Question: Which markdown items still have high stock and weak sell-through? */
SELECT TOP (20)
    md.collection,
    md.product_name,
    md.sku_code,
    md.markdown_pct,
    md.sold_units,
    md.remaining_stock,
    CAST(
        CASE
            WHEN md.sold_units + md.remaining_stock > 0
                THEN md.sold_units * 100.0 / (md.sold_units + md.remaining_stock)
            ELSE NULL
        END
        AS DECIMAL(18,2)
    ) AS stock_based_sell_through
FROM analytics.vw_markdown_analysis AS md
WHERE md.markdown_pct > 0
ORDER BY
    md.remaining_stock DESC,
    md.markdown_pct DESC;
GO

/* 8. Business Question: What is the return rate by channel? */
SELECT
    channel,
    return_rate
FROM analytics.vw_channel_performance
ORDER BY channel;
GO

/* 9. Business Question: What are the main return reasons by channel? */
SELECT
    channel,
    return_reason,
    COUNT(*) AS return_lines,
    SUM(return_quantity) AS return_units,
    SUM(refund_amount) AS refund_amount
FROM analytics.vw_return_analysis
GROUP BY
    channel,
    return_reason
ORDER BY
    channel,
    return_units DESC;
GO

/* 10. Business Question: How do online and offline compare on UPT and ATV? */
SELECT
    channel,
    orders,
    units_sold,
    revenue,
    upt,
    atv
FROM analytics.vw_channel_performance
ORDER BY channel;
GO

/* 11. Business Question: Which stores have the most healthy vs risky stock positions? */
SELECT
    ds.store_id,
    ds.store_name,
    inv.stock_status,
    COUNT(*) AS sku_count,
    SUM(inv.stock_quantity) AS total_units
FROM analytics.vw_inventory_status AS inv
JOIN analytics.vw_dim_store AS ds
    ON inv.store_id = ds.store_id
WHERE inv.store_id IS NOT NULL
GROUP BY
    ds.store_id,
    ds.store_name,
    inv.stock_status
ORDER BY
    ds.store_id,
    inv.stock_status;
GO

/* 12. Business Question: Which SKUs are overstock or stockout candidates right now? */
SELECT TOP (25)
    sku.collection,
    sku.product_name,
    sku.sku_code,
    inv.store_id,
    inv.warehouse_id,
    inv.stock_quantity,
    inv.safety_stock_qty,
    inv.reorder_point_qty,
    inv.stock_status,
    inv.days_left
FROM analytics.vw_inventory_status AS inv
JOIN analytics.vw_dim_sku AS sku
    ON inv.variant_id = sku.variant_id
WHERE inv.stock_status IN (N'stockout', N'below_safety_stock', N'below_reorder_point')
   OR inv.days_left > 120
ORDER BY
    CASE inv.stock_status
        WHEN N'stockout' THEN 1
        WHEN N'below_safety_stock' THEN 2
        WHEN N'below_reorder_point' THEN 3
        ELSE 4
    END,
    inv.days_left DESC;
GO

/* 13. Business Question: Which stores are ahead or behind their monthly revenue target? */
WITH store_month_revenue AS
(
    SELECT
        fs.store_id,
        YEAR(fs.order_datetime) AS target_year,
        MONTH(fs.order_datetime) AS target_month,
        SUM(fs.net_sales) AS actual_revenue
    FROM analytics.vw_fact_sales AS fs
    WHERE fs.channel = N'offline'
      AND fs.store_id IS NOT NULL
    GROUP BY
        fs.store_id,
        YEAR(fs.order_datetime),
        MONTH(fs.order_datetime)
)
SELECT
    ds.store_name,
    st.target_year,
    st.target_month,
    st.revenue_target,
    COALESCE(smr.actual_revenue, 0) AS actual_revenue,
    COALESCE(smr.actual_revenue, 0) - st.revenue_target AS variance_to_target
FROM marketing.store_targets AS st
JOIN analytics.vw_dim_store AS ds
    ON st.store_id = ds.store_id
LEFT JOIN store_month_revenue AS smr
    ON st.store_id = smr.store_id
   AND st.target_year = smr.target_year
   AND st.target_month = smr.target_month
ORDER BY
    st.target_year,
    st.target_month,
    variance_to_target DESC;
GO

/* 14. Business Question: Which suppliers and factories deliver most reliably? */
SELECT
    supplier_name,
    factory_name,
    purchase_orders,
    received_quantity,
    accepted_quantity,
    rejected_quantity,
    delivery_variance
FROM analytics.vw_supplier_performance
ORDER BY
    delivery_variance ASC,
    accepted_quantity DESC;
GO

/* 15. Business Question: Which factories have the highest quality rejection rate? */
SELECT
    supplier_name,
    factory_name,
    received_quantity,
    rejected_quantity,
    CAST(
        CASE
            WHEN received_quantity > 0
                THEN rejected_quantity * 100.0 / received_quantity
            ELSE NULL
        END
        AS DECIMAL(18,2)
    ) AS rejection_rate_pct
FROM analytics.vw_supplier_performance
ORDER BY rejection_rate_pct DESC, rejected_quantity DESC;
GO

/* 16. Business Question: What is the fulfillment mix between ship-from-store and warehouse? */
SELECT
    fulfilled_from,
    COUNT(*) AS order_count,
    CAST(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0) AS DECIMAL(18,2)) AS fulfillment_mix_pct
FROM sales_online.online_fulfillments
GROUP BY fulfilled_from
ORDER BY order_count DESC;
GO
