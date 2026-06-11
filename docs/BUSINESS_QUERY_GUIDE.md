# Business Query Guide

## Purpose

This guide explains the SQL learning and validation queries in [business_queries.sql](</d:/Fashion analytics/scripts/business_queries.sql>).

The goal is to help a beginner Data Analyst understand:

- what question each query answers
- why the question matters in fashion retail
- which future dashboard page the query can support

## Query Map

### 1. Revenue by channel

Question:

- Which channel generates more revenue overall?

Why it matters:

- Omnichannel fashion teams need to know whether offline stores or online commerce are driving the business.

Useful dashboard page:

- Executive summary
- Omnichannel overview

### 2. Revenue trend by month

Question:

- How does revenue move over time by month and by channel?

Why it matters:

- Fashion retail is seasonal. Monthly trends help show launch peaks, markdown periods, and demand shifts across channels.

Useful dashboard page:

- Executive trend page
- Channel trend page

### 3. Top 10 products by revenue

Question:

- Which products generate the most revenue?

Why it matters:

- Helps identify hero products and which collections or product concepts are commercially strongest.

Useful dashboard page:

- Product performance
- Collection performance

### 4. Top 10 variants by quantity sold

Question:

- Which SKU variants sell the most units?

Why it matters:

- Fashion success often happens at variant level, not just product level. Size and color combinations matter.

Useful dashboard page:

- SKU ranking
- Size and color analysis

### 5. Sell-through rate by collection

Question:

- Which collections are selling through fastest?

Why it matters:

- Sell-through is one of the most important fashion KPIs for collection health and markdown timing.

Useful dashboard page:

- Collection page
- Merchandising page

### 6. Sell-through rate by size and color

Question:

- Which size and color combinations perform best?

Why it matters:

- Supports buying decisions, assortment planning, and future purchase allocation.

Useful dashboard page:

- Size / color page
- Assortment optimization page

### 7. Markdown impact analysis

Question:

- Which markdown items still have high stock and weak sell-through?

Why it matters:

- Shows where markdown may not yet be clearing inventory effectively, or where aged stock remains risky.

Useful dashboard page:

- Inventory and markdown page

### 8. Return rate by channel

Question:

- How different are return rates between online and offline?

Why it matters:

- Return rate changes the true economics of omnichannel retail, especially in fashion.

Useful dashboard page:

- Omnichannel comparison
- Returns page

### 9. Return reasons by channel

Question:

- Why are customers returning products, and does that differ by channel?

Why it matters:

- Helps diagnose sizing issues, fit problems, expectation mismatch, and fulfillment quality problems.

Useful dashboard page:

- Returns analysis
- Customer experience page

### 10. Online vs offline UPT and ATV

Question:

- How do channels compare on units per transaction and average transaction value?

Why it matters:

- UPT and ATV are core retail KPIs and often differ meaningfully between offline and online behavior.

Useful dashboard page:

- Channel performance
- Executive KPI cards

### 11. Inventory stock status by store

Question:

- Which stores have healthy stock, low stock, or stockout risk?

Why it matters:

- Store-level stock health is critical for replenishment and lost-sales prevention.

Useful dashboard page:

- Inventory operations
- Store performance page

### 12. Overstock and stockout candidates

Question:

- Which SKUs look risky because they are overstocked or near stockout?

Why it matters:

- Supports replenishment actions, transfer decisions, and markdown planning.

Useful dashboard page:

- Inventory exception page
- Action priority page

### 13. Store performance vs target

Question:

- Which stores are ahead of or behind their monthly revenue target?

Why it matters:

- Store target tracking is essential for retail management and store-level accountability.

Useful dashboard page:

- Store scorecard
- Regional performance page

### 14. Supplier/factory delivery performance

Question:

- Which suppliers and factories are most reliable on delivery and output?

Why it matters:

- Late delivery can damage seasonal fashion performance because launch timing matters.

Useful dashboard page:

- Supplier performance
- Supply chain operations

### 15. Quality rejection rate by factory

Question:

- Which factories have the highest rejection rate?

Why it matters:

- Quality issues increase waste, delay receipts, and reduce sellable stock.

Useful dashboard page:

- Supplier quality page
- Sourcing review page

### 16. Ship-from-store vs warehouse fulfillment mix

Question:

- How much of online fulfillment comes from stores versus warehouses?

Why it matters:

- This is a core omnichannel capability and helps measure the operational role of ship-from-store.

Useful dashboard page:

- Omnichannel fulfillment page
- Logistics / fulfillment page

## Suggested Usage

- Use these queries as a validation pack before building new Power BI pages.
- Start with channel, collection, and inventory questions first because they are the highest-signal views for fashion retail.
- Reuse the logic when converting business questions into DAX measures or dashboard cards later.
