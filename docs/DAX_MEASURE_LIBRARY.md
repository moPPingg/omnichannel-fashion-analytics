# Omnichannel Fashion Analytics DAX Measure Library

## What Is a DAX Measure?

A DAX measure is a calculation you create inside Power BI to answer a business question.

Think of it like this:

- SQL views prepare the data
- Power BI relationships connect the tables
- DAX measures calculate the KPI you want to show on cards, charts, and tables

Example:

- a column stores `net_sales` for each sales row
- a DAX measure called `Revenue` adds those rows together based on the filters currently applied

That means one measure can automatically recalculate for:

- one channel
- one month
- one collection
- one store
- or the whole business

So measures are useful because they are dynamic. They change with slicers and filters.

## Recommended Assumptions

These formulas are designed to work with the current Omnichannel Fashion Analytics model using existing analytics views only.

Main source views:

- `vw_fact_sales`
- `vw_return_analysis`
- `vw_channel_performance`
- `vw_sell_through`
- `vw_markdown_analysis`
- `vw_inventory_status`
- `vw_supplier_performance`

## Sales Measures

### Revenue

**DAX**

```DAX
Revenue = SUM(vw_fact_sales[net_sales])
```

**Plain-English explanation**

- Adds up all net sales after discounts.

**Dashboard page**

- Executive Overview
- Sales & Channel Performance
- Product, SKU & Collection Performance

**Depends on**

- `vw_fact_sales`

### Gross Sales

**DAX**

```DAX
Gross Sales = SUM(vw_fact_sales[gross_sales])
```

**Plain-English explanation**

- Adds up sales before discounts.

**Dashboard page**

- Executive Overview
- Sales & Channel Performance

**Depends on**

- `vw_fact_sales`

### Discount Amount

**DAX**

```DAX
Discount Amount = SUM(vw_fact_sales[discount_amount])
```

**Plain-English explanation**

- Shows how much value was given away through discounts.

**Dashboard page**

- Sales & Channel Performance
- Product, SKU & Collection Performance

**Depends on**

- `vw_fact_sales`

### Orders

**DAX**

```DAX
Orders = DISTINCTCOUNT(vw_fact_sales[order_id])
```

**Plain-English explanation**

- Counts how many unique orders were placed.

**Dashboard page**

- Executive Overview
- Sales & Channel Performance

**Depends on**

- `vw_fact_sales`

### Units Sold

**DAX**

```DAX
Units Sold = SUM(vw_fact_sales[quantity])
```

**Plain-English explanation**

- Adds up total units sold across all order lines.

**Dashboard page**

- Executive Overview
- Sales & Channel Performance
- Product, SKU & Collection Performance

**Depends on**

- `vw_fact_sales`

## Profitability Measures

### Gross Profit

**DAX**

```DAX
Gross Profit = SUM(vw_fact_sales[gross_profit])
```

**Plain-English explanation**

- Adds up profit before returns, shipping cost, and overhead.

**Dashboard page**

- Executive Overview
- Sales & Channel Performance

**Depends on**

- `vw_fact_sales`

### Gross Margin %

**DAX**

```DAX
Gross Margin % = DIVIDE([Gross Profit], [Revenue], 0)
```

**Plain-English explanation**

- Shows what percent of revenue remains as gross profit.

**Dashboard page**

- Executive Overview
- Sales & Channel Performance

**Depends on**

- `vw_fact_sales`
- measure `[Gross Profit]`
- measure `[Revenue]`

## Customer Basket Measures

### ATV

**DAX**

```DAX
ATV = DIVIDE([Revenue], [Orders], 0)
```

**Plain-English explanation**

- Average Transaction Value.
- It shows the average revenue per order.

**Dashboard page**

- Executive Overview
- Sales & Channel Performance

**Depends on**

- measure `[Revenue]`
- measure `[Orders]`

### UPT

**DAX**

```DAX
UPT = DIVIDE([Units Sold], [Orders], 0)
```

**Plain-English explanation**

- Units Per Transaction.
- It shows how many units customers buy in each order on average.

**Dashboard page**

- Executive Overview
- Sales & Channel Performance

**Depends on**

- measure `[Units Sold]`
- measure `[Orders]`

## Returns Measures

### Return Amount

**DAX**

```DAX
Return Amount = SUM(vw_return_analysis[refund_amount])
```

**Plain-English explanation**

- Adds up the refunded value of returned items.

**Dashboard page**

- Returns & Fulfillment
- Sales & Channel Performance

**Depends on**

- `vw_return_analysis`

### Return Units

**DAX**

```DAX
Return Units = SUM(vw_return_analysis[return_quantity])
```

**Plain-English explanation**

- Counts how many units were returned.

**Dashboard page**

- Returns & Fulfillment

**Depends on**

- `vw_return_analysis`

### Return Rate %

**DAX**

```DAX
Return Rate % =
DIVIDE(
    DISTINCTCOUNT(vw_return_analysis[order_id]),
    [Orders],
    0
)
```

**Plain-English explanation**

- Shows the share of orders that had a return.

**Dashboard page**

- Executive Overview
- Sales & Channel Performance
- Returns & Fulfillment

**Depends on**

- `vw_return_analysis`
- measure `[Orders]`

