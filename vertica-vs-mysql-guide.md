# Vertica vs MySQL Performance Comparison — End-to-End Guide
### Using the VMart Sample Dataset

This guide walks through exporting VMart data from Vertica, recreating the schema in MySQL, loading the data, and running identical queries on both engines to compare and explain performance differences (columnar/MPP vs row-store OLTP).

It assumes the same environment already used for the Adaps training: **Windows 11 + WSL2 (Ubuntu) + Docker Desktop + Vertica CE (molo17/vertica-ce image) + DBeaver Community Edition**. MySQL will be added as a second Docker container in the same WSL2 environment so both databases are reachable from one machine and one SQL client.

---

## 1. Goals of This Exercise

- Show that Vertica (columnar, MPP-style engine) and MySQL (row-store, OLTP-oriented engine) are optimized for different workloads.
- Quantify the difference on realistic analytical queries (aggregations, star-schema joins, wide-table scans).
- Teach students to read `EXPLAIN` plans on both engines and explain *why* the numbers differ, not just *that* they differ.
- Be honest about where MySQL wins too (point lookups, single-row OLTP) — the point is workload-fit, not "Vertica is always faster."

---

## 2. Environment Setup

### 2.1 Vertica CE (already running per Adaps training setup)

- Container: `molo17/vertica-ce:24.1.0-0`
- Host/port: `localhost:5433`
- DB: `demo`, user: `dbadmin`, no password
- VMart sample data: load via Vertica's official VMart example schema/data generator if not already present (`/opt/vertica/examples/VMart_Schema` inside the container, or the VMart data generator scripts from Vertica's GitHub examples repo).

Verify VMart is loaded:
```sql
SELECT COUNT(*) FROM store.store_sales_fact;
SELECT COUNT(*) FROM online_sales.online_sales_fact;
```

### 2.2 Add MySQL via Docker (same WSL2 Ubuntu shell)

```bash
docker run -d \
  --name mysql-vmart \
  -e MYSQL_ROOT_PASSWORD=vmartpass \
  -e MYSQL_DATABASE=vmart \
  -p 3306:3306 \
  mysql:8.0
```

Confirm it's up:
```bash
docker ps
docker exec -it mysql-vmart mysql -uroot -pvmartpass -e "SHOW DATABASES;"
```

### 2.3 Connect DBeaver to both

- Add a second DBeaver connection: MySQL, host `localhost`, port `3306`, user `root`, password `vmartpass`, database `vmart`.
- Keep the existing Vertica connection (`localhost:5433`, db `demo`) alongside it.
- Having both open side-by-side in DBeaver makes the comparison demo much easier to run live in class.

---

## 3. VMart Schema Overview

VMart is a star schema. The core tables to use for this comparison:

| Table | Type | Approx. role |
|---|---|---|
| `store.store_sales_fact` | Fact | Large fact table, store sales transactions |
| `online_sales.online_sales_fact` | Fact | Large fact table, online sales transactions |
| `store.store_dimension` | Dimension | Store attributes |
| `public.product_dimension` | Dimension | Product attributes |
| `public.customer_dimension` | Dimension | Customer attributes |
| `public.date_dimension` | Dimension | Calendar/date attributes |
| `public.employee_dimension` | Dimension | Employee attributes |

Pick 5–7 tables (2 fact + a handful of dimensions) rather than the full schema — enough to run meaningful star-schema joins without turning the export/load step into its own multi-day project.

---

## 4. Export Data from Vertica

### 4.1 Export schema (DDL) for reference

```bash
docker exec -it <vertica-container> vsql -U dbadmin -d demo -c "\d store.store_sales_fact"
```
Repeat for each table you're exporting, or use:
```sql
SELECT EXPORT_OBJECTS('', 'store.store_sales_fact,public.product_dimension,public.customer_dimension,public.date_dimension,store.store_dimension');
```
This gives you the Vertica `CREATE TABLE` DDL to reference when writing the MySQL equivalent (Section 5).

### 4.2 Export data to CSV

For each table:
```sql
\o /tmp/store_sales_fact.csv
SELECT * FROM store.store_sales_fact;
\o
```

Better — use `COPY ... TO` with explicit delimiter/quoting so MySQL's loader accepts it cleanly:
```sql
COPY store.store_sales_fact TO '/tmp/store_sales_fact.csv'
  WITH DELIMITER ',' ENCLOSED BY '"' NULL '';
```

