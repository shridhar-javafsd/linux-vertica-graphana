# Day 7 — Vertica: Loading & Performance

*Mon, 7 Sep 2026*

---

## 🔁 Recap: Day 6

You built a schema from scratch, wrote real DDL/DML/SELECT/JOIN/GROUP BY, and got DBeaver talking to the same database as `vsql`. Today: how data *actually* gets into Vertica at scale (not one `INSERT` at a time), and the first real look under the hood at what makes queries fast or slow.

---

## 📚 Concepts

### Bulk loading with `COPY`

`INSERT` one row at a time doesn't scale — real pipelines load thousands or millions of rows in one shot via `COPY`. The catch: `vsql`'s `COPY ... FROM LOCAL` reads the file from wherever `vsql` itself is running — and since we connect via `docker exec`, that means **inside the container's filesystem**, not your Ubuntu host. So loading a file you created on the Ubuntu side needs one extra step: `docker cp` it in first.

**Step 1 — create a CSV on your Ubuntu host:**

```bash
mkdir -p ~/vertica_data
cat > ~/vertica_data/new_orders.csv << 'EOF'
order_id,customer_id,product_id,quantity,order_date
101,1,1,3,2024-03-10
102,2,2,1,2024-03-11
103,1,2,4,2024-03-12
104,2,1,2,2024-03-13
105,1,1,1,2024-03-14
EOF
```

**Step 2 — copy it into the running container:**

```bash
docker cp ~/vertica_data/new_orders.csv vertica-ce:/tmp/new_orders.csv
```

**Step 3 — load it, from inside `vsql`:**

```sql
COPY training.orders FROM LOCAL '/tmp/new_orders.csv' DELIMITER ',' SKIP 1;
```

`SKIP 1` skips the CSV header row. Verify:

```sql
SELECT COUNT(*) FROM training.orders;
```

### Delimiters, formats, and handling bad rows gracefully

Real data is messy. `COPY` has options for exactly this:

```sql
COPY training.orders FROM LOCAL '/tmp/messy_orders.csv'
    DELIMITER ','
    SKIP 1
    REJECTED DATA '/tmp/rejected_rows.txt'
    EXCEPTIONS '/tmp/load_exceptions.txt';
```

- **`REJECTED DATA`** — bad rows get written here instead of failing the whole load
- **`EXCEPTIONS`** — the actual error explaining *why* each row was rejected

This is the difference between "one malformed row kills a 2-million-row load" and "999,998 rows load fine, 2 rows get flagged for review." Always prefer the second in any real pipeline.

### Projections — why Vertica needs them, and why you should care

Every table gets a default **superprojection** automatically the moment you `CREATE TABLE` — that's the actual physical, column-encoded, sorted data sitting on disk. Nothing works without at least one.

**Why create *more* than the default?** A projection is sorted and stored in a specific order. A query filtering on `customer_id` runs fastest against a projection sorted by `customer_id` — Vertica can jump straight to the relevant range instead of scanning everything. A different query filtering by `order_date` would prefer a *different* sort order. Vertica's query optimizer automatically picks whichever existing projection best matches each incoming query — you don't manually tell it which one to use.

```sql
CREATE PROJECTION training.orders_by_customer
AS SELECT * FROM training.orders
ORDER BY customer_id;
```

This doesn't replace the superprojection — it's an *additional* physical copy of the same data, sorted differently, that the optimizer can choose between depending on the query. That's the fundamental trade-off of columnar/projection-based databases: **more projections = faster reads for the queries they match, at the cost of more disk space and slower writes** (every projection has to be updated on every load).

### Basic performance monitoring with system tables

Vertica tracks its own query history in system tables under the `v_monitor` schema:

```sql
SELECT request, request_duration_ms
FROM v_monitor.query_requests
ORDER BY request_duration_ms DESC
LIMIT 5;
```

This shows your 5 slowest recent queries — the starting point for "why is this slow," always.

### Introductory query profiling: `EXPLAIN` and `PROFILE`

**`EXPLAIN`** shows you the query *plan* — what Vertica intends to do — without actually running it:

```sql
EXPLAIN
SELECT p.category_description, SUM(f.sales_dollar_amount)
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description;
```

