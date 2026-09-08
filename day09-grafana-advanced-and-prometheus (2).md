# Day 9 — Advanced Grafana Ops, then a Fork: Prometheus Track vs. Grafana Mastery Track

*Tue — full day, structure changes after lunch*

---

## 🔁 Recap: Day 8

You went deep on panels, field formatting, transformations, chained variables, panel repeats, annotations, and alerting anatomy — and built a full multi-panel "Sales Command Center" dashboard against real Vertica/VMart data. You also peeked at the raw JSON Model behind a dashboard for the first time. Today builds directly on that last bit.

---

## 🌅 Morning session — everyone together

This morning is about **how Grafana gets used and managed in an actual company**, not just how to build one dashboard. Same room, same content, no split yet.

### 📚 Concepts

#### Dashboards as code — the JSON Model, properly this time

Yesterday you glanced at **Dashboard settings → JSON Model** and saw that a dashboard is really just a big JSON object. Today, let's actually use that.

A dashboard's JSON has (roughly) this shape:

```json
{
  "title": "VMart Sales Command Center",
  "panels": [ { "type": "timeseries", "title": "Daily Sales", "targets": [ ... ] }, ... ],
  "templating": { "list": [ { "name": "region", "query": "..." } ] },
  "time": { "from": "2003-01-01", "to": "2003-01-31" }
}
```

Why this matters practically: you can **copy this entire JSON, paste it into a text file, and hand it to a teammate** — they import it via **Dashboards → New → Import** (📍 the same "New" button from yesterday's orientation, top-right of the Dashboards list — just pick "Import" from the dropdown instead of "New dashboard"), paste the JSON, and get an exact working copy of your dashboard, panels, variables, and all. This is also how the "Import dashboard by ID" trick works (the one you'll use for Prometheus this afternoon, if that's your track) — someone else built a dashboard, exported its JSON, published it publicly with an ID number, and you're importing that exact JSON into your own Grafana, through that same Import screen.

**Try it now:** open your Day 8 dashboard's JSON Model, copy the whole thing, open a **new** dashboard, go to its JSON Model, and paste your copied JSON in, replacing what's there. Save. You've just cloned a dashboard purely through JSON — no clicking through the UI at all.

#### Dashboard versions — Grafana's built-in undo history

Every time you save a dashboard, Grafana keeps a version snapshot. **Dashboard settings → Versions** shows the history, lets you compare any two versions side-by-side (a proper diff view), and lets you restore an older version if you mess something up. This is a genuinely useful safety net — worth knowing it exists *before* the day you accidentally wreck a dashboard right before a demo.

#### Provisioning — the production-grade version of "dashboards as code"

Manually importing JSON is fine for one-off sharing. In a real company, dashboards and data sources are usually **provisioned** — defined in YAML config files that live in source control (Git), and Grafana reads them automatically on startup. This means a dashboard's entire definition — including which data source it uses — is version-controlled, code-reviewed, and deployable, exactly like application code.

A provisioning config for a data source looks roughly like this:

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

You won't set this up hands-on today (your data source is already configured through the UI, and that's fine for this course) — but recognizing this pattern matters: if you ever join a team running Grafana at scale, "dashboards live in the UI and someone clicks Save" is usually a sign of an *early-stage* setup, while "dashboards and data sources are provisioned from YAML in a Git repo" is the more mature, production pattern.

#### Folders & permissions — organizing beyond "one long list of dashboards"

As dashboard count grows, a flat list gets unmanageable fast. On the same **Dashboards** list page from yesterday, that "New" dropdown (top-right) has more than one option — **New folder** is right there next to "New dashboard" and "Import." Pick it to group related dashboards (e.g., a "Sales" folder, an "Inventory" folder). Folders also carry **permissions** — you can restrict who can view or edit dashboards within a folder, based on Grafana's role model:

| Role | Can do |
|---|---|
| **Viewer** | See dashboards, use variables/filters — no editing |
| **Editor** | Everything a Viewer can, plus create/edit dashboards and panels |
| **Admin** | Everything an Editor can, plus manage data sources, users, and permissions |

**Try it:** create a folder called `VMart Training`, move both your dashboards into it, then open **Folder permissions** and just look at what's configurable — no need to actually restrict anyone in this training environment.

#### User management — Users, Teams, and Service accounts

Yesterday's orientation flagged **Administration** in the sidebar and moved on ("no need to touch it today"). Today's the day to actually look inside it, since permissions (above) mean nothing without knowing who they're being granted to.

