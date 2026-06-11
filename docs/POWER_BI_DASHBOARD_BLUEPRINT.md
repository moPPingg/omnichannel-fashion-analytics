# Omnichannel Fashion Analytics Power BI Dashboard Blueprint

## Purpose

This blueprint turns the existing SQL analytics layer into a practical Power BI dashboard plan.

It is designed to be:

- implementation-ready
- beginner-friendly
- aligned with the current SQL views
- focused on fashion retail business decisions

Primary source views:

- `analytics.vw_fact_sales`
- `analytics.vw_dim_sku`
- `analytics.vw_inventory_status`
- `analytics.vw_return_analysis`
- `analytics.vw_channel_performance`
- `analytics.vw_sell_through`
- `analytics.vw_markdown_analysis`
- `analytics.vw_supplier_performance`

## Recommended Power BI Data Model

### Fact Tables

- `vw_fact_sales`
- `vw_return_analysis`
- `vw_inventory_status`
- `vw_sell_through`
- `vw_supplier_performance`

### Dimension Tables

- `vw_dim_sku`
- `vw_dim_customer`
- `vw_dim_store`
- `masterdata.dim_date`

### Recommended Relationships

- `vw_fact_sales[variant_id]` -> `vw_dim_sku[variant_id]`
- `vw_return_analysis[variant_id]` -> `vw_dim_sku[variant_id]`
- `vw_inventory_status[variant_id]` -> `vw_dim_sku[variant_id]`
- `vw_sell_through[variant_id]` -> `vw_dim_sku[variant_id]`
- `vw_fact_sales[customer_id]` -> `vw_dim_customer[customer_id]`
- `vw_fact_sales[store_id]` -> `vw_dim_store[store_id]`
- `vw_inventory_status[store_id]` -> `vw_dim_store[store_id]`
- `vw_fact_sales[order_datetime]` -> `dim_date[full_date]`
  Practical note:
  Create a date-only column in Power BI if needed for joining datetime to date.
- `vw_return_analysis[return_datetime]` -> `dim_date[full_date]`
  Practical note:
  Also use a date-only column here.

### Star Schema Explanation

Use `vw_fact_sales` as the main commercial fact table.

- It connects revenue, units, orders, customer, store, and SKU.
- `vw_dim_sku`, `vw_dim_customer`, `vw_dim_store`, and `dim_date` act as reusable dimensions.
- `vw_return_analysis`, `vw_inventory_status`, and `vw_sell_through` work as supporting fact tables for specific subject areas.

This keeps the model simple:

- central facts
- shared dimensions
- clear filtering behavior

## Core DAX Measure Catalog

### Revenue

```DAX
Revenue = SUM(vw_fact_sales[net_sales])
```

### Gross Profit

```DAX
Gross Profit = SUM(vw_fact_sales[gross_profit])
```

### Gross Margin %

```DAX
Gross Margin % = DIVIDE([Gross Profit], [Revenue], 0)
```

### Orders

```DAX
Orders = DISTINCTCOUNT(vw_fact_sales[order_id])
```

### Units Sold

```DAX
Units Sold = SUM(vw_fact_sales[quantity])
```

### ATV

```DAX
ATV = DIVIDE([Revenue], [Orders], 0)
```

### UPT

```DAX
UPT = DIVIDE([Units Sold], [Orders], 0)
```

### Return Orders

```DAX
Return Orders = DISTINCTCOUNT(vw_return_analysis[order_id])
```

### Return Rate

```DAX
Return Rate = DIVIDE([Return Orders], [Orders], 0)
```

### Returned Units

```DAX
Returned Units = SUM(vw_return_analysis[return_quantity])
```

### Sell-through Rate

```DAX
Sell-through Rate =
DIVIDE(
    SUM(vw_sell_through[sold_units]),
    SUM(vw_sell_through[purchased_units]),
    0
)
```

### Markdown %

```DAX
Markdown % =
AVERAGE(vw_markdown_analysis[markdown_pct])
```

### Stockout Count

