# Day 6 — Vertica: SQL Fundamentals

*Fri, 4 Sep 2026*

---

## 🔁 Recap: Day 5

You installed Docker Desktop, pulled and ran the `molo17/vertica-ce` container, connected via `vsql`, and loaded the VMart sample dataset (5 million rows in `store_sales_fact`, if your COUNT check matched). Today you actually *write SQL* against it — plus you build your own schema from scratch, and add a GUI client to your toolkit.

---

## 📚 Concepts

### Reconnecting to Vertica

Quick refresher — you'll type this at the start of nearly every session from here on:

```bash
docker start vertica-ce      # if it's not already running
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```

### Databases, schemas, tables — the hierarchy

Vertica's structure: **database** → **schema** → **table**. Your `demo` database already has a `public` schema and a `store` schema (from VMart). Schemas are just namespaces — a way to group related tables without name collisions. Let's make our own:

```sql
CREATE SCHEMA IF NOT EXISTS training;
```

### Vertica data types — the essentials

| Type | Use for |
|---|---|
| `INTEGER` | whole numbers |
| `NUMERIC(p,s)` | exact decimals — money, always use this over floats for prices |
| `VARCHAR(n)` | short-to-medium text, max length `n` |
| `LONG VARCHAR` | large text blocks, no practical length cap |
| `DATE` | calendar date, no time |
| `TIMESTAMP` | date + time |
| `BOOLEAN` | true/false |

### Creating tables

```sql
CREATE TABLE training.customers (
    customer_id  INTEGER,
    name         VARCHAR(50),
    city         VARCHAR(50),
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
    order_date   DATE
);
```

> 💡 **Behind the scenes:** every `CREATE TABLE` in Vertica automatically creates a default **superprojection** — the actual physical column-store layout on disk. You're not managing that yet, but it's *why* Vertica needed those `CREATE TABLE` statements to run before any data can land anywhere. Tomorrow (Day 7) you'll learn why custom projections matter for performance.

### DML — inserting, updating, deleting

```sql
INSERT INTO training.customers VALUES (1, 'Asha Rao', 'Hyderabad', '2024-01-15');
INSERT INTO training.customers VALUES (2, 'Vikram Shah', 'Mumbai', '2024-02-20');

UPDATE training.customers SET city = 'Bengaluru' WHERE customer_id = 2;

DELETE FROM training.customers WHERE customer_id = 99;   -- no-op if it doesn't exist, that's fine
```

