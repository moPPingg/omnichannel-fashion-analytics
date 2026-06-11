# Omnichannel Fashion Analytics ERD Review

Compact ERD-style review for the current Omnichannel Fashion Analytics SQL bundle. This design intentionally keeps the explicit 38-table fashion-domain list and does not reuse any RetailPulse or FMCG schema.

## Masterdata

| Schema | Table | Primary Key | Important Foreign Keys | Business Meaning | Analytics / Power BI Use Case |
| --- | --- | --- | --- | --- | --- |
| `masterdata` | `regions` | `region_id` | None | Geographic operating regions such as HCM, HN, DN | Region slicers and geographic rollups |
| `masterdata` | `warehouses` | `warehouse_id` | `region_id -> masterdata.regions` | Central warehouse network for offline and online fulfillment | Warehouse stock, receipt, and fulfillment source analysis |
| `masterdata` | `stores` | `store_id` | `region_id -> masterdata.regions`, `warehouse_id -> masterdata.warehouses` | Offline store master with ship-from-store capability | Store performance, ship-from-store mix, regional comparison |
| `masterdata` | `collections` | `collection_id` | None | Fashion collections by season, launch window, planned units | Sell-through by collection, seasonal lifecycle tracking |
| `masterdata` | `categories` | `category_id` | None | Fashion categories with gender and age targeting | Category mix, gender mix, assortment analysis |
| `masterdata` | `products` | `product_id` | `collection_id -> masterdata.collections`, `category_id -> masterdata.categories` | Base style or fashion product before size/color expansion | Collection planning, product pricing, NOOS vs seasonal |
| `masterdata` | `product_variants` | `variant_id` | `product_id -> masterdata.products` | SKU-level unit by size and color; central fashion grain | Size/color analytics, SKU profitability, inventory by variant |
| `masterdata` | `customers` | `customer_id` | None | Customer master with membership and preferred channel | Customer segmentation, omnichannel behavior, retention |
| `masterdata` | `dim_date` | `date_key` | None | Date dimension with `fashion_season` | Time intelligence, MTD/YTD/SPLY, season filters |

## Sales Offline

| Schema | Table | Primary Key | Important Foreign Keys | Business Meaning | Analytics / Power BI Use Case |
| --- | --- | --- | --- | --- | --- |
| `sales_offline` | `store_orders` | `order_id` | `store_id -> masterdata.stores`, `customer_id -> masterdata.customers` | POS order header at physical store | Offline revenue trend, AOV, basket count |
| `sales_offline` | `store_order_items` | `item_id` | `order_id -> sales_offline.store_orders`, `variant_id -> masterdata.product_variants` | POS line items at SKU level | UPT, size/color sales, gross profit by SKU |
| `sales_offline` | `store_payments` | `payment_id` | `order_id -> sales_offline.store_orders` | In-store payment facts | Tender mix and payment behavior |
| `sales_offline` | `store_returns` | `return_id` | `order_id -> sales_offline.store_orders`, `store_id -> masterdata.stores`, `customer_id -> masterdata.customers` | Store return header | Offline return rate and refund analysis |
| `sales_offline` | `store_return_items` | `return_item_id` | `return_id -> sales_offline.store_returns`, `order_id -> sales_offline.store_orders`, `variant_id -> masterdata.product_variants` | Returned SKU lines from store sales | Return reasons and variant-level return hotspots |

## Sales Online

