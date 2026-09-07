# The Pooja Dashboard — One VP, Ten Panels, and "Just One More Thing"

*A single continuous build exercise covering every panel type and every major concept from Day 8 and Day 9. Build this in your live Grafana, in order — each section assumes the previous ones exist. Uses real, verified VMart schema throughout (confirmed via `\d` against a live instance — see the schema appendix at the end for the exact column dumps this is built on).*

---

## The setup

**Pooja Sharma is VMart's VP of Retail Analytics.** Three weeks ago, her manager asked for "just a quick chart of daily sales." She built one. Then the CFO saw it and wanted a headline number. Then the COO wanted margin. Then the regional heads wanted their own view. Then Finance wanted a proper table. Then the CEO wanted to be *alerted*, not asked to go look.

None of this was ever one project. It was one dashboard, growing, one request at a time — which is exactly how real dashboards get built in real companies, and exactly why you're building it the same way today.

**Create your starting point:**

1. Dashboards → New → New dashboard, name it `VMart Retail Command Center`
2. Dashboard settings (gear icon) → General → Folder → create a folder called `Retail Analytics`, save into it
3. Before building any panels, add the dashboard's first variable — Pooja's manager immediately wants the option to look at one region at a time:

```
Dashboard settings → Variables → New variable
Name: region
Type: Query
Data source: Vertica-VMart
Query: SELECT DISTINCT store_region FROM store.store_dimension ORDER BY store_region;
```

Leave it as **single-value** for now — it'll get upgraded later (Panel 4), and you'll see exactly why that upgrade has consequences.

> 💡 **Real gotcha, flagged now:** `product_dimension.category_description` is a fixed-length `char(32)` column, not `varchar` — meaning short values come back padded with trailing spaces. You'll see this bite in Panel 5. Wrap it in `TRIM()` wherever you group or display it. This is a genuinely common real-world annoyance with legacy fixed-width columns, not a course-specific trick.

---

## Panel 1 — Time series: "Just show me the trend"

**The ask:** Pooja's manager wants to see daily store revenue for January 2003, filterable down to a single region.

```sql
SELECT
    s.store_sales_date AS time,
    SUM(s.sales_dollar_amount) AS sales
FROM store.store_sales_fact s
JOIN store.store_dimension d ON s.store_key = d.store_key
WHERE $__timeFilter(s.store_sales_date)
  AND d.store_region = '$region'
GROUP BY s.store_sales_date
ORDER BY s.store_sales_date;
```

- Panel type: **Time series**
- Title it `Daily Revenue Trend`
- Set the dashboard's default time range to January 2003 (Dashboard settings → General → Time options)

**Now add a manual annotation:** pick a visible dip or spike in your chart, Ctrl+Click (Cmd+Click on Mac) directly on it, and label it something like "Cold snap kept shoppers home" — Pooja's manager asked "what happened here?" in a meeting, and now the answer's on the chart permanently.

**Then add a query-driven annotation:** VMart actually has a real promotions table — use it instead of guessing:

```sql
SELECT promotion_begin_date AS time, promotion_name AS text
FROM public.promotion_dimension
WHERE $__timeFilter(promotion_begin_date);
```

Configure this via the dashboard's annotation settings (📍 on current Grafana versions this lives in the dashboard's own sidebar, not Dashboard settings — if you see a redirect message in Dashboard settings → Annotations, click through it). Now every promotion date auto-marks itself on the graph, live, without you ever touching it again.

---

## Panel 2 — Stat: "The CFO wants one number"

**The ask:** the CFO doesn't want a chart. The CFO wants a single number, and wants to know at a glance whether it's good or bad.

```sql
SELECT SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date);
```

- Panel type: **Stat**, title `Total Revenue (Period)`
- Field → Standard options → Unit → Currency (Indian Rupee or your relevant currency)
- Field → Thresholds → set red/yellow/green cutoffs based on what your actual number looks like — note your reasoning
- Field → Value mappings → map `0` to a label like `"No transactions recorded"` — a genuine edge case if a day/period ever comes back empty, rather than showing a bare, confusing zero

**Bonus, if you did the earlier exercise on this:** reshape this into a two-row query (current period + previous period via `DATE_TRUNC` and `$__timeFrom() - INTERVAL '1 month'`) exactly like you already tested — now the Stat panel's **Percent change** setting has something real to compare against, and the CFO gets "up 12% vs last month" for free.

---

## Panel 3 — Gauge: "The COO cares about margin, not revenue"