```DAX
Stockout Count =
CALCULATE(
    COUNTROWS(vw_inventory_status),
    vw_inventory_status[stock_status] = "stockout"
)
```

### Overstock Count

```DAX
Overstock Count =
CALCULATE(
    COUNTROWS(vw_inventory_status),
    vw_inventory_status[days_left] > 120
)
```

## Dashboard Pages

## 1. Executive Overview

### Business Objective

Give leadership a fast summary of overall commercial health across channels.

### Main Business Questions

- How much revenue are we generating?
- Is online or offline performing better?
- What are our current margin, return rate, and sell-through levels?
- Are inventory risks building up?

### Recommended Visuals

- KPI cards for Revenue, Gross Profit, Gross Margin %, Orders, Return Rate, Sell-through Rate
- Line chart for monthly revenue trend
- Donut chart for channel revenue mix
- Clustered column chart for channel comparison on Revenue, ATV, UPT
- Small matrix for inventory exceptions: Stockout Count, Overstock Count

### Required Fields

- `vw_fact_sales[channel]`
- `vw_fact_sales[order_datetime]`
- `vw_fact_sales[net_sales]`
- `vw_fact_sales[gross_profit]`
- `vw_channel_performance[atv]`
- `vw_channel_performance[upt]`
- `vw_channel_performance[return_rate]`
- `vw_sell_through[sold_units]`
- `vw_sell_through[purchased_units]`
- `vw_inventory_status[stock_status]`
- `vw_inventory_status[days_left]`

### Source Views

- `vw_fact_sales`
- `vw_channel_performance`
- `vw_sell_through`
- `vw_inventory_status`

### Suggested DAX Measures

- Revenue
- Gross Profit
- Gross Margin %
- Orders
- Return Rate
- Sell-through Rate
- Stockout Count
- Overstock Count

### Slicers / Filters

- Year
- Month
- Channel
- Collection
- Category

### Expected Insights

- Revenue growth or slowdown by month
- Online may show stronger ATV and UPT
- Return rate differences may signal margin pressure
- Inventory risk may rise before markdown decisions

### Why This Page Matters for Fashion Retail

Fashion leaders need a fast pulse on sales, margin, returns, and inventory at the same time because seasonal decisions must happen quickly.

## 2. Sales & Channel Performance

### Business Objective

Compare offline and online channel behavior in a more detailed way.

### Main Business Questions

- Which channel drives more revenue and profit?
- How do ATV and UPT differ by channel?
- How does channel performance move over time?
- Which channel is more return-heavy?

### Recommended Visuals

- Clustered bar chart for Revenue and Gross Profit by channel
- Line chart for monthly revenue trend by channel
- KPI cards for ATV and UPT by channel
- Bar chart for return rate by channel
- Matrix with channel, orders, units, revenue, gross profit, ATV, UPT, return rate

### Required Fields

- `vw_fact_sales[channel]`
- `vw_fact_sales[net_sales]`
- `vw_fact_sales[gross_profit]`
- `vw_fact_sales[quantity]`
- `vw_fact_sales[order_id]`
- `vw_return_analysis[channel]`
- `vw_return_analysis[order_id]`
- `vw_channel_performance[atv]`
- `vw_channel_performance[upt]`
- `vw_channel_performance[return_rate]`

### Source Views

- `vw_fact_sales`
- `vw_return_analysis`
- `vw_channel_performance`

### Suggested DAX Measures

- Revenue
- Gross Profit
- Gross Margin %
- Orders
- Units Sold
- ATV
- UPT
- Return Rate

### Slicers / Filters

- Year
- Month
- Category
- Collection

### Expected Insights

- Online should show higher UPT and ATV
- Offline may contribute more total revenue
- Return rates explain why high gross sales do not always mean high-quality revenue

### Why This Page Matters for Fashion Retail

Omnichannel fashion performance is not only about revenue. Channel behavior affects returns, fulfillment cost, and merchandising strategy.

## 3. Product, SKU & Collection Performance

### Business Objective

