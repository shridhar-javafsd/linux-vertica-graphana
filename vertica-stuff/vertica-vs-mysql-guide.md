# Vertica vs MySQL Performance Comparison — End-to-End Guide
### Using the VMart Sample Dataset

This guide walks through exporting VMart data from Vertica, recreating the schema in MySQL, loading the data, and running identical queries on both engines to compare and explain performance differences (columnar/MPP vs row-store OLTP).

**Your actual setup:**
- **Vertica CE** — running in Docker Desktop (`molo17/vertica-ce:24.1.0-0`), WSL2 backend, reachable at `localhost:5433` from Windows. VMart schema and data are already loaded.
- **MySQL 8.0 Community Server** — installed natively on Windows 11, reachable at `localhost:3306`.
- **DBeaver Community Edition** — one client, two connections (Vertica + MySQL), both via `localhost`.

Because Vertica is in Docker (WSL2 under the hood) and MySQL is native Windows, there's one extra step versus a same-host setup: getting exported CSV files from inside the Docker container onto your Windows filesystem where native MySQL can read them. This guide calls that out explicitly wherever it matters — follow it in order and you won't hit surprises.

---

## 1. Goals of This Exercise

- Show that Vertica (columnar, MPP-style engine) and MySQL (row-store, OLTP-oriented engine) are optimized for different workloads.
- Quantify the difference on realistic analytical queries (aggregations, star-schema joins, wide-table scans).
- Read `EXPLAIN` plans on both engines and explain *why* the numbers differ, not just *that* they differ.
- Be honest about where MySQL wins too (point lookups, single-row OLTP) — the point is workload-fit, not "Vertica is always faster."

---

## 2. Environment Check (do this first)

### 2.1 Confirm Vertica + VMart is up

In DBeaver (or `vsql` inside the container), run:
```sql
SELECT COUNT(*) FROM store.store_sales_fact;
SELECT COUNT(*) FROM online_sales.online_sales_fact;
SELECT COUNT(*) FROM public.product_dimension;
SELECT COUNT(*) FROM public.customer_dimension;
SELECT COUNT(*) FROM public.date_dimension;
```
All five should return non-zero counts. If any of these table/schema names don't match what you see in DBeaver's navigator tree, adjust the schema prefixes (`store.`, `online_sales.`, `public.`) throughout this guide to match your actual install — VMart's schema names occasionally differ slightly by version.

### 2.2 Confirm MySQL 8.0 is up

Open a Windows Command Prompt or PowerShell:
```
mysql -u root -p
```
Then:
```sql
CREATE DATABASE IF NOT EXISTS vmart;
USE vmart;
```

### 2.3 Find your Windows working folder

Pick one folder on Windows to hold everything for this exercise, e.g.:
```
C:\vmart-comparison\
```
Create two subfolders inside it: `exports\` (CSV files coming out of Vertica) and `ddl\` (schema files). You'll reference `C:\vmart-comparison\exports\` repeatedly below.

### 2.4 Check MySQL's `secure_file_priv` setting (MySQL 8.0 specific — do this now, not later)

MySQL 8.0 on Windows restricts where `LOAD DATA INFILE` can read files from, by default. Check it before you get to the loading step:
```sql
SHOW VARIABLES LIKE 'secure_file_priv';
```

You'll see one of three results:
- **A folder path** (e.g. `C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\`) — you must put your CSV files in *this exact folder*, not `C:\vmart-comparison\exports\`. Copy files here instead, or change your export step to write directly here.
- **Empty string** — no restriction, any folder works, including `C:\vmart-comparison\exports\`.
- **NULL** — file loading is disabled entirely on this server. In that case skip `LOAD DATA INFILE` and use the MySQL Workbench "Table Data Import Wizard" instead (Section 6.3 covers this fallback).

If it's a fixed folder, write it down now — every trainee's laptop may have this set to a different path depending on how MySQL was installed, so this is a per-machine check, not something to assume from this guide.

---

## 3. Get the Real VMart DDL from Vertica (don't hand-type it)

Rather than guessing column names and types, pull the actual DDL straight from your live Vertica instance. This guarantees it matches what's really installed.

Run this in DBeaver against Vertica (adjust the table list to the ones you're using — see Section 4):
```sql
SELECT EXPORT_OBJECTS('', 'store.store_sales_fact,public.product_dimension,public.customer_dimension,public.date_dimension,store.store_dimension');
```

This returns the full `CREATE TABLE` statements as text. Copy the output into a file at `C:\vmart-comparison\ddl\vertica_ddl.sql` — you'll use it as the reference when writing the MySQL `CREATE TABLE` statements in Section 5.

If your VMart installation guide already has the original `.sql` schema-definition scripts (commonly named something like `vmart_define_schema.sql`), those work too and save you this step — but `EXPORT_OBJECTS` is the safer source since it reflects the schema as it actually exists right now, not as originally scripted.

---

## 4. Choose Your Tables

Use these five VMart tables for the exercise — enough for meaningful star-schema joins without turning setup into a multi-day project:

| Table | Type | Role |
|---|---|---|
| `store.store_sales_fact` | Fact | Large fact table, store sales transactions |
| `store.store_dimension` | Dimension | Store attributes |
| `public.product_dimension` | Dimension | Product attributes |
| `public.customer_dimension` | Dimension | Customer attributes |
| `public.date_dimension` | Dimension | Calendar/date attributes |

If your Vertica install uses different schema prefixes for these (check DBeaver's navigator tree), substitute your actual names everywhere below.

---

## 5. Export Data from Vertica → Windows Filesystem

### 5.1 Export each table to CSV, inside the container

Run in DBeaver (connected to Vertica) or via `vsql`:
```sql
COPY store.store_sales_fact TO '/tmp/store_sales_fact.csv'
  WITH DELIMITER ',' ENCLOSED BY '"' NULL '';

