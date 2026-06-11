# Omnichannel Fashion Analytics

### Omnichannel Fashion Analytics Project using SQL Server, Python, and Power BI

## Overview

This is a portfolio project that simulates an omnichannel fashion retailer operating across offline stores, online channels, warehouses, suppliers, factories, and seasonal collections.

This project is intentionally developed in small, reviewable milestones to show:

* SQL schema design
* FK-safe ETL loading
* reproducible fake data generation
* data quality validation
* fashion-specific business modeling

The domain is fashion retail, not FMCG. The data model focuses on:

* product variants by size and color
* SS/FW collection lifecycle
* NOOS vs seasonal products
* markdown logic
* ship-from-store fulfillment
* inventory policy by SKU
* return-aware omnichannel analytics

## Current Repo Scope

This repository is currently at the `SQL + masterdata/supporting setup` stage.

Completed in the current codebase:

* SQL Server database design
* 8-schema architecture
* core DDL, constraints, indexes, and verification scripts
* master data fake generation
* supply, marketing, and inventory-setup fake generation
* CSV backup export to `data/raw/`
* FK-safe Python ETL loaders into SQL Server
* SQL verification scripts for loaded groups

Not implemented yet in the current repo state:

* offline sales
* online sales
* returns
* purchase orders and receipts
* inventory transactions
* final Power BI dashboards

## Project Architecture

```text
Python Faker + business rules
          │
          ▼
CSV backup files (data/raw/)
          │
          ▼
Python ETL loaders
          │
          ▼
SQL Server
          │
          ▼
Verification SQL + data quality checks
          │
          ▼
Analytics views
          │
          ▼
Power BI dashboards
```

## Technology Stack

* SQL Server 2022
* T-SQL
* Python 3.11
* Pandas
* Faker `vi_VN`
* SQLAlchemy
* PyODBC
* Power BI

## Database Design

The database is organized into 8 schemas:

* `masterdata`
* `sales_offline`
* `sales_online`
* `inventory`
* `supply`
* `marketing`
* `analytics`
* `staging`

The modeling center is `masterdata.product_variants`, because fashion analytics is performed at SKU level rather than only product level.

## Current Implemented Data Groups

### Group 1: Master Data

* `regions`
* `warehouses`
* `stores`
* `collections`
* `categories`
* `products`
* `product_variants`
* `customers`

### Group 2: Supporting Setup

* `suppliers`
* `factories`
* `factory_products`
* `promotions`
* `promotion_products`
* `collection_events`
* `store_targets`
* `inventory_policy`
* `inventory_current`

## Current Validation Status

The current implemented loaders were executed successfully against SQL Server.

Verified examples:

* `product_variants = 3600`
* `customers = 15000`
* `suppliers = 6`
* `factories = 8`
* `factory_products = 400`
* `promotions = 20`
* `promotion_products = 2000`
* `collection_events = 16`
* `store_targets = 120`
* `inventory_policy = 31680`
* `inventory_current = 31680`

## Milestone Strategy

This project is being pushed to GitHub in milestones instead of one large dump.

Recommended milestone order:

1. `SQL foundation`
   SQL DDL, schema design, indexes, verify scripts, calendar
2. `Masterdata generation + ETL`
   Faker rules, CSV backups, ETL loader, verification
3. `Supporting setup groups`
   supply, marketing, inventory setup
4. `Transactional simulation`
   purchase orders, sales, returns, inventory transactions
5. `Analytics layer`
   views, business queries, stored procedures
6. `BI layer`
   Power BI model and dashboards

## Repository Structure

```text
omnichannel-fashion-analytics/
├── data/raw/
├── docs/
├── scripts/
├── sql/
├── src/
├── README.md
└── requirements.txt
```

## Author

**Nguyen Thien Khoi**

FPT University - Artificial Intelligence

Aspiring Data Analyst | Data Engineer
