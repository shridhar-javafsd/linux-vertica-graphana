# Interview Prep — Grafana (+ Prometheus)

*For client interviews after this training. Mix of fresher-friendly basics and deeper questions experienced folks should expect. A handful of Prometheus questions are included at the end since it's a common Grafana pairing worth knowing about, even as a stretch topic.*

---

### 1. What is Grafana, in one line? *(Fresher)*
An open-source dashboarding and visualization tool — it connects to data sources and turns query results into graphs, tables, and dashboards. It doesn't store any data itself.

### 2. Does Grafana store any data of its own? *(Fresher — very commonly asked, easy to get wrong)*
No. Every panel re-runs its query live against the actual data source every time it refreshes. Grafana is a query-and-render layer, not a database.
> 🎯 **Gotcha follow-up:** "So how does a dashboard show historical trends, then?" → The *history* lives in the data source (a time-series database, a table with a date column, etc.) — Grafana is just querying and displaying whatever history is already there.

### 3. What are the four core building blocks of Grafana? *(Fresher)*
Data source (a connection), Query (the request sent to it), Panel (one visualization), Dashboard (a collection of panels).

### 4. Why does Grafana need a plugin to connect to something like Vertica? *(Fresher/Experienced)*
Grafana only bundles a handful of very common data sources by default (Prometheus, MySQL, PostgreSQL, and a few others). Everything else — Vertica included — is a separately installable plugin, so the core product doesn't get bloated with integrations most users never touch.

### 5. Why does Grafana need to be restarted after installing a new plugin? *(Experienced)*
Plugins are scanned once, at startup — Grafana doesn't watch the plugins directory live while running. A restart forces it to re-scan and pick up the newly installed plugin.

### 6. What's the difference between a data source's Builder mode and Code mode? *(Fresher)*
Builder mode is point-and-click query construction — quick, but limited once you need joins or complex logic. Code mode is writing raw SQL (or PromQL, etc.) directly — full control, and what most real dashboards end up using.

### 7. What column format does a time-series panel expect from a SQL query? *(Experienced — Grafana-specific)*
One column aliased literally `time` (a timestamp), plus one or more numeric value columns. Without a properly aliased `time` column, Grafana can't render it as a time series.

### 8. What does the `$__timeFilter()` macro do? *(Experienced)*
It's a placeholder Grafana expands into a real SQL `WHERE` condition based on whatever time range is currently selected in the dashboard's time picker — meaning the same saved query can show "last 7 days" or "all of last year" just by changing the picker, without editing the SQL.

### 9. A panel says "Data outside time range" — what does that actually mean? *(Fresher/Experienced — a real troubleshooting question)*
The query ran successfully and genuinely returned data — the currently selected time range on the dashboard's time picker just doesn't overlap with the timestamps in that data. It's not a broken query; it's a mismatched time window.

### 10. What's the difference between a Table panel and a Time series panel, and when would you pick each? *(Fresher)*
Time series is for trends over time and needs that `time` column. Table is for ranked rows or raw detail with no time dimension requirement — e.g., "top 5 categories by revenue" belongs in a table, not forced into a fake time axis.

### 11. What's a dashboard variable, and why use one instead of hardcoding a filter? *(Fresher/Experienced)*
A variable creates a dropdown (or similar input) that filters every panel referencing it, without editing any query. It also stays current automatically — if the variable's own query finds a new value in the data (a new product category, say), it shows up in the dropdown without anyone touching the dashboard.

### 12. What's a chained (dependent) variable? *(Experienced)*
A variable whose options depend on another variable's current selection — e.g., a `store` dropdown that only shows stores within whichever `region` is currently selected. Built by referencing the parent variable inside the child variable's own query.

### 13. What's "repeat by variable" on a panel? *(Experienced)*
A feature that automatically clones a single panel once per value of a multi-value variable — e.g., one panel becomes five automatically, one per region, without manually copy-pasting panels.

### 14. What is a transformation in Grafana? *(Experienced)*
A post-query, no-code reshaping step applied to a query's result before it's rendered — renaming/hiding columns, adding a calculated field, combining two queries into one panel — without touching the underlying SQL or costing another database round-trip.

### 15. Why would you use a transformation instead of just fixing it in SQL? *(Experienced)*
When you want to reuse the same query across multiple panels but display it differently in each, when the reshaping is purely cosmetic/display-only, or when you need to combine results from two different queries (or even two different data sources) into a single panel — something SQL alone can't do.

### 16. What are Field thresholds used for? *(Fresher/Experienced)*
Defining value ranges that change a panel's color (e.g., red below target, green above) — turning a raw number into an instant visual signal on a Stat or Gauge panel, without needing to read and interpret the number.