COPY store.store_dimension TO '/tmp/store_dimension.csv'
  WITH DELIMITER ',' ENCLOSED BY '"' NULL '';

COPY public.product_dimension TO '/tmp/product_dimension.csv'
  WITH DELIMITER ',' ENCLOSED BY '"' NULL '';

COPY public.customer_dimension TO '/tmp/customer_dimension.csv'
  WITH DELIMITER ',' ENCLOSED BY '"' NULL '';

COPY public.date_dimension TO '/tmp/date_dimension.csv'
  WITH DELIMITER ',' ENCLOSED BY '"' NULL '';
```

This writes the CSVs *inside the Docker container's* filesystem — not yet visible from Windows.

### 5.2 Get the files out to Windows (the one non-obvious step)

Open a Windows Command Prompt / PowerShell / WSL2 shell (any of these can run `docker` commands against Docker Desktop):

```bash
docker cp <vertica-container-name>:/tmp/store_sales_fact.csv C:\vmart-comparison\exports\
docker cp <vertica-container-name>:/tmp/store_dimension.csv C:\vmart-comparison\exports\
docker cp <vertica-container-name>:/tmp/product_dimension.csv C:\vmart-comparison\exports\
docker cp <vertica-container-name>:/tmp/customer_dimension.csv C:\vmart-comparison\exports\
docker cp <vertica-container-name>:/tmp/date_dimension.csv C:\vmart-comparison\exports\
```

Replace `<vertica-container-name>` with your actual container name — find it with:
```bash
docker ps
```

**If you determined in Section 2.4 that MySQL requires files in a specific `secure_file_priv` folder**, `docker cp` your files directly to that folder instead of `C:\vmart-comparison\exports\`, or copy them there as an extra step before loading.

### 5.3 Sanity-check the exports

Open each CSV in a text editor or Excel and confirm:
- Row count roughly matches what you saw in Section 2.1's `COUNT(*)` queries (open in Excel and check the row number, or count lines).
- No obviously broken rows (unescaped commas splitting a field, garbled characters).
- Date columns look like a format you recognize (e.g. `2023-06-15`).

---

## 6. Create the Schema in MySQL

### 6.1 Data type mapping (Vertica → MySQL 8.0)

| Vertica type | MySQL 8.0 equivalent | Notes |
|---|---|---|
| `INTEGER` / `INT` | `INT` | Direct |
| `NUMERIC(p,s)` | `DECIMAL(p,s)` | Direct |
| `FLOAT` | `DOUBLE` | Vertica FLOAT is 8-byte |
| `VARCHAR(n)` | `VARCHAR(n)` | Check byte vs char length semantics |
| `CHAR(n)` | `CHAR(n)` | Direct |
| `DATE` | `DATE` | Direct |
| `TIMESTAMP` | `DATETIME` | MySQL's native `TIMESTAMP` type has a narrow 1970–2038 range; use `DATETIME` instead |
| `BOOLEAN` | `TINYINT(1)` | MySQL has no native boolean type |

Go through the DDL you pulled in Section 3 column by column using this table — don't skip columns, since a mismatched type will either fail the load or silently truncate data.

### 6.2 No columnar equivalent — and that's the point

Vertica's speed comes from **projections**: physically sorted, encoded, column-oriented copies of data tailored to query patterns — not from B-tree indices. MySQL (InnoDB) has no direct equivalent. Don't try to "fix" this gap; it's the architectural difference this whole exercise exists to show.

### 6.3 Indices to add in MySQL (needed for a fair comparison)

Without these, you're comparing "columnar vs untuned row-store," which isn't an honest test. Add indices on every foreign key and every column your Section 8 queries filter, join, or group by:

```sql
USE vmart;