## Sell-through & Markdown Measures

### Sell-through Rate %

**DAX**

```DAX
Sell-through Rate % =
DIVIDE(
    SUM(vw_sell_through[sold_units]),
    SUM(vw_sell_through[purchased_units]),
    0
)
```

**Plain-English explanation**

- Shows how much of purchased inventory has already been sold.

**Dashboard page**

- Executive Overview
- Product, SKU & Collection Performance

**Depends on**

- `vw_sell_through`

### Markdown %

**DAX**

```DAX
Markdown % = AVERAGE(vw_markdown_analysis[markdown_pct])
```

**Plain-English explanation**

- Shows the average markdown level of the filtered products or SKUs.

**Dashboard page**

- Product, SKU & Collection Performance
- Inventory & Replenishment

**Depends on**

- `vw_markdown_analysis`

### Remaining Stock

**DAX**

```DAX
Remaining Stock = SUM(vw_markdown_analysis[remaining_stock])
```

**Plain-English explanation**

- Adds up how much stock is still left for the selected products or variants.

**Dashboard page**

- Product, SKU & Collection Performance
- Inventory & Replenishment

**Depends on**

- `vw_markdown_analysis`

## Inventory Measures

### Stock Quantity

**DAX**

```DAX
Stock Quantity = SUM(vw_inventory_status[stock_quantity])
```

**Plain-English explanation**

- Adds up the inventory currently on hand.

**Dashboard page**

- Inventory & Replenishment

**Depends on**

- `vw_inventory_status`

### Stockout Count

**DAX**

```DAX
Stockout Count =
CALCULATE(
    COUNTROWS(vw_inventory_status),
    vw_inventory_status[stock_status] = "stockout"
)
```

**Plain-English explanation**

- Counts how many inventory rows are fully out of stock.

**Dashboard page**

- Executive Overview
- Inventory & Replenishment

**Depends on**

- `vw_inventory_status`

### Overstock Count

**DAX**

```DAX
Overstock Count =
CALCULATE(
    COUNTROWS(vw_inventory_status),
    vw_inventory_status[days_left] > 120
)
```

**Plain-English explanation**

- Counts rows where stock cover is very high and may indicate slow-moving inventory.

**Dashboard page**

- Executive Overview
- Inventory & Replenishment

**Depends on**

- `vw_inventory_status`

### Safety Stock Breach Count

**DAX**

```DAX
Safety Stock Breach Count =
CALCULATE(
    COUNTROWS(vw_inventory_status),
    vw_inventory_status[stock_status] = "below_safety_stock"
)
```

**Plain-English explanation**

- Counts inventory rows that have dropped below safety stock.

**Dashboard page**

- Inventory & Replenishment

**Depends on**

- `vw_inventory_status`

## Supply Chain Measures

### Received Quantity

**DAX**

```DAX
Received Quantity = SUM(vw_supplier_performance[received_quantity])
```

**Plain-English explanation**

- Adds up total received quantity from suppliers and factories.

**Dashboard page**

- Supplier & Factory Performance

**Depends on**

- `vw_supplier_performance`

### Accepted Quantity

**DAX**

```DAX
Accepted Quantity = SUM(vw_supplier_performance[accepted_quantity])
```

**Plain-English explanation**

- Adds up the quantity that passed quality checking.

**Dashboard page**

- Supplier & Factory Performance

**Depends on**

- `vw_supplier_performance`

### Rejected Quantity

**DAX**

```DAX
Rejected Quantity = SUM(vw_supplier_performance[rejected_quantity])
```

**Plain-English explanation**

- Adds up the quantity rejected due to quality issues.

**Dashboard page**

- Supplier & Factory Performance

**Depends on**

- `vw_supplier_performance`

### Rejection Rate %

**DAX**

```DAX
Rejection Rate % =
DIVIDE(
    [Rejected Quantity],
    [Received Quantity],
    0
)
```

**Plain-English explanation**

- Shows what percent of received quantity was rejected.

**Dashboard page**

- Supplier & Factory Performance

**Depends on**

- measure `[Rejected Quantity]`
- measure `[Received Quantity]`

## Beginner Build Order

## First 5 Measures To Create

Start with these because almost every page needs them:

1. `Revenue`
2. `Orders`
3. `Units Sold`
4. `Gross Profit`
5. `Return Amount`

## Next 5 Measures

These turn basic totals into stronger business KPIs:

1. `Gross Margin %`
2. `ATV`
3. `UPT`
4. `Return Rate %`
5. `Stock Quantity`

## Advanced Measures Later

Create these after the dashboard structure is already working:

1. `Sell-through Rate %`
2. `Markdown %`
3. `Remaining Stock`
4. `Stockout Count`
5. `Overstock Count`
6. `Safety Stock Breach Count`
7. `Received Quantity`
8. `Accepted Quantity`
9. `Rejected Quantity`
10. `Rejection Rate %`

## Practical Tips For Power BI Desktop

- Create measures in a dedicated measure table if you want a cleaner model.
- Validate each measure against SQL outputs from `business_queries.sql`.
- Build card visuals first so you can quickly test whether each measure behaves correctly with slicers.
- After the first few measures work, reuse them instead of rewriting logic in many places.
