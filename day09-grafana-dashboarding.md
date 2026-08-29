# Day 9 — Grafana: Dashboarding

*Wed, 9 Sep 2026*

---

## 🔁 Recap: Day 8

Grafana's installed, running as a systemd service, and you've poked around the UI using the built-in TestData source. Today the training wheels come off — you connect Grafana to your **actual** Vertica instance and build a real dashboard against real data.

---

## 📚 Concepts

### Grafana doesn't speak Vertica out of the box

Grafana ships knowing how to talk to a handful of common data sources, but Vertica isn't one of them by default — it needs a dedicated **datasource plugin** installed first, the same way DBeaver needed a JDBC driver on Day 6.

### Data sources vs. queries vs. panels — reinforcing yesterday's model

Today you'll do, for real, exactly what you did yesterday with TestData: **add a data source → write a query against it → render the result as a panel.** The only thing that changes is what's on the other end of that connection — your own live Vertica container instead of fake random data.

### Why time-series queries need a `time` column

Grafana's graph panels expect query results shaped a specific way: a column literally aliased `time` (or `AS time`), plus one or more value columns. Grafana also provides special macros like `$__timeFilter(column)` that automatically inject Grafana's currently-selected time range into your `WHERE` clause — so the same panel can show "last 7 days" or "all of January 2003" just by changing the time picker, without editing the query itself.

---

## 🔌 Installing the Vertica plugin

**🐧 Run inside Ubuntu:**

```bash
grafana cli plugins install vertica-grafana-datasource
grafana cli plugins ls | grep -i vertica
sudo systemctl restart grafana-server
sudo systemctl status grafana-server --no-pager
```

If the plugin doesn't show up in Grafana's UI after this, a restart is almost always the fix — Grafana only loads plugins at startup.

---

## 🔗 Adding Vertica as a data source

Open `http://localhost:3000`, then:

**Connections → Data sources → Add data source → search "Vertica" → select it**

| Field | Value |
|---|---|
| Name | `Vertica-VMart` |
| Host | `localhost:5433` (host **and** port together in this one field) |
| Database | `demo` |
| User | `dbadmin` |
| Password | `password` |
| SSL Mode | `Disable` (fine for this local lab; never do this in production) |

Click **Save & test** — you want a success message. At that point the full chain is live: **Grafana → Vertica plugin → `localhost:5433` → your Docker container → the `demo` database.**

---

## 🧪 Your first real query

Go to **Explore**, select your `Vertica-VMart` data source, switch to raw SQL mode, and run:

```sql
SELECT
    store_sales_date AS time,
    SUM(sales_dollar_amount) AS sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date)
GROUP BY store_sales_date
ORDER BY store_sales_date;
```

Set **Format as: Time Series**, then **Run query**.

### If you see "Data outside time range" — don't panic

This means your SQL genuinely worked and Vertica genuinely returned data — it's just that Grafana's default time picker (usually "last 6 hours") doesn't overlap with VMart's actual date range (2003–2027). Fix it by setting an **absolute custom time range**:

```
From: 2003-01-01 00:00:00
To:   2003-01-31 23:59:59
```

Apply, re-run the query — you should now see a real daily sales graph for January 2003.

---

## 📊 Building panels

### Panel types you'll use today

- **Time series / Graph** — a line chart over time (the query above)
- **Table** — raw rows, good for rankings or lists
- **Stat (single-stat)** — one big number, great for "total X" at a glance

**Table example — top product categories by sales:**

```sql
SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY category_sales DESC;
```

Set this panel's visualization type to **Table**.

**Single-stat example — total sales for the period:**

```sql
SELECT SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date);
```

Set this panel's visualization type to **Stat**.

### Organizing panels into a dashboard

Each panel you build gets added to a **dashboard** — a named collection you can arrange, resize, and save. Create a new dashboard, add all three panels above to it, and arrange them so the time series graph is prominent (top or full-width) with the table and stat panel below or beside it.

### Variables — making a dashboard dynamic

