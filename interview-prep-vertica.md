# Interview Prep — Vertica

*For client interviews after this training. Mix of fresher-friendly basics and deeper architecture questions experienced folks should expect. Answers are kept short and interview-ready.*

---

### 1. What is Vertica, in one line? *(Fresher)*
A columnar, MPP (Massively Parallel Processing) analytical database, built for fast querying over very large datasets — used for data warehousing and analytics, not transactional (OLTP) workloads.

### 2. What's the difference between a row store and a columnar store? *(Fresher — very commonly asked)*
A row store (like MySQL/Postgres by default) stores each row's data together — efficient for reading/writing whole records. A columnar store (Vertica) stores each *column's* data together — efficient when a query only needs a few columns out of many, and great for aggregations (`SUM`, `AVG`) since it reads only the relevant columns, not entire rows.
> 🎯 **Gotcha follow-up:** "So is Vertica always faster than a row store?" → No — for OLTP-style workloads (fetch/update single rows, e.g., "get this one customer's order"), row stores are usually faster. Vertica shines specifically for analytical, aggregate-heavy queries over large data.

### 3. What is MPP, and why does it matter? *(Fresher/Experienced)*
Massively Parallel Processing — the database runs across multiple nodes, each handling a slice of the data, working in parallel rather than one machine doing everything sequentially. This is what lets Vertica scale to very large datasets by adding more nodes rather than needing one bigger machine.

### 4. What is a projection in Vertica? *(Experienced — Vertica-specific, likely to come up)*
Vertica's core physical storage structure — a specific arrangement of columns, sorted and encoded a particular way, optimized for a certain query pattern. Every table needs at least one projection to actually store data; Vertica can auto-create a default one, but custom projections (sorted/segmented for your actual query patterns) are where real performance gains come from.

### 5. Why would you create a custom projection instead of relying on the default one? *(Experienced)*
The default (superprojection) is a reasonable general-purpose choice, but if your real queries always filter/sort by a specific column (e.g., always by date), a projection sorted on that column lets Vertica skip scanning irrelevant data entirely — often a large speed gain for that specific query pattern.

### 6. What does "segmentation" mean in Vertica? *(Experienced)*
How data is distributed (sharded) across the nodes in a cluster — Vertica hashes rows across nodes based on a segmentation clause so parallel nodes can each work on their own slice during a query.

### 7. What's K-safety? *(Experienced)*
Vertica's fault-tolerance setting — how many node failures the cluster can survive without losing data or availability, achieved by storing redundant copies (buddy projections) across nodes. K-safety of 1 means the cluster survives one node going down.

### 8. What's the difference between `COPY` and a regular `INSERT` in Vertica? *(Fresher/Experienced)*
`COPY` is Vertica's bulk-loading command — built for loading large volumes of data efficiently from a file (CSV, etc.), often bypassing much of the per-row overhead a series of individual `INSERT`s would carry. For anything beyond a handful of rows, `COPY` is the right tool.

### 9. What are `EXPLAIN` and `PROFILE` used for? *(Experienced)*
`EXPLAIN` shows the query's execution *plan* — how Vertica intends to run it — without actually running it. `PROFILE` actually runs the query and shows real execution stats (time spent per step, rows processed) — the go-to tool for diagnosing why a specific query is slow.

### 10. What is ROS vs. WOS in Vertica? *(Experienced — a favorite "do you actually know Vertica" question)*
WOS (Write Optimized Store) is an in-memory buffer for newly-inserted data, optimized for fast writes. ROS (Read Optimized Store) is the actual on-disk, sorted/encoded columnar storage, optimized for fast reads. Data moves from WOS to ROS via a background process called the **Tuple Mover** (moveout).

### 11. What is `vsql`? *(Fresher)*
Vertica's command-line SQL client — the Vertica-flavored equivalent of `psql` for Postgres or `mysql` for MySQL.

### 12. How do you check a table's structure from `vsql`? *(Fresher)*
`\d schema.table_name` — describes columns, types, and constraints.

### 13. What's a resource pool in Vertica? *(Experienced)*
A mechanism to control how much memory/CPU/concurrency a group of queries or users is allowed to consume — used to prevent one heavy analytical query from starving the rest of the cluster.

### 14. Why is Vertica described as "share-nothing"? *(Experienced)*
Each node in the cluster has its own local storage and compute — nodes don't share disks the way some other clustered databases do. This avoids a shared-storage bottleneck and is a big part of why MPP scaling works cleanly.

### 15. What's the difference between Vertica and a data lake (e.g., raw files in S3 queried via Spark)? *(Experienced)*
Vertica stores data in its own optimized, indexed, encoded columnar format — much faster for repeated analytical queries, but requires loading/transforming data in. A data lake stores raw files (Parquet, CSV, etc.) queried on-demand by an engine like Spark — more flexible and cheaper for storage, but generally slower per-query since there's less pre-optimization.

