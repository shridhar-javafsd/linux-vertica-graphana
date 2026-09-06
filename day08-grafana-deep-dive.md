# Day 8 — Grafana Deep Dive: Panels, Queries, Transformations, Variables & Alerting

*Mon — Grafana block begins (PM), continuing full-day Tue*

---

## 🔁 Recap: where we're starting from

No install drama today — that's already sorted. By this point, per the installation guide, you're standing on:

```
✅ Grafana running as a systemd service on :3000
✅ Vertica Grafana plugin installed
✅ "Vertica-VMart" data source added and tested
✅ A first Explore query against store.store_sales_fact already worked
```

If any of that isn't true for your machine — flag it *now*, before we go further, because everything today builds directly on top of a working connection. Today isn't about getting Grafana talking to Vertica (done); it's about actually becoming *good* at Grafana. No cap, this is the day the tool stops feeling like a random UI you're clicking around in and starts feeling like something you actually understand.

---

## 📚 Concepts — the mental model, leveled up

### Quick refresher: the chain you already know

```
Data source  →  Query  →  Panel  →  Dashboard
```

You know this. Today we zoom into *each link* of that chain and go deep on what's actually configurable, because "it works" and "you know why it works, and can make it do exactly what you want" are two very different skill levels.

### A dashboard is secretly just a JSON document

Here's the thing nobody tells you on day one: every dashboard you build in the pretty drag-and-drop UI is, underneath, just a big JSON object being edited through a nice interface. Panels are an array. Variables are an array. Time settings are a few keys. You'll actually go look at this raw JSON later today (Dashboard settings → JSON Model) — it demystifies a *lot*, and it's also exactly how "dashboards as code" works in real companies (more on that Day 9).

### Query editor: Builder mode vs. Code mode

The Vertica plugin (like most SQL-based Grafana plugins) gives you two ways to write a query:

- **Builder mode** — point-and-click: pick a table, pick columns, pick aggregations. Good for quick exploration, bad once your query needs a `JOIN`, a `CASE WHEN`, or anything with real logic.
- **Code mode (raw SQL)** — you type actual SQL, same as you would in `vsql` or DBeaver. This is what we've used so far and what we'll keep using — because you already know SQL, and it gives you full control.

There's a toggle for this in every panel's query editor. Worth knowing it exists, even if you live in Code mode 99% of the time.

---

## 🎛️ Panel types — the full tour

You've met **Time series**, **Table**, and **Stat**. Here's the wider cast, with when each one actually earns its place on a dashboard (not just "looks cool"):

| Panel type | Best for | VMart example |
|---|---|---|
| **Time series** | Trend over time | Daily sales over January 2003 |
| **Table** | Ranked rows, raw detail | Top categories by revenue |
| **Stat** | One headline number | Total sales this period |
| **Gauge** | A number against a min/max range | "% of monthly sales target hit" |
| **Bar gauge** | Several values, each shown as a mini progress bar | Sales by store, ranked |
| **Bar chart** | Category comparison (not time-based) | Revenue per product category, side by side |
| **Pie chart** | Share of a whole | % of sales by region |
| **Histogram** | Distribution of a numeric value | Spread of individual transaction amounts |
| **State timeline** | Categorical state over time (on/off, status codes) | Rare for VMart — more common in ops monitoring |
| **Text / Markdown** | Static notes, instructions, links — no query at all | "This dashboard covers Q1 2003 store sales. Contact: training team." |

> 💡 **The mistake to avoid:** choosing a panel type because it *looks* nice, not because it matches what your query result actually represents. A ranked list of categories belongs in a table or bar chart — cramming it into a time series with a fake time axis is a classic beginner move, and it actively makes the data harder to read, not easier.

### Try it: same query, different panel types

Take this query:

```sql
SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY category_sales DESC;
```

Build it as a **Table**, then switch the *same panel* to **Bar chart**, then to **Pie chart**, using the visualization picker at the top-right of the panel editor — no need to re-run or re-type the query each time. Notice how the bar chart makes ranking obvious at a glance, while the pie chart makes proportion obvious but ranking harder to read precisely. Neither is "wrong" — they answer slightly different questions.

---

## 🎨 Field options & panel options — making data readable, not just present

Every panel has two settings tabs worth knowing cold: **Panel options** (title, description, repeat behavior — more on repeat later) and **Field** (how the actual values get displayed).

### Units