Repeat for each table you selected. Copy the CSVs out of the container to the WSL2 filesystem:
```bash
docker cp <vertica-container>:/tmp/store_sales_fact.csv ./exports/
```
(Repeat per file, or export directly to a bind-mounted volume to skip the copy step.)

**Note on volume**: `store_sales_fact` in full VMart can be several million rows. For a training demo, either use the full set (better for showing real performance gaps) or `LIMIT`/sample it (faster to iterate on while building the lesson). Decide based on how much time you want students to spend waiting on loads vs. queries.

---

## 5. Recreate Schema in MySQL

This is the step that needs actual thought, not a mechanical translation. Key differences to handle explicitly:

### 5.1 Data type mapping

| Vertica type | MySQL equivalent | Notes |
|---|---|---|
| `INTEGER` / `INT` | `INT` | Direct |
| `NUMERIC(p,s)` | `DECIMAL(p,s)` | Direct |
| `FLOAT` | `DOUBLE` | Vertica FLOAT is 8-byte |
| `VARCHAR(n)` | `VARCHAR(n)` | Check byte vs char length semantics |
| `CHAR(n)` | `CHAR(n)` | Direct |
| `DATE` | `DATE` | Direct |
| `TIMESTAMP` | `DATETIME` or `TIMESTAMP` | MySQL `TIMESTAMP` has a narrower range (1970–2038); prefer `DATETIME` for safety |
| `BOOLEAN` | `TINYINT(1)` | MySQL has no native boolean |

### 5.2 No columnar equivalent — and that's the point

Vertica gets its performance from **projections**: physically sorted, encoded, column-oriented copies of data tailored to query patterns — not from B-tree indices. MySQL (InnoDB) has no direct equivalent. Do not try to "fix" this gap; it's the architectural difference the whole exercise is meant to illustrate.

### 5.3 Indices you DO need to add in MySQL

To keep the comparison fair (columnar vs row-store, not tuned vs untuned), add standard indices on:
- Primary keys on each dimension table (`*_key` columns)
- Foreign keys on fact tables (e.g., `product_key`, `customer_key`, `date_key`, `store_key` on `store_sales_fact`)
- Any column used in `WHERE`/`JOIN`/`GROUP BY` in your test query set

Example:
```sql
CREATE TABLE store_sales_fact (
  date_key INT,
  product_key INT,
  customer_key INT,
  store_key INT,
  sales_quantity INT,
  sales_dollar_amount DECIMAL(10,2),
  cost_dollar_amount DECIMAL(10,2),
  PRIMARY KEY (date_key, product_key, customer_key, store_key),
  INDEX idx_product (product_key),
  INDEX idx_customer (customer_key),
  INDEX idx_store (store_key),
  INDEX idx_date (date_key)
);
```

### 5.4 Views

VMart views (if used) translate directly — both engines support standard `CREATE VIEW ... AS SELECT ...` syntax.

---

## 6. Load Data into MySQL

Copy CSVs into the MySQL container (or a shared bind mount):
```bash
docker cp ./exports/store_sales_fact.csv mysql-vmart:/tmp/
```

Load with `LOAD DATA INFILE` (much faster than row-by-row `INSERT`):
```sql
SET FOREIGN_KEY_CHECKS=0;

LOAD DATA INFILE '/tmp/store_sales_fact.csv'
INTO TABLE store_sales_fact
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

SET FOREIGN_KEY_CHECKS=1;
```

Things to double check before/after loading:
- **Encoding**: set the MySQL connection/table charset to `utf8mb4` to avoid mismatches with Vertica's export encoding.
- **Date/timestamp format**: Vertica's default export format may not match MySQL's expected `YYYY-MM-DD HH:MM:SS` — reformat during export (Section 4) or during load with a `SET` clause in `LOAD DATA INFILE`.
- **NULL handling**: make sure empty strings from the Vertica export map to `NULL` in MySQL where appropriate (`NULL ''` in the Vertica `COPY` command, per Section 4.2, helps here).
- **Row counts**: `SELECT COUNT(*)` on both sides after loading — they must match exactly before you trust any query comparison.

---

## 7. Query Set for Comparison

Use identical SQL (adjusting only engine-specific syntax where unavoidable) across both databases. A good spread for a training demo:

**Q1 — Simple aggregation (tests full-column scan)**
```sql
SELECT SUM(sales_dollar_amount) FROM store_sales_fact;
```

**Q2 — Aggregation with GROUP BY (tests columnar projection advantage)**
```sql
SELECT product_key, SUM(sales_dollar_amount) AS total_sales
FROM store_sales_fact
GROUP BY product_key
ORDER BY total_sales DESC
LIMIT 10;
```

