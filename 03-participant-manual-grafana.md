# Participant's Manual — Grafana (Complete Edition)

*Covers: the full Grafana block — installation recap, Day 8 (deep-dive dashboarding), and Day 9 (advanced ops + the Prometheus/Grafana Mastery split)*
*Companion to: `day04-vertica-grafana-installation-guide.md`, `day08-grafana-deep-dive.md`, `day09-grafana-advanced-and-prometheus.md`*

---

## 🎯 What this manual is for

The courseware docs have the **what** — commands, labs, copy-paste blocks, spread across three separate files now (install guide, Day 8, Day 9). This manual pulls all of it into **one place**, with the **why** and **how underneath it**, so you're not flipping between three documents trying to remember which one explained a given concept. Read it once end to end, then come back to a section whenever you want the deeper explanation behind something you just ran.

> 💡 **How to use this manual alongside the courseware:** every section below opens with a `→ Referenced in:` line telling you exactly which document and which heading it maps to. If you're mid-lab and something isn't clicking, that's your signal for which section to jump to here.

---

## 0. 🧭 Quick reference: how this environment came together

*→ Referenced in: `day04-vertica-grafana-installation-guide.md`, entire document*

You didn't build this stack today — it was set up across the earlier install session, and Grafana is already running. This section is a **map of what happened**, not a set of steps to redo. If you ever need to rebuild this environment from scratch (a new laptop, a fresh WSL2 instance, whatever), this is your pointer back to the full document.

### The chain, top to bottom

```
Windows 11
   └── WSL2 (Ubuntu)
         └── Docker Desktop (WSL2 backend)
               └── Vertica CE (running in a Docker container, port 5433)
   └── DBeaver (native Windows app, connects to Vertica over JDBC)
   └── Grafana (native Ubuntu package inside WSL2, systemd service, port 3000)
         └── Vertica Grafana plugin → talks to the same Vertica container
```

### What was installed, and where to find the full steps

| Component | What it is | Full steps live in |
|---|---|---|
| WSL2 + Ubuntu | The Linux environment everything else runs inside | `day04`, PART 2 |
| Docker Desktop + WSL2 integration | Container runtime, backing Vertica | `day04`, PARTs 3–4 |
| Vertica CE (Docker workaround) | The actual database engine, VMart sample data loaded | `day04`, PARTs 5–9 |
| DBeaver | GUI SQL client, connected to Vertica over JDBC | `day04`, PARTs 10–12 |
| Grafana (native `apt` package) | The dashboarding layer, running as `systemd` service on port 3000 | `day04`, PARTs 13–16 |
| Vertica Grafana plugin | Lets Grafana actually speak to Vertica | `day04`, PART 17 |
| Vertica data source in Grafana | The saved connection: `Vertica-VMart`, `localhost:5433`, database `demo` | `day04`, PART 18 |
| First working query + time-range fix | Proof the whole chain works end to end | `day04`, PARTs 19–20 |

### The one habit worth carrying forward

Grafana was deliberately **not** `enable`d as a service (only `start`ed) — see Section 3 below for why. Practically: **every session, before touching Grafana, run:**

```bash
sudo systemctl start grafana-server
```

If `localhost:3000` isn't loading and you haven't run that yet today, that's almost always the fix.

### Troubleshooting

If anything about the base stack itself misbehaves (Docker won't start, `vsql` can't connect, `systemctl` isn't working in WSL2, Grafana won't come up), don't reinvent the fix here — `day04` PART 22 is a full troubleshooting cheat sheet covering 18 specific known issues with their exact fixes. Check there first.

---

## 1. Grafana doesn't store data — and that changes how you should think about it

*→ Referenced in: `day04-vertica-grafana-installation-guide.md`, PART 0 ("What You Are Installing") and PART 23 ("The Mental Model Trainees Should Remember"); reinforced throughout `day08-grafana-deep-dive.md` and `day09-grafana-advanced-and-prometheus.md`*

The single most important mental model for this whole block: **Grafana holds zero data of its own.** Every panel you'll ever build is really just "run this query, right now, against some external data source, and draw whatever comes back." When you refresh a dashboard, Grafana doesn't refresh a cache — it re-runs the actual query against the actual data source, live, every time.

This has a direct, practical consequence you were meant to prove for yourself back in the install session: if you go change data in Vertica directly (an `UPDATE`, a new `INSERT`) and then refresh a Grafana panel querying that same table, the panel changes too — instantly, no separate "sync" step. Grafana is a *window*, not a copy.