- **Users** — individual human logins, each with an org-wide default role (Viewer/Editor/Admin), which folder/dashboard permissions can then override more specifically.
- **Teams** — a group of users, so permissions can be granted once to "the Sales team" rather than repeated per person. This is what folder permissions were actually built to point at in a real company, not individual users one by one.
- **Service accounts** — the one genuinely new idea here, and the most relevant if you ever touch Grafana outside the browser: a non-human identity, used when a **script or CI pipeline** needs to talk to Grafana's API (e.g., automatically provisioning a dashboard, or pulling data out programmatically) rather than a person clicking around. A service account gets an **API key/token** instead of a password — that token is what a script authenticates with.

**Try it:** Administration → Users and access → Service accounts → create one, generate a token, and just look at what you're given (you don't need to actually use it anywhere today). This is genuinely the mechanism behind "provisioning" from earlier this morning working automatically without a human logging in every time.

#### Sharing & exporting — getting a dashboard out of Grafana

📍 **Where this lives:** open any dashboard, and look for a **Share icon** in the top toolbar — right next to the Save button and the gear icon you learned yesterday. Click it, and everything below shows up as tabs inside that one panel.

A few different "share" mechanisms exist, each suited to a different situation:

- **Share → Link** — a direct URL to the dashboard, optionally with the current time range and variable selections baked in. Best for "hey, look at this" within your own Grafana instance.
- **Share → Embed** — an iframe snippet, for embedding a panel inside another webpage. Requires the target page to be able to reach your Grafana instance.
- **Share → Snapshot** — captures the *current data* as a static, shareable copy — useful for sharing a specific moment in time with someone who doesn't have Grafana access at all. ⚠️ Public snapshots are visible to anyone with the link and are hosted (by default) on Grafana's own servers if you don't have snapshot storage configured — never snapshot anything containing sensitive data without checking where it's actually being stored.
- **Public dashboards** — a newer, different mechanism from both of the above: a live (not static) link that anyone can open **with no Grafana login at all**. Unlike a Snapshot, it stays current as the underlying data changes; unlike a regular Share Link, the viewer never needs an account. Increasingly the default way people share a dashboard outside their own company — worth knowing this exists even if you don't set one up today, since it's easy to confuse with Snapshot or Link at a glance.
- **Export → Save dashboard JSON** — what we used above for the copy-paste trick; the "proper" long-term way to back up or hand off a dashboard definition.
- **PDF / image export** — needs the separate Grafana Image Renderer plugin installed; not set up in this lab, but worth knowing it's how "email me a PDF of this dashboard every Monday" gets implemented in practice.

#### Dashboard Links — a different, dashboard-wide cousin of Data links

Don't confuse this with **Data links**, which you'll meet this afternoon if you're on Track B — that's a link tied to one specific field's *value* (click "Medical," jump somewhere filtered to Medical). This is simpler and un-tied to any data at all: **Dashboard settings → Links → New link** lets you add a small nav bar of URLs or links to other dashboards, shown at the top of the *whole* dashboard regardless of what any panel contains. Think "quick links to the three dashboards my team always jumps between" rather than anything driven by a query result.

#### Tags — making dashboards findable once you have more than a handful

Every dashboard has a `"tags": []` field sitting in its JSON Model that this course hasn't touched yet — **Dashboard settings → General → Tags**. Add a couple (e.g., `training`, `vmart`, `sales`) and they become filterable on the main Dashboards list page. Trivial to set up, genuinely useful the moment more than a few dashboards exist — which, by the end of today, yours will.

#### Playlists — dashboards on autoplay