Track which products, variants, and collections are winning or underperforming.

### Main Business Questions

- Which products and SKUs drive the most revenue?
- Which collections are selling through well?
- Which sizes and colors perform best?
- Which items may need markdown action?

### Recommended Visuals

- Top N bar chart for top products by revenue
- Top N bar chart for top variants by quantity sold
- Matrix for collection sell-through
- Heatmap or matrix for size and color sell-through
- Scatter plot for markdown % vs remaining stock
- Table for low sell-through, high-stock SKUs

### Required Fields

- `vw_dim_sku[product_name]`
- `vw_dim_sku[sku_code]`
- `vw_dim_sku[size]`
- `vw_dim_sku[color]`
- `vw_dim_sku[collection]`
- `vw_dim_sku[season]`
- `vw_fact_sales[net_sales]`
- `vw_fact_sales[quantity]`
- `vw_sell_through[sold_units]`
- `vw_sell_through[purchased_units]`
- `vw_sell_through[sell_through_rate]`
- `vw_markdown_analysis[markdown_pct]`
- `vw_markdown_analysis[remaining_stock]`

### Source Views

- `vw_fact_sales`
- `vw_dim_sku`
- `vw_sell_through`
- `vw_markdown_analysis`

### Suggested DAX Measures

- Revenue
- Units Sold
- Sell-through Rate
- Markdown %

### Slicers / Filters

- Collection
- Season
- Category
- Size
- Color
- Channel

### Expected Insights

- Hero products and hero variants
- Slow collections that may require intervention
- Specific size/color gaps in assortment
- Markdown candidates with weak movement and heavy remaining stock

### Why This Page Matters for Fashion Retail

Fashion profitability is driven at SKU level through size, color, and collection timing, not just at total product level.

## 4. Inventory & Replenishment

### Business Objective

Monitor stock health and identify replenishment or transfer priorities.

### Main Business Questions

- Which locations are healthy, low on stock, or stocked out?
- Which SKUs have too much stock left?
- Which items are below safety stock or reorder point?
- How much stock cover remains?

### Recommended Visuals

- KPI cards for Stockout Count and Overstock Count
- Stacked bar chart for stock status by location
- Table for below safety stock items
- Table for overstock candidates using `days_left`
- Matrix by store and stock status

### Required Fields

- `vw_inventory_status[variant_id]`
- `vw_inventory_status[store_id]`
- `vw_inventory_status[warehouse_id]`
- `vw_inventory_status[stock_quantity]`
- `vw_inventory_status[safety_stock_qty]`
- `vw_inventory_status[reorder_point_qty]`
- `vw_inventory_status[stock_status]`
- `vw_inventory_status[days_left]`
- `vw_dim_sku[sku_code]`
- `vw_dim_sku[product_name]`
- `vw_dim_store[store_name]`

### Source Views

- `vw_inventory_status`
- `vw_dim_sku`
- `vw_dim_store`

### Suggested DAX Measures

- Stockout Count
- Overstock Count
- Inventory Units = SUM(vw_inventory_status[stock_quantity])
- Avg Days Left = AVERAGE(vw_inventory_status[days_left])

### Slicers / Filters

- Store
- Warehouse
- Collection
- Category
- Stock Status

### Expected Insights

- Stores or warehouses under pressure
- SKUs likely to require replenishment
- Items aging too slowly relative to demand

### Why This Page Matters for Fashion Retail

Fashion inventory loses value over time. The business needs to balance stock availability with markdown risk.

## 5. Returns & Fulfillment

### Business Objective

Understand return behavior and fulfillment-source mix.

### Main Business Questions

- Why are customers returning items?
- Is online return behavior worse than offline?
- Which variants are returned most often?
- How much online demand is fulfilled by warehouse vs ship-from-store?

### Recommended Visuals

- KPI card for Return Rate
- Bar chart for return reasons by channel
- Column chart for refund amount by channel
- Table for highest-return SKUs
- Donut chart for fulfillment source mix: warehouse vs store