**Q3 — Star-schema join with filter (tests join + dimension filtering)**
```sql
SELECT d.calendar_year, SUM(f.sales_dollar_amount) AS total_sales
FROM store_sales_fact f
JOIN date_dimension d ON f.date_key = d.date_key
WHERE d.calendar_year = 2023
GROUP BY d.calendar_year;
```

**Q4 — Multi-table star join (tests wider join fan-out)**
```sql
SELECT p.category_description, c.customer_state, SUM(f.sales_dollar_amount) AS total_sales
FROM store_sales_fact f
JOIN product_dimension p ON f.product_key = p.product_key
JOIN customer_dimension c ON f.customer_key = c.customer_key
GROUP BY p.category_description, c.customer_state
ORDER BY total_sales DESC
LIMIT 20;
```

**Q5 — Point lookup (tests where MySQL should do well or match)**
```sql
SELECT * FROM customer_dimension WHERE customer_key = 12345;
```

**Q6 — Narrow column scan on a wide table (highlights columnar advantage)**
```sql
SELECT AVG(sales_quantity) FROM store_sales_fact;
```

---

## 8. Running and Measuring

For each query, on each engine:

1. Run `EXPLAIN` (or Vertica's `EXPLAIN` / `PROFILE`) first and capture the plan.
2. Run the query 3 times:
   - 1st run = cold cache
   - 2nd and 3rd = warm cache (discard 1st, average 2nd/3rd)
3. Record wall-clock time. In MySQL:
   ```sql
   SET profiling = 1;
   -- run query
   SHOW PROFILES;
   ```
   In Vertica:
   ```sql
   \timing
   -- run query
   ```
4. Log results in a simple table (query, engine, cold time, warm avg time, rows scanned/returned).

### Suggested results table for the class

| Query | Vertica (cold) | Vertica (warm) | MySQL (cold) | MySQL (warm) | Notes |
|---|---|---|---|---|---|
| Q1 |  |  |  |  |  |
| Q2 |  |  |  |  |  |
| Q3 |  |  |  |  |  |
| Q4 |  |  |  |  |  |
| Q5 |  |  |  |  |  |
| Q6 |  |  |  |  |  |

---

## 9. Interpreting the Results

Expect (and explain *why*):

- **Q1, Q2, Q6** (aggregation, narrow scans): Vertica should win clearly — it only reads the columns needed, with compression and encoding reducing I/O. MySQL/InnoDB reads full rows even when only one column is needed.
- **Q3, Q4** (star-schema joins): Vertica's advantage should still show, but less dramatically if MySQL's indices are well-chosen. This is a good moment to show `EXPLAIN` side-by-side and point out index usage vs projection usage.
- **Q5** (point lookup by primary key): MySQL should be competitive, sometimes faster — this is exactly the workload InnoDB's B-tree indices are built for. Use this to make the point explicit: **the "right" database depends on the workload**, not a universal winner.

Close the demo by discussing:
- Why Vertica is the wrong choice for high-frequency single-row transactional writes (MPP/columnar engines batch-load and re-encode; frequent small writes fragment projections).
- Why MySQL would struggle at large-scale ad hoc analytics without heavy indexing/denormalization workarounds.

---

## 10. Common Pitfalls to Flag in Class

- Comparing an untuned MySQL against a well-loaded Vertica — always add the obvious indices before timing, or the comparison teaches the wrong lesson.
- Forgetting to verify row counts match after load — a silent partial load will make one engine look artificially fast.
- Timing only cold-cache runs — caching effects can dominate small datasets and mislead students about real-world behavior.
- Using too small a dataset — differences may not show up meaningfully below a few hundred thousand rows in the fact table; use closer to the full VMart fact tables if time allows.

---

## 11. Suggested Session Flow (for Adaps-style delivery)

1. **(15 min)** Explain columnar vs row-store conceptually, with a diagram.
2. **(20 min)** Export VMart tables from Vertica (live, or pre-exported CSVs handed out to save time).
3. **(30 min)** Walk through MySQL schema creation, discussing the type/index mapping decisions.
4. **(20 min)** Load data, verify row counts.
5. **(40 min)** Run the 6 queries on both engines, filling in the results table live in DBeaver.
6. **(15 min)** Discuss results, `EXPLAIN` plans, and the "right tool for the job" takeaway.

Total: ~2.5 hours — fits as a single module within a larger Vertica or database-architecture day.
