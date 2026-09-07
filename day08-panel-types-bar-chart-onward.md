# Day 8 — Panel Types, Continued: Bar Chart Onward

*Picking up right where "🎛️ Panel types — the full tour" left off. You've already covered Time series, Table, Stat, and Gauge — this section starts at Bar chart and runs through the rest of the cast.*

---

## The map, business-ask first

Before the deep dive, here's the same information reframed the way a client actually asks for it — nobody says "give me a Bar chart," they say "compare these categories." This is the translation layer:

| Business ask | Panel type(s) | Concepts folded in |
|---|---|---|
| "Compare categories side by side" | Bar chart vs Pie chart (same query) | the "one query, one picker" trick already in the guide |
| "Compare two metrics per category, not just one" | Bar chart (grouped/stacked) | multi-series queries, grouped vs stacked mode |
| "Show me the actual spread of values, not a summary" | Histogram | binning, why aggregated SQL breaks this panel |
| "Track which state something was in, over time" | State timeline | categorical time, value mappings reused for color |
| "Just put instructions/context on the dashboard — no data" | Text/Markdown | a panel with zero query at all |

Keep this table as your mental index — each row below expands one line of it.

---

## Bar chart

**Best for:** category comparison, not time-based. If the X-axis is "categories" rather than "dates," Bar chart (or Pie chart) is almost always the right instinct, not Time series.

**VMart example — the one you already have loaded:**

```sql
SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY category_sales DESC;
```

You've already seen this render as Table → Bar chart → Pie chart via the picker. Two settings turn a default bar chart into something a client would actually approve:

- **Orientation** (Panel options → Orientation): Horizontal bars read easier than vertical ones once category names get long — try switching this on the category-sales panel and see `category_description` labels stop overlapping.
- **Sort by value**: under the query or via a transformation, make sure bars render tallest-to-shortest rather than in whatever order SQL happened to return them (your `ORDER BY category_sales DESC` already handles this at the SQL layer — worth noticing that the panel just trusts the query's row order).

### Grouped/stacked bar chart — comparing two metrics per category

Bar chart panels aren't limited to one series. Query two numeric columns per category and Grafana draws them as either grouped (side-by-side) or stacked bars:

```sql
SELECT p.category_description,
       SUM(f.sales_dollar_amount) AS sales,
       SUM(f.cost_dollar_amount)  AS cost
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY sales DESC;
```

Set this as a Bar chart panel and you get two bars per category automatically — one for `sales`, one for `cost` — because Grafana treats every non-category numeric column as its own series. Under **Panel options → Bar chart → Stacking**, toggle between **Grouped** (side-by-side, easy to compare exact values) and **Stacked** (bars sit on top of each other, easier to see total + composition at once). Neither is "more correct" — it's the same "which question are you answering" judgment call as Bar vs Pie.

> 💡 **Try it:** take the sales-vs-cost query above, render it as a stacked bar chart, then flip to grouped. Notice stacked makes "which category has the biggest total footprint" obvious, while grouped makes "which category has the worst cost-to-sales ratio" easier to eyeball category-by-category.

---

## Pie chart

**Best for:** share of a whole — "what % does each slice represent," not "which is biggest" (that's still a bar chart's job, even on the same data).

**VMart example — proportion by region, not category this time, to keep the two examples visually distinct:**

```sql
SELECT s.store_region, SUM(f.sales_dollar_amount) AS region_sales
FROM store.store_sales_fact f
JOIN store.store_dimension s ON f.store_key = s.store_key
GROUP BY s.store_region
ORDER BY region_sales DESC;
```

Two settings matter more here than on any other panel type:

- **Legend values** (Panel options → Legend): switch between showing raw `region_sales` numbers and showing `%` — for a pie chart, percent is almost always what the viewer actually wants.
- **Donut vs full pie**: a cosmetic toggle, but donut mode leaves a hole in the middle that's a common spot to also drop a Stat-style total (via panel layering) — worth knowing it exists even if you don't use it today.

> ⚠️ **The mistake to avoid, restated for pie charts specifically:** once you're past 6–8 slices, a pie chart stops being readable — categories start blurring into slivers nobody can compare by eye. If your `category_description` breakdown has a dozen-plus rows, that's a **Table** or **Bar chart** job, not a pie chart, regardless of how the data is shaped. Try this yourself: take the *unfiltered* category-sales query and look at how many slices VMart's `product_dimension` actually produces — if it's more than a handful, that's your signal to switch panel types, not to fight the pie chart into being readable.

---

## Histogram

**Best for:** the distribution of a single numeric value — not "the sum by category," but "how are individual values spread out." This is the panel type most likely to trip you up, because the instinct after Time series/Table/Stat is to reach for `GROUP BY` and `SUM()` — and Histogram wants the opposite.

**VMart example — spread of individual transaction amounts:**

```sql
SELECT sales_dollar_amount
FROM store.store_sales_fact
WHERE sales_dollar_amount IS NOT NULL;
```

Notice what's *missing* compared to every other query today: no `GROUP BY`, no `SUM()`, no aggregation at all. A histogram does its own aggregation — client-side, after the query returns — by sorting your raw values into buckets and counting how many fall in each. If you aggregate in SQL first, you've already thrown away the row-level detail a histogram needs, and you'll get a flat, meaningless chart.

**The one setting that makes or breaks this panel:** Panel options → **Bucket size** (or Bucket count). Too few buckets and everything mushes into 2–3 giant bars; too many and it turns into noise. Start with Grafana's auto setting, then hand-tune once you see the shape.

> 💡 **Try it:** run the query above as a Time series panel first (it'll look like garbage — a scatter of points with no time axis to anchor them), then switch to Histogram and watch the same raw data suddenly tell a real story: most transactions cluster in a normal range, with a thin tail of unusually large ones. That contrast is the clearest illustration all day of "picking a panel type that matches what the data represents."

---

## State timeline

**Best for:** a categorical value tracked over time — think server up/down, order status codes, a machine's on/off state. It's a Time series panel's cousin, except the Y-axis is discrete labels instead of a number.

**VMart's honest limitation:** this is the one panel type on today's tour that VMart's static, historical schema doesn't naturally showcase — there's no column that represents an evolving *state*. Real-world uses are things like ops/infrastructure monitoring dashboards (a service's health status over the last 24 hours), which is more Day 9's Prometheus territory than today's SQL tables.

That said, here's a contrived-but-honest VMart approximation, treating `tender_type` (cash/credit/etc.) as a pseudo-state per transaction, so you can at least see the panel render correctly:

```sql
SELECT store_sales_datetime AS time, tender_type AS state
FROM store.store_sales_fact
WHERE store_key = 1
ORDER BY store_sales_datetime;
```

Set this as a State timeline panel and each `tender_type` value gets its own color band along the timeline — same underlying idea as **Value mappings** from earlier (turning raw data into readable, colored labels), just applied to a time axis instead of a table cell.

> ⚠️ Don't over-invest here today. The goal is recognizing the panel type and knowing when it's the right call (live status/health data) — not forcing VMart into a shape it was never designed to represent.

---

## Text / Markdown

**Best for:** static notes, instructions, links, section headers within a dashboard — anything that isn't a query result at all.

This is the one panel type where step 3 of the orientation walkthrough ("pick a data source") doesn't apply — Text/Markdown panels skip querying entirely. In the panel editor, there's no Query tab doing anything meaningful; instead, **Panel options → Content** is a plain markdown box.

**VMart example — a header panel for the dashboard you're building:**

```markdown
## VMart Sales Command Center
Store & online sales, January 2003. Filter by **region** and **store** using
the dropdowns above. Contact: training team.
```

Drop this as the first panel at the top of your dashboard, resize it to a thin strip across the full width, and it instantly reads as a real, documented deliverable instead of a loose pile of charts — the same "someone could open this tomorrow and understand it" bar the orientation section set for the whole day.

---

## Bringing it together: same query, four ways

Full-circle version of the "one query, one picker" exercise, now that you've seen every panel type on the tour:

```sql
SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY category_sales DESC;
```

Paste it once, then cycle the visualization picker through **Table → Bar chart → Pie chart**, without touching the query. Then, separately, try the *raw* (non-aggregated) version of the underlying data — individual `sales_dollar_amount` rows — as a **Histogram**. Four completely different readings of numbers that all live in the same fact table, and the only thing that changed each time was which picker option you clicked.

---

## Updated panel-type cheat sheet (full set)

**Time series** (trend) · **Table** (ranking/detail) · **Stat** (headline number) · **Gauge** (value vs. range) · **Bar gauge** (several values as mini progress bars) · **Bar chart** (category comparison, single or multi-series) · **Pie chart** (share of whole, ≤6–8 slices) · **Histogram** (distribution of raw values) · **State timeline** (categorical state over time) · **Text/Markdown** (no query, static content)