**`PROFILE`** actually *runs* the query and records real execution statistics — how long each step really took, not just what was planned:

```sql
PROFILE
SELECT p.category_description, SUM(f.sales_dollar_amount)
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description;
```

You don't need to master reading full query plans today — the goal is just knowing these two commands exist, what the difference is (*intent* vs *actual*), and that `v_monitor.query_requests` is where you'd go hunting if something felt slow later.

---

## 🧪 Guided hands-on (do this together)

**🐧 In Ubuntu (creating + copying the file):**

```bash
mkdir -p ~/vertica_data
cat > ~/vertica_data/new_orders.csv << 'EOF'
order_id,customer_id,product_id,quantity,order_date
101,1,1,3,2024-03-10
102,2,2,1,2024-03-11
103,1,2,4,2024-03-12
EOF
docker cp ~/vertica_data/new_orders.csv vertica-ce:/tmp/new_orders.csv
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```

**In `vsql`:**

```sql
COPY training.orders FROM LOCAL '/tmp/new_orders.csv' DELIMITER ',' SKIP 1;
SELECT COUNT(*) FROM training.orders;

CREATE PROJECTION training.orders_by_customer
AS SELECT * FROM training.orders
ORDER BY customer_id;

EXPLAIN SELECT customer_id, COUNT(*) FROM training.orders GROUP BY customer_id;

PROFILE SELECT customer_id, COUNT(*) FROM training.orders GROUP BY customer_id;

SELECT request, request_duration_ms
FROM v_monitor.query_requests
ORDER BY request_duration_ms DESC
LIMIT 5;
```

---

## 🔬 Lab — on your own

1. Create a CSV of at least 10 rows for one of your own tables from Day 6's lab (matching its column structure).
2. `docker cp` it into the container and load it with `COPY ... SKIP 1`. Confirm the row count went up by exactly the number of rows you added.
3. Deliberately create a **second**, slightly broken CSV — give one row the wrong number of columns, or an invalid date. Load it using `REJECTED DATA` and `EXCEPTIONS` clauses. Open both output files (`cat /tmp/rejected_rows.txt` etc., via `docker exec`) and confirm you can see exactly what got rejected and why — while the good rows still loaded successfully.
4. Create one additional projection on one of your own tables, sorted by whichever column you'd most commonly filter on.
5. Run `EXPLAIN` and then `PROFILE` on the same query against your table. You don't need to fully interpret every line — just note one thing each command told you that the other didn't.
6. Query `v_monitor.query_requests` and find your own slowest query from today's session.
7. **Bonus:** Run `PROFILE` on one of the big VMart aggregate queries from Day 6 (the category sales one) and see how its duration compares to your tiny training-schema queries.

---

## 📎 Copy-paste command reference — Day 7

```bash
# --- Getting a file into the container ---
mkdir -p ~/vertica_data
cat > ~/vertica_data/<file>.csv << 'EOF'
col1,col2,col3
...
EOF
docker cp ~/vertica_data/<file>.csv vertica-ce:/tmp/<file>.csv
```

```sql
-- Bulk load
COPY <schema>.<table> FROM LOCAL '/tmp/<file>.csv' DELIMITER ',' SKIP 1;

-- Load with bad-row handling
COPY <schema>.<table> FROM LOCAL '/tmp/<file>.csv'
    DELIMITER ','
    SKIP 1
    REJECTED DATA '/tmp/rejected_rows.txt'
    EXCEPTIONS '/tmp/load_exceptions.txt';

-- Projections
CREATE PROJECTION <schema>.<name>
AS SELECT * FROM <schema>.<table>
ORDER BY <column>;

-- Profiling
EXPLAIN SELECT ...;
PROFILE SELECT ...;

-- Performance monitoring
SELECT request, request_duration_ms
FROM v_monitor.query_requests
ORDER BY request_duration_ms DESC
LIMIT 5;
```

---

## 👀 Tomorrow: Day 8 — Grafana: Intro & Install

The Vertica block is done — you can load data, query it, and reason about performance basics. Tomorrow you install Grafana (natively, via `systemctl` this time, not Docker) and start turning this data into something you can actually *look* at.