📍 **Where this lives:** back on the **Dashboards** list page — look for a **Playlists** link near the top, close to the "New" button (some Grafana versions tuck it under a "..." menu on that same page if it's not immediately visible). **New playlist**: pick a set of dashboards and an interval (e.g., 30 seconds), and Grafana will auto-cycle through them. This is *the* feature behind those big wall-mounted monitors you see in NOCs (Network Operations Centers) or open-plan offices, silently rotating through system-health dashboards all day. Purely a "nice to know it exists" feature for this course, but a fun one.

#### Query performance — Vertica-specific tips, now that you're building real dashboards

A few habits worth building now, before they become bad habits later:

- **Never `SELECT *`** in a Grafana panel query — Vertica is a columnar database, and it's *specifically* optimized to only read the columns you actually ask for. `SELECT *` forces it to read everything, which is slower and, at scale, expensive.
- **Aggregate in SQL, not in the panel** — `GROUP BY` and `SUM()` in your query is far more efficient than pulling raw rows into Grafana and trying to make a transformation do the aggregating.
- **Always use `$__timeFilter()`** on time-series queries rather than hardcoding date ranges — it's not just about convenience, it also means Vertica only scans the relevant partition of data instead of the whole table.
- **Set a sensible dashboard refresh interval** — a dashboard set to auto-refresh every 5 seconds re-runs every single panel's SQL every 5 seconds. For historical VMart data that never changes, there's no reason for that. Set refresh to "Off" or something sane like 5 minutes, and only tighten it for genuinely live data (a lesson that becomes very real this afternoon, if you're on the Prometheus track).

#### Explore mode — the deeper tour

You've used **Explore** for quick ad-hoc queries already. Two features worth knowing:

- **Split view** — click the split icon to run two queries side by side, even against two *different* data sources at once. Handy for comparing a Vertica query against a MySQL query without building a whole dashboard.
- **Query history** — Explore keeps a running history of every query you've run, per data source, so you can dig up something you tried an hour ago without having to remember or retype it.

---

## 🍽️ After lunch: the room splits

Two paths from here. Find your track below.

---

## 🅰️ Track A — Prometheus (for the pair with the extra runway)

*This is a stretch topic, outside the client's core Vertica+Grafana ask — genuinely worth your time, but don't sweat perfection here. The goal is understanding the pattern, not mastering PromQL.*

### 📚 Concepts

#### The one real exception to "Grafana never collects data"

Everything you've built so far follows one rule: Grafana asks, something else (Vertica) already has the answer ready. Prometheus is the one system in this course that breaks that a little — **Prometheus itself does the collecting.** It's a metrics database that actively **scrapes** (pulls, on a repeating schedule) numeric data from small helper programs called **exporters**, running on whatever machine you want visibility into.

```
[node_exporter on WSL2] --scraped by--> [Prometheus] <--queried by-- [Grafana]
```

Three tools, three jobs:
- **node_exporter** — reads OS-level counters (CPU, RAM, disk, network) and exposes them as plain-text metrics on a local port
- **Prometheus** — pulls those metrics on a timer, stores a rolling history
- **Grafana** — queries Prometheus using **PromQL** (its own query language, not SQL) and draws the result — same data source → query → panel → dashboard skeleton as every Vertica panel you've built

#### Why this is worth your afternoon

This is, by a wide margin, the most common real-world Grafana pairing — especially in DevOps, SRE, and cloud-native teams. Knowing it exists, and having actually touched it once, is genuinely resume-relevant in a way that most "extra" course content isn't.

### 🛠️ Fast-tracked setup

Speed over depth here — the goal is seeing the whole pipeline light up, not hand-crafting configs.

**1. Install node_exporter (WSL2 Ubuntu):**

```bash
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
cd node_exporter-1.8.2.linux-amd64
./node_exporter &
```

Confirm it's exposing metrics:

```bash
curl localhost:9100/metrics | head -20
```

You should see a wall of plain-text metric lines — that's the raw, unprocessed format Prometheus is built to scrape.

**2. Install Prometheus:**

```bash
cd ~
wget https://github.com/prometheus/prometheus/releases/download/v2.54.1/prometheus-2.54.1.linux-amd64.tar.gz
tar xvf prometheus-2.54.1.linux-amd64.tar.gz
cd prometheus-2.54.1.linux-amd64
```

**3. Point it at node_exporter — edit `prometheus.yml`:**

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

**4. Run Prometheus:**

```bash
./prometheus --config.file=prometheus.yml &
```

**5. Confirm it's scraping:** open `http://localhost:9090` in your browser (Prometheus's own basic UI) → **Status → Targets** → you should see the `node` job showing `State: UP`.

**6. Add Prometheus as a Grafana data source:**

Grafana ships with Prometheus support **built in** — no plugin install needed, unlike Vertica. This is the exact same screen and flow you used to add Vertica back during install — **Connections → Data sources** in the left sidebar (📍 the one you've already visited once before) — just search for "Prometheus" instead of "Vertica" this time:

```
Connections → Data sources → Add data source → Prometheus
URL: http://localhost:9090
→ Save & test
```

**7. Import the standard community dashboard:**

```
Dashboards → New → Import
Dashboard ID: 1860   ("Node Exporter Full")
→ select your Prometheus data source
→ Import
```

You should now see a full, pre-built dashboard — CPU, memory, disk, network — live-updating from your own WSL2 instance. This is the exact "Task Manager, but with history and dashboards" outcome you were originally asking about, several conversations ago.

### PromQL, in one paragraph

Where a Vertica panel runs `SELECT ... WHERE $__timeFilter(...)`, a Prometheus panel runs a PromQL expression, like:

```promql
rate(node_cpu_seconds_total{mode="idle"}[5m])
```

You don't need to master this today — just recognize the shape: it's still "a query that returns a time-series result," same concept as SQL, just a different syntax suited to metrics rather than rows. If you want to try writing one yourself, open **Explore**, select your Prometheus data source, and try:

```promql
node_memory_MemAvailable_bytes
```

— a single metric, no math, just to see the raw number and confirm the Explore workflow feels familiar.

### Alerting that can actually fire

Remember Section 8 from yesterday's manual: VMart never changes, so no alert can ever meaningfully trip. Live CPU/RAM numbers genuinely fluctuate — so build one real alert rule here:

```
Data source: Prometheus
Query: node_load1
Condition: WHEN last() IS ABOVE 2
Evaluate every: 30s
```

Open a few heavy applications on your Windows host (or run a small CPU-burning loop in WSL2) and watch whether the condition trips. This is the payoff moment Vertica/VMart genuinely couldn't give you.

### Bridge it back

Before you reconvene with the rest of the group: be ready to explain, in your own words, **why Prometheus needed an exporter and a scrape config, when Vertica never needed anything like that.** (Short answer: Vertica already had data sitting in tables; nothing existed yet on your OS in a form Grafana — or anything — could query, until node_exporter created that form.) That's the one idea worth carrying out of this afternoon.

---

## 🅱️ Track B — Grafana Mastery Lab (deeper practice + two new concepts)

*You're not falling behind by being on this track — this is where the actual client deliverable gets rock-solid. Everyone reconvenes at the end of the day, and this dashboard is what you'll be showing off.*

### 📚 Two new lightweight concepts

#### Data links — click-through drill-downs

A **data link**, set under a field's options (**Field → Data links**), lets you turn a value in a panel into a clickable link — either to an external URL, or to *another dashboard within Grafana*, optionally carrying the clicked value along as a variable. Example: click a category name in your ranking table, and it opens a second dashboard already filtered to that exact category.

**Try it:** on your category-sales table from Day 8, add a data link on the `category_description` field, pointing to a URL like:

```
/d/<your-other-dashboard-uid>?var-category=${__value.text}
```

`${__value.text}` is a special Grafana variable meaning "whatever value was just clicked." This is genuinely one of the more advanced, more impressive things you can show off in a capstone demo.

#### The full alerting loop — contact points, for real this time

Yesterday you built an alert rule's condition but stopped short of wiring a destination. Today, actually configure a **contact point**.

📍 **Where this lives:** the **Alerting** icon in the left sidebar (the bell 🔔 — flagged but not yet clicked in yesterday's orientation table). Click it, and you'll see tabs across the top for **Alert rules**, **Contact points**, and **Notification policies** — all three pieces of today's full loop live in this one section.

```
Alerting → Contact points → Add contact point
Name: training-alerts
Integration: Email (or Webhook, if you'd rather not use real email)
```

Then a **notification policy** routing your alert rule's labels to that contact point. Even without a real alert ever firing on static VMart data, walking through this full loop once — rule → label → policy → contact point — means you've genuinely seen the entire alerting pipeline end to end, not just half of it.

**One more piece worth knowing about, even briefly: Silences.** Alerting → Silences → New silence lets you temporarily mute an alert (matched by its labels) without deleting the rule — the real-world use case being a planned maintenance window or a known issue you don't want paging anyone about for the next few hours. It's a genuinely common alerting task that's easy to overlook once you've built the rule → contact point → policy chain and consider alerting "done."

### 🔬 Guided practice build

**Goal: a second full dashboard, built with less hand-holding than Day 8, plus a doubt-clearing pass on anything still fuzzy.**

1. **Pick a new angle:** build against `online_sales.online_sales_fact` instead of `store.store_sales_fact` — same core skills, different schema, forces you to actually re-derive the queries rather than copy-paste Day 8's.
2. **Rebuild the full pattern from scratch:** time series, table with a transformation, Stat with thresholds, a chained variable pair, one panel repeated by variable — everything from Day 8, but on new data, unaided.
3. **Add one data link**, per the concept above, connecting this dashboard to your Day 8 dashboard.
4. **Complete a full alerting loop** — rule, label, contact point, notification policy — on at least one panel.
5. **Doubt-clearing round:** before the group reconvenes, write down (even just mentally) one thing from Day 8 or this morning that's still not 100% clicking. We'll go through these together as a group.
6. **Bonus:** try cloning a dashboard purely via the JSON Model copy-paste trick from this morning, on your own, without being walked through it again.

---

## 🎤 End-of-day reconvene — show and tell

Whichever track you were on, be ready to demo **one thing** to the whole group:
- **Prometheus track:** show the imported Node Exporter dashboard live, and explain the scrape → store → query chain in your own words.
- **Grafana Mastery track:** show your new online-sales dashboard, particularly the data link drill-down and the full alerting loop.

This is a genuinely good use of the last 15–20 minutes — the freshers get a preview of what Prometheus looks like without having to build it themselves, and the experienced pair gets to explain a new concept out loud, which is one of the best ways to actually cement it.

---

## 🐛 Known gotchas — earned the hard way, not from a textbook

These aren't theoretical. Every one of these tripped someone up on a real build during this course, and each cost real debugging time before the actual cause was found. Read them once now, and you'll recognize the symptom instantly instead of hunting blind if you hit it yourself.

**"Check the Queries tab count first — every single time something looks wrong."** If a panel is behaving strangely — numbers not changing, duplicate-looking values, a chart that won't update — the very first thing to check, before touching a single setting, is the small number next to the **Queries** tab in the panel editor. More than one query sitting there, and one of them silently leftover from an earlier edit, will blend its (often stale, often unfiltered) data into everything you see. This single check resolves a surprising fraction of "nothing makes sense" moments.

**Pie/Bar gauge showing one giant slice/bar instead of several — "Show" is set to "Calculate," not "All values."** Any panel expecting multiple rows (one slice per region, one bar per store) needs **Value options → Show → All values**. Left on the default "Calculate," Grafana reduces your entire multi-row result down to a single number (usually via `lastNotNull`) before it ever reaches the chart — which looks like a data problem but is actually a display setting.

**A transformation "not working" is sometimes the wrong transformation for the job, not a bug.** "Add field from calculation," in Reduce row or Binary operation mode, only ever combines fields that already sit *side-by-side on the same row*. It cannot look across rows to compute something like "this row's value as a percentage of the grand total across every row" — no matter how it's configured. That specific ask needs either a SQL window function (`SUM(x) / SUM(SUM(x)) OVER ()`) or a proper three-step transformation chain (Reduce → Merge → Add field from calculation). Recognizing *which kind* of calculation you're attempting — within-row vs. across-row — before reaching for a transformation saves a lot of confused re-configuring.

**A hand-typed or hand-edited variable that silently returns zero options isn't always a syntax error — sometimes it's an unverified field shape.** If a variable's dropdown shows real values when built through the UI but shows nothing (or "Selected (0)") after being edited outside it, the safest fix isn't guessing at the JSON again — it's recreating that one variable through the UI, which always produces a schema-correct result by construction.

**A variable only affects the panels whose SQL actually references it.** Picking a value in a `$store` dropdown does nothing to a panel whose `WHERE` clause never mentions `$store` — that's not a bug, the query simply was never wired to that variable. Before assuming a variable is broken, open the panel's query and check whether it's even in there.

---

## 📎 Copy-paste reference — Day 9

**Provisioning example (conceptual — not run hands-on today):**
```yaml
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

**Track A — Prometheus fast-track:**
```bash
# node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
cd node_exporter-1.8.2.linux-amd64 && ./node_exporter &
curl localhost:9100/metrics | head -20

# prometheus
cd ~
wget https://github.com/prometheus/prometheus/releases/download/v2.54.1/prometheus-2.54.1.linux-amd64.tar.gz
tar xvf prometheus-2.54.1.linux-amd64.tar.gz
cd prometheus-2.54.1.linux-amd64
# edit prometheus.yml: add localhost:9100 as a scrape target under job_name 'node'
./prometheus --config.file=prometheus.yml &
```
```
Grafana data source: Prometheus, URL http://localhost:9090 (built-in, no plugin needed)
Import dashboard ID: 1860 ("Node Exporter Full")
Sample PromQL: node_memory_MemAvailable_bytes
Sample alert: node_load1 IS ABOVE 2, evaluate every 30s
```

**Track B — data link syntax:**
```
/d/<dashboard-uid>?var-category=${__value.text}
```

---

## 👀 Tomorrow: Day 10 — Capstone Project

Everyone works independently: fresh dataset, real dashboard, start to finish, no guided walkthrough. Baseline deliverable is the same for everyone — a solid Vertica+Grafana dashboard applying everything from Days 8–9. Anyone who went through the Prometheus track today is welcome to add an optional stretch panel pulling in live system metrics alongside it — but it's a bonus, not a requirement.
