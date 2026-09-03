# VMart Schema, Explained 🛒

VMart is Vertica's built-in "practice database" — pretend it's the backend of a supermarket chain that sells stuff both **in stores** and **online**. It's the same idea as a college using dummy student records to teach SQL, except VMart is built specifically to teach you how a **star schema** (the standard layout for analytics/data-warehouse databases) works.

---

## 1. The big idea: star schema in one line

> **Facts = things that *happened* (a sale, a shipment). Dimensions = things that describe *who/what/when/where*.**

Every fact table sits in the middle, surrounded by dimension tables it points to — like a star. That's literally where the name comes from.

| Term | Think of it as... | VMart example |
|---|---|---|
| **Fact table** | A transaction log / event record | `store_sales_fact` — one row per item sold at a checkout |
| **Dimension table** | A lookup table with descriptive detail | `customer_dimension` — who the customer actually is |
| **Surrogate key** | An internal ID (not the real-world ID) that links fact ↔ dimension | `customer_key`, `product_key`, `date_key` — all just integers |

Ask your trainees: *"If I want to know total sales by state last March, do I query one giant flat table, or do I join a slim fact table to a couple of dimension tables?"* — that's the whole pitch for why star schemas exist (fewer repeated columns, faster scans, easy joins).

---

## 2. VMart has three schemas, not one

| Schema | What it models | Feels like |
|---|---|---|
| `public` | Stuff shared across the whole business — customers, products, dates, vendors, employees, warehouses | The "master data" everyone shares |
| `store` | Physical, walk-in-store retail | POS terminal + backroom inventory |
| `online_sales` | E-commerce | The company's website checkout |

Good discussion prompt: *why keep `date_dimension` and `product_dimension` in `public` instead of duplicating them in `store` and `online_sales`?* → Answer: they're **conformed dimensions** — shared across schemas so "total sales" queries can union store + online cleanly.

---

## 3. Table-by-table cheat sheet

### `public` schema

| Table | Role | Key columns |
|---|---|---|
| `customer_dimension` | Who's buying | `customer_key` (PK), customer_name, customer_type, city/state/region |
| `product_dimension` | What's being sold | `product_key` + `product_version` (composite PK), sku_number, category_description, department_description |
| `date_dimension` | When | `date_key` (PK), full date, day/month/year, day_of_week |
| `vendor_dimension` | Who supplies stock | `vendor_key` (PK), vendor_name, address |
| `employee_dimension` | Staff | `employee_key` (PK), employee_name, job_title |
| `promotion_dimension` | Discounts/campaigns | `promotion_key` (PK), promotion_name, promotion_type |
| `shipping_dimension` | Delivery method | `shipping_key` (PK), ship_method, carrier |
| `warehouse_dimension` | Storage location | `warehouse_key` (PK), warehouse_name, city/state |
| `inventory_fact` | Stock levels over time | date_key, product_key, warehouse_key (all FK), qty_in_stock |

### `store` schema

| Table | Role | Key columns |
|---|---|---|
| `store_dimension` | Physical store details | `store_key` (PK), store_name, city/state |
| `store_sales_fact` | POS sales — **the main fact table** | date_key, product_key, customer_key, employee_key, store_key, promotion_key (all FK), sales_quantity, sales_dollar_amount |
| `store_orders_fact` | Restocking orders from vendors | date_key, product_key, vendor_key, store_key (all FK) |

### `online_sales` schema

| Table | Role | Key columns |
|---|---|---|
| `online_page_dimension` | Which web page drove the sale | `online_page_key` (PK), page name/type |
| `call_center_dimension` | Support/order-routing center | `call_center_key` (PK), region |
| `online_sales_fact` | Web sales | date_key, product_key, customer_key, call_center_key, online_page_key, promotion_key, ship_key (all FK), sales_dollar_amount |
| `click_stream_fact` | Website clicks | date_key, online_page_key (FK), click event details |

---

## 4. Relationships at a glance

| Fact table | Joins to |
|---|---|
| `store_sales_fact` | customer, product, date, store, employee, promotion |
| `online_sales_fact` | customer, product, date, call_center, online_page, promotion |
| `inventory_fact` | product, date, warehouse |
| `store_orders_fact` | product, date, vendor, store |

Every join is **fact.some_key = dimension.some_key**, always many-fact-rows-to-one-dimension-row. That's it — no surprises, no weird many-to-many joins to explain.

---

## 5. Try-it-yourself for trainees

```sql
-- Warm-up: what tables exist and where?
SELECT table_schema, table_name FROM tables ORDER BY 1,2;

-- Classic star-schema join: total sales by product category
SELECT p.category_description, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN public.product_dimension p ON s.product_key = p.product_key
GROUP BY 1
ORDER BY 2 DESC;

# TODO (Lab): have trainees rewrite the query above to break revenue down
# by customer_state instead of category_description ????
```

**Stretch goal (flag as optional):** union `store_sales_fact` and `online_sales_fact` together to get one "total company revenue by date" view — this is where trainees hit the fact tables having slightly different FK sets (store has `store_key`/`employee_key`, online has `call_center_key`/`online_page_key`) and have to think about how to reconcile that. Good discussion, don't force it if the batch is still shaky on basic joins.

---

## 6. One-slide summary (if you want a TL;DR for the deck)

- **3 schemas**: public (shared), store (offline), online_sales (online)
- **Facts = events**, always end in `_fact`, always numeric measures + a bunch of FKs
- **Dimensions = descriptions**, always end in `_dimension`, always have a `_key` PK
- **date_dimension** and **product_dimension** are shared across both sales channels — that's the whole point of conformed dimensions
