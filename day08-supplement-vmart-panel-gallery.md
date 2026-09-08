# Day 8 Supplement — The VMart Panel Gallery: One Dashboard, One Growing Business Story

*Companion to `day08-grafana-deep-dive.md` — read that first for the mental model (data source → query → panel → dashboard, Builder vs Code mode, the panel editor layout). This doc is the full trainer-demo script for everything under "Panel types," "Field options," "Transformations," "Variables," "Annotations," and "Alerting" — one continuous case study instead of scattered snippets.*

**How to use this:** every query below is complete and tested against the real VMart schema (confirmed via `\d`, no guessed column names). Run it live, panel by panel, in front of the room. It's designed to *replace or run alongside* the "Guided hands-on" section of the main Day 8 doc — same spirit, way more depth on the "why this panel, why now" side.

---

## 🎬 The setup

Meet **Pooja** — VMart's newly promoted VP of Retail Analytics. She's been handed Grafana and told "figure out our sales story." Over the next hour, she keeps coming back with one more ask. Each ask is exactly the kind of question that decides *which panel type earns its place* — which is the whole point of this exercise.

We're building one dashboard, section by section: **`VMart Retail Intelligence Suite`**.

**Create it now** (same flow as the orientation walkthrough in the main guide):
`Dashboards → New → New dashboard → + Add visualization → Vertica-VMart`

---

## 🧮 Section 0 — Calibrate before you decorate

Before setting a single threshold, target, or bucket size later in this doc, run this once and **write down what you get** — every threshold/target/bucket choice below assumes you know your own data's real range instead of guessing:

```sql
SELECT
  MIN(daily_sales) AS min_day,
  AVG(daily_sales) AS avg_day,
  MAX(daily_sales) AS max_day
FROM (
  SELECT store_sales_date, SUM(sales_dollar_amount) AS daily_sales
  FROM store.store_sales_fact
  GROUP BY store_sales_date
) t;
```

> 💡 **Why this matters more than it looks:** a threshold of "red below ₹50L" is meaningless noise if your actual daily sales hover around ₹2L or ₹5Cr. Thresholds, gauge targets, and histogram bucket widths should always come from a quick look at the real distribution — not vibes. Every dollar figure in the sections below is a placeholder for *your* numbers from this query.

---

## 📈 Section 1 — Time series: "What's our daily sales trend?"

This is Pooja's opening ask — the most natural first question for any sales dataset.

```sql
SELECT store_sales_date AS time, SUM(sales_dollar_amount) AS sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date)
GROUP BY store_sales_date
ORDER BY store_sales_date;
```