CREATE TABLE date_dimension (
  date_key INT PRIMARY KEY,
  calendar_year INT,
  calendar_month INT,
  full_date DATE
);

CREATE TABLE product_dimension (
  product_key INT PRIMARY KEY,
  product_description VARCHAR(128),
  category_description VARCHAR(64)
);

CREATE TABLE customer_dimension (
  customer_key INT PRIMARY KEY,
  customer_name VARCHAR(128),
  customer_state VARCHAR(32)
);

CREATE TABLE store_dimension (
  store_key INT PRIMARY KEY,
  store_name VARCHAR(128),
  store_city VARCHAR(64)
);

CREATE TABLE store_sales_fact (
  date_key INT,
  product_key INT,
  customer_key INT,
  store_key INT,
  sales_quantity INT,
  sales_dollar_amount DECIMAL(10,2),
  cost_dollar_amount DECIMAL(10,2),
  INDEX idx_date (date_key),
  INDEX idx_product (product_key),
  INDEX idx_customer (customer_key),
  INDEX idx_store (store_key)
);
```

**Adjust column names/types to match what you actually pulled in Section 3** — this is a template, not a guaranteed match to your exact VMart version. If your real DDL has additional columns you want to compare on (e.g. `discount_amount`, `employee_key`), add them the same way.

### 6.4 Views

If your VMart install uses any views, they translate directly — both engines support standard `CREATE VIEW ... AS SELECT ...` syntax.

---

## 7. Load Data into MySQL

### 7.1 Loading with `LOAD DATA INFILE`

Use the folder path you confirmed in Section 2.4. Example assuming no `secure_file_priv` restriction:

```sql
SET FOREIGN_KEY_CHECKS=0;

LOAD DATA INFILE 'C:/vmart-comparison/exports/date_dimension.csv'
INTO TABLE date_dimension
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA INFILE 'C:/vmart-comparison/exports/product_dimension.csv'
INTO TABLE product_dimension
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA INFILE 'C:/vmart-comparison/exports/customer_dimension.csv'
INTO TABLE customer_dimension
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA INFILE 'C:/vmart-comparison/exports/store_dimension.csv'
INTO TABLE store_dimension
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA INFILE 'C:/vmart-comparison/exports/store_sales_fact.csv'
INTO TABLE store_sales_fact
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

