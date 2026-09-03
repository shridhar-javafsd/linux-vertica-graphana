# Vertica: Best Practices vs. Workarounds (a.k.a. Pro-Tips vs. Jugaad) 🛠️

A no-cap comparison of the "do it right" way vs. the "it works on my laptop" way, for common Vertica scenarios. Domain: our usual EMS crew — Sonu, Monu, Tonu, Ponu, Gonu.

---

## 1. Case-Insensitive Matching

| | Approach | Why |
|---|---|---|
| ✅ Pro-tip | Normalize casing at load time (store data pre-uppercased, or maintain a shadow column) | Keeps plain `=` predicates sargable — sort order / projection pruning still works |
| ⚠️ Workaround | `SET LOCALE TO LEN_S1` (case-insensitive locale) | Works, but Vertica's own docs flag a real perf hit — comparisons stop being simple binary compares |
| 🩹 Jugaad | `UPPER()` / `LOWER()` / `ILIKE` wrapped around every query | Quick fix, but defeats sort-order pruning on that predicate at scale |

```sql
-- Jugaad: wrap function around the column every single time
SELECT count(*) FROM employees WHERE UPPER(name) = UPPER('Sonu');
SELECT count(*) FROM employees WHERE name ILIKE 'sonu';

-- Workaround: session-level case-insensitive locale (has a documented perf cost)
SET LOCALE TO LEN_S1;
SELECT count(*) FROM employees WHERE name = 'SONU';

-- Pro-tip: normalize once at load, query stays clean and index/sort-friendly
ALTER TABLE employees ADD COLUMN name_norm VARCHAR(50) DEFAULT UPPER(name);
SELECT count(*) FROM employees WHERE name_norm = UPPER('Sonu');
```

---

## 2. Bulk Loading Data

| | Approach |
|---|---|
| ✅ Pro-tip | `COPY ... DIRECT` for large batch loads |
| 🩹 Jugaad | Row-by-row `INSERT` in a loop |

```sql
-- Pro-tip: single bulk load straight to disk (ROS), properly sorted/encoded
COPY employees (id, name, dept, doj)
FROM '/data/employees_bulk.csv'
DELIMITER ','
DIRECT;

-- Jugaad: death by a thousand inserts — each one is its own tiny load event
INSERT INTO employees VALUES (101, 'Monu', 'HR', '2024-01-05');
INSERT INTO employees VALUES (102, 'Tonu', 'IT', '2024-01-06');
-- ...repeat 50,000 times -> ROS container explosion, constant mergeout
```

---

## 3. Updates & Deletes

| | Approach |
|---|---|
| ✅ Pro-tip | Batch updates; use `MERGE` for upserts |
| 🩹 Jugaad | Thousands of single-row `UPDATE`/`DELETE` statements |

```sql
-- Pro-tip: one batched MERGE (upsert) instead of many single-row updates
MERGE INTO employees tgt
USING staging_employees src
ON tgt.id = src.id
WHEN MATCHED THEN UPDATE SET dept = src.dept
WHEN NOT MATCHED THEN INSERT (id, name, dept, doj)
  VALUES (src.id, src.name, src.dept, src.doj);

-- Jugaad: one row at a time — remember, Vertica UPDATE = delete-marker + new insert
UPDATE employees SET dept = 'IT' WHERE id = 101;
UPDATE employees SET dept = 'HR' WHERE id = 102;
-- ...repeat per row -> storage bloat, needs purge to reclaim space
```

---

## 4. Projections

| | Approach |
|---|---|
| ✅ Pro-tip | Let Database Designer (`DBD`) recommend projections from a real query workload |
| 🩹 Jugaad | Hand-roll a new projection every time a query feels slow |

```sql
-- Pro-tip: run DBD against representative queries, deploy its recommendation
SELECT DESIGNER_DESIGN_PROJECTION_ENCODINGS('ems_design', 'public.employees');
-- (DBD workflow: create design -> add tables -> add query set -> run design -> deploy)

-- Jugaad: one-off manual projection per painful query, no workload analysis
CREATE PROJECTION employees_by_dept_adhoc
AS SELECT id, name, dept FROM employees ORDER BY dept
SEGMENTED BY HASH(id) ALL NODES;
-- multiply this by 15 more "quick fixes" -> projection sprawl, slower loads
```

---

## 5. Partition Pruning / Purging Old Data

| | Approach |
|---|---|
| ✅ Pro-tip | `PARTITION BY` date, then `DROP PARTITION` |
| 🩹 Jugaad | `DELETE ... WHERE date < X` |

```sql
-- Table partitioned by joining year, so old cohorts can be dropped cheaply
CREATE TABLE employees (
  id INT,
  name VARCHAR(50),
  dept VARCHAR(30),
  doj DATE
) PARTITION BY EXTRACT(YEAR FROM doj);

-- Pro-tip: metadata-only, near-instant removal
SELECT DROP_PARTITION('employees', 2019);

-- Jugaad: row-level delete — leaves delete vectors, needs a purge afterwards
DELETE FROM employees WHERE doj < '2020-01-01';
SELECT PURGE_TABLE('employees'); -- extra step you now have to remember
```

---

## 6. Joins on Large Fact/Dimension Tables

| | Approach |
|---|---|
| ✅ Pro-tip | Segment fact & dimension on the join key so joins are co-located |
| 🩹 Jugaad | Ignore segmentation, let Vertica broadcast/resegment every query |

```sql
-- Pro-tip: both tables segmented on employee_id -> local join, no network shuffle
CREATE TABLE employees (id INT, name VARCHAR(50), dept_id INT)
SEGMENTED BY HASH(id) ALL NODES;

CREATE TABLE attendance (employee_id INT, work_date DATE, status VARCHAR(10))
SEGMENTED BY HASH(employee_id) ALL NODES;

SELECT e.name, a.status
FROM employees e JOIN attendance a ON e.id = a.employee_id
WHERE a.work_date = '2026-09-01';

-- Jugaad: default/unsegmented tables -> Vertica resegments or broadcasts at
-- query time, every time, especially painful as attendance grows
```

---

## 7. Diagnosing Slow Queries

| | Approach |
|---|---|
| ✅ Pro-tip | `EXPLAIN` / `PROFILE` + system tables |
| 🩹 Jugaad | Trial-and-error index/rewrite guessing |

```sql
-- Pro-tip: see the actual plan and projection usage before touching anything
EXPLAIN
SELECT dept, count(*) FROM employees GROUP BY dept;

-- Or run it live and inspect engine-level timing after
PROFILE SELECT dept, count(*) FROM employees GROUP BY dept;
SELECT * FROM query_profiles ORDER BY query_start_time DESC LIMIT 1;

-- Jugaad: "let me just add ILIKE / an ORDER BY / a random new projection and
-- see if it's faster" -- no plan inspection, pure guesswork
```

---

## 8. Statistics Maintenance

| | Approach |
|---|---|
| ✅ Pro-tip | `ANALYZE_STATISTICS` after significant loads |
| 🩹 Jugaad | Never refresh stats, let the optimizer work off stale data |

```sql
-- Pro-tip: refresh stats so the optimizer's row-count/cardinality estimates
-- reflect reality after a big load
SELECT ANALYZE_STATISTICS('public.employees');

-- Jugaad: load millions of new rows, run queries for months, never re-analyze
-- -> optimizer keeps picking join orders/projections based on old estimates
```

---

### TL;DR for the batch
Most "jugaad" fixes aren't wrong per se — they solve the immediate query. The pattern across all eight: **jugaad fixes it at query time (repeated, cumulative cost); pro-tip fixes it upstream, once (load/design time), and every query benefits after.**