| Step | What to do |
|---|---|
| Panel type | Time series (Grafana's default guess — correct here) |
| Field → Standard options → Unit | Currency (USD), or your relevant currency |
| Field → Standard options → Decimals | 0 |
| Dashboard time range | January 2003 (this is when VMart's sample data actually lives) |

Save this range as the dashboard default: **Dashboard settings → General → Time options**, or via the Save dropdown's "Save current time range as dashboard default" checkbox — so it doesn't reset to "Last 6 hours" every time someone opens it.

---

## 🔢 Section 2 — Stat: "Give me one number for the exec summary slide"

Pooja's next ask: she doesn't want a chart in the board meeting — she wants **one number**, and she wants it to visually scream "good" or "bad" without anyone reading a label.

```sql
SELECT SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date);
```

| Step | What to do |
|---|---|
| Panel type | Stat |
| Field → Unit | Currency |
| Field → Thresholds | Red below your Section 0 `min_day`-ish floor, yellow mid-range, green above your `avg_day` |

> 💡 This is the "here's a number, and here's whether it's good or bad, at a glance" moment the main guide calls out — genuinely the highest-impact, lowest-effort thing in this whole doc.

---

## 🎯 Section 3 — Gauge: "Are we hitting our monthly sales target?"

Pooja's leadership has a number in mind: a monthly sales target. She wants to see progress against it as a literal dial, not a raw total.

Pick a target based on your Section 0 numbers — e.g., if `avg_day` × 30 gives you a ballpark, round it to something clean. We'll call it `$__TARGET__` below — swap in your real number.

```sql
SELECT (SUM(sales_dollar_amount) / 50000000.0) * 100 AS pct_of_target
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date);
```

> Replace `50000000.0` with your actual target once you've calibrated it against Section 0.

| Step | What to do |
|---|---|
| Panel type | Gauge |
| Field → Standard options → Unit | Percent (0–100) |
| Field → Standard options → Min / Max | 0 / 100 |
| Field → Thresholds | Red < 60, Yellow 60–90, Green ≥ 90 |

> 💡 Note the difference from Section 2: Stat is "here's the number." Gauge is "here's the number **against a range that gives it meaning**." Same underlying idea as a threshold, but the range itself is now visually part of the story.

---

## 🏪 Section 4 — Bar gauge: "Rank our stores — but I want to see the *values*, not just position"

Pooja wants a store ranking, but unlike a plain table, she wants each store's bar length to visually communicate scale immediately — a boardroom-friendly version of a leaderboard.

```sql
SELECT sd.store_name, SUM(f.sales_dollar_amount) AS store_sales
FROM store.store_sales_fact f
JOIN store.store_dimension sd ON f.store_key = sd.store_key
WHERE $__timeFilter(f.store_sales_date)
GROUP BY sd.store_name
ORDER BY store_sales DESC;
```

| Step | What to do |
|---|---|
| Panel type | Bar gauge |
| Panel options → Orientation | Horizontal (reads more naturally for a name-then-value list) |
| Field → Unit | Currency |

---

## 📊🥧 Section 5 — Bar chart vs. Pie chart: same query, two different questions

Pooja's marketing lead jumps in: "Which categories are actually driving revenue?" This is the exact "one query, one picker, three pictures" moment from the orientation section — let's put it directly into the real dashboard instead of a throwaway Explore tab.

```sql
SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
WHERE $__timeFilter(f.store_sales_date)
GROUP BY p.category_description
ORDER BY category_sales DESC;
```

**Demo it live in this order:**

1. Run it as **Table** first — just to see the raw ranked numbers.
2. Switch (no re-run needed) to **Bar chart** — ranking is now obvious at a glance.
3. Switch to **Pie chart** — proportion ("categories A and B together are basically half our business") is now obvious, but exact ranking between close categories gets harder to read.

> 💡 Ask the room: "If Pooja needs to say '*Snacks is our #1 category*' in a meeting, which chart do you hand her? If she needs to say '*Snacks and Dairy together are over half our sales*,' which one?" There's no universally-right answer — that's the point.

We'll keep the **Bar chart** version on the dashboard and reuse the Pie chart as a talking point only (not both, to avoid dashboard clutter with duplicate data).

---

## 📋 Section 6 — Table + Transformations: the deep dive

Pooja's finance partner has the most demanding ask yet: *"I want the ranked category detail, a % of total column, colored by size, without the SKU-count clutter I don't need for this view — and I want it to include online sales too, not just store."*

This single ask is going to exercise **every transformation** worth knowing.

### 6a. The base query

```sql
SELECT
  p.category_description,
  p.department_description,
  SUM(f.sales_dollar_amount) AS category_sales,
  COUNT(DISTINCT f.product_key) AS distinct_skus
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
WHERE $__timeFilter(f.store_sales_date)
GROUP BY p.category_description, p.department_description
ORDER BY category_sales DESC;
```

Set panel type to **Table**.

### 6b. Rename by regex — bulk-cleaning the headers

Both `category_description` and `department_description` share the same clunky `_description` suffix. Instead of renaming each by hand:

**Transform tab → Add transformation → Rename by regex**
- Match pattern: `(.*)_description`
- Replace with: `$1`

Both headers instantly clean up to `category` and `department` in one shot — this is exactly the "a dozen similarly-named columns" scenario the concept doc describes, just with two columns instead of a dozen, so the mechanism is easy to see.

### 6c. Organize fields — hiding what finance doesn't need

Finance doesn't need `distinct_skus` for this particular view (it's still useful elsewhere, so we don't want to remove it from the SQL).

**Transform tab → Add transformation → Organize fields**
- Toggle `distinct_skus` **off** (hidden, not deleted from the query)
- Drag to reorder: `category`, `department`, `category_sales`

### 6d. Filter by value — only show categories that matter

Finance also only cares about categories clearing a minimum revenue bar (small noise categories clutter the slide).

**Transform tab → Add transformation → Filter by value**
- Field: `category_sales`
- Condition: `Is greater than` → your Section-0-calibrated threshold

### 6e. Add field from calculation — the "% of total" column

This is the signature transformation move from the concept doc.

**Transform tab → Add transformation → Add field from calculation**
- Mode: Reduce row fields, or Binary operation on `category_sales` ÷ (sum of `category_sales`)
- Format the new field's unit as **Percent (0.0–1.0)**

You now have a share-of-total column that exists **nowhere in your SQL** — pure Grafana-side transformation, computed after the query already ran.

### 6f. Field styling — make it pop

**Field → Cell type → Color background**, driven by thresholds on `category_sales`. Try **Field → Standard options → Color scheme → Continuous (green-yellow-red)** for a heatmap-style effect across rows.

### 🎯 Stretch — 6g. Group by: combining store *and* online sales into one table

This is the transformation that genuinely can't be done in plain SQL alone — combining two separate queries (potentially even two data sources) into a single panel.

**Add a second query (Query B)** in the same panel:

```sql
SELECT p.category_description, SUM(o.sales_dollar_amount) AS category_sales
FROM online_sales.online_sales_fact o
JOIN public.product_dimension p ON o.product_key = p.product_key
WHERE $__timeFilter(o.online_sales_saledate)
GROUP BY p.category_description
ORDER BY category_sales DESC;
```

Now both Query A (store) and Query B (online) return rows into the same panel. Add:

**Transform tab → Add transformation → Group by**
- Group by: `category_description`
- Calculate: `Sum` on `category_sales`

This second-pass aggregation merges both result sets into one combined "total category revenue across channels" table — the exact scenario the concept doc flags as where Group by earns its keep, since your SQL alone stopped at "per-query" totals.

> 🎯 Flag this one as a stretch goal if time's tight — it's the richest but also the most conceptually dense piece in this whole section.

---

## 📶 Section 7 — Histogram: "How spread out are individual transaction sizes?"

Pooja's ops lead asks a different kind of question — not "what's the total," but "**what does a typical transaction actually look like**, and are there outliers?" This needs *individual row-level* data, not a pre-aggregated sum.

```sql
SELECT sales_dollar_amount
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date)
  AND sales_dollar_amount IS NOT NULL;
```

| Step | What to do |
|---|---|
| Panel type | Histogram |
| Panel options → Bucket size | Set based on your Section 0 range — start with "Auto," then manually tighten if buckets look too coarse or too sparse |

> ⚠️ **Common trainee mistake:** pasting the *aggregated* category-sales query into a Histogram panel. A histogram needs one row per transaction/event to show a real distribution — feeding it pre-summed data just produces a single meaningless bar. This is the same "match the panel to what your query actually represents" trap the concept doc warns about, just in reverse (using a fine-grained panel with coarse-grained data instead of the other way round).

---

## 🎨 Section 8 — State timeline: "What selling season is each day in, next to our sales trend?"

This is the one panel type the main guide is honestly upfront about being a stretch for VMart — most retail fact/dimension data doesn't have a natural "on/off" or status field. **But we got lucky**: `public.date_dimension.selling_season` is a genuine categorical value that changes day-to-day (e.g., "Regular Season," "Christmas," "Back to School") — this is about as clean and *non-contrived* a State timeline example as VMart offers.

```sql
SELECT d.date AS time, d.selling_season AS state
FROM public.date_dimension d
WHERE $__timeFilter(d.date)
ORDER BY d.date;
```

| Step | What to do |
|---|---|
| Panel type | State timeline |
| Field → Standard options | No unit needed — this is categorical, not numeric |

> 💡 **Tell the room this explicitly:** unlike most of today's examples, this one isn't "here's a workaround to force-fit a panel type" — `selling_season` is *actually* a categorical state that varies over time, which is the literal textbook use case for this panel. Put this side-by-side (same dashboard row) with Section 1's Time series panel and the story writes itself: "sales climb noticeably once we hit the Christmas season band."

---

## 📝 Section 9 — Text/Markdown: dashboard usage notes

No query — just context for whoever opens this dashboard next.

**Panel type → Text**, paste (Markdown mode):

```markdown
## VMart Retail Intelligence Suite

This dashboard covers **VMart's January 2003 retail dataset** across store and online sales channels.

- **Time range**: defaults to January 2003 — VMart's sample data window
- **Filters**: use the `Region` and `Store` dropdowns at the top to narrow any panel
- **Questions?** Contact: Retail Analytics Team

*Last updated during Day 8 Grafana training.*
```

---

## 🎚️ Section 10 — Variables: letting Pooja's team self-serve

Right now, every panel above shows everything. Pooja's regional managers each want to see *their own* region without asking Pooja to build them a separate dashboard each.

### 10a. The chained pair: region → store

**Dashboard settings → Variables → New variable**

```
Name: region
Type: Query
Query: SELECT DISTINCT store_region FROM store.store_dimension;
```

```
Name: store
Type: Query
Query: SELECT store_name FROM store.store_dimension WHERE store_region = '$region';
```

Pick "South" in `$region` at the top of the dashboard — `$store` instantly narrows to only South's stores. This is the real "cascading filter" pattern behind production BI dashboards.

**Apply it:** go back to Section 4's Bar gauge query and add:

```sql
SELECT sd.store_name, SUM(f.sales_dollar_amount) AS store_sales
FROM store.store_sales_fact f
JOIN store.store_dimension sd ON f.store_key = sd.store_key
WHERE $__timeFilter(f.store_sales_date)
  AND sd.store_region = '$region'
GROUP BY sd.store_name
ORDER BY store_sales DESC;
```

### 10b. Multi-value: letting finance pick several categories at once

Finance's Section 6 table currently shows every category. Give them a multi-select filter instead.

```
Name: category
Type: Query
Query: SELECT DISTINCT category_description FROM public.product_dimension ORDER BY category_description;
Options: enable "Multi-value" and "Include All option"
```

Update Section 6's base query (6a) — swap the WHERE-less filter for:

```sql
SELECT
  p.category_description,
  p.department_description,
  SUM(f.sales_dollar_amount) AS category_sales,
  COUNT(DISTINCT f.product_key) AS distinct_skus
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
WHERE $__timeFilter(f.store_sales_date)
  AND p.category_description IN ($category)
GROUP BY p.category_description, p.department_description
ORDER BY category_sales DESC;
```

> ⚠️ Note the switch from `=` to `IN` — required the moment multi-value is on. Grafana expands `$category` into a properly comma-separated, quoted list automatically; you don't hand-build that logic.

### 10c. Repeat by variable: one Stat panel, one per region, automatically

Take Section 2's Stat panel (total sales). **Panel options → Repeat options → Repeat by variable → `region`** (requires `region` to be set to Multi-value first — go back and enable that).

Result: Grafana clones that one Stat panel once per region value — no copy-pasting, no manually building five near-identical tiles.

---

## 📌 Section 11 — Annotations: marking promotion dates on the trend

Pooja's marketing lead has one more ask: "Overlay our promotion dates on the sales trend — I want to see if sales actually spike when we run a promo."

**Manual version (quick, ad-hoc):** Ctrl+Click (Cmd+Click on Mac) directly on Section 1's Time series panel to drop a one-off marker with a note. Good for "hey, something happened here" during a live investigation — not for anything that should update automatically.

**Query-driven version (the real answer for this ask):**

**Dashboard settings → Annotations → New query annotation**

```sql
SELECT promotion_begin_date AS time, promotion_name AS text
FROM public.promotion_dimension
WHERE promotion_begin_date IS NOT NULL
ORDER BY promotion_begin_date;
```

Apply this to Section 1's Time series panel. Every promotion's start date now shows as a vertical marker with its name — and unlike the manual version, this updates automatically if the `promotion_dimension` table ever changes, since Grafana isn't storing its own static copy of these dates.

---

## 🚨 Section 12 — Alerting: a fresh panel, full anatomy

Pooja's last ask for today: "If online sales ever craters on a given day, someone should know." This gets its **own** panel — not reusing Section 2's Stat, to keep the alerting anatomy clean and separate from the exec-summary tile.

### The panel

```sql
SELECT SUM(sales_dollar_amount) AS daily_online_sales
FROM online_sales.online_sales_fact
WHERE $__timeFilter(online_sales_saledate);
```

Panel type: **Stat**. Field → Unit: Currency.

### The alert rule anatomy

Walk through each piece explicitly — this is the part worth slowing down on:

| Piece | What we set it to | Why |
|---|---|---|
| Query | The query above | Same as any panel — alerting reuses it |
| Condition | `IS BELOW` your Section-0-calibrated floor | The threshold that defines "something's wrong" |
| Evaluation interval | `Evaluate every: 1m` | How often Grafana re-checks |
| For duration | `5m` | Condition must stay true this long before firing — avoids flapping on one noisy blip |
| Labels | `severity: warning`, `team: retail-ops` | Used for routing once contact points/notification policies are wired up |

Click through **Alerting → Contact points** and **Alerting → Notification policies** just to see where email/Slack/PagerDuty routing would live — we're not wiring real notifications today.

> ⚠️ **Why this alert will never actually fire:** VMart is static historical data — nothing changes between evaluations, so the condition never has a chance to flip from false to true. That's fine. Today's goal is the anatomy (query → condition → interval → for-duration → labels → routing), not watching a real page go off. You'll see a genuinely live-firing alert if your track heads into Prometheus territory on Day 9.

---

## 🗂️ Recap — everything this dashboard now demonstrates

| Panel | Type | Concepts demonstrated |
|---|---|---|
| 1 | Time series | Base trend, units, decimals |
| 2 | Stat | Thresholds, repeat-by-variable |
| 3 | Gauge | Min/max range, percent unit |
| 4 | Bar gauge | Orientation, chained variable filter |
| 5 | Bar chart / Pie chart | Same query, different picker choice |
| 6 | Table | Rename by regex, Organize fields, Filter by value, Add field from calculation, Group by (stretch), cell coloring, multi-value variable |
| 7 | Histogram | Row-level vs. aggregated data |
| 8 | State timeline | Genuinely-natural categorical-over-time fit |
| 9 | Text/Markdown | No-query static content |
| — | *(dashboard-wide)* | Chained variables, multi-value + `IN`, annotations (manual + query-driven), full alert rule anatomy |

**Last thing to do:** open **Dashboard settings → JSON Model** and find this dashboard's panel array, variable definitions, and annotation config. Everything built by clicking today is sitting right there as plain JSON — exactly the "dashboards as code" idea Day 9 picks up.