| Schema | Table | Primary Key | Important Foreign Keys | Business Meaning | Analytics / Power BI Use Case |
| --- | --- | --- | --- | --- | --- |
| `sales_online` | `online_orders` | `order_id` | `customer_id -> masterdata.customers` | Online order header from web/app | Online revenue, AOV, channel mix |
| `sales_online` | `online_order_items` | `item_id` | `order_id -> sales_online.online_orders`, `variant_id -> masterdata.product_variants` | Online SKU-level sales lines | Online sell-through, online margin, assortment demand |
| `sales_online` | `online_payments` | `payment_id` | `order_id -> sales_online.online_orders` | Online payment facts | COD/prepaid split, payment success analysis |
| `sales_online` | `online_fulfillments` | `fulfillment_id` | `order_id -> sales_online.online_orders`, `store_id -> masterdata.stores`, `warehouse_id -> masterdata.warehouses` | Fulfillment routing from warehouse or ship-from-store | Fulfillment source mix, delivery performance, omnichannel ops |
| `sales_online` | `online_returns` | `return_id` | `order_id -> sales_online.online_orders`, `customer_id -> masterdata.customers` | Online return header | Online return rate and refund status |
| `sales_online` | `online_return_items` | `return_item_id` | `return_id -> sales_online.online_returns`, `order_id -> sales_online.online_orders`, `variant_id -> masterdata.product_variants` | Returned SKU lines from online orders | Return cost impact by category, size, color |

## Inventory

| Schema | Table | Primary Key | Important Foreign Keys | Business Meaning | Analytics / Power BI Use Case |
| --- | --- | --- | --- | --- | --- |
| `inventory` | `inventory_current` | `inventory_current_id` | `store_id -> masterdata.stores`, `warehouse_id -> masterdata.warehouses`, `variant_id -> masterdata.product_variants` | Current stock by SKU and location | Stock on hand, aged inventory, stockout monitoring |
| `inventory` | `inventory_transactions` | `inventory_transaction_id` | `store_id -> masterdata.stores`, `warehouse_id -> masterdata.warehouses`, `variant_id -> masterdata.product_variants`, `reference_order_id -> sales_offline.store_orders`, `reference_online_order_id -> sales_online.online_orders`, `reference_po_id -> supply.purchase_orders`, `reference_transfer_id -> inventory.stock_transfers` | Stock movement ledger across receipts, sales, returns, transfers, adjustments | Inventory flow, turnover, lineage, auditability |
| `inventory` | `inventory_policy` | `inventory_policy_id` | `variant_id -> masterdata.product_variants`, `store_id -> masterdata.stores`, `warehouse_id -> masterdata.warehouses` | Safety stock and reorder rules by SKU/location | Replenishment planning, NOOS vs seasonal policy analysis |
| `inventory` | `stock_transfers` | `stock_transfer_id` | `from_store_id -> masterdata.stores`, `from_warehouse_id -> masterdata.warehouses`, `to_store_id -> masterdata.stores`, `to_warehouse_id -> masterdata.warehouses`, `related_online_order_id -> sales_online.online_orders` | Transfer header for warehouse-to-store or store-to-store movement | Transfer lead time, support for ship-from-store rebalancing |
| `inventory` | `stock_transfer_items` | `stock_transfer_item_id` | `stock_transfer_id -> inventory.stock_transfers`, `variant_id -> masterdata.product_variants` | SKU lines within transfer orders | Variant-level transfer demand and shortage analysis |

## Supply

| Schema | Table | Primary Key | Important Foreign Keys | Business Meaning | Analytics / Power BI Use Case |
| --- | --- | --- | --- | --- | --- |
| `supply` | `suppliers` | `supplier_id` | None | Supplier master for materials or sourcing partners | Supplier scorecards and lead time tracking |
| `supply` | `factories` | `factory_id` | `supplier_id -> supply.suppliers` | Factory master with capacity, MOQ, defect rate | Factory comparison, sourcing risk |
| `supply` | `factory_products` | `factory_product_id` | `factory_id -> supply.factories`, `product_id -> masterdata.products` | Factory-to-product assignment | Product sourcing matrix, primary factory analysis |
| `supply` | `purchase_orders` | `purchase_order_id` | `supplier_id -> supply.suppliers`, `factory_id -> supply.factories`, `collection_id -> masterdata.collections` | PO header by supplier/factory/collection | Collection buy plan, inbound pipeline, vendor performance |
| `supply` | `purchase_order_items` | `purchase_order_item_id` | `purchase_order_id -> supply.purchase_orders`, `variant_id -> masterdata.product_variants` | Variant-level PO lines | Planned units by SKU, inbound cost analysis |
| `supply` | `goods_receipts` | `goods_receipt_id` | `purchase_order_id -> supply.purchase_orders`, `warehouse_id -> masterdata.warehouses` | Actual inbound receipt events | On-time delivery and receipt variance |
| `supply` | `quality_checks` | `quality_check_id` | `goods_receipt_id -> supply.goods_receipts` | Post-receipt quality inspection | Defect analysis, supplier/factory quality performance |