### Why this matters for troubleshooting

If a Grafana panel ever shows wrong or missing data, the bug is almost never "something's broken in Grafana's storage" (there isn't any) — it's either the underlying data source, the query itself, or the panel's display settings (like a time range that doesn't overlap your actual data — see Section 5). Knowing there's no separate storage layer to distrust narrows down where to actually look.

### The one nuance worth flagging now, for later

"Grafana holds no data" is true for every data source in this course except one. Skip ahead to Section 20 when you get there: **Prometheus itself** (not Grafana) *does* retain a rolling history of scraped values. Grafana querying Prometheus is still "ask, don't store" from Grafana's side — but the *data source* it's talking to, in that one case, is doing more than a plain database table would.

---

## 2. The building-block hierarchy: data source → query → panel → dashboard

*→ Referenced in: `day04-vertica-grafana-installation-guide.md`, PART 0; this hierarchy is the spine of everything in `day08` and `day09`*

Four concepts, each one built on the last:

- **Data source** — a configured connection to somewhere data lives (Vertica, in your case — and, if you're on the Prometheus track, a second one)
- **Query** — the specific request sent to that data source when a panel loads or refreshes
- **Panel** — one visualization, built by running one query and rendering its result a particular way (graph, table, stat, etc.)
- **Dashboard** — a saved collection of panels, arranged together

This is genuinely the entire mental model of Grafana. Everything from here — panel types, transformations, variables, alerting, even Prometheus — is a variation or extension of these four ideas, never a departure from them. Even the deepest features covered later (dashboards-as-code, provisioning, data links) are still, underneath, just richer ways of configuring one of these four layers.

---

## 3. Why native install here, unlike Vertica *(background — already done, not a step to repeat)*

*→ Referenced in: `day04-vertica-grafana-installation-guide.md`, PARTs 13–15*

> This section explains the reasoning behind an install you've already completed. Nothing here needs to be re-run — treat it as context for *why* your setup looks the way it does, useful if you ever have to explain or repeat it on another machine.

Grafana OSS has a normal, actively-maintained official APT repository — no licensing gap, no ownership-change disruption, no community workaround needed. That's exactly why your install used the standard `wget` key + `apt` repository + `systemctl` pattern you'd already learned the mechanics of back on Day 3 (package management) and Day 2 (`systemctl`) — nothing there was Grafana-specific trickery, it's the same general pattern you'd use to install almost any modern Linux service package. Worth contrasting directly with Vertica: Vertica's install needed the Docker workaround specifically because of Vertica's own licensing/distribution situation (see the Vertica manual) — Grafana never had that problem.

### The `.list` extension gotcha, explained properly

When a new APT repository is added by writing a file into `/etc/apt/sources.list.d/`, `apt` only reads files ending in `.list` from that directory — this is a deliberate convention, not a Grafana requirement, so that the directory can hold other non-config files without `apt` trying to parse them as repositories. Get the filename wrong (`grafana` instead of `grafana.list`) and `apt update` silently skips it, only surfacing an easy-to-miss `N: Ignoring file...` notice — worth knowing about if you ever set this up again elsewhere, even though it's not something you need to check on your current machine.

### `enable` vs `start`, one more time — now with real stakes

You saw this distinction back in the Linux manual for `cron`. Here it matters more directly, and it's still live for you day to day: if `start` is run but Grafana was never `enable`d, it won't survive your next `wsl --shutdown`/reboot — you have to remember to `start` it manually every session. This course deliberately keeps it this way rather than relying purely on `enable`, specifically so this mechanic stays reinforced rather than becoming invisible. Practically: expect to run `sudo systemctl start grafana-server` at the beginning of each session from here on (see Section 0 above).

---

## 4. Data sources need plugins — why Vertica isn't "built in"

*→ Referenced in: `day04-vertica-grafana-installation-guide.md`, PART 17; contrasted in `day09-grafana-advanced-and-prometheus.md`, Track A*

Grafana ships with support for a handful of very common data sources out of the box, but the universe of things people connect Grafana to is enormous — Vertica included. Rather than bundle every possible integration into Grafana's core (bloating every install with things most people never use), Grafana uses a **plugin architecture**: each data source integration is a separate, installable package.

```bash
grafana cli plugins install vertica-grafana-datasource
```

This is conceptually the same idea as the Vertica JDBC driver DBeaver needed on Day 6 — a tool that doesn't natively speak a particular database's protocol needs an add-on that translates for it. Different ecosystem, same underlying idea: **core tool + swappable integration plugins**, rather than one monolithic tool that tries to speak every protocol natively.

Prometheus, by contrast, is one of the handful of data sources Grafana *does* ship with built in — no plugin install step needed, which is one of the small reasons it's a common first "second data source" for people to try after a relational database. (Full detail in Section 20.)

### Why a restart is required after installing a plugin

Grafana loads its available plugins **once, at startup** — it doesn't watch the plugins directory for live changes while running. Installing a plugin drops the files in place, but Grafana's already-running process has no way of knowing they're there until it restarts and re-scans. That's why `sudo systemctl restart grafana-server` was a mandatory step during install, not an optional "just to be safe" one.

---

## 5. Why time-series queries need a `time` column, and what `$__timeFilter` actually does

*→ Referenced in: `day04-vertica-grafana-installation-guide.md`, PARTs 19–20; used throughout `day08-grafana-deep-dive.md` and `day09-grafana-advanced-and-prometheus.md`*

Grafana's time-series/graph panels expect a specific shape from your query results: one column that represents *when* (aliased literally `time`), and one or more numeric value columns. This isn't Vertica-specific — it's how Grafana's graph rendering works across every SQL-based data source it supports.

`$__timeFilter(column)` is a **macro** — Grafana doesn't send that literal text to Vertica. Before executing your query, Grafana substitutes it with a real SQL condition based on whatever time range is currently selected in the dashboard's time picker (e.g., `store_sales_date >= '2003-01-01' AND store_sales_date <= '2003-01-31'`). This is *why* the same saved query can show "last 7 days" or "all of January 2003" without you ever editing the SQL — only the time picker changes, and the macro expands differently each time.

### Decoding "Data outside time range" properly

This message specifically means: **your SQL executed successfully, and Vertica genuinely returned rows** — but none of those rows fall inside whatever time window the panel's time picker currently covers. It is *not* an error about your query being wrong. VMart's data spans 2003–2027; Grafana's default time picker is usually something like "last 6 hours" — there's essentially zero chance of overlap by default. Recognizing this message as "time range mismatch," not "broken query," saves a lot of wasted debugging time. This is exactly why `day08` has you set a sensible default time range in **Dashboard settings → General → Time options**, rather than leaving every new dashboard on "last 6 hours."

---

## 6. Panel types — the full tour, and picking the right one

*→ Referenced in: `day08-grafana-deep-dive.md`, "Panel types — the full tour"*

You know the "big three" — Time series, Table, Stat — but the real toolkit is wider:

| Panel type | Best for | VMart example |
|---|---|---|
| **Time series** | Trend over time | Daily sales over January 2003 — needs that `time` column from Section 5 |
| **Table** | Ranked rows, raw detail | Top categories by revenue |
| **Stat** | One headline number | Total sales this period |
| **Gauge** | A number against a min/max range | "% of monthly sales target hit" |
| **Bar gauge** | Several values, each shown as a mini progress bar | Sales by store, ranked |
| **Bar chart** | Category comparison (not time-based) | Revenue per product category, side by side |
| **Pie chart** | Share of a whole | % of sales by region |
| **Histogram** | Distribution of a numeric value | Spread of individual transaction amounts |
| **State timeline** | Categorical state over time (on/off, status codes) | Rare for VMart — more common in ops monitoring (relevant again in Section 20) |
| **Text / Markdown** | Static notes, instructions, links — no query at all | "This dashboard covers Q1 2003 store sales. Contact: training team." |

> 💡 **The mistake to avoid:** choosing a panel type because it *looks* nice, not because it matches what your query result actually represents. A ranked list of categories belongs in a table or bar chart — cramming it into a time series with a fake time axis is a classic beginner move, and it actively makes the data harder to read, not easier.

**The trick worth remembering:** you can build one query, then switch the *same panel* between Table, Bar chart, and Pie chart using the visualization picker — no need to re-type or re-run the query for each. This is how `day08` has you experience, hands-on, that the query and the visualization are genuinely separate decisions.

---

## 7. Field & panel options — making data readable, not just present

*→ Referenced in: `day08-grafana-deep-dive.md`, "Field options & panel options"*

Every panel has two settings tabs worth knowing cold: **Panel options** (title, description, repeat behavior — see Section 9) and **Field** (how the actual values get displayed).

### Units

Grafana doesn't know `sales_dollar_amount` is money unless told. Under **Field → Standard options → Unit**, choosing `Currency (USD)` makes Grafana auto-format `1250000` as `$1.25M` instead of a raw number — a five-second change that makes a dashboard look genuinely professional rather than "someone's SQL homework."

### Decimals

Right next to Unit — controls how many decimal places show. For big currency totals, 0–1 decimals is usually cleaner than Grafana's default of showing every digit.

### Thresholds — turning a number into a signal

Under **Field → Thresholds**, define value ranges that change a panel's color — e.g., red below 100,000, yellow 100,000–200,000, green above 200,000. On a **Stat** or **Gauge** panel, this turns "here's a number" into "here's a number, and here's whether that number is good or bad" — at a glance, no reading required. Genuinely one of the highest-impact, lowest-effort additions to any KPI panel.

### Value mappings — renaming what the data literally says

Sometimes raw data says `1`/`0` or `Y`/`N`, and the dashboard should show something human-readable instead — "Active"/"Inactive". **Field → Value mappings** defines that translation without touching SQL. Handy for status codes or category codes that aren't self-explanatory.

### Color scheme

Under **Field → Standard options → Color scheme**, move beyond Grafana's default single-color-per-series scheme toward "Value mapped colors" (driven by thresholds) or a continuous gradient (useful for heatmap-style coloring in tables — try **Cell type → Color background** on a table panel).

---

## 8. Transformations — reshaping data *after* the query, before it hits the panel

*→ Referenced in: `day08-grafana-deep-dive.md`, "Transformations"*

### The core idea

A **transformation** operates on the *result set* your query already returned — it doesn't touch Vertica, doesn't re-run SQL, doesn't cost a database round-trip. Think of it as a lightweight, no-code step between "here's what SQL gave me" and "here's what the panel will actually draw." Found under the **Transform** tab, right next to **Query**, in any panel editor.

### Why not just fix it in SQL instead?

Fair question — often you *could* rewrite the SQL to do the same thing. Transformations earn their keep when:
- You want to reuse the exact same query across multiple panels but display it differently in each
- The reshaping is presentation-only (renaming a column header for display, without touching the underlying data)
- You're combining results from **two different queries** (or even two different data sources!) into one panel — SQL alone can't do that, but a transformation can

### The transformations worth knowing

- **Organize fields** — rename columns for display, reorder them, or hide ones you queried but don't want shown
- **Rename by regex** — bulk-rename column headers using a pattern
- **Filter by name / Filter by value** — hide specific columns, or hide *rows* based on a condition — without touching the `WHERE` clause
- **Add field from calculation** — create a brand-new column computed from existing ones, right there in the panel (e.g., a "% of total" column) — without rewriting SQL
- **Group by** — a second-pass aggregation on top of what SQL already returned; mostly useful when combining multiple queries
- **Reduce** — collapse a whole time series down to a single value per series (e.g., "just the max," "just the last value")

`day08`'s hands-on has you build a genuine "% of total sales" column purely through a transformation — nothing in the underlying SQL computes it. That's the moment this concept actually clicks: real reshaping power, with zero database cost.

---

## 9. Variables — the deep dive

*→ Referenced in: `day08-grafana-deep-dive.md`, "Variables — the deep dive"*

A dashboard variable isn't just a UI nicety — it's the difference between building **one dashboard per category** (a maintenance nightmare, and every future category needs a whole new dashboard) versus **one dashboard that adapts**. A variable's own query runs against your live data source too — meaning if a brand-new product category shows up in Vertica tomorrow, it automatically appears in the dropdown without anyone touching the dashboard's configuration.

### Variable types

| Type | What it does | Example |
|---|---|---|
| **Query** | Populated by running a query against a data source, live | `SELECT DISTINCT category_description FROM public.product_dimension` |
| **Custom** | You manually type a fixed list of options | `North,South,East,West` |
| **Interval** | A dropdown of time intervals (`1m, 5m, 1h, 1d`) | Rarely needed for static VMart data, common in live-metrics dashboards |
| **Textbox** | A free-text input box, not a dropdown | Let a viewer type an arbitrary search term |
| **Datasource** | Lets the data source itself be switchable via dropdown | Two Vertica environments (dev/prod), one dashboard for both |

### Chained (dependent) variables

Variables can depend on each other — a `region` variable, and a `store` variable that only shows stores *within* the selected region:

```sql
-- Parent
SELECT DISTINCT store_region FROM store.store_dimension;

-- Child, referencing the parent
SELECT store_name FROM store.store_dimension WHERE store_region = '$region';
```

> ⚠️ Verify `store_region`/`store_name` against your actual VMart install with `\d store.store_dimension` — naming can vary slightly by version.

Changing `$region` automatically narrows what `$store` offers — the real production pattern behind cascading-filter dashboards in any BI tool.

### Multi-value and "All"

Enabling **Multi-value** and **Include All option** on a query variable means your SQL needs `IN ($category)` instead of `= '$category'` — Grafana automatically expands `$category` into a properly comma-separated, quoted list (and handles "All" specially), as long as you use `IN`.

### Repeating panels and rows by variable

A genuinely slick feature: build **one panel**, set it to **repeat by** a multi-value variable, and Grafana clones that panel once per value automatically — one chart per region, generated for you, no copy-pasting. Configured under **Panel options → Repeat options → Repeat by variable**.

---

## 10. Annotations — marking moments on a graph

*→ Referenced in: `day08-grafana-deep-dive.md`, "Annotations"*

An **annotation** is a vertical marker line on a time-series panel, with an optional label — "here's when something happened," layered on top of "here's how the data changed."

- **Manual annotations** — Ctrl+Click (Cmd+Click on Mac) directly on a time-series panel to drop a note. Good for one-off, ad-hoc marking during a live investigation.
- **Query-driven annotations** — configured in **Dashboard settings → Annotations**, pulling timestamps and labels live from a data source (e.g., every date a promotion ran). Unlike manual annotations, these update automatically as the underlying data changes — the same "Grafana doesn't store its own copy" principle from Section 1, applied to markers instead of chart values.

---

## 11. Alerting — from anatomy to a full working loop

*→ Referenced in: `day08-grafana-deep-dive.md`, "Alerting — the real, unified alerting model"; the full loop is completed in `day09-grafana-advanced-and-prometheus.md`, Track B*

### The anatomy of an alert rule (Day 8)

Every Grafana alert rule has:
- **A query** — same as any panel, run against a data source
- **A condition** — a threshold expression evaluated against that query's result (`IS ABOVE`, `IS BELOW`, etc.)
- **An evaluation interval** — how often Grafana re-checks the condition (`Evaluate every: 1m`)
- **A "for" duration** — how long the condition must stay true before the alert actually fires (avoids flapping on a single noisy blip)
- **Labels** — key-value tags attached to the alert, used to route it to the right notification channel

### Why VMart alerts still won't fire

VMart is static historical data — nothing about it changes between one evaluation and the next — so you genuinely will not see a real alert fire in this lab, no matter how correctly you configure one. That's expected, not a sign something's broken. The goal on Day 8 is understanding *where* alert rules live and *how* a condition gets structured.

### Completing the loop (Day 9, Grafana Mastery track)

Day 8 stops at the condition. Day 9's Grafana Mastery track goes further, wiring up:
- **Contact points** (Alerting → Contact points) — destinations like email or a webhook
- **Notification policies** (Alerting → Notification policies) — routing rules matching an alert's labels to the right contact point

Walking through rule → label → policy → contact point once, even without a real firing alert on static data, means you've genuinely seen the entire alerting pipeline end to end — not just half of it.

### The one place it *can* actually fire

Prometheus data is not static — it's numbers changing every scrape interval — so it's a genuinely better fit for watching an alert evaluate meaningfully. If you're on the Prometheus track (Section 20), you'll build a `node_load1`-based alert with a real shot at tripping during class.

---

## 12. Dashboards as code — the JSON Model, properly

*→ Referenced in: `day09-grafana-advanced-and-prometheus.md`, morning session, "Dashboards as code — the JSON Model, properly this time"*

A dashboard is, underneath the drag-and-drop UI, just a big JSON object — panels are an array, variables are an array, time settings are a few keys:

```json
{
  "title": "VMart Sales Command Center",
  "panels": [ { "type": "timeseries", "title": "Daily Sales", "targets": [ ... ] } ],
  "templating": { "list": [ { "name": "region", "query": "..." } ] },
  "time": { "from": "2003-01-01", "to": "2003-01-31" }
}
```

**The practical payoff:** copy this whole JSON, paste it into a new dashboard's own JSON Model, and you've cloned the entire dashboard — panels, variables, everything — with zero clicking through the UI. This is also exactly how "Import dashboard by ID" works for community dashboards (see Section 20): someone else exported their dashboard's JSON, published it with an ID, and importing it just pastes that JSON into your Grafana.

### Dashboard versions

Every save creates a version snapshot. **Dashboard settings → Versions** shows history, lets you diff any two versions side by side, and lets you restore an older one. A genuine safety net worth knowing about before the day you need it.

---

## 13. Provisioning — dashboards-as-code, for real

*→ Referenced in: `day09-grafana-advanced-and-prometheus.md`, morning session, "Provisioning"*

Manually importing JSON is fine for one-off sharing. In a real company, dashboards and data sources are usually **provisioned** — defined in YAML files living in Git, which Grafana reads automatically on startup:

```yaml
# /etc/grafana/provisioning/datasources/vertica.yaml
apiVersion: 1
datasources:
  - name: Vertica-VMart
    type: vertica-grafana-datasource
    access: proxy
    url: localhost:5433
    jsonData:
      database: demo
      sslmode: disable
```

This wasn't set up hands-on in this course (the data source was configured through the UI, which is fine at this scale) — but recognizing the pattern matters: "dashboards live in the UI and someone clicks Save" is an early-stage setup; "dashboards and data sources are provisioned from YAML in a Git repo, code-reviewed like application code" is the mature, production pattern you'll likely meet on a real team.

---

## 14. Folders & permissions — organizing beyond one long list

*→ Referenced in: `day09-grafana-advanced-and-prometheus.md`, morning session, "Folders & permissions"*

As dashboard count grows, a flat list stops working. **Dashboards → New folder** groups related dashboards (a "Sales" folder, an "Inventory" folder). Folders also carry **permissions**, based on Grafana's role model:

| Role | Can do |
|---|---|
| **Viewer** | See dashboards, use variables/filters — no editing |
| **Editor** | Everything a Viewer can, plus create/edit dashboards and panels |
| **Admin** | Everything an Editor can, plus manage data sources, users, and permissions |

---

## 15. Sharing & exporting — getting a dashboard out of Grafana

*→ Referenced in: `day09-grafana-advanced-and-prometheus.md`, morning session, "Sharing & exporting"*

- **Share → Link** — a direct URL, optionally with the current time range/variables baked in. Best for "hey, look at this" within your own Grafana instance.
- **Share → Embed** — an iframe snippet for embedding a panel in another webpage.
- **Share → Snapshot** — a static, shareable copy of the *current data*, viewable without Grafana access. ⚠️ Public snapshots are visible to anyone with the link, and by default hosted on Grafana's own servers — never snapshot sensitive data without checking where it's stored.
- **Export → Save dashboard JSON** — the "proper" long-term way to back up or hand off a dashboard definition (see Section 12).
- **PDF / image export** — needs the separate Grafana Image Renderer plugin, not set up in this lab, but this is how "email me a PDF every Monday" gets implemented in practice.

---

## 16. Playlists — dashboards on autoplay

*→ Referenced in: `day09-grafana-advanced-and-prometheus.md`, morning session, "Playlists"*

**Dashboards → Playlists → New playlist**: pick a set of dashboards and an interval, and Grafana auto-cycles through them. This is the feature behind those big wall-mounted monitors in NOCs (Network Operations Centers) or open-plan offices, silently rotating through system-health dashboards all day. Mostly "nice to know it exists" for this course.

---

## 17. Query performance — Vertica-specific habits

*→ Referenced in: `day09-grafana-advanced-and-prometheus.md`, morning session, "Query performance"*

- **Never `SELECT *`** in a Grafana panel query — Vertica is columnar, specifically optimized to only read the columns you actually ask for. `SELECT *` forces it to read everything.
- **Aggregate in SQL, not in the panel** — `GROUP BY`/`SUM()` in your query beats pulling raw rows and making a transformation do the aggregating.
- **Always use `$__timeFilter()`** on time-series queries rather than hardcoding date ranges — Vertica then only scans the relevant partition of data.
- **Set a sensible refresh interval** — a dashboard auto-refreshing every 5 seconds re-runs every panel's SQL every 5 seconds. For historical VMart data that never changes, there's no reason for that; set refresh to "Off" or a few minutes, and only tighten it for genuinely live data (Section 20).

---

## 18. Explore mode — the deeper tour

*→ Referenced in: `day09-grafana-advanced-and-prometheus.md`, morning session, "Explore mode"*

Beyond basic ad-hoc querying:
- **Split view** — run two queries side by side, even against two *different* data sources at once (e.g., Vertica next to Prometheus). Handy for comparison without building a whole dashboard.
- **Query history** — Explore keeps a running history of every query run per data source, so a query from an hour ago doesn't have to be retyped from memory.

---

## 19. Data links — click-through drill-downs

*→ Referenced in: `day09-grafana-advanced-and-prometheus.md`, Track B (Grafana Mastery Lab)*

A **data link**, set under a field's options (**Field → Data links**), turns a value in a panel into a clickable link — either to an external URL, or to *another dashboard within Grafana*, optionally carrying the clicked value along as a variable:

```
/d/<dashboard-uid>?var-category=${__value.text}
```

`${__value.text}` means "whatever value was just clicked." Clicking a category name in a ranking table can open a second dashboard already filtered to that exact category — a genuinely impressive, genuinely useful thing to show off in a capstone demo.

---

## 20. 🧭 Prometheus — the exception, and brief guidance

*→ Referenced in: `day09-grafana-advanced-and-prometheus.md`, Track A (afternoon)*

*This section is not required for the core Vertica+Grafana deliverable — it's the afternoon-of-Day-9 stretch topic for whoever's on that track. If you were on the Grafana Mastery track (Track B) instead, this is still worth a read: your teammates will demo this at the end-of-day reconvene, and understanding the shape of it makes that demo land.*

### What Prometheus actually is

Prometheus is a **metrics database that also collects its own data** — the one meaningful exception flagged back in Section 1. Rather than pointing it at a table like Vertica, Prometheus **scrapes** (pulls, on a schedule) metrics from small helper programs called **exporters**, running on whatever machine you want visibility into.

```
[node_exporter on WSL2] --scraped by--> [Prometheus] <--queried by-- [Grafana]
```

Three distinct jobs, three distinct tools:
- **node_exporter** — reads OS-level counters (CPU, RAM, disk, network) and exposes them as plain-text metrics on a local port (`:9100`)
- **Prometheus** — pulls those metrics on a timer and stores a rolling history of them (`:9090`)
- **Grafana** — queries Prometheus (via **PromQL**, its own query language — not SQL) and draws the result, exactly like it does for Vertica — same data source → query → panel → dashboard skeleton from Section 2

### The minimum viable path (fast-tracked)

1. Install and run **node_exporter** — exposes metrics at `http://localhost:9100/metrics`
2. Install and run **Prometheus**, pointed at a `prometheus.yml` config listing `localhost:9100` as a scrape target
3. In Grafana: **Connections → Data sources → Add data source → Prometheus** (built in, no plugin needed) → URL `http://localhost:9090` → **Save & test**
4. Import a ready-made community dashboard by ID — **dashboard ID `1860`** ("Node Exporter Full") — rather than building panels from scratch: **Dashboards → New → Import**, paste the ID, pick your Prometheus data source, done

That last step is deliberate: the goal is seeing the *pattern* (scrape → store → query → visualize) working end to end quickly, not hand-authoring PromQL under time pressure.

### PromQL, in one paragraph

Where a Vertica panel runs `SELECT ... WHERE $__timeFilter(...)`, a Prometheus panel runs a PromQL expression like `rate(node_cpu_seconds_total[5m])`. Recognize the shape rather than memorize the syntax: it's still "a query that returns a time-series result," just suited to metrics rather than rows.

### Why alerting feels more "real" here than with VMart

Section 11 above noted that VMart never changes, so alerts can't meaningfully fire. Live CPU/RAM/disk numbers from `node_exporter` genuinely fluctuate second to second — a rule like `node_load1 IS ABOVE 2` has an actual chance of tripping during class, which is the payoff moment VMart genuinely couldn't offer.

### What this does *not* replace

Prometheus is a good second example of the pull-based data source pattern — it is **not** a substitute for the Vertica/SQL dashboarding skills that are the actual client deliverable. If time is limited, a solid, working Vertica dashboard always beats a rushed Prometheus one.

---

## 21. How it all fits together

**Install session (`day04`) — the foundation, done once.** WSL2, Docker, Vertica CE + VMart, DBeaver, Grafana, the Vertica plugin, the data source connection, and a first working query. Everything from here assumes this is solid ground.

**Day 8 — the mechanic, mastered.** Panel types, field formatting, transformations, variables (including chained and repeat-by-variable), annotations, and alert-rule anatomy — all built hands-on into one comprehensive dashboard against real Vertica/VMart data. This is where "I can connect Grafana to a database" becomes "I can build a genuinely good dashboard."

**Day 9 morning — how it's actually run in a company.** Dashboards as code (JSON Model, provisioning), folders and permissions, sharing and exporting, playlists, Vertica-specific query performance habits, and a deeper look at Explore. Same room, same content, no split yet.

**Day 9 afternoon — a fork.** Two paths:
- **Track A (Prometheus)** — a stretch topic, outside the core deliverable, showing the *other* major Grafana pattern: metrics-scraping instead of database querying, using the exact same data source → query → panel → dashboard skeleton.
- **Track B (Grafana Mastery)** — two new lightweight concepts (data links, the full alerting loop with contact points and notification policies) plus a guided rebuild of the whole Day 8 skillset against a fresh schema (`online_sales` instead of `store`), unaided.

Both tracks reconvene for a short show-and-tell — Track A demos live system metrics, Track B demos a drill-down and a complete alerting pipeline.

**Capstone — you, unassisted.** The core version of all of the above (Vertica + Grafana, start to finish, on a fresh dataset) is the baseline deliverable for everyone. Anyone who went through Track A may optionally extend their capstone with a Prometheus panel — but it's a bonus, never a requirement.

---

## 📌 Quick-reference: "why" answers you'll want most

| You ask | Short answer |
|---|---|
| Why doesn't refreshing a dashboard need a "sync" step? | Grafana has no storage of its own — every refresh re-runs the real query live. |
| Why does apt silently ignore my new repo file sometimes? | It must end in `.list` — anything else in `sources.list.d/` gets skipped, with only a small `N: Ignoring...` warning. |
| Why install a plugin for Vertica specifically? | Grafana only bundles a handful of data sources by default; everything else — Vertica included — is a separate installable plugin. |
| Why restart Grafana after installing a plugin? | Plugins are only scanned at startup, not watched live while running. |
| Why does my panel say "Data outside time range" when my SQL is fine? | Your query worked — the *time picker's* selected window just doesn't overlap where your actual data's timestamps fall. |
| Why use a variable instead of just hardcoding a filter? | One adaptable dashboard vs. one dashboard per possible value — and it stays current as new values appear in the data. |
| Why use `IN ($var)` instead of `= '$var'`? | Only `IN` works once a variable is set to Multi-value/All — Grafana expands it into a proper comma-separated list. |
| What does "repeat by variable" actually do? | Clones one panel automatically, once per value in a multi-value variable — no manual copy-pasting. |
| Why bother with transformations instead of just fixing the SQL? | Reuse the same query across panels differently, combine two queries/data sources in one panel, or reshape purely for display. |
| Why didn't my alert ever fire in the Day 8 lab? | VMart is static data — nothing changes between evaluations, so no condition can ever trip. Expected, not broken. |
| What's the difference between an alert *rule* and a *contact point*? | The rule defines the condition; the contact point is where a firing alert actually gets sent — two separate pieces you wire together with a notification policy. |
| Why look at a dashboard's JSON Model at all? | It's the real, portable definition of the dashboard — copy it to clone a dashboard, or hand it off entirely without touching the UI. |
| What's the difference between exporting JSON and provisioning? | Exporting JSON is a manual, one-off copy; provisioning is Grafana automatically loading dashboards/data sources from YAML in Git on startup — the production pattern. |
| Why doesn't Prometheus need a plugin like Vertica does? | It's one of the handful of data sources bundled into Grafana core by default. |
| Why does Prometheus "break the rule" that Grafana's data sources hold no data themselves? | It doesn't — Grafana still just queries it. Prometheus itself, though, does collect and retain a history, unlike a plain SQL table you populated yourself. |
| Why is a Prometheus alert more likely to actually fire than a VMart one? | Live system metrics genuinely change every scrape; VMart is static historical data that never does. |