**The ask:** revenue going up means nothing to the COO if margin is collapsing.

```sql
SELECT SUM(gross_profit_dollar_amount) * 1.0 / SUM(sales_dollar_amount) AS gross_margin
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date);
```

- Panel type: **Gauge**, title `Gross Margin`
- Field → Unit → Percent (0.0–1.0)
- Field → Thresholds — place them around whatever your actual margin comes out to; explain your choice

---

## Panel 4 — Bar gauge: "Now every regional head wants their own number"

**The ask:** every regional head separately asks Pooja for "just my region's number." Building five near-identical panels by hand is exactly the trap Day 8's repeat-by-variable feature exists to avoid.

**First, upgrade the `region` variable:** Dashboard settings → Variables → `region` → enable **Multi-value** and **Include All option**.

> ⚠️ **This breaks Panel 1 — on purpose, so you feel it.** Go back and change its filter from `d.store_region = '$region'` to `d.store_region IN ($region)`. This is the exact real-world consequence of one shared variable being reused across panels: change it once, and every dependent panel needs to keep up. Real dashboards accumulate this kind of hidden coupling constantly.

Now build the actual panel:

```sql
SELECT SUM(s.sales_dollar_amount) AS regional_sales
FROM store.store_sales_fact s
JOIN store.store_dimension d ON s.store_key = d.store_key
WHERE $__timeFilter(s.store_sales_date)
  AND d.store_region IN ($region);
```

- Panel type: **Bar gauge**, title `Revenue by Region`
- Panel options → Repeat options → Repeat by variable → `region`

One panel, cloned automatically — one bar per region, no copy-pasting.

---

## Panel 5 — Bar chart: "Merchandising wants category ranking"

**The ask:** which product categories are actually driving revenue, ranked, side by side.

```sql
SELECT TRIM(p.category_description) AS category, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p
  ON f.product_key = p.product_key AND f.product_version = p.product_version
GROUP BY TRIM(p.category_description)
ORDER BY category_sales DESC;
```

- Panel type: **Bar chart**, title `Revenue by Category`
- Notice the `TRIM()` around `category_description` — this is the fixed-width `char(32)` gotcha flagged at the top. Try removing it and look closely at the axis labels; you'll likely see inconsistent-looking spacing or grouping oddities without it.
- Transform tab → **Organize fields** → rename `category` to `Product Category` and `category_sales` to `Revenue` for cleaner axis labels

---

## Panel 6 — Pie chart: "The CMO wants channel share — store vs. online"

**The ask:** what fraction of revenue comes from physical stores vs. the online channel.

**Query A:**
```sql
SELECT 'Store' AS channel, SUM(sales_dollar_amount) AS revenue
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date);
```

**Query B:**
```sql
SELECT 'Online' AS channel, SUM(sales_dollar_amount) AS revenue
FROM online_sales.online_sales_fact
WHERE $__timeFilter(online_sales_saledate);
```

- Add both as separate query rows (A and B) in the same panel
- Transform tab → **Merge** (or **Outer join**, depending on your Grafana version — check which is available) → combines both into one two-row result
- Panel type: **Pie chart**, title `Revenue Share by Channel`

This is the real payoff of Day 8's transformations concept: two completely different fact tables, in two different schemas, combined into one panel without a SQL `UNION`.

---

## Panel 7 — Table: "Finance wants the detail, but readable"

**The ask:** a ranked store performance table — but Finance doesn't want to see internal keys, wants profit margin computed, and doesn't want to scroll past stores that barely sold anything.

```sql
SELECT
    d.store_name,
    d.store_region,
    SUM(f.sales_dollar_amount) AS total_sales,
    SUM(f.gross_profit_dollar_amount) AS total_profit
FROM store.store_sales_fact f
JOIN store.store_dimension d ON f.store_key = d.store_key
WHERE $__timeFilter(f.store_sales_date)
GROUP BY d.store_name, d.store_region
ORDER BY total_sales DESC;
```

- Panel type: **Table**, title `Store Performance`
- Transform tab → **Add field from calculation** → compute `total_profit / total_sales` as a new `profit_margin` field → format its unit as Percent (0.0–1.0)
- Transform tab → **Filter by value** → hide rows where `total_sales` is below a threshold you decide is sensible ("Pooja doesn't want stores that barely sold anything cluttering the view")
- Transform tab → **Organize fields** → rename headers for display (`store_name` → `Store`, `store_region` → `Region`, etc.)
- Field → Cell type → **Color background** on the `profit_margin` column

