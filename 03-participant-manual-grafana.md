# Participant's Manual — Grafana

*Covers: Days 8–9 (Intro & Install, Dashboarding)*
*Companion to: `day08`–`day09` courseware*

---

## 🎯 What this manual is for

The daywise courseware has the **what** — commands, labs, copy-paste blocks. This manual has the **why** and **how underneath it**, so you understand what's actually happening instead of just pattern-matching commands. Read it once end to end, then come back to a section when you want the deeper explanation behind something you just ran.

> 💡 **Worth noting up front:** unlike Vertica (Days 5–7), Grafana in this course installs the *normal*, production-equivalent way — native package, real `systemctl` service. There's no Docker-workaround asterisk here. What you install in this lab is architecturally the same thing a real company would run, just smaller-scale. That's a meaningful contrast worth keeping in mind against the Vertica manual's warning.

---

## 1. Grafana doesn't store data — and that changes how you should think about it

*→ Referenced in: `day08-grafana-intro-install.md`, Concepts*

The single most important mental model for this whole block: **Grafana holds zero data of its own.** Every panel you'll ever build is really just "run this query, right now, against some external data source, and draw whatever comes back." When you refresh a dashboard, Grafana doesn't refresh a cache — it re-runs the actual query against the actual data source, live, every time.

This has a direct, practical consequence you'll prove for yourself in the Day 9 lab: if you go change data in Vertica directly (an `UPDATE`, a new `INSERT`) and then refresh a Grafana panel querying that same table, the panel changes too — instantly, no separate "sync" step. Grafana is a *window*, not a copy.

### Why this matters for troubleshooting

