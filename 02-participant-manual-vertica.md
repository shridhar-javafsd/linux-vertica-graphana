# Participant's Manual — Vertica

*Covers: Days 5–7 (Intro & Install, SQL Fundamentals, Loading & Performance)*
*Companion to: `day05`–`day07` courseware*

---

## 🎯 What this manual is for

The daywise courseware has the **what** — commands, labs, copy-paste blocks. This manual has the **why** and **how underneath it**, so you understand what's actually happening instead of just pattern-matching commands. It's organized by topic, not by day, since a few ideas (projections, `vsql` mechanics) get touched more than once.

Read it once end to end, then come back to the relevant section when you want the deeper explanation behind something you just ran.

> ⚠️ **Read this part first, seriously.** Everything in Days 5–7 runs on `molo17/vertica-ce`, a **community-maintained Docker image** — not an official Rocket Software (Vertica's current owner) distribution. Docker exists in this course *specifically* to make this workaround possible; it's not a general "here's how Vertica is normally deployed" lesson. In a real production environment, Vertica almost always runs very differently — proper multi-node clusters, official installers, paid licensing, dedicated hardware or cloud VMs. Section 2 below goes into exactly what's different and why. Keep that distinction in your head throughout — it'll stop you from walking out of this course thinking "Vertica = a Docker container," which isn't true outside a training lab.

---

## 1. What actually makes Vertica different

*→ Referenced in: `day05-vertica-intro-install.md`, Concepts*

### Columnar storage, properly explained

A row-store database (MySQL, Postgres in typical use) keeps each row's data physically together on disk — great when you want *one whole record* (`give me everything about customer #4521`), because it's one contiguous read. But it's genuinely bad at analytical questions like "what's the average `sales_dollar_amount` across 5 million rows" — the engine still has to read every column of every row, including all the ones you don't care about, just to get at the one you do.

Vertica flips this: it stores data **column by column**. A query that only touches `sales_dollar_amount` and `sale_date` reads *only* those two columns off disk — every other column in the table is simply never touched. This is called **column pruning**, and it's the single biggest reason columnar databases crush row-stores on aggregate/analytical queries over wide tables. It also means columnar storage compresses far better than row storage — a column of repeated `category` values (`Electronics`, `Electronics`, `Electronics`...) compresses beautifully when stored together; that same repetition scattered across different rows compresses far worse.

### MPP — and why you're not actually seeing it in this course

MPP (massively parallel processing) means a *real* Vertica deployment splits a query across many physical nodes simultaneously, each node crunching its own slice of the data, results merged at the end. **You're running a single-node container** — so the actual parallel-execution benefit isn't visible in this lab. Understand this as "the reason Vertica exists and scales in production," not something you'll personally observe on your laptop. If you ever work with a real multi-node Vertica cluster, this is the part that becomes concretely visible.

### Why not just use Vertica for everything, including transactional work?

Vertica is deliberately not built for OLTP (online transaction processing — think: a live checkout page hammering thousands of small, individual writes per second). Its whole architecture — columnar storage, projections, bulk-oriented loading — optimizes for **read-heavy, aggregate-heavy analytical workloads**, not high-frequency single-row writes. That's *why* Day 6 flagged that heavy row-by-row `UPDATE`/`DELETE` isn't the natural fit here — more on that in Section 5.

---

## 2. The Docker workaround — what's really happening, and why production looks different

*→ Referenced in: `day05-vertica-intro-install.md`, Parts A–B*

### Why we're doing this at all

Vertica's free, self-service Community Edition download became unavailable partway through 2026, around when Vertica changed ownership from OpenText to Rocket Software. Rather than block this entire course on a licensing process outside anyone's control, we're using `molo17/vertica-ce` — a community-built Docker image that packages a working Vertica CE instance, pre-loaded with the VMart sample dataset. It's genuinely useful for learning SQL and Vertica concepts hands-on. It is **not** something Rocket Software built, publishes, or supports.

### What each `docker run` flag is *actually* doing

```bash
docker run -d \
  --name vertica-ce \
  -p 5433:5433 \
  -v vertica-data:/data \
  molo17/vertica-ce:24.1.0-0
```

- **`-p 5433:5433`** — this is *port mapping*: traffic hitting port `5433` on your actual machine (the "host") gets forwarded into the container's own internal port `5433`, where Vertica is actually listening. Without this flag, Vertica would be running *inside* an isolated container network, completely unreachable from `vsql`, DBeaver, or Grafana outside it — you'd have a database nobody could talk to.
- **`-v vertica-data:/data`** — this is a *volume*: persistent storage that lives outside the container's own throwaway filesystem. Containers are meant to be disposable — if you ever `docker rm` this container and recreate it, everything *inside* the container (without a volume) would vanish, VMart data and all. The volume is what makes your data survive a container being removed and recreated.

### Why this genuinely isn't how production Vertica looks

A real enterprise Vertica deployment typically means:

- **A real multi-node cluster** — several physical machines or cloud VMs, networked together, each holding a segment (shard) of the data, coordinated via Vertica's own internal cluster-communication protocol
- **Official installation** — Rocket Software's own `.deb`/`.rpm` packages, installed via `admintools`/`install_vertica` scripts across every node in the cluster, under a paid commercial license (or an officially-issued CE license for smaller/eval use)
- **No third-party Docker image** — official deployments don't rely on unofficial, community-maintained container images for anything customer-facing or production-critical

None of the *SQL* you're learning changes — `SELECT`, `JOIN`, `COPY`, projections, all identical. What changes is the **installation and operational story**: single unofficial container on your laptop vs. a properly licensed, multi-node, officially-installed cluster. Keep the two mentally separate.

---

## 3. `vsql` mechanics — where does "LOCAL" actually mean local?

*→ Referenced in: `day05-vertica-intro-install.md`, Part C; `day07-vertica-loading-performance.md`, COPY section*

### What `docker exec -it` is actually doing

```bash
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```

`exec` launches a **new process inside an already-running container** — it doesn't start a fresh container, it attaches to the one already running (`vertica-ce`). `-i` keeps the session interactive (accepts your typed input), `-t` allocates a proper terminal so things like backspace, arrow keys, and a clean prompt actually work correctly. Drop `-it` and you'd get a broken, non-interactive mess.

### Why `COPY ... FROM LOCAL` doesn't mean "local to your Windows/Ubuntu machine"

This is a genuinely common point of confusion, and it's actually a useful, transferable database concept, not just a Vertica quirk: most database systems distinguish **server-side file access** (the database engine reads a file from wherever *it* is running) from **client-side/LOCAL file access** (the file streams from wherever the *connecting client program* is running). Since `vsql` here is launched *inside* the container via `docker exec`, as far as Vertica is concerned, `vsql` **is the client, and it's running inside the container**. `FROM LOCAL '/tmp/file.csv'` means "local to `vsql`" — which is local to the container's filesystem, not your Ubuntu host. That's exactly why Day 7 has you `docker cp` a file into the container *before* `COPY` can see it — you're moving the file into the same filesystem `vsql`'s process actually has access to.

---

## 4. Data types — why they matter more in a columnar store

*→ Referenced in: `day06-vertica-sql-fundamentals.md`, Concepts*

In a row-store database, data type choice is mostly about correctness. In a **columnar** store, it also directly affects performance and storage: each column is compressed and encoded based on its type and the patterns within it. A well-chosen, consistent type per column compresses dramatically better than a loosely-typed equivalent — this is part of *why* columnar databases achieve such strong compression ratios on large analytical tables.

**Why `NUMERIC(10,2)` for money, never a float type:** floating-point types store an *approximation* of decimal values — perfectly fine for scientific calculations, genuinely dangerous for money, where rounding errors compound. `NUMERIC(p,s)` stores an **exact** decimal value. This isn't a Vertica-specific rule — it's a near-universal database best practice, worth carrying with you into any database you touch after this course.

---

## 5. DML in an analytical database — why it feels different from OLTP habits

*→ Referenced in: `day06-vertica-sql-fundamentals.md`, Concepts*

If you've touched MySQL or Postgres before, `UPDATE`/`DELETE` probably felt instant and free. In Vertica, single-row updates and deletes are architecturally **more expensive** than they'd be in a row-oriented OLTP engine — the columnar storage model isn't built around surgically rewriting one row in place the way a row-store is. Under the hood, changes get handled through background processes that reconcile the "logical" state of your data with its physical columnar layout, rather than an instant in-place edit.

This is exactly *why* the courseware flagged that Vertica leans on **bulk operations** (`COPY`, big batched loads) far more than continuous row-by-row writes in real production use. The DML syntax you learned is completely standard SQL and totally fine for occasional corrections or this lab — just don't walk away assuming Vertica is a drop-in replacement for an OLTP database doing thousands of individual row updates per second. That's not the workload it's built for.

---

## 6. Superprojections vs. custom projections — the real mental model

*→ Referenced in: `day06-vertica-sql-fundamentals.md`, table creation note; `day07-vertica-loading-performance.md`, Concepts*

Every table gets a default **superprojection** automatically — it contains *every column* of the table, in some default sort order, and it's what makes the table queryable at all the moment you `CREATE TABLE`. Nothing about this is optional; you can't have a Vertica table with zero projections.

**Why add more?** Because a projection's physical sort order determines how efficiently a matching query can run. A projection sorted by `customer_id` lets a customer-filtered query jump straight to the relevant range instead of scanning the whole table; a projection sorted by `order_date` does the same for date-range queries. Vertica's optimizer automatically picks whichever existing projection best matches each incoming query — you never manually tell a query which projection to use.

**The trade-off, made explicit:** every additional projection is a full additional physical copy of that data, stored in its own sort order. More projections = faster reads for the query patterns they match, but more disk space consumed and slower writes (every projection needs updating on every load). The practical lesson: **add projections based on query patterns you've actually observed** (via `v_monitor`, Section 8) — not preemptively for every column you can imagine someone might filter on someday. Over-projecting is a real, common mistake in production Vertica environments.

---

## 7. `COPY`, bulk loading, and why rejected-row handling matters

*→ Referenced in: `day07-vertica-loading-performance.md`, Concepts*

Real-world data pipelines load millions of rows in one shot, and real-world data is never perfectly clean. Without `REJECTED DATA`/`EXCEPTIONS`, a single malformed row anywhere in a multi-million-row file fails the **entire** load — everything, not just the bad row. With those clauses, Vertica quietly routes bad rows to a separate file (with a matching explanation in the exceptions file) while everything else loads successfully.

This isn't a Vertica-specific nicety — it's standard practice across essentially all serious data engineering/ETL work: **never let one bad record block an entire batch** if you can isolate and flag it instead. The habit of designing loads this way (rather than assuming input data is always clean) is one of the more transferable lessons in this whole course.

---

## 8. `EXPLAIN`, `PROFILE`, and `v_monitor` — using them day to day

*→ Referenced in: `day07-vertica-loading-performance.md`, Concepts*

**`EXPLAIN`** shows you Vertica's *intended* plan for a query — which projection it expects to use, roughly how it plans to execute — without actually running anything. **`PROFILE`** actually executes the query and records **real** measured statistics per step.

Why does the gap between "planned" and "actual" matter? Query optimizers make their planning decisions based on statistics about your data (row counts, distributions) — when those statistics are stale or a table's data has changed significantly since they were last gathered, the *plan* can diverge from what actually happens at *runtime*. Comparing `EXPLAIN` output against `PROFILE` output is exactly how you'd start noticing that gap in a real environment.

`v_monitor.query_requests` is your starting point whenever something *feels* slow and you don't know why yet — it's genuinely just "show me my recent queries, sorted by how long they actually took," the most direct way to find out what to investigate further.

---

## 9. How the three Vertica days fit together

**Day 5 — Getting a live database.** Docker, the container, `vsql`, VMart loaded. The goal here is purely environmental: you end the day with something real to query.

**Day 6 — Fluency.** You go from "a database exists" to "I can make it do what I want" — schema design, DML, `SELECT`/`JOIN`/`GROUP BY`, and a second interface (DBeaver) to prove the skill isn't tied to one specific tool.

**Day 7 — Production mindset.** Manual `INSERT`s don't scale; `COPY` does. Default behavior isn't optimized for every query pattern; projections are how you fix that deliberately. And "did it work" isn't enough once you're past toy data — `EXPLAIN`/`PROFILE`/`v_monitor` are how you start reasoning about *why* something is fast or slow.

That progression — **environment → fluency → production mindset** — is the same shape as the Linux block's **filesystem → identity → processes/services → automation → troubleshooting**, just compressed into three days instead of four.

---

## 📌 Quick-reference: "why" answers you'll want most

| You ask | Short answer |
|---|---|
| Why Docker for Vertica specifically? | Official free CE download was unavailable during this course; `molo17/vertica-ce` is a community workaround, not how production Vertica is normally installed. |
| Why does `COPY ... FROM LOCAL` need a `docker cp` first? | `vsql` runs *inside* the container via `docker exec` — "LOCAL" means local to `vsql`, i.e. local to the container, not your Ubuntu host. |
| Why is `UPDATE`/`DELETE` "different" in Vertica? | Columnar storage isn't built for instant in-place row rewrites the way OLTP row-stores are — Vertica favors bulk operations. |
| Why create more projections if a superprojection already exists? | Different sort orders speed up different query patterns; the optimizer auto-picks the best match. Trade-off: more disk, slower writes. |
| Why bother with `REJECTED DATA`/`EXCEPTIONS`? | One bad row shouldn't fail a million-row load — isolate and flag it instead, standard real-world ETL practice. |
| Why does `EXPLAIN` sometimes not match what `PROFILE` shows actually happened? | The planner works off statistics about your data; stale or shifted stats mean planned vs. actual can diverge. |
| Is any of this exactly how a real company runs Vertica? | The SQL — yes. The Docker/single-node setup — no. Production means multi-node clusters, official installers, real licensing. |

---

system metadata layer 

star schema 

columner storage 

compression 

--- 

## Useful System Metadata Queries


1. List schemas

```sql
SELECT * FROM v_catalog.schemata ORDER BY schema_name;
```

2. List tables

```sql
SELECT * FROM v_catalog.tables ORDER BY table_schema, table_name;
```

3. List columns

```sql
SELECT * FROM v_catalog.columns ORDER BY table_schema, table_name, ordinal_position;
```

4. List projections

```sql
SELECT * FROM v_catalog.projections ORDER BY projection_schema, projection_name;
```

5. List projections for a specific table

```sql
SELECT * FROM v_catalog.projections WHERE anchor_table_schema = 'store' AND anchor_table_name = 'store_sales_fact';
```

6. List projection columns

```sql
SELECT * FROM v_catalog.projection_columns WHERE projection_name = 'your_projection_name';
```

7. List views

```sql
SELECT * FROM v_catalog.views ORDER BY table_schema, table_name;
```

8. List databases

```sql
SELECT * FROM v_catalog.databases;
```