> 💡 Vertica is architecturally optimized for **bulk loads and heavy reads**, not constant single-row updates (that's more an OLTP database's job — MySQL/Postgres territory). The syntax above is standard SQL and totally fine for this lab and for occasional corrections — just know that *production* Vertica workflows lean much more on bulk `COPY` (tomorrow's topic) than row-by-row `INSERT`.

### SELECT, WHERE, JOIN, GROUP BY

```sql
SELECT * FROM training.customers WHERE city = 'Bengaluru';

SELECT c.name, o.order_id, o.quantity, p.product_name
FROM training.orders o
JOIN training.customers c ON o.customer_id = c.customer_id
JOIN training.products p ON o.product_id = p.product_id;

SELECT c.city, COUNT(*) AS total_orders
FROM training.orders o
JOIN training.customers c ON o.customer_id = c.customer_id
GROUP BY c.city
ORDER BY total_orders DESC;
```

**Same patterns, bigger dataset — try these against VMart:**

```sql
SELECT
    COUNT(*) AS number_of_sales,
    SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact;

SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY category_sales DESC
LIMIT 5;
```

This is the same SQL vocabulary — `JOIN`, `GROUP BY`, aggregates — just running against 5 million rows instead of 2. That's the whole point of a columnar analytical database: this shouldn't feel meaningfully slower.

---

## 🖥️ Installing DBeaver Community

Everything so far has been `vsql` — command-line only. Let's add a GUI.

**🪟 On Windows:**

1. Download: https://dbeaver.io/download/ → **Community → Windows → x86 → EXE**
2. Run the installer, choose **Standard installation**, finish.
3. Open DBeaver.

### Connect DBeaver to Vertica

1. **Database → New Database Connection**
2. Search for and select **Vertica**
3. Enter:

| Field | Value |
|---|---|
| Host | `localhost` |
| Port | `5433` |
| Database | `demo` |
| Username | `dbadmin` |
| Password | `password` |

4. If prompted to **Download driver files**, click **Download** — DBeaver fetches the Vertica JDBC driver automatically.
5. Click **Test Connection** → you want to see **Connected**.
6. Click **Finish**.

### Browse and query

In the left panel: **Vertica connection → demo → Schemas → public** and **store** — you should see the same tables you've been querying via `vsql`. (`training` will show up here too, once you create it together in the Guided Hands-on section next — if it's not there yet, that's expected, not a problem.)

Open a SQL editor on the connection and run the exact same VMart query from earlier:

```sql
SELECT
    COUNT(*) AS number_of_sales,
    SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact;
```

Same numbers as `vsql` gave you — same database, two different windows into it.

---

## 🧪 Guided hands-on (do this together)

**🐧 Start in Ubuntu/`vsql`:**

```sql
CREATE SCHEMA IF NOT EXISTS training;

CREATE TABLE training.customers (
    customer_id INTEGER, name VARCHAR(50), city VARCHAR(50), signup_date DATE
);
CREATE TABLE training.products (
    product_id INTEGER, product_name VARCHAR(50), category VARCHAR(30), price NUMERIC(10,2)
);
CREATE TABLE training.orders (
    order_id INTEGER, customer_id INTEGER, product_id INTEGER, quantity INTEGER, order_date DATE
);

INSERT INTO training.customers VALUES (1, 'Asha Rao', 'Hyderabad', '2024-01-15');
INSERT INTO training.customers VALUES (2, 'Vikram Shah', 'Mumbai', '2024-02-20');
INSERT INTO training.products VALUES (1, 'Wireless Mouse', 'Electronics', 799.00);
INSERT INTO training.products VALUES (2, 'Notebook Set', 'Stationery', 149.00);
INSERT INTO training.orders VALUES (1, 1, 1, 2, '2024-03-01');
INSERT INTO training.orders VALUES (2, 2, 2, 5, '2024-03-02');

SELECT c.name, o.order_id, p.product_name, o.quantity
FROM training.orders o
JOIN training.customers c ON o.customer_id = c.customer_id
JOIN training.products p ON o.product_id = p.product_id;
```

**🪟 Then in DBeaver:** connect, browse to `training` schema, run that same `JOIN` query, compare results side by side with what `vsql` showed you.

---

## 🔬 Lab — on your own

**Scenario:** Build a small schema of your own, then prove you can work it from both interfaces.

1. Create a new schema named after yourself (e.g. `CREATE SCHEMA IF NOT EXISTS <yourname>_lab;`).
2. Inside it, create **two related tables** (your choice of subject — a mini library system, a food-delivery order set, a gym membership tracker, whatever you like) with at least 4 columns each, using at least 3 different data types across both tables.
3. Manually `INSERT` at least 5 rows into each table.
4. Write one `UPDATE` statement and one `DELETE` statement against your data, and confirm the change with a `SELECT` before/after.
5. Write a `JOIN` query combining both tables, with a `WHERE` filter.
6. Write a `GROUP BY` + aggregate query (e.g., count/sum grouped by some category).
7. Open DBeaver, connect to the same `demo` database, and run your exact `JOIN` query from Step 5 there too. Confirm identical results.
8. **Bonus:** In DBeaver, browse to `store.store_sales_fact` and use the GUI's data viewer (not SQL) to look at raw rows — get a feel for browsing vs querying.

---

## 📎 Copy-paste command reference — Day 6

```sql
-- Reconnect
-- (bash) docker start vertica-ce
-- (bash) docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo

-- Schema
CREATE SCHEMA IF NOT EXISTS training;

-- Table creation
CREATE TABLE training.customers (
    customer_id INTEGER, name VARCHAR(50), city VARCHAR(50), signup_date DATE
);

-- DML
INSERT INTO <schema>.<table> VALUES (...);
UPDATE <schema>.<table> SET <col> = <value> WHERE <condition>;
DELETE FROM <schema>.<table> WHERE <condition>;

-- Querying
SELECT * FROM <schema>.<table> WHERE <condition>;
SELECT a.col, b.col FROM <schema>.<table_a> a JOIN <schema>.<table_b> b ON a.key = b.key;
SELECT <group_col>, COUNT(*) FROM <schema>.<table> GROUP BY <group_col> ORDER BY COUNT(*) DESC;

-- Exit vsql
\q
```

**DBeaver connection reference:**
```
Host: localhost | Port: 5433 | Database: demo | Username: dbadmin | Password: password
```

---

## 👀 Tomorrow: Day 7 — Vertica: Loading & Performance

You'll move past manual `INSERT`s into real bulk loading with `COPY` — including handling malformed rows without the whole load failing — then get an introduction to **projections** (why Vertica needs them, how they change performance) and basic query profiling with `EXPLAIN` and `PROFILE`.