### Required Fields

- `vw_return_analysis[channel]`
- `vw_return_analysis[return_reason]`
- `vw_return_analysis[return_quantity]`
- `vw_return_analysis[refund_amount]`
- `vw_return_analysis[variant_id]`
- `vw_dim_sku[sku_code]`
- `vw_dim_sku[product_name]`
- `sales_online.online_fulfillments[fulfilled_from]`

### Source Views

- `vw_return_analysis`
- `vw_dim_sku`
- `vw_channel_performance`
- `sales_online.online_fulfillments`

### Suggested DAX Measures

- Return Orders
- Return Rate
- Returned Units
- Refund Amount = SUM(vw_return_analysis[refund_amount])

### Slicers / Filters

- Channel
- Return Reason
- Collection
- Category
- Size
- Color

### Expected Insights

- Online should show clearly higher return rate
- Size and fit issues may dominate return behavior
- Ship-from-store share shows omnichannel operational maturity

### Why This Page Matters for Fashion Retail

Returns are a major margin issue in fashion, and fulfillment strategy strongly shapes service level and cost.

## 6. Supplier & Factory Performance

### Business Objective

Evaluate sourcing reliability and quality performance.

### Main Business Questions

- Which suppliers and factories deliver reliably?
- Which factories have the highest rejection rate?
- How large is the received vs accepted gap?
- Which factories may create future collection risk?

### Recommended Visuals

- Table for supplier/factory summary
- Bar chart for accepted vs rejected quantity by factory
- Bar chart for rejection rate by factory
- Scatter plot for delivery variance vs accepted quantity

### Required Fields

- `vw_supplier_performance[supplier_name]`
- `vw_supplier_performance[factory_name]`
- `vw_supplier_performance[purchase_orders]`
- `vw_supplier_performance[received_quantity]`
- `vw_supplier_performance[accepted_quantity]`
- `vw_supplier_performance[rejected_quantity]`
- `vw_supplier_performance[delivery_variance]`

### Source Views

- `vw_supplier_performance`

### Suggested DAX Measures

- Received Quantity = SUM(vw_supplier_performance[received_quantity])
- Accepted Quantity = SUM(vw_supplier_performance[accepted_quantity])
- Rejected Quantity = SUM(vw_supplier_performance[rejected_quantity])
- Rejection Rate % =
```DAX
Rejection Rate % =
DIVIDE([Rejected Quantity], [Received Quantity], 0)
```

### Slicers / Filters

- Supplier
- Factory

### Expected Insights

- Reliable factories with low rejection and low delivery variance
- Risky factories with higher defect or lateness patterns

### Why This Page Matters for Fashion Retail

Fashion collections are time-sensitive. Supplier reliability directly affects launch success and in-season sales opportunity.

## Beginner-Friendly Build Order

### Which Page to Build First

1. Executive Overview
2. Sales & Channel Performance
3. Product, SKU & Collection Performance
4. Returns & Fulfillment
5. Inventory & Replenishment
6. Supplier & Factory Performance

### Which Visuals to Create First

Start with the simplest and highest-value visuals:

1. KPI cards
2. Monthly revenue trend line chart
3. Channel comparison bar chart
4. Top product table / bar chart
5. Return reason chart
6. Inventory status matrix

### Which DAX Measures to Write First

Write these first:

1. Revenue
2. Gross Profit
3. Orders
4. Units Sold
5. ATV
6. UPT
7. Return Rate

Then add:

8. Gross Margin %
9. Sell-through Rate
10. Markdown %
11. Stockout Count
12. Overstock Count

## Practical Build Tips

- Use `vw_fact_sales` as the primary table for most visuals.
- Bring in `vw_dim_sku` early because fashion analysis needs category, collection, size, and color immediately.
- Use `dim_date` for all time-based slicing instead of building month text logic inside visuals.
- Keep the first version simple. A clean and working page is better than an overbuilt page with too many visuals.
- Validate KPI numbers against `business_queries.sql` before finalizing dashboard visuals.