### 16. What is VMart? *(Fresher — specific to this course)*
Vertica's official sample dataset — a retail/sales dataset (store sales, online sales, products, customers, dates) used for demos and training, similar in spirit to Oracle's or SQL Server's sample databases.

### 17. What does "columnar encoding" mean, and why does it help? *(Experienced)*
Vertica can compress each column using an encoding scheme suited to that column's actual data pattern (e.g., run-length encoding for a column with lots of repeated values, like a status flag). Because similar values are stored together in a columnar layout, compression ratios are often much better than row-based storage — less disk I/O, faster scans.

### 18. What's a join, and what types does Vertica support? *(Fresher)*
Combining rows from two or more tables based on a related column. Standard SQL join types apply: `INNER JOIN`, `LEFT/RIGHT OUTER JOIN`, `FULL OUTER JOIN`, `CROSS JOIN` — same syntax as most SQL databases.

### 19. What's a window function, and can you give an example? *(Experienced)*
A calculation across a set of rows related to the current row, without collapsing them into a single output row (unlike `GROUP BY`). Example: `RANK() OVER (PARTITION BY category ORDER BY sales DESC)` — ranks products within each category by sales, while still showing every row.

### 20. Why might a query be slow in Vertica even though the table is properly projected? *(Experienced)*
Common culprits: `SELECT *` pulling unneeded columns, a `WHERE` clause on a column the projection isn't sorted by (forcing a full scan), an unindexed join key causing a large hash join, or stale statistics leading the optimizer to pick a bad plan. `PROFILE` is the tool to actually find out which.

### 21. What is Vertica Community Edition (CE), and what are its limitations? *(Fresher/Experienced — relevant since that's what's used in this course)*
The free version of Vertica — full feature set, but capped at a small number of nodes and a data size limit (historically 3 nodes / 1TB, worth double-checking current limits), meant for evaluation, learning, and small deployments rather than production-scale use.

### 22. What's the difference between OLTP and OLAP, and where does Vertica sit? *(Fresher)*
OLTP (Online Transaction Processing) — many small, fast read/write operations (e.g., a banking app processing transactions). OLAP (Online Analytical Processing) — fewer, heavier, aggregate-style queries over large historical datasets (e.g., "total sales by region last quarter"). Vertica is built specifically for OLAP.

### 23. What is a "flattened table" or denormalization, and why does it matter for analytical databases? *(Experienced)*
Combining data that would normally be split across multiple normalized tables into fewer, wider tables — trading some redundancy for far fewer expensive joins at query time. Analytical workloads often favor this, since read speed matters more than write efficiency or storage normalization purity.

### 24. How would you load a large CSV file into Vertica efficiently? *(Fresher/Experienced)*
`COPY table_name FROM '/path/to/file.csv' DELIMITER ',' ERROR TOLERANCE(handles malformed rows) DIRECT;` — `DIRECT` loads straight to ROS, skipping the WOS buffer, which is typically preferred for large one-time bulk loads.

### 25. What happens to malformed rows during a `COPY` load, by default? *(Experienced)*
Without special handling, a bad row can abort the whole load. Vertica supports `REJECTED DATA` and `EXCEPTIONS` clauses to redirect malformed rows to a separate file instead of failing the entire load — letting good rows load successfully while you inspect the rejects separately.

### 26. What's a materialized view, conceptually, and does Vertica have an equivalent? *(Experienced)*
A materialized view is a precomputed, stored query result that's refreshed rather than recalculated every time. Vertica's projections serve a similar performance purpose (precomputed, optimized physical layout) but are a lower-level, storage-oriented concept rather than a saved query result in the traditional materialized-view sense.

### 27. Why would a company choose Vertica over, say, Snowflake or Redshift? *(Experienced — likely from a client evaluating skills)*
It depends on context (this is a fair, "no single right answer" question) — Vertica offers strong on-prem/hybrid deployment flexibility and has historically had a reputation for raw query performance at scale, while Snowflake/Redshift lean more heavily into fully-managed cloud-native operation with less infrastructure management. The honest answer in an interview is to name the trade-off, not claim one is unconditionally better.

---

## 🎯 A few extra gotcha-style follow-ups to be ready for

- **"If columnar storage is so great, why doesn't everyone just always use it?"** → It's worse for OLTP-style single-row lookups/updates, since fetching one full row means touching many separate column stores instead of one contiguous block.
- **"Your `COPY` load is taking forever — what would you check first?"** → Whether it's going through WOS (slower, memory-buffered) instead of `DIRECT`; whether there are too many small files instead of one large one; and whether target projections are unnecessarily numerous, since each load writes to every projection.
- **"A query that used to be fast is suddenly slow — what changed?"** → Data volume grew significantly since the projection was designed, statistics are stale, or the query pattern shifted to filter on a column the projection isn't optimized for.
- **"What's the actual risk of running Vertica Community Edition in production?"** → It's node/size-capped and not intended for production SLAs — a client asking this is testing whether you understand CE is a training/eval tool, not a production deployment choice.