**Bonus — data link:** Field → Data links, on `store_name`:
```
/d/<dashboard-uid>?var-region=${__data.fields.store_region}&var-store=${__value.text}
```
Clicking a store name now jumps straight to a filtered view — genuinely one of the more impressive things to show off.

---

## Panel 8 — Histogram: "Pricing wants to see the actual spread"

**The ask:** not a total, not an average — the actual distribution of individual transaction sizes. Are most sales small with a few big outliers, or fairly even?

```sql
SELECT sales_dollar_amount
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date)
  AND sales_dollar_amount IS NOT NULL;
```

- Set **Format as: Table**, not Time Series — a histogram needs raw individual values, not a pre-aggregated time series
- Panel type: **Histogram**, title `Transaction Size Distribution`
- If this feels slow to load, add `LIMIT 5000` for the purposes of this exercise — a real production histogram would typically pre-bucket the values in SQL rather than shipping every raw row to Grafana

This is the one panel in the whole dashboard that's deliberately *not* aggregated in SQL — worth noticing the contrast with every other panel here.

---

## Panel 9 — State timeline: "Ops wants to see which selling season each day falls into"

**The ask:** a simple categorical view — which "selling season" (regular, holiday, etc.) does each date fall into.

```sql
SELECT date AS time, selling_season AS state
FROM public.date_dimension
WHERE $__timeFilter(date)
ORDER BY date;
```

- Panel type: **State timeline**, title `Selling Season Calendar`
- This is a straight query against a dimension table — no fact table join needed at all, worth noticing after eight panels that all joined back to `store_sales_fact`

> 🧪 **Worth testing, not guaranteed:** State timeline's exact expectations around string-valued time series can vary by Grafana/plugin version. If it doesn't render cleanly with "Format as: Time Series," try "Format as: Table" instead. Flag this one for your own hands-on troubleshooting — it's the least "guaranteed to work first try" panel on this list, deliberately, since real dashboard-building involves exactly this kind of trial and adjustment.

---

## Panel 10 — Text/Markdown: "The one panel with no query at all"

**The ask:** nothing analytical — just context, so the next person who opens this (or Pooja herself, six months from now) knows what they're looking at.

- Panel type: **Text / Markdown**, no data source or query needed
- Content:

```markdown
## VMart Retail Command Center
**Maintained by:** Pooja Sharma, VP Retail Analytics
**Started as:** a single daily-sales chart
**Grew into:** this — one leadership request at a time

Questions or requests? #retail-analytics
```

Every other panel in this dashboard queries something. This one is proof that not every panel has to.

---

## The epilogue — "One more thing": alerting

**The ask:** the CEO doesn't want to open the dashboard every morning. The CEO wants to be told the moment something's wrong.

On **Panel 2** (Total Revenue Stat):

1. Edit → Alert tab → Create alert rule
2. `Condition: WHEN last() OF query IS BELOW <a value you consider a meaningful floor>`
3. `Evaluate every: 1m`
4. Be ready to explain **why this specific alert has zero chance of ever firing** on this dataset — the same static-data reasoning from Day 8

**Then complete the full loop**, exactly like the CEO would actually expect:

5. Alerting (bell icon, left sidebar) → Contact points → Add contact point (Email or Webhook — doesn't need to be real for this exercise)
6. Notification policies → route your alert rule's label to that contact point

Rule → label → policy → contact point. The CEO's ask is now fully wired, even though — on this particular static dataset — it will never actually ring.

---

## The second epilogue — handing it off

**The ask:** IT wants to take over maintaining this dashboard, and needs it in a form they can actually manage.

1. Dashboard settings → JSON Model — find the `"templating"` block and confirm your `region` variable is sitting right there in the raw JSON
2. Copy the whole JSON, paste it into a new dashboard's JSON Model, rename the title — you've now proven this dashboard can be cloned and handed off without touching a single button in the UI
3. Share icon → generate a snapshot of the current state, and separately, a link with the January 2003 time range locked in
4. Note (no need to actually do this): in a real company, this dashboard and its `Vertica-VMart` data source would likely end up **provisioned** from YAML in a Git repo instead of living purely in the UI — the mature, production version of everything you just built by hand

---

## 🆘 If you get stuck

| Stuck on... | Go back to |
|---|---|
| Panel types | `day08-grafana-deep-dive.md`, "Panel types — the full tour" + Grafana manual §6 |
| Field formatting (units, thresholds, value mappings) | `day08-grafana-deep-dive.md`, "Field & panel options" + Grafana manual §7 |
| Transformations (Organize fields, Merge, Add field from calculation, Filter by value) | `day08-grafana-deep-dive.md`, "Transformations" + Grafana manual §8 |
| Variables (chained, multi-value/All, repeat-by-variable) | `day08-grafana-deep-dive.md`, "Variables — the deep dive" + Grafana manual §9 |
| Annotations (manual + query-driven, and the sidebar relocation) | `day08-grafana-deep-dive.md`, "Annotations" + Grafana manual §10 |
| Alerting (anatomy + full loop) | `day08-grafana-deep-dive.md` (anatomy) + `day09-grafana-advanced-and-prometheus.md`, Track B (full loop) + Grafana manual §11 |
| JSON Model, provisioning, sharing | `day09-grafana-advanced-and-prometheus.md`, morning session + Grafana manual §12–15 |
| Data links | `day09-grafana-advanced-and-prometheus.md`, Track B + Grafana manual §19 |

---

## Appendix — verified VMart schema this guide was built against

Confirmed via `\d` against a live instance. If your own instance shows anything different, trust your own `\d` output over this document.

**`store.store_sales_fact`** — `date_key`, `product_key`, `product_version`, `store_key`, `promotion_key`, `customer_key`, `employee_key`, `pos_transaction_number`, `sales_quantity`, `sales_dollar_amount`, `cost_dollar_amount`, `gross_profit_dollar_amount`, `transaction_type`, `transaction_time`, `tender_type`, `store_sales_date` (computed from `date_dimension` via `date_key`), `store_sales_datetime`

**`online_sales.online_sales_fact`** — `sale_date_key`, `ship_date_key`, `product_key`, `product_version`, `customer_key`, `call_center_key`, `online_page_key`, `shipping_key`, `warehouse_key`, `promotion_key`, `pos_transaction_number`, `sales_quantity`, `sales_dollar_amount`, `ship_dollar_amount`, `net_dollar_amount`, `cost_dollar_amount`, `gross_profit_dollar_amount`, `transaction_type`, `online_sales_saledate` (computed via `sale_date_key`), `online_sales_shipdate`

**`public.product_dimension`** — `product_key`, `product_version`, `product_description`, `sku_number`, `category_description` (⚠️ `char(32)`, fixed-width — `TRIM()` it), `department_description`, `package_type_description`, `package_size`, `fat_content`, `diet_type`, `weight`, `weight_units_of_measure`, `shelf_width/height/depth`, `product_price`, `product_cost`, `lowest/highest/average_competitor_price`, `discontinued_flag`

**`store.store_dimension`** — `store_key`, `store_name`, `store_number`, `store_address`, `store_city`, `store_state`, `store_region`, `floor_plan_type`, `photo_processing_type`, `financial_service_type`, `selling_square_footage`, `total_square_footage`, `first_open_date`, `last_remodel_date`, `number_of_employees`, `annual_shrinkage`, `foot_traffic`, `monthly_rent_cost`

**`public.customer_dimension`** — `customer_key`, `customer_type`, `customer_name`, `customer_gender`, `title`, `household_id`, `customer_address`, `customer_city`, `customer_state`, `customer_region`, `marital_status`, `customer_age`, `number_of_children`, `annual_income`, `occupation`, `largest_bill_amount`, `store_membership_card`, `customer_since`, `deal_stage`, `deal_size`, `last_deal_update`

**`public.date_dimension`** — `date_key`, `date`, `full_date_description`, `day_of_week`, `day_number_in_calendar_month/year`, `day_number_in_fiscal_month/year`, `last_day_in_week/month_indicator`, `calendar_week_number_in_year`, `calendar_month_name`, `calendar_month_number_in_year`, `calendar_year_month`, `calendar_quarter`, `calendar_year_quarter`, `calendar_half_year`, `calendar_year`, `holiday_indicator`, `weekday_indicator`, `selling_season`

**`public.promotion_dimension`** — `promotion_key`, `promotion_name`, `price_reduction_type`, `promotion_media_type`, `ad_type`, `display_type`, `coupon_type`, `ad_media_name`, `display_provider`, `promotion_cost`, `promotion_begin_date`, `promotion_end_date`

⚠️ **Not verified in this guide:** `public.employee_dimension`'s own columns weren't captured in the schema dump this guide was built from (only its foreign-key relationship to `store_sales_fact.employee_key` is confirmed to exist). No panel above relies on it — if you want to add an employee-performance panel of your own, run `\d public.employee_dimension` first rather than guessing column names.