A **dashboard variable** lets viewers filter the whole dashboard without editing any query. Example: a variable listing every distinct product category, letting anyone switch which category's sales they're looking at.

**Dashboard settings → Variables → New variable:**

```
Name: category
Type: Query
Data source: Vertica-VMart
Query: SELECT DISTINCT category_description FROM public.product_dimension;
```

Then reference it in a panel's query using `$category`:

```sql
SELECT store_sales_date AS time, SUM(f.sales_dollar_amount) AS sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
WHERE $__timeFilter(f.store_sales_date)
  AND p.category_description = '$category'
GROUP BY store_sales_date
ORDER BY store_sales_date;
```

A dropdown now appears at the top of your dashboard, and every panel using `$category` updates together when you change it.

### Basic alerting

Grafana can watch a panel's value and notify you when it crosses a threshold. On any time-series panel: **Edit → Alert tab → Create alert rule.** For a quick, low-stakes example:

```
Condition: WHEN last() OF query IS BELOW 100000
Evaluate every: 1m
```

You won't have live-changing data in this lab (VMart is static, historical data), so you won't see a real alert fire — the goal today is just knowing where alert rules live and how a condition is structured, not building a production alerting pipeline.

---

## 🧪 Guided hands-on (do this together)

```bash
grafana cli plugins install vertica-grafana-datasource
grafana cli plugins ls | grep -i vertica
sudo systemctl restart grafana-server
```

**In the browser:**
1. Add the Vertica data source with the settings table above, **Save & test**
2. **Explore** → run the January 2003 sales time-series query, fix the time range if needed
3. Build all three panels together (time series, table, stat) and add them to a new dashboard
4. Add the `$category` variable and wire it into the time series panel's query

---

## 🔬 Lab — on your own

**Goal: a dashboard with at least 3 different panel types, all live from your own Vertica instance.**

1. Build your own version of the three panels above — same queries are fine, but change at least one (e.g., group by `store_dimension` instead of product category, or use `online_sales_fact` instead of `store_sales_fact`).
2. Save them all into one dashboard with a clear title.
3. Add a dashboard variable of your own — it doesn't have to be `category`; pick any dimension from VMart you find interesting (store region, customer segment, whatever's available) — and use it to filter at least one panel.
4. Set up one basic alert rule on any panel (it doesn't need to fire — just needs to exist with a sensible condition).
5. Confirm the whole chain is genuinely live: go back to `vsql` or DBeaver, run an `UPDATE` or `INSERT` against a table your dashboard queries, then refresh the Grafana panel and confirm the number changes. This is the real proof that Grafana isn't showing you a snapshot — it's querying live.
6. **Bonus:** rename your data source connection to something more descriptive than `Vertica-VMart`, and add a text/markdown panel to your dashboard with a one-line description of what it shows.

---

## 📎 Copy-paste command reference — Day 9

```bash
# --- Plugin install ---
grafana cli plugins install vertica-grafana-datasource
grafana cli plugins ls | grep -i vertica
sudo systemctl restart grafana-server
```

```sql
-- Time series panel
SELECT store_sales_date AS time, SUM(sales_dollar_amount) AS sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date)
GROUP BY store_sales_date
ORDER BY store_sales_date;

-- Table panel
SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY category_sales DESC;

-- Stat panel
SELECT SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date);

-- Dashboard variable (category example)
SELECT DISTINCT category_description FROM public.product_dimension;
```

**Vertica data source connection settings:**
```
Host: localhost:5433 | Database: demo | User: dbadmin | Password: password | SSL: Disable
```

**Useful time range for VMart data:** `2003-01-01 00:00:00` → `2003-01-31 23:59:59` (or any range within 2003–2027).

---

## 👀 Tomorrow: Day 10 — Capstone Project

Everything comes together. You'll independently spin up your environment, load a fresh dataset into Vertica, and build a working dashboard on it — start to finish, no guided walkthrough. This is the day that proves the whole 9 days actually stuck.