SET FOREIGN_KEY_CHECKS=1;
```

Notes:
- Use forward slashes in the path even on Windows (`C:/...` not `C:\...`) — MySQL's SQL parser expects this.
- If MySQL's `secure_file_priv` pointed to a specific folder, use that folder's path here instead of `C:/vmart-comparison/exports/`.
- `IGNORE 1 LINES` skips a header row — remove it if your Vertica export had no header.

### 7.2 If you get an error about `--secure-file-priv` or "command denied"

This means the file isn't in the folder MySQL is allowed to read from (Section 2.4). Move the CSV there and retry, rather than trying to change the setting — changing `secure_file_priv` requires editing `my.ini` and restarting the MySQL service, which isn't worth it for a training exercise.

### 7.3 Fallback: MySQL Workbench Import Wizard (if `LOAD DATA INFILE` is fully disabled)

If Section 2.4 showed `NULL`, use Workbench instead:
1. Open MySQL Workbench, connect to your local server.
2. Right-click the `vmart` schema → **Table Data Import Wizard**.
3. Point it at each CSV, map columns to your already-created table, and run the import.

This is slower than `LOAD DATA INFILE` for large tables but works with no server-side reconfiguration.

### 7.4 Verify the load

```sql
SELECT COUNT(*) FROM store_sales_fact;
SELECT COUNT(*) FROM product_dimension;
SELECT COUNT(*) FROM customer_dimension;
SELECT COUNT(*) FROM store_dimension;
SELECT COUNT(*) FROM date_dimension;
```
Compare each count against the Vertica counts from Section 2.1. **They must match exactly** before trusting any timing comparison — a partial load will make MySQL look artificially fast.

---

## 8. Query Set for Comparison

Run identical SQL on both engines (adjust table/column names only if yours differ from Section 6.3).

**Q1 — Simple aggregation (full-column scan)**
```sql
SELECT SUM(sales_dollar_amount) FROM store_sales_fact;
```

**Q2 — Aggregation with GROUP BY (columnar projection advantage)**
```sql
SELECT product_key, SUM(sales_dollar_amount) AS total_sales
FROM store_sales_fact
GROUP BY product_key
ORDER BY total_sales DESC
LIMIT 10;
```

**Q3 — Star-schema join with filter**
```sql
SELECT d.calendar_year, SUM(f.sales_dollar_amount) AS total_sales
FROM store_sales_fact f
JOIN date_dimension d ON f.date_key = d.date_key
WHERE d.calendar_year = 2023
GROUP BY d.calendar_year;
```

**Q4 — Multi-table star join (wider fan-out)**
```sql
SELECT p.category_description, c.customer_state, SUM(f.sales_dollar_amount) AS total_sales
FROM store_sales_fact f
JOIN product_dimension p ON f.product_key = p.product_key
JOIN customer_dimension c ON f.customer_key = c.customer_key
GROUP BY p.category_description, c.customer_state
ORDER BY total_sales DESC
LIMIT 20;
```

**Q5 — Point lookup (where MySQL should do well)**
```sql
SELECT * FROM customer_dimension WHERE customer_key = 12345;
```
(Pick an actual `customer_key` value that exists in your data — check with `SELECT customer_key FROM customer_dimension LIMIT 1;` first.)

**Q6 — Narrow column scan on a wide table (columnar advantage)**
```sql
SELECT AVG(sales_quantity) FROM store_sales_fact;
```

---

## 9. Running and Measuring

For each query, on each engine:

1. Run `EXPLAIN` first (Vertica: `EXPLAIN` or `PROFILE`; MySQL: `EXPLAIN`) and capture the plan.
2. Run the query 3 times — discard the 1st (cold cache), average the 2nd and 3rd (warm cache).
3. Record timing:
   - **MySQL**: `SET profiling = 1;` before running, then `SHOW PROFILES;` after.
   - **Vertica**: `\timing` in `vsql`, or check the "Duration" shown in DBeaver's result panel.
4. Log results in a table like this:

| Query | Vertica (cold) | Vertica (warm) | MySQL (cold) | MySQL (warm) | Notes |
|---|---|---|---|---|---|
| Q1 |  |  |  |  |  |
| Q2 |  |  |  |  |  |
| Q3 |  |  |  |  |  |
| Q4 |  |  |  |  |  |
| Q5 |  |  |  |  |  |
| Q6 |  |  |  |  |  |

---

## 10. Interpreting the Results

- **Q1, Q2, Q6** (aggregation, narrow scans): Vertica should win clearly — it reads only the needed columns, with compression reducing I/O. MySQL/InnoDB reads full rows even when one column is needed.
- **Q3, Q4** (star-schema joins): Vertica's advantage should still show, but less dramatically with well-chosen MySQL indices in place. Compare `EXPLAIN` plans side-by-side here — index usage (MySQL) vs projection usage (Vertica).
- **Q5** (point lookup by primary key): MySQL should be competitive, sometimes faster — this is exactly what InnoDB's B-tree indices are built for. Use this to make the point explicit: **the right database depends on the workload**, not a universal winner.

---

## 11. Common Pitfalls to Avoid

- Comparing untuned MySQL against a well-loaded Vertica — always add indices (Section 6.3) before timing.
- Skipping the row-count check after loading (Section 7.4) — a silent partial load makes one engine look artificially fast.
- Timing only cold-cache runs — caching effects dominate on smaller datasets and can mislead the comparison.
- Forgetting the `secure_file_priv` check (Section 2.4) — this is the single most common blocker when loading into MySQL 8.0 on Windows.
- Using forward slashes vs backslashes incorrectly in `LOAD DATA INFILE` paths — MySQL wants `C:/...`.

---

## 12. Suggested Session Flow

1. **(10 min)** Confirm environment (Section 2) — do this per-trainee before the session, if possible, to avoid burning class time on setup issues.
2. **(15 min)** Conceptual intro: columnar vs row-store, with a diagram.
3. **(15 min)** Pull real DDL from Vertica (Section 3), discuss type mapping decisions.
4. **(20 min)** Export from Vertica → Windows filesystem (Section 5) — this is the step most likely to trip people up (Docker → host file path), budget extra time here.
5. **(25 min)** Create MySQL schema with indices (Section 6), load data (Section 7), verify row counts.
6. **(40 min)** Run the 6 queries on both engines, filling in the results table live.
7. **(15 min)** Discuss results, `EXPLAIN` plans, and the "right tool for the job" takeaway.

Total: ~2.5 hours — fits as a single module within a larger Vertica or database-architecture day.

---

## 13. Optional: Run MySQL in Docker Too (instead of native Windows)

The main guide uses native Windows MySQL because that's what's already installed. But running MySQL in Docker alongside Vertica is a reasonable alternative — worth knowing about, especially if trainees hit repeated `secure_file_priv` headaches or want an easy way to reset the environment and try again.

### 13.1 Why you might do this

- **No `secure_file_priv` fight** — you control the container's filesystem directly, so file paths for `LOAD DATA INFILE` are predictable and consistent for every trainee.
- **No Docker → Windows file hop** — if both containers can share a Docker volume, you skip the `docker cp ... C:\...` step in Section 5.2 entirely.
- **Easy reset** — `docker rm -f mysql-vmart` and re-run the container to start over with a clean database, no uninstall/reinstall.
- **Consistency across trainee laptops** — removes "what version/config did you install" as a variable, since everyone pulls the same image.

### 13.2 Why you might NOT do this

- **Less fair as a performance comparison** — both databases now compete for the same Docker Desktop resource allocation (CPU/RAM cap you set in Docker's settings), whereas native MySQL gets the full host. If your goal is a clean architectural comparison, having MySQL on native Windows (full host resources) vs Vertica in a resource-capped container is arguably *more* representative of how each engine is normally deployed in production, not less. Keep this trade-off in mind rather than assuming Docker-for-both is automatically the better setup.
- **Extra Docker Desktop resource pressure** — running two database containers at once on a trainee's laptop needs more RAM/CPU headroom than one container + one native install.

### 13.3 Steps, if you go this route

```bash
docker run -d \
  --name mysql-vmart \
  -e MYSQL_ROOT_PASSWORD=vmartpass \
  -e MYSQL_DATABASE=vmart \
  -p 3306:3306 \
  -v vmart-shared-data:/var/lib/mysql-files \
  mysql:8.0
