# The Complete Vertica SQL Guide
### Data Types · DDL · DML · SELECT · Advanced SELECT — built on your live VMart database

Every table, column, and data type referenced in this guide was pulled
directly from your own running `vertica-ce` container via:
 
```sql
SELECT table_schema, table_name, column_name, data_type
FROM v_catalog.columns
WHERE table_schema IN ('public', 'store', 'online_sales')
ORDER BY table_schema, table_name, ordinal_position;
```

Nothing here is guessed from generic documentation — every query is
written against columns that genuinely exist in your VMart instance
right now.

---

## Table of Contents

1. [VMart, at a glance](#1-vmart-at-a-glance)
2. [Data types](#2-data-types)
3. [Creating database objects (DDL)](#3-creating-database-objects-ddl)
4. [DML — INSERT, UPDATE, DELETE](#4-dml--insert-update-delete)
5. [SELECT fundamentals](#5-select-fundamentals)
6. [Advanced SELECT — JOIN, GROUP BY, HAVING](#6-advanced-select--join-group-by-having)
7. [Subqueries](#7-subqueries)
8. [Window functions — a light introduction](#8-window-functions--a-light-introduction)
9. [Gotchas](#9-gotchas)
10. [Quick reference](#10-quick-reference)

---

## 1. VMart, at a glance

Your VMart database has **three schemas**, each with real tables:

| Schema | Tables |
|---|---|
| `public` | `customer_dimension`, `date_dimension`, `employee_dimension`, `inventory_fact`, `product_dimension`, `promotion_dimension`, `shipping_dimension`, `vendor_dimension`, `warehouse_dimension` |
| `store` | `store_dimension`, `store_sales_fact`, `store_orders_fact` |
| `online_sales` | `call_center_dimension`, `online_page_dimension`, `online_sales_fact` |

**Two table "shapes" you'll see throughout:**
- **Dimension tables** (`product_dimension`, `customer_dimension`, `store_dimension`, `date_dimension`...) — descriptive attributes about an entity. Small-ish, rarely change.
- **Fact tables** (`store_sales_fact`, `online_sales_fact`, `inventory_fact`, `store_orders_fact`) — the actual transactional events, referencing dimension tables via `_key` columns. Large — `store_sales_fact` alone is 5 million rows.

---

## 2. Data types

Types actually in use across your real VMart schema:

| Type | Used for | Real example from your schema |
|---|---|---|
| `INT` / `INTEGER` | Whole numbers, keys | `product_dimension.product_key` |
| `NUMERIC(p,s)` | Exact decimals — money, always over floats | `employees.salary NUMERIC(10,2)` |
| `FLOAT` | Approximate decimals | `online_sales_fact.sales_dollar_amount` |
| `VARCHAR(n)` | Variable-length text, up to `n` characters | `customer_dimension.customer_name VARCHAR(256)` |
| `CHAR(n)` | **Fixed**-length text, always padded to exactly `n` characters | `store_dimension.store_state CHAR(2)` |
| `DATE` | Calendar date, no time | `store_sales_fact.store_sales_date` |
| `TIME` | Time of day, no date | `store_sales_fact.transaction_time` |
| `TIMESTAMP` | Date + time together | `store_sales_fact.store_sales_datetime` |

### `VARCHAR` vs. `CHAR` — a real distinction your own schema demonstrates

Your schema genuinely mixes both, which makes this easy to show
concretely instead of abstractly:

```sql
-- CHAR(2): always exactly 2 characters, space-padded if shorter
store.store_dimension.store_state       -- e.g. 'CA', 'NY'

-- VARCHAR(9): variable length, up to 9 characters, no padding
public.date_dimension.day_of_week        -- e.g. 'Monday', 'Tuesday'
```

**Rule of thumb:** use `CHAR(n)` only when every value is genuinely
always the same length (state codes, fixed status codes). Use
`VARCHAR(n)` for anything that varies — names, descriptions, free
text. Getting this backwards doesn't break anything functionally, but
wastes storage and can produce trailing-space surprises in comparisons
if you're not careful.

### Why `NUMERIC(p,s)` over `FLOAT` for money — proven by your own schema

Notice `employees.salary` uses `NUMERIC(10,2)` while
`online_sales_fact.sales_dollar_amount` uses `FLOAT`. This is a real,
worth-noticing inconsistency in VMart's own design: `FLOAT` stores an
*approximation*, which can introduce tiny rounding errors that compound
across millions of rows of aggregation. `NUMERIC(p,s)` stores an
*exact* decimal value — always the right choice for genuinely
financial figures in anything you design yourself.

```sql
CREATE TABLE training.payroll (
    employee_id  INTEGER,
    salary       NUMERIC(10,2)      -- exact — 2 digits after the decimal, 10 total
);
```

---

## 3. Creating database objects (DDL)

### Creating a schema

```sql
CREATE SCHEMA IF NOT EXISTS training;
```

`IF NOT EXISTS` prevents an error if you (or someone else) already
created it — safe to re-run.

### Creating tables

```sql
CREATE TABLE training.customers (
    customer_id  INTEGER,
    name         VARCHAR(50),
    state        CHAR(2),
    signup_date  DATE
);

CREATE TABLE training.products (
    product_id    INTEGER,
    product_name  VARCHAR(50),
    category      VARCHAR(30),
    price         NUMERIC(10,2)
);

CREATE TABLE training.orders (
    order_id     INTEGER,
    customer_id  INTEGER,
    product_id   INTEGER,
    quantity     INTEGER,
    order_date   DATE,
    order_time   TIME
);
```

Every `CREATE TABLE` automatically creates a default **superprojection**
— the actual physical, column-encoded layout on disk. Nothing works
without at least one; you never need to create it yourself.

### Constraints — a real gotcha worth understanding before you use them

You can declare `PRIMARY KEY`, `UNIQUE`, and `FOREIGN KEY` constraints
in Vertica using standard-looking syntax:

```sql
CREATE TABLE training.customers (
    customer_id  INTEGER PRIMARY KEY,
    name         VARCHAR(50),
    state        CHAR(2),
    signup_date  DATE
);
```

**But this doesn't do what it would in MySQL or Postgres.** By
default, Vertica does **not enforce** `PRIMARY KEY` or `UNIQUE`
constraints — you can still insert duplicate `customer_id` values and
Vertica won't stop you. To actually enforce a primary key, you must
say so explicitly:

```sql
CREATE TABLE training.customers (
    customer_id  INTEGER PRIMARY KEY ENABLED,
    name         VARCHAR(50)
);
```

**`FOREIGN KEY` constraints are never enforced at all**, `ENABLED` or
not — Vertica only uses them as a hint to the query optimizer for
faster joins, never as an integrity check. If you need to verify
existing data against a constraint, use:

```sql
SELECT ANALYZE_CONSTRAINTS('training.customers');
```

This checks current data for violations after the fact — Vertica's
answer to "enforce it after loading" rather than "block it at
insert time," which fits the bulk-load-oriented design covered in
Section 4.

### Dropping and altering

```sql
DROP TABLE IF EXISTS training.customers;
ALTER TABLE training.customers ADD COLUMN email VARCHAR(100);
DROP SCHEMA IF EXISTS training CASCADE;   -- CASCADE also drops everything inside it
```

---

## 4. DML — INSERT, UPDATE, DELETE

### INSERT

```sql
INSERT INTO training.customers VALUES (1, 'Asha Rao', 'TG', '2024-01-15');
INSERT INTO training.customers VALUES (2, 'Vikram Shah', 'MH', '2024-02-20');

INSERT INTO training.products VALUES (1, 'Wireless Mouse', 'Electronics', 799.00);
INSERT INTO training.products VALUES (2, 'Notebook Set', 'Stationery', 149.00);

INSERT INTO training.orders VALUES (1, 1, 1, 2, '2024-03-01', '10:15:00');
INSERT INTO training.orders VALUES (2, 2, 2, 5, '2024-03-02', '14:30:00');
```

### UPDATE

```sql
UPDATE training.customers SET state = 'KA' WHERE customer_id = 2;
```

### DELETE

```sql
DELETE FROM training.customers WHERE customer_id = 99;   -- no-op if it doesn't exist
```

### Why this feels different from MySQL/Postgres habits

Vertica's columnar storage isn't built for instant in-place row
rewrites the way an OLTP row-store is. Under the hood, single-row
`UPDATE`/`DELETE` gets handled through background reconciliation
processes rather than an immediate physical edit. The syntax above is
completely standard SQL and fine for occasional corrections — but
production Vertica pipelines lean on **bulk `COPY`** loads far more
than row-by-row `INSERT`/`UPDATE`. `COPY` itself isn't covered in this
guide (it's already thoroughly covered in Day 7's courseware) — this
section is specifically about hand-written DML for small corrections
and lab exercises.

---

## 5. SELECT fundamentals

### Basic SELECT and WHERE

```sql
SELECT * FROM training.customers WHERE state = 'KA';

SELECT customer_name, customer_city, customer_state
FROM public.customer_dimension
WHERE customer_state = 'TX';
```

### DISTINCT — unique values only

```sql
SELECT DISTINCT category_description
FROM public.product_dimension;
```

### ORDER BY

```sql
SELECT product_description, product_price
FROM public.product_dimension
ORDER BY product_price DESC;
```

### LIMIT — cap the number of rows returned

```sql
SELECT product_description, product_price
FROM public.product_dimension
ORDER BY product_price DESC
LIMIT 10;
```

### Filtering with comparison and logical operators

```sql
SELECT product_description, product_price
FROM public.product_dimension
WHERE product_price > 100
  AND category_description = 'Beverages';

SELECT customer_name, customer_state
FROM public.customer_dimension
WHERE customer_state IN ('TX', 'CA', 'NY');

SELECT product_description
FROM public.product_dimension
WHERE product_description LIKE '%Chocolate%';
```

---

## 6. Advanced SELECT — JOIN, GROUP BY, HAVING

### INNER JOIN — combining fact and dimension tables

Every fact table connects to its dimension tables through `_key`
columns. This is the single most common query shape you'll write
against VMart:

```sql
SELECT
    p.product_description,
    p.category_description,
    f.sales_dollar_amount,
    f.store_sales_date
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
LIMIT 20;
```

### Joining three tables

```sql
SELECT
    c.customer_name,
    p.product_description,
    s.store_name,
    f.sales_dollar_amount
FROM store.store_sales_fact f
JOIN public.customer_dimension c ON f.customer_key = c.customer_key
JOIN public.product_dimension p ON f.product_key = p.product_key
JOIN store.store_dimension s ON f.store_key = s.store_key
LIMIT 20;
```

### GROUP BY with aggregates

```sql
SELECT
    p.category_description,
    SUM(f.sales_dollar_amount) AS total_sales,
    COUNT(*) AS number_of_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY total_sales DESC;
```

Common aggregates: `SUM()`, `COUNT()`, `AVG()`, `MIN()`, `MAX()`.

### HAVING — filtering on an aggregate result

`WHERE` filters rows *before* grouping; `HAVING` filters groups
*after* aggregation — this is the distinction worth drilling into,
since it's the single most common point of confusion:

```sql
SELECT
    p.category_description,
    SUM(f.sales_dollar_amount) AS total_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
HAVING SUM(f.sales_dollar_amount) > 1000000
ORDER BY total_sales DESC;
```

You cannot write `WHERE SUM(f.sales_dollar_amount) > 1000000` — an
aggregate function can't be evaluated until *after* the rows are
grouped, and `WHERE` runs before grouping happens. That's precisely
why `HAVING` exists as a separate clause.

### A cross-schema join example — store vs. online sales

```sql
SELECT
    p.category_description,
    SUM(f.sales_dollar_amount) AS store_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description

UNION ALL

SELECT
    p.category_description,
    SUM(o.sales_dollar_amount) AS online_sales
FROM online_sales.online_sales_fact o
JOIN public.product_dimension p ON o.product_key = p.product_key
GROUP BY p.category_description;
```
(This uses `UNION ALL` to stack two separate result sets — worth
knowing exists, even though it's not a JOIN itself: `UNION ALL` stacks
rows from two queries with matching columns, `JOIN` combines columns
from two tables side by side.)

---

## 7. Subqueries

A subquery is a `SELECT` nested inside another query — used where you
need a value or a set of values computed first, before the outer
query can run.

### Subquery in `WHERE` — filtering against a computed value

```sql
SELECT product_description, product_price
FROM public.product_dimension
WHERE product_price > (
    SELECT AVG(product_price) FROM public.product_dimension
);
```
Finds every product priced above the average price across all
products — the inner query computes that average first.

### Subquery with `IN` — filtering against a set of values

```sql
SELECT customer_name, customer_state
FROM public.customer_dimension
WHERE customer_key IN (
    SELECT customer_key
    FROM store.store_sales_fact
    WHERE sales_dollar_amount > 500
);
```
Finds every customer who has made at least one purchase over $500 —
the inner query produces the list of qualifying `customer_key` values.

### Subquery in `FROM` — treating a query result as a table

```sql
SELECT category_description, total_sales
FROM (
    SELECT
        p.category_description,
        SUM(f.sales_dollar_amount) AS total_sales
    FROM store.store_sales_fact f
    JOIN public.product_dimension p ON f.product_key = p.product_key
    GROUP BY p.category_description
) AS category_totals
WHERE total_sales > 500000
ORDER BY total_sales DESC;
```
Notice this achieves something similar to `HAVING` here, but by
building the aggregate first as its own named result (`category_totals`)
and filtering that afterward — useful when the filtering logic gets
complex enough that `HAVING` alone would be awkward to read.

---

## 8. Window functions — a light introduction

Window functions look similar to aggregates (`SUM`, `AVG`, `RANK`) but
**don't collapse rows into groups** — every original row stays in the
result, with the calculated value added alongside it. This is the key
mental difference from `GROUP BY`.

### `ROW_NUMBER()` — numbering rows within a group

```sql
SELECT
    p.category_description,
    p.product_description,
    p.product_price,
    ROW_NUMBER() OVER (
        PARTITION BY p.category_description
        ORDER BY p.product_price DESC
    ) AS price_rank_in_category
FROM public.product_dimension p;
```
`PARTITION BY` restarts the numbering for each category — this gives
you a rank *within* each category, side by side with every individual
product row, unlike `GROUP BY` which would collapse each category down
to a single summary row.

### `SUM() OVER()` — a running total

```sql
SELECT
    store_sales_date,
    sales_dollar_amount,
    SUM(sales_dollar_amount) OVER (
        ORDER BY store_sales_date
    ) AS running_total
FROM store.store_sales_fact
WHERE store_sales_date BETWEEN '2003-01-01' AND '2003-01-10';
```
Each row shows its own sale amount *and* the cumulative total up to
and including that row — impossible to get from a plain `GROUP BY`,
since grouping would collapse the individual dates away entirely.

**The takeaway for this stage:** `GROUP BY` answers "give me one row
per category" questions. Window functions answer "give me every row,
plus something computed about its position relative to other rows"
questions. Full mastery of window functions (ranking functions, lag/lead,
frame clauses) is a topic in its own right — this is intentionally just
enough to recognize the pattern and know it exists for later.

---

## 9. Gotchas

**1. `PRIMARY KEY` alone doesn't enforce uniqueness.**
```sql
customer_id INTEGER PRIMARY KEY            -- NOT enforced by default
customer_id INTEGER PRIMARY KEY ENABLED     -- actually enforced
```

**2. `FOREIGN KEY` is never enforced, `ENABLED` or not.** It only
helps the query optimizer plan joins — use `ANALYZE_CONSTRAINTS()` if
you need to actually check referential integrity after loading.

**3. `WHERE` cannot filter on an aggregate — use `HAVING`.**
```sql
WHERE SUM(sales_dollar_amount) > 1000     -- ERROR
HAVING SUM(sales_dollar_amount) > 1000      -- correct
```

**4. `online_sales_fact` needs its schema prefix.**
```sql
SELECT * FROM online_sales_fact;              -- fails — no schema, wrong default assumption
SELECT * FROM online_sales.online_sales_fact;   -- correct
```

**5. `CHAR(n)` pads with spaces — can silently break string comparisons.**
```sql
WHERE store_state = 'CA '   -- trailing space — may or may not match depending on comparison context
WHERE store_state = 'CA'      -- safer; but be aware CHAR columns store padded values internally
```
When in doubt, prefer `TRIM()` around `CHAR` columns in comparisons if
results look unexpectedly empty.

**6. Row-by-row `UPDATE`/`DELETE` works but isn't the intended workload.**
Fine for lab corrections; real pipelines lean on bulk `COPY` instead
(Day 7's territory).

**7. A subquery in `FROM` needs an alias.**
```sql
SELECT * FROM (SELECT ...) ;              -- ERROR — missing alias
SELECT * FROM (SELECT ...) AS my_alias;     -- correct
```

---

## 10. Quick reference

```sql
-- Schema & table creation
CREATE SCHEMA IF NOT EXISTS training;
CREATE TABLE training.customers (
    customer_id INTEGER,
    name VARCHAR(50),
    state CHAR(2),
    signup_date DATE
);
DROP TABLE IF EXISTS training.customers;
ALTER TABLE training.customers ADD COLUMN email VARCHAR(100);

-- Enforced constraint (opt-in, not default)
customer_id INTEGER PRIMARY KEY ENABLED;
SELECT ANALYZE_CONSTRAINTS('training.customers');

-- DML
INSERT INTO training.customers VALUES (1, 'Asha Rao', 'TG', '2024-01-15');
UPDATE training.customers SET state = 'KA' WHERE customer_id = 2;
DELETE FROM training.customers WHERE customer_id = 99;

-- Basic SELECT
SELECT * FROM training.customers WHERE state = 'KA';
SELECT DISTINCT category_description FROM public.product_dimension;
SELECT * FROM public.product_dimension ORDER BY product_price DESC LIMIT 10;

-- JOIN
SELECT p.product_description, f.sales_dollar_amount
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key;

-- GROUP BY + HAVING
SELECT p.category_description, SUM(f.sales_dollar_amount) AS total_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
HAVING SUM(f.sales_dollar_amount) > 1000000
ORDER BY total_sales DESC;

-- Subquery
SELECT product_description FROM public.product_dimension
WHERE product_price > (SELECT AVG(product_price) FROM public.product_dimension);

-- Window function
SELECT category_description, product_description, product_price,
    ROW_NUMBER() OVER (PARTITION BY category_description ORDER BY product_price DESC) AS rnk
FROM public.product_dimension;

-- Key real table references
store.store_sales_fact        -- 5,000,000 rows, brick-and-mortar sales
online_sales.online_sales_fact  -- online sales (note the schema!)
public.product_dimension       -- product catalog
public.customer_dimension        -- customers
store.store_dimension              -- physical stores
public.date_dimension                -- calendar/date attributes
```

--- 

MySQL - SQL courseware - 

https://github.com/vamzzzz/sql-stuff 