## Marketing

| Schema | Table | Primary Key | Important Foreign Keys | Business Meaning | Analytics / Power BI Use Case |
| --- | --- | --- | --- | --- | --- |
| `marketing` | `promotions` | `promotion_id` | None | Campaign header for markdown, flash sale, launch, member day | Promo period slicing and discount governance |
| `marketing` | `promotion_products` | `promotion_product_id` | `promotion_id -> marketing.promotions`, `variant_id -> masterdata.product_variants` | Variant-level promotion assignment | Markdown analysis, promo lift by SKU |
| `marketing` | `collection_events` | `collection_event_id` | `collection_id -> masterdata.collections` | Launch and campaign events by collection | Collection launch impact and event ROI |
| `marketing` | `store_targets` | `store_target_id` | `store_id -> masterdata.stores` | Monthly store targets for revenue, sell-through, UPT | Actual vs target dashboards and store ranking |

## Analytics

| Schema | View | Grain / Key | Main Sources | Business Meaning | Power BI Use Case |
| --- | --- | --- | --- | --- | --- |
| `analytics` | `vw_dim_sku` | `variant_id` | `masterdata.product_variants`, `products`, `collections`, `categories` | Canonical SKU dimension | Shared SKU dimension for model relationships |
| `analytics` | `vw_dim_store` | `store_id` | `masterdata.stores`, `regions`, `warehouses` | Canonical store dimension | Store slicers and geographic hierarchies |
| `analytics` | `vw_dim_customer` | `customer_id` | `masterdata.customers` | Canonical customer dimension | Customer segmentation visuals |
| `analytics` | `vw_fact_sales` | Sales line | Offline + online order facts | Unified omnichannel sales fact | Core fact table for revenue, units, gross profit |
| `analytics` | `vw_inventory_status` | SKU-location | `inventory.inventory_current` + product hierarchy | Current stock and weeks in stock | Inventory health and aged stock visuals |
| `analytics` | `vw_sell_through` | `variant_id` | `vw_fact_sales`, `vw_dim_sku`, `collections` | Planned vs sold view by SKU/product/collection | Sell-through waterfall, collection ranking |
| `analytics` | `vw_markdown_analysis` | `variant_id` | `vw_dim_sku`, `vw_inventory_status` | Current markdown exposure and inventory risk | Markdown rate, aged stock, recovery analysis |
| `analytics` | `vw_channel_performance` | `sales_channel` | `vw_fact_sales` | Channel-level sales summary | Online vs offline KPI cards |
| `analytics` | `vw_return_analysis` | Channel-variant | Offline and online return lines | Return unit and refund summary | Return rate and refund cost analysis |
| `analytics` | `vw_supplier_performance` | Supplier-factory | `suppliers`, `factories`, `purchase_orders`, `goods_receipts`, `quality_checks` | Supplier and factory operational performance | Vendor scorecards |

## Staging

| Schema | Table | Primary Key | Important Foreign Keys | Business Meaning | Analytics / Power BI Use Case |
| --- | --- | --- | --- | --- | --- |
| `staging` | `order_events` | `event_id` | `store_id -> masterdata.stores`, `variant_id -> masterdata.product_variants` | Event intake table for order and inventory events | Operational audit, future near-real-time ingestion |
| `staging` | `failed_events` | `failed_event_id` | None | Failed event capture and retry tracking | Data pipeline monitoring, operational QA |