Grafana doesn't know `sales_dollar_amount` is money unless you tell it. Under **Field → Standard options → Unit**, search for `Currency (USD)` (or your relevant currency) — Grafana will then auto-format `1250000` as `$1.25M` instead of a raw number. Do this on every Stat/Gauge panel; it's a five-second change that makes a dashboard look genuinely professional instead of "someone's SQL homework."

### Decimals

Right next to Unit — control how many decimal places show. For big currency totals, 0–1 decimals is usually cleaner than Grafana's default of showing every digit.

### Thresholds — turning a number into a signal

Under **Field → Thresholds**, you can define value ranges that change a panel's color — e.g., red below 100,000, yellow 100,000–200,000, green above 200,000. On a **Stat** or **Gauge** panel, this turns "here's a number" into "here's a number, and here's whether that number is good or bad" — at a glance, no reading required. This is genuinely one of the highest-impact, lowest-effort things you can add to any KPI panel.

**Try it:** on your total-sales Stat panel, set thresholds so anything below ₹50L (or whatever's sensible for your data range) shows red, and above shows green.

### Value mappings — renaming what the data literally says

Sometimes your raw data says `1` and `0`, or `Y` and `N`, and you want the dashboard to show something human-readable instead — "Active"/"Inactive", "Yes"/"No". **Field → Value mappings** lets you define exactly that translation, without touching your SQL. Handy for status codes, boolean-ish columns, or category codes that aren't self-explanatory.

### Color scheme

Under **Field → Standard options → Color scheme**, you can move away from Grafana's default single-color-per-series scheme toward "Value mapped colors" (driven by thresholds) or a continuous gradient scheme (useful for heatmap-style value coloring in tables). Play with this on your table panel — under **Cell type**, try **Color background** to turn your category-sales table into something that visually pops based on value size.

---

## 🔧 Transformations — reshaping data *after* the query, before it hits the panel

This is one of the most underused, most powerful features in Grafana, and today's the day you actually learn it properly.

### The core idea

A **transformation** operates on the *result set* your query already returned — it doesn't touch Vertica, doesn't re-run SQL, doesn't cost you a database round-trip. Think of it as a lightweight, no-code step between "here's what SQL gave me" and "here's what the panel will actually draw." You'll find the **Transform** tab right next to **Query** in any panel editor.

### Why not just fix it in SQL instead?

Fair question — often you *could* rewrite the SQL to do the same thing. Transformations earn their keep when:
- You want to reuse the exact same query across multiple panels but display it differently in each
- The reshaping is presentation-only (renaming a column header for display, without touching the underlying data)
- You're combining results from **two different queries** (or even two different data sources!) into one panel — SQL alone can't do that, but a transformation can

### The transformations worth knowing today

**Organize fields** — rename columns for display, reorder them, or hide ones you queried but don't want shown. Example: hide a raw `product_key` column you needed for joins but nobody needs to actually see.

**Rename by regex** — bulk-rename column headers using a pattern. Handy when a query returns a dozen similarly-named columns and you don't want to edit your SQL just to relabel the display.

**Filter by name / Filter by value** — hide specific columns, or hide *rows* based on a condition (e.g., only show categories with sales above a certain amount) — without touching the `WHERE` clause.

**Add field from calculation** — create a brand-new column computed from existing ones, right there in the panel (e.g., a "% of total" column computed from a `category_sales` column) — again, without rewriting SQL.

**Group by** — a second-pass aggregation on top of what SQL already returned. Mostly useful when combining multiple queries, less useful when your SQL already does the grouping (which yours will, in this course).

**Reduce** — collapse a whole time series down to a single value per series (e.g., "show me just the max," "just the last value") — a common trick behind turning a time-series query into a Stat panel's single number.

### Hands-on: build a "% of total" column with a transformation

1. Use the category-sales query from earlier, as a **Table** panel
2. Go to the **Transform** tab → **Add transformation** → **Add field from calculation**
3. Set the calculation to a **Reduce Row** or use **Binary operation** with the `category_sales` field, computing each row's share of the column total
4. Format the new field's unit as **Percent (0.0–1.0)**

You've now got a "share of total sales" column that exists nowhere in your actual SQL — it's pure Grafana-side transformation. This is the "aha" moment for this whole section.

---

## 🎚️ Variables — the deep dive

You've seen the basic idea: a dropdown at the top of a dashboard that filters every panel using it. Today, the full picture.

### Variable types

| Type | What it does | Example |
|---|---|---|
| **Query** | Populated by running a query against a data source, live | `SELECT DISTINCT category_description FROM public.product_dimension` |
| **Custom** | You manually type a fixed list of options | `North,South,East,West` |
| **Interval** | A dropdown of time intervals (`1m, 5m, 1h, 1d`) — mostly used for auto-grouping in time-series queries | Rarely needed for static VMart data, but common in live-metrics dashboards |
| **Textbox** | A free-text input box, not a dropdown | Let a viewer type an arbitrary search term |
| **Datasource** | Lets the *data source itself* be switchable via dropdown | Useful if you had two Vertica environments (dev/prod) and wanted one dashboard for both |

### Chained (dependent) variables — the genuinely cool part

Variables can depend on each other. Example: a `region` variable, and a `store` variable that only shows stores *within* the region currently selected.

**Step 1 — the parent variable:**
```
Name: region
Query: SELECT DISTINCT store_region FROM store.store_dimension;
```

**Step 2 — the child variable, referencing the parent:**
```
Name: store
Query: SELECT store_name FROM store.store_dimension WHERE store_region = '$region';
```

> ⚠️ **Column-name heads-up:** `store_region` and `store_dimension` are the standard VMart naming conventions, but exact column names can shift slightly between VMart versions. Before typing these queries, run `\d store.store_dimension` in `vsql` (or browse the table in DBeaver) to confirm the real column names on your install, and adjust if needed.

Now, changing `$region` at the top of your dashboard automatically narrows down what shows up in the `$store` dropdown — pick "South," and `$store` only offers South's stores. This is the actual production pattern behind those "cascading filter" dashboards you see in real BI tools.

### Multi-value and "All"

Under a query variable's options, you can enable **Multi-value** (let someone select several categories at once) and **Include All option** (a special "All" choice). If you do this, your SQL needs to handle it — instead of `= '$category'`, you'd use:

```sql
WHERE p.category_description IN ($category)
```

Grafana automatically expands `$category` into a properly comma-separated, quoted list when multi-value is on — including a special `IN (1=1)`-style trick behind the scenes when "All" is selected. You don't need to hand-build that logic; Grafana's `IN ($var)` syntax handles it, as long as you switch from `=` to `IN`.

### Repeating panels and rows by variable — the "one panel, many outputs" trick

Here's a genuinely slick feature: instead of manually building one panel per region, you can build **one panel**, tell it to **repeat by** the `$region` variable, and Grafana will automatically clone that panel once per value in the variable — one chart per region, generated for you.

**How:** Panel options → **Repeat options** → **Repeat by variable** → select `region`. Set **Repeat direction** to Horizontal or Vertical depending on your dashboard layout.

This only makes sense when `$region` is set to **Multi-value** (so there's more than one value to repeat across). Try it on a simple Stat panel showing total sales, repeated by region — you'll get one Stat tile automatically generated per region, side by side, no copy-pasting panels required.

---

## 📌 Annotations — marking moments on a graph

An **annotation** is a vertical marker line on a time-series panel, with an optional label — think "here's when something happened" layered on top of "here's how the data changed."

### Manual annotations
Ctrl+Click (or Cmd+Click on Mac) directly on a time-series panel to drop a manual annotation with a text note. Good for one-off, ad-hoc marking during a live investigation.

### Query-driven annotations
Configure a query (in **Dashboard settings → Annotations**) that returns timestamps and labels from your data source itself — e.g., marking every date a major promotion ran, pulled live from a `promotion_dimension` table's date column. Unlike manual annotations, these update automatically as the underlying data changes — same "Grafana doesn't store its own copy" principle from the manual, just applied to markers instead of chart values.

---

## 🚨 Alerting — the real, unified alerting model

You got a taste of this already; today's the deeper version.

### The anatomy of an alert rule

Every Grafana alert rule has:
- **A query** — same as any panel, run against a data source
- **A condition** — a threshold expression evaluated against that query's result (`IS ABOVE`, `IS BELOW`, etc.)
- **An evaluation interval** — how often Grafana re-checks the condition (`Evaluate every: 1m`)
- **A "for" duration** — how long the condition must stay true before the alert actually fires (avoids flapping on a single noisy blip)
- **Labels** — key-value tags attached to the alert, used to route it to the right notification channel

### Contact points and notification policies

An alert firing doesn't automatically know *who* to tell. **Contact points** (Alerting → Contact points) define destinations — email, Slack webhook, PagerDuty, etc. **Notification policies** (Alerting → Notification policies) are the routing rules: "alerts with label `severity=critical` go to the on-call Slack channel; everything else goes to email." For this lab, we're not wiring up real notifications — but it's worth clicking through both screens so you know where this lives when you need it for real.

### Why VMart alerts still won't fire (and that's fine)

Same reason as before: VMart is static historical data. An alert rule needs something that *changes* between evaluations to ever trip. Today's goal is understanding the anatomy — query, condition, evaluation interval, labels, routing — not watching a real alert go off. (You'll get an actual live-firing alert if your track heads into Prometheus territory on Day 9.)

---

## 🧪 Guided hands-on (do this together)

We're building one comprehensive dashboard together, section by section, using everything above.

**1. New dashboard, name it** `VMart Sales Command Center`

**2. Panel 1 — Time series (the trend):**
```sql
SELECT store_sales_date AS time, SUM(sales_dollar_amount) AS sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date)
GROUP BY store_sales_date
ORDER BY store_sales_date;
```
Set the dashboard's default time range to January 2003 in **Dashboard settings → General → Time options**, so it doesn't reset to "last 6 hours" every time someone opens it.

**3. Panel 2 — Stat (the headline number), with thresholds:**
```sql
SELECT SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date);
```
Set Unit to Currency, add red/yellow/green thresholds.

**4. Panel 3 — Table (category ranking) with a transformation:**
Use the category-sales query, add the "Add field from calculation" transformation for a % of total column, set Cell type to Color background.

**5. Add the `$region` variable**, chained down to a `$store` variable (per the syntax above).

**6. Panel 4 — Bar gauge, repeated by `$region`:**
Total sales, filtered by store region, repeating panel by the `$region` variable (set to multi-value).

**7. Add one query-driven annotation** — pick any date-bearing dimension table available and mark those dates on the time series panel.

**8. Add one alert rule** on the Stat panel — condition, evaluation interval, and a label — no need for it to fire.

**9. Open Dashboard settings → JSON Model** and just look. Find your panels array. Find your variable definitions. This is what "dashboards as code" actually looks like under the hood — you'll come back to this idea tomorrow.

---

## 🔬 Lab — on your own

**Goal:** apply everything from today to build a second, independent dashboard — not a copy of the guided one.

1. Pick a different angle on VMart data — e.g., `online_sales.online_sales_fact` instead of `store.store_sales_fact` (note the schema difference), or a customer-focused view using `public.customer_dimension`.
2. Build at least **5 panels**, using **at least 4 different panel types** from the table above.
3. Apply proper **units, decimals, and thresholds** to every Stat/Gauge panel — no raw unformatted numbers allowed.
4. Add **at least one transformation** that genuinely changes what's displayed (not just a cosmetic rename).
5. Build a **chained variable pair** (parent → child), different from the region/store one we did together.
6. Set up **panel repeat by variable** on at least one panel.
7. Add **one annotation** (manual or query-driven, your choice) and **one alert rule**.
8. **Bonus:** open the JSON Model for your dashboard and find the exact spot where your chained variable's query is stored. Screenshot or note it — you'll want this instinct for Day 9's provisioning discussion.

---

## 📎 Copy-paste reference — Day 8

```sql
-- Category sales, for table/bar/pie panel experiments
SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY category_sales DESC;

-- Total sales, for Stat panel with thresholds
SELECT SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date);

-- Parent variable: region
SELECT DISTINCT store_region FROM store.store_dimension;

-- Child variable: store, dependent on $region
SELECT store_name FROM store.store_dimension WHERE store_region = '$region';

-- Multi-value-safe filter pattern (use IN, not =, once multi-value is on)
WHERE p.category_description IN ($category)
```

> ⚠️ Verify `store_region`, `store_name`, and any other column referenced here against your actual VMart install with `\d store.store_dimension` before typing — naming can vary slightly by version.

**Panel type cheat sheet:** Time series (trend) · Table (ranking/detail) · Stat (headline number) · Gauge/Bar gauge (value vs. range) · Bar chart (category comparison) · Pie chart (share of whole) · Text/Markdown (no query, static notes)

**Transformation cheat sheet:** Organize fields (hide/rename/reorder) · Rename by regex (bulk relabel) · Filter by name/value (hide columns/rows) · Add field from calculation (new computed column) · Reduce (collapse a series to one value)

---

## 👀 Tomorrow: Day 9 — Advanced Grafana Ops, then a fork in the road

Morning: dashboard-as-code (JSON model, provisioning), folders & permissions, sharing/exporting, playlists, and Vertica-specific query performance tips — all together as one group.

Afternoon: the room splits. Two of you go deep on **Prometheus** — a completely different (and, in the industry, extremely common) way of feeding Grafana data, built around live system metrics instead of SQL tables. The other four keep sharpening Grafana skills with a fresh hands-on build plus a couple of new lightweight concepts. Everyone reconvenes at the end of the day to show off what they built.