```

Connect from DBeaver the same way as native MySQL: host `localhost`, port `3306`, user `root`, password `vmartpass`, database `vmart`. Nothing in Sections 6, 8, 9, or 10 of this guide changes — schema creation and the query set are identical either way.

**For the file transfer step (replaces Section 5.2):** instead of copying CSVs to a Windows folder, copy them into a Docker volume both containers can reach, or directly into the MySQL container:
```bash
docker cp <vertica-container-name>:/tmp/store_sales_fact.csv mysql-vmart:/var/lib/mysql-files/
docker cp <vertica-container-name>:/tmp/store_dimension.csv mysql-vmart:/var/lib/mysql-files/
docker cp <vertica-container-name>:/tmp/product_dimension.csv mysql-vmart:/var/lib/mysql-files/
docker cp <vertica-container-name>:/tmp/customer_dimension.csv mysql-vmart:/var/lib/mysql-files/
docker cp <vertica-container-name>:/tmp/date_dimension.csv mysql-vmart:/var/lib/mysql-files/
```
Then in Section 7.1's `LOAD DATA INFILE` statements, use `/var/lib/mysql-files/<filename>.csv` as the path instead of `C:/vmart-comparison/exports/...` — MySQL's default Docker image typically whitelists this directory for `secure_file_priv` out of the box, so this usually avoids the permission issue in Section 2.4 altogether. Confirm with `SHOW VARIABLES LIKE 'secure_file_priv';` inside the container the same way as Section 2.4.

**Recommendation:** stick with the native-Windows MySQL path in the main guide as the default for this training batch, since it's already installed and working. Offer this section only to trainees who want to experiment further or hit persistent `secure_file_priv` issues they can't resolve.


--- 

EXPLAIN SELECT c.customer_key, sum(s.sales_dollar_amount) as total_spend 
FROM public.customer_dimension c
JOIN store.store_sales_fact s
ON c.customer_key = s.customer_key
GROUP BY c.customer_key
HAVING  total_spend > avg (s.sales_dollar_amount) limit 10;


create projection cust_spends s.customer_key, s.sales_dollar_amount FROM  store.store_sales_fact s; 



