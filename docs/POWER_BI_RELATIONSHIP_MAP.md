# Omnichannel Fashion Analytics Power BI Relationship Map

## Purpose

This document explains how to build the Power BI data model for the Omnichannel Fashion Analytics project using the verified analytics views.

The goal is to create a clean star schema so that:

- slicers work correctly
- KPIs aggregate correctly
- visuals stay simple
- DAX measures behave predictably

## Star Schema Overview

The model should use:

- a small set of shared dimension tables
- several fact-like tables for different business subjects

Recommended design principle:

- dimensions sit on the “one” side
- fact-like tables sit on the “many” side
- cross filter direction should usually be `Single`

This keeps the model stable and easier for a beginner to debug.

## Fact-Like Tables

These tables hold transactional or analytical numeric activity:

- `vw_fact_sales`
- `vw_return_analysis`
- `vw_inventory_status`
- `vw_sell_through`
- `vw_markdown_analysis`
- `vw_supplier_performance`

## Dimension Tables

These tables provide reusable business context:

- `vw_dim_date`
- `vw_dim_sku`
- `vw_dim_store`
- `vw_dim_customer`
- `vw_dim_supplier`

## Recommended Relationship Table

| From table | From column | To table | To column | Cardinality | Cross filter direction | Active / Inactive | Business purpose |
|---|---|---|---|---|---|---|---|
| `vw_dim_sku` | `variant_id` | `vw_fact_sales` | `variant_id` | One-to-many | Single | Active | Lets product, size, color, category, and collection filter sales |
| `vw_dim_sku` | `variant_id` | `vw_return_analysis` | `variant_id` | One-to-many | Single | Active | Lets SKU attributes explain return behavior |
| `vw_dim_sku` | `variant_id` | `vw_inventory_status` | `variant_id` | One-to-many | Single | Active | Lets SKU dimension filter inventory status |
| `vw_dim_sku` | `variant_id` | `vw_sell_through` | `variant_id` | One-to-many | Single | Active | Lets collection / product / variant analysis stay consistent |
| `vw_dim_sku` | `variant_id` | `vw_markdown_analysis` | `variant_id` | One-to-many | Single | Active | Lets markdown visuals reuse SKU filters |
| `vw_dim_customer` | `customer_id` | `vw_fact_sales` | `customer_id` | One-to-many | Single | Active | Lets customer segmentation filter sales |
| `vw_dim_store` | `store_id` | `vw_fact_sales` | `store_id` | One-to-many | Single | Active | Lets store and region attributes filter offline and fulfilled sales |
| `vw_dim_store` | `store_id` | `vw_inventory_status` | `store_id` | One-to-many | Single | Active | Lets store views analyze on-hand stock |
| `vw_dim_date` | `full_date` | `vw_fact_sales` | `order_date` | One-to-many | Single | Active | Enables date slicing and time intelligence on sales |
| `vw_dim_date` | `full_date` | `vw_return_analysis` | `return_date` | One-to-many | Single | Active | Enables date slicing and time intelligence on returns |
| `vw_dim_supplier` | `factory_id` | `vw_supplier_performance` | `factory_id` | One-to-many | Single | Active | Lets supplier / factory dimension filter sourcing KPIs |

## Recommended Settings

Default recommendation for this model:

- Cardinality: `One-to-many`
- Cross filter direction: `Single`
- Active: `Yes`

Exception note:

- If Power BI detects ambiguity because of extra accidental relationships, keep only the relationships listed in this document active.
- Do not switch everything to `Both` unless there is a clear reason and you understand the side effects.

After relationships are created:

- hide key columns like `variant_id`, `customer_id`, `store_id`, `factory_id`, and date keys from report view if users do not need them directly

## Which Relationships To Create First

Create them in this order:

1. `vw_dim_sku` -> all SKU-based fact-like tables
2. `vw_dim_date` -> `vw_fact_sales` and `vw_return_analysis`
3. `vw_dim_customer` -> `vw_fact_sales`
4. `vw_dim_store` -> `vw_fact_sales`
5. `vw_dim_store` -> `vw_inventory_status`
6. `vw_dim_supplier` -> `vw_supplier_performance`

Why this order works:

- SKU is the central business grain
- Date is needed for almost every visual
- Customer and store add business slicing
- Supplier comes last because it supports a narrower page

## Step-by-Step Instructions In Power BI Model View

### 1. Load the Views

Import these views into Power BI:

- `vw_fact_sales`
- `vw_return_analysis`
- `vw_inventory_status`
- `vw_sell_through`
- `vw_markdown_analysis`
- `vw_supplier_performance`
- `vw_dim_date`
- `vw_dim_sku`
- `vw_dim_store`
- `vw_dim_customer`
- `vw_dim_supplier`

### 2. Open Model View

In Power BI Desktop:

- go to the left sidebar
- click `Model`

### 3. Create the SKU Relationships First

Drag:

- `vw_dim_sku[variant_id]` -> `vw_fact_sales[variant_id]`
- `vw_dim_sku[variant_id]` -> `vw_return_analysis[variant_id]`
- `vw_dim_sku[variant_id]` -> `vw_inventory_status[variant_id]`
- `vw_dim_sku[variant_id]` -> `vw_sell_through[variant_id]`
- `vw_dim_sku[variant_id]` -> `vw_markdown_analysis[variant_id]`

For each relationship:

- set cardinality to `One to many`
- set cross filter direction to `Single`
- keep it `Active`

### 4. Create the Date Relationships

Drag:

- `vw_dim_date[full_date]` -> `vw_fact_sales[order_date]`
- `vw_dim_date[full_date]` -> `vw_return_analysis[return_date]`

Important:

- Use `order_date` and `return_date`
- Do not use raw datetime columns if the dimension is at date grain

### 5. Create Customer and Store Relationships

Drag:

- `vw_dim_customer[customer_id]` -> `vw_fact_sales[customer_id]`
- `vw_dim_store[store_id]` -> `vw_fact_sales[store_id]`
- `vw_dim_store[store_id]` -> `vw_inventory_status[store_id]`

### 6. Create Supplier Relationship

Drag:

- `vw_dim_supplier[factory_id]` -> `vw_supplier_performance[factory_id]`

Why factory grain:

- `vw_supplier_performance` is already summarized at supplier + factory level
- `factory_id` is the cleanest unique key on the dimension side

### 7. Clean Up The Model

After relationships are done:

- move dimensions to the top
- move fact-like tables below them
- hide technical key columns that end users should not drag into visuals
- keep business columns visible

## Common Mistakes To Avoid

### Using datetime instead of date-only

Problem:

- `vw_fact_sales[order_datetime]` may not match `vw_dim_date[full_date]` exactly

Correct approach:

- use `vw_fact_sales[order_date]`
- use `vw_return_analysis[return_date]`

### Using Both-direction filters everywhere

Problem:

- creates ambiguous filtering
- makes debugging measures much harder

Correct approach:

- use `Single` by default

### Building relationships between fact-like tables

Problem:

- creates messy snowflake behavior
- increases ambiguity

Correct approach:

- connect facts to dimensions, not facts to facts

### Keeping duplicate relationship paths active

Problem:

- Power BI may block relationships or return confusing results

Correct approach:

- keep only the intended star-schema paths active

### Forgetting to hide technical columns

Problem:

- report builders may drag wrong columns into visuals

Correct approach:

- hide IDs and helper keys after relationships are created

## How To Test Relationships With A Simple Visual

### Test 1: SKU to Sales

Create a table visual with:

- `vw_dim_sku[product_name]`
- `vw_dim_sku[size]`
- measure `Revenue`

Expected result:

- revenue changes correctly by product and size

### Test 2: Date to Sales

Create a line chart with:

- `vw_dim_date[year_month]`
- measure `Revenue`

Expected result:

- monthly trend appears with no blank date mismatch

### Test 3: Channel and Returns

Create a clustered bar chart with:

- `vw_return_analysis[channel]`
- measure `Return Amount`

Expected result:

- online should show larger return pressure than offline

### Test 4: Store to Inventory

Create a matrix with:

- `vw_dim_store[store_name]`
- `vw_inventory_status[stock_status]`
- measure `Stock Quantity`

Expected result:

- inventory totals change correctly by store

### Test 5: Supplier to Factory Performance

Create a table visual with:

- `vw_dim_supplier[supplier_name]`
- `vw_dim_supplier[factory_name]`
- measure `Rejected Quantity`

Expected result:

- factory-level quality patterns should display correctly

## Final Practical Recommendation

Use `vw_dim_sku` and `vw_dim_date` as the two most important shared dimensions first.

Once those are working:

- connect customer and store
- then connect supplier

That sequence gives you the fastest path to a stable Power BI model for Omnichannel Fashion Analytics.