If a Grafana panel ever shows wrong or missing data, the bug is almost never "something's broken in Grafana's storage" (there isn't any) — it's either the underlying data source, the query itself, or the panel's display settings (like a time range that doesn't overlap your actual data, which you'll hit directly today). Knowing there's no separate storage layer to distrust narrows down where to actually look.

---

## 2. The building-block hierarchy: data source → query → panel → dashboard

*→ Referenced in: `day08-grafana-intro-install.md`, Concepts*

Four concepts, each one built on the last:

- **Data source** — a configured connection to somewhere data lives (Vertica, in your case)
- **Query** — the specific request sent to that data source when a panel loads or refreshes
- **Panel** — one visualization, built by running one query and rendering its result a particular way (graph, table, stat, etc.)
- **Dashboard** — a saved collection of panels, arranged together

**Why TestData DB on Day 8, before touching real Vertica data:** it isolates the *mechanic* (data source → query → panel) from any actual database complexity. If something goes wrong on Day 8, you know it's a Grafana-UI issue, not a Vertica connectivity issue — genuinely useful for building confidence before Day 9 adds a second system's worth of things that could go wrong.

---

## 3. Why native install here, unlike Vertica

*→ Referenced in: `day08-grafana-intro-install.md`, Installing Grafana natively*

Grafana OSS has a normal, actively-maintained official APT repository — no licensing gap, no ownership-change disruption, no community workaround needed. That's exactly why this install uses the standard `wget` key + `apt` repository + `systemctl` pattern you already learned the mechanics of back on Day 3 (package management) and Day 2 (`systemctl`) — nothing here is Grafana-specific trickery, it's the same general pattern you'd use to install almost any modern Linux service package.

### The `.list` extension gotcha, explained properly

When you add a new APT repository by writing a file into `/etc/apt/sources.list.d/`, `apt` only reads files ending in `.list` from that directory — this is a deliberate convention, not a Grafana requirement, so that the directory can hold other non-config files without `apt` trying to parse them as repositories. Get the filename wrong (`grafana` instead of `grafana.list`) and `apt update` will silently skip it, only telling you via an easy-to-miss `N: Ignoring file...` notice — which is exactly why the courseware calls this out explicitly as something to watch for.

### `enable` vs `start`, one more time — now with real stakes

You saw this distinction back in the Linux manual for `cron`. Here it matters more directly: if you `start` Grafana but never `enable` it, it won't survive your next `wsl --shutdown`/reboot — you'd have to remember to `start` it manually every single session. This course deliberately has you run `start` each morning rather than relying purely on `enable`, specifically so this mechanic stays reinforced rather than becoming invisible.

---

## 4. Data sources need plugins — why Vertica isn't "built in"

*→ Referenced in: `day09-grafana-dashboarding.md`, Concepts + Installing the Vertica plugin*

Grafana ships with support for a handful of very common data sources out of the box, but the universe of things people connect Grafana to is enormous — Vertica included. Rather than bundle every possible integration into Grafana's core (bloating every install with things most people never use), Grafana uses a **plugin architecture**: each data source integration is a separate, installable package.

```bash
grafana cli plugins install vertica-grafana-datasource
```

This is conceptually the same idea as the Vertica JDBC driver DBeaver needed on Day 6 — a tool that doesn't natively speak a particular database's protocol needs an add-on that translates for it. Different ecosystem, same underlying idea: **core tool + swappable integration plugins**, rather than one monolithic tool that tries to speak every protocol natively.

### Why a restart is required after installing a plugin

Grafana loads its available plugins **once, at startup** — it doesn't watch the plugins directory for live changes while running. Installing a plugin drops the files in place, but Grafana's already-running process has no way of knowing they're there until it restarts and re-scans. That's why `sudo systemctl restart grafana-server` is a mandatory step here, not an optional "just to be safe" one.

---

## 5. Why time-series queries need a `time` column, and what `$__timeFilter` actually does

*→ Referenced in: `day09-grafana-dashboarding.md`, "Why time-series queries need a time column" + "Your first real query"*

Grafana's time-series/graph panels expect a specific shape from your query results: one column that represents *when* (aliased literally `time`), and one or more numeric value columns. This isn't Vertica-specific — it's how Grafana's graph rendering works across every SQL-based data source it supports.

`$__timeFilter(column)` is a **macro** — Grafana doesn't send that literal text to Vertica. Before executing your query, Grafana substitutes it with a real SQL condition based on whatever time range is currently selected in the dashboard's time picker (e.g., `store_sales_date >= '2003-01-01' AND store_sales_date <= '2003-01-31'`). This is *why* the same saved query can show "last 7 days" or "all of January 2003" without you ever editing the SQL — only the time picker changes, and the macro expands differently each time.

### Decoding "Data outside time range" properly

This message specifically means: **your SQL executed successfully, and Vertica genuinely returned rows** — but none of those rows fall inside whatever time window the panel's time picker currently covers. It is *not* an error about your query being wrong. VMart's data spans 2003–2027; Grafana's default time picker is usually something like "last 6 hours" — there's essentially zero chance of overlap by default. Recognizing this message as "time range mismatch," not "broken query," saves a lot of wasted debugging time.

---

## 6. Panel types — picking the right one, not just any one

*→ Referenced in: `day09-grafana-dashboarding.md`, "Building panels"*

- **Time series** — for anything where "how did this change over time" is the actual question. Needs that `time` column.
- **Table** — for anything where you want to see individual rows/rankings, not a trend. No `time` column requirement.
- **Stat** — for a single headline number someone should see at a glance ("total sales this period"). Deliberately strips away detail in favor of instant readability.

The mistake worth avoiding: picking a visualization type because it looks nice, rather than because it matches what the query result actually represents. A ranked list of categories by sales genuinely belongs in a table, not forced into a bar-chart-style time series with no real time dimension.

---

## 7. Variables — why they matter beyond convenience

*→ Referenced in: `day09-grafana-dashboarding.md`, "Variables — making a dashboard dynamic"*

A dashboard variable isn't just a UI nicety — it's the difference between building **one dashboard per category** (a maintenance nightmare, and every future category needs a whole new dashboard) versus **one dashboard that adapts**. The variable's own query (`SELECT DISTINCT category_description FROM ...`) runs against your live data source too — meaning if a brand-new product category shows up in Vertica tomorrow, it automatically appears in the dropdown without anyone touching the dashboard's configuration. This is the actual production pattern: dashboards built to adapt to data, not dashboards rebuilt every time the underlying data changes shape.

---

## 8. Alerting — what you're seeing today, and what you're not

*→ Referenced in: `day09-grafana-dashboarding.md`, "Basic alerting"*

Grafana's alerting evaluates a panel's query result against a condition on a schedule (`Evaluate every: 1m`, for instance), and can notify somewhere when the condition is met. VMart is static historical data — nothing about it changes between one evaluation and the next — so you genuinely will not see a real alert fire in this lab, no matter how correctly you configure one. That's expected, not a sign something's broken. The goal today is understanding *where* alert rules live and *how* a condition gets structured — a real production setup would point this at a live, changing metric (current server load, live sales figures, an error rate) where the condition meaningfully could trip.

---

## 9. How the two Grafana days fit together

**Day 8 — The mechanic, isolated.** Install, verify, and learn "data source → query → panel" using fake data (TestData DB) specifically so nothing about a real database can confuse what's a pure-Grafana-UI question.

**Day 9 — The real thing.** Same exact mechanic, now pointed at your own live Vertica instance from Days 5–7 — plugin, real queries, real panels, variables, and a first look at alerting. This is also the day that closes the loop on the entire course: Linux (Days 1–4) got you an environment, Vertica (Days 5–7) got you real data, and Grafana (Days 8–9) turns that data into something you can actually show someone. Day 10's capstone is you doing all three, unassisted.

---

## 📌 Quick-reference: "why" answers you'll want most

| You ask | Short answer |
|---|---|
| Why doesn't refreshing a dashboard need a "sync" step? | Grafana has no storage of its own — every refresh re-runs the real query live. |
| Why TestData DB before real Vertica? | Isolates "am I using Grafana right" from "is my database connection right" — one variable at a time. |
| Why does apt silently ignore my new repo file sometimes? | It must end in `.list` — anything else in `sources.list.d/` gets skipped, with only a small `N: Ignoring...` warning. |
| Why install a plugin for Vertica specifically? | Grafana only bundles a handful of data sources by default; everything else — Vertica included — is a separate installable plugin. |
| Why restart Grafana after installing a plugin? | Plugins are only scanned at startup, not watched live while running. |
| Why does my panel say "Data outside time range" when my SQL is fine? | Your query worked — the *time picker's* selected window just doesn't overlap where your actual data's timestamps fall. |
| Why use a variable instead of just hardcoding a filter? | One adaptable dashboard vs. one dashboard per possible value — and it stays current as new values appear in the data. |
| Why didn't my alert ever fire in this lab? | VMart is static data — nothing changes between evaluations, so no condition can ever trip. Expected, not broken. |