### 17. What's the anatomy of a Grafana alert rule? *(Experienced)*
A query, a condition (threshold expression), an evaluation interval (how often it's re-checked), a "for" duration (how long the condition must persist before actually firing, to avoid noise), and labels (used for routing).

### 18. What's the difference between a contact point and a notification policy? *(Experienced)*
A contact point is a destination — email, Slack webhook, PagerDuty. A notification policy is the routing rule that decides which alert (based on its labels) goes to which contact point. Both are needed to complete the alerting pipeline.

### 19. What's an annotation in Grafana? *(Fresher)*
A marker line on a time-series graph noting when something happened — either dropped manually (click on the graph) or pulled automatically from a query (e.g., marking every date a promotion ran).

### 20. What is the JSON Model of a dashboard? *(Experienced)*
The raw JSON document that actually defines a dashboard underneath the UI — panels, variables, and time settings are all just keys in that JSON. It can be copied to clone a dashboard entirely, or exported/version-controlled outside the UI.

### 21. What is "provisioning" in Grafana? *(Experienced)*
Defining dashboards and data sources in YAML config files that Grafana automatically loads on startup, instead of manually clicking through the UI. This is the production pattern — dashboards live in source control, get code-reviewed, and are deployable like application code.

### 22. What's the difference between a dashboard snapshot and just sharing a link? *(Experienced)*
A link points to the live dashboard — anyone opening it re-runs the real queries (and needs Grafana access). A snapshot captures the *current data* as a static, standalone copy viewable without any Grafana access at all — but it's also a moment-in-time freeze, not live.

### 23. What are Grafana folders and permissions used for? *(Fresher/Experienced)*
Organizing dashboards as they grow beyond a flat list, and controlling who can view vs. edit them — based on Grafana's role model (Viewer, Editor, Admin).

### 24. What is Grafana's "Explore" mode, and how is it different from building a dashboard? *(Fresher)*
A space for ad-hoc, one-off querying against a data source — no dashboard, no saved panel, just "run this query and see the result right now." Good for investigation/debugging before committing to a permanent dashboard.

### 25. Can one Grafana dashboard use more than one data source? *(Experienced)*
Yes — different panels on the same dashboard can each point at entirely different data sources (e.g., one panel from Vertica, another from MySQL). Transformations can even combine results from two data sources into a single panel.

### 26. What's a playlist in Grafana? *(Fresher)*
A configured, auto-cycling rotation through a set of dashboards on a timer — commonly used for wall-mounted monitoring displays in ops centers.

### 27. Why is `SELECT *` generally discouraged in a Grafana panel querying a columnar database like Vertica? *(Experienced)*
Columnar databases are optimized to read only the specific columns a query asks for. `SELECT *` forces a full read across every column, defeating that optimization and slowing the query down unnecessarily.

---

## 🎯 Prometheus — a handful of likely questions

### 28. What is Prometheus, and how is it different from a database like Vertica? *(Experienced)*
Prometheus is a metrics database that *also collects its own data* — it actively scrapes (pulls) metrics from exporters on a schedule and stores a rolling history. Vertica, by contrast, never collects anything itself — something else has to load data into it first.

### 29. What is an exporter, in the Prometheus world? *(Experienced)*
A small helper program running on a target machine that exposes metrics (CPU, memory, disk, etc.) in a plain-text format Prometheus knows how to scrape — e.g., `node_exporter` for OS-level Linux metrics.

### 30. What's the difference between a push-based and pull-based monitoring model, and which is Prometheus? *(Experienced)*
Pull-based: the monitoring system reaches out and requests data on its own schedule (Prometheus scraping an exporter). Push-based: the source actively sends data to the monitoring system whenever it wants (less common for metrics, more typical of some logging pipelines). Prometheus is pull-based.

### 31. Does Grafana need a plugin to connect to Prometheus? *(Fresher/Experienced)*
No — Prometheus is one of the handful of data sources Grafana ships with built in, unlike Vertica which needs a separate plugin install.

### 32. What is PromQL? *(Experienced)*
Prometheus's own query language — conceptually similar in role to SQL (a query that returns a time-series result), but syntactically different, purpose-built for metrics rather than relational rows. Example: `rate(node_cpu_seconds_total[5m])`.

### 33. Why is a Prometheus-based alert more likely to actually fire in a demo than one built on static historical data? *(Fresher/Experienced)*
Live system metrics (CPU, memory) genuinely change every scrape interval, giving a threshold condition a real chance to trip. Static historical data never changes between evaluations, so a condition built on it can never meaningfully fire.

---

## 🎯 A few extra gotcha-style follow-ups to be ready for

- **"If Grafana doesn't store data, why does a dashboard sometimes feel slow to load?"** → Because it's re-running every panel's live query against the data source on every load — the bottleneck is the data source (or the query's efficiency), not Grafana itself.
- **"You built a great dashboard, but a colleague opens it and half the panels say 'No data' — what's your first guess?"** → Their session's selected time range doesn't match the underlying data's actual timestamps, or a variable is pointing at a value that doesn't exist in their environment's data source.
- **"When would you reach for a transformation instead of just rewriting the SQL query?"** → When you need to combine multiple queries/data sources into one panel, or want the same underlying query reused elsewhere but displayed differently — transformations are presentation-layer, SQL changes are data-layer.
- **"Someone says 'we don't need Prometheus, Grafana can just read live server stats directly' — what's wrong with that statement?"** → Grafana never collects or reads anything directly from an OS; it only queries data sources. Something (an exporter + Prometheus, in this case) has to actually gather and expose that data first.
