# Data Quality Report

## Scope

This report summarizes the final database-wide verification for the Omnichannel Fashion Analytics project after all core generation and load phases were completed.

Completed domains:

- Master data
- Supply and sourcing
- Marketing
- Inventory and stock movement
- Purchase supply chain
- Offline sales and returns
- Online sales, fulfillment, and returns
- Staging placeholders

Verification source:

- [verify_full_database.sql](</d:/Fashion analytics/scripts/verify_full_database.sql>)

Latest result:

- `26 / 26` checks passed
- `0` failed checks

## Key Row Counts

Masterdata:

- `regions = 4`
- `warehouses = 2`
- `stores = 10`
- `collections = 8`
- `categories = 8`
- `products = 200`
- `product_variants = 3600`
- `customers = 15000`
- `dim_date = 1461`

Supply and marketing:

- `suppliers = 6`
- `factories = 8`
- `factory_products = 400`
- `purchase_orders = 40`
- `purchase_order_items = 3600`
- `goods_receipts = 40`
- `quality_checks = 40`
- `promotions = 20`
- `promotion_products = 2000`
- `collection_events = 16`
- `store_targets = 120`

Inventory:

- `inventory_policy = 31680`
- `inventory_current = 31680`
- `inventory_transactions = 3600`
- `stock_transfers = 72`
- `stock_transfer_items = 348`

Sales offline:

- `store_orders = 61664`
- `store_order_items = 132536`
- `store_payments = 61664`
- `store_returns = 4008`
- `store_return_items = 4727`

Sales online:

- `online_orders = 7963`
- `online_order_items = 22178`
- `online_payments = 7963`
- `online_fulfillments = 7963`
- `online_returns = 1792`
- `online_return_items = 2735`

Staging:

- `order_events = 0`
- `failed_events = 0`

## Major Quality Checks

Structure and keys:

- Row counts returned for all project tables across `masterdata`, `supply`, `marketing`, `inventory`, `sales_offline`, `sales_online`, and `staging`
- No FK orphan records across major fact and bridge tables
- No duplicate `sku_code`
- No duplicate `promotion_id + variant_id`
- No duplicate `stock_transfer_id + variant_id`

Financial reconciliation:

- Offline order totals align with item totals and payment totals
- Online order totals align with item totals and payment totals
- Offline return refund totals align with returned items
- Online return refund totals align with returned items

Business KPI logic:

- Online return rate is higher than offline return rate
- `online return rate = 22.50%`
- `offline return rate = 6.50%`
- Online UPT is higher than offline UPT
- `online UPT = 2.79`
- `offline UPT = 2.15`

Operational and inventory checks:

- No negative or invalid sales / return / transfer quantities
- Inventory current stock is non-negative
- Safety stock checks pass
- Purchase receipt transactions align with accepted quality-check quantities
- Fulfillment timeline checks pass
- Return timeline checks pass
- Purchase receipt dates are within the allowed variance from planned delivery

Calendar coverage:

- `dim_date` spans `2023-01-01` through `2026-12-31`

## Known Assumptions

- `dim_date` is intentionally seeded only for `2023-01-01` to `2026-12-31`, matching the requested analytics calendar window.
- Late online orders placed near the end of `2026` may have fulfillment or return operational dates in early `2027`. This is treated as valid operational behavior and does not conflict with the date-dimension coverage requirement for the core reporting window.
- `staging.order_events` and `staging.failed_events` are present as placeholders and are expected to remain empty until streaming / event ingestion is implemented.
- The current inventory transaction set contains inbound purchase-receipt movements only, because sales/return inventory posting logic was not requested in this phase.

## Ready for Analytics

The database is ready for the next semantic and reporting layer:

- Analytics views
- Business KPI validation
- Power BI model relationships
- Channel comparison reporting
- Sell-through and markdown analysis
- Return-rate and fulfillment-source analysis

Practical readiness:

- Fact tables are populated and reconciled
- Core omni-channel KPIs already validate correctly
- Product, collection, customer, store, supply, and inventory dimensions are consistent enough for Power BI modeling
