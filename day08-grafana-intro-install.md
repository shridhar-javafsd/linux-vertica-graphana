# Day 8 — Grafana: Intro & Install

*Tue, 8 Sep 2026*

---

## 🔁 Recap: Day 7

You loaded real data into Vertica with `COPY`, handled malformed rows gracefully, created a custom projection, and got your first taste of `EXPLAIN`/`PROFILE`. The Vertica block is done. Today you install the last piece of the stack — the thing that turns SQL results into something you can actually *look* at.

---

## 📚 Concepts

### What is "observability," really?

Observability is the general idea of being able to understand what's happening *inside* a system just from what it exposes externally — metrics (numbers over time), logs (event records), and traces (request paths through a system). Grafana's job sits specifically in the **metrics/dashboarding** corner of that world: it doesn't store data itself — it connects to *data sources* (databases, monitoring systems, anything with a plugin) and turns query results into visual panels.

### Grafana's architecture, at a glance

```
Your browser (localhost:3000)
        ↓
Grafana server (the systemd service you're about to install)
        ↓
Data source plugins (Vertica, MySQL, Prometheus, etc.)
        ↓
The actual data source (your Vertica container, tomorrow)
```

Grafana itself holds no data — every panel you build is really just "run this query against that data source, right now, and draw the result." That's *why* a Grafana dashboard stays live and current — refresh it, and it re-queries the real data source again.

**The building blocks, in order of scale:**
- **Data source** — a connection to somewhere data lives (you'll add Vertica tomorrow)
- **Query** — the actual request sent to that data source
- **Panel** — one visualization (a graph, table, single number) built from a query
- **Dashboard** — a collection of panels, arranged together

---

## 🛠️ Installing Grafana natively

Unlike Vertica, Grafana installs the "normal" way — a native Ubuntu package, no Docker involved, running as a proper `systemd` service.

**🐧 Run inside Ubuntu:**

```bash
sudo apt-get install -y apt-transport-https wget gnupg
```

**Import the signing key:**

```bash
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
sudo chmod 644 /etc/apt/keyrings/grafana.asc
```

**Add the repository — one single line, don't split it across multiple lines when you type or paste it:**

```bash
echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
```

> ⚠️ **Watch the filename.** That command must create a file ending in `.list` — `grafana.list`, not just `grafana`. APT silently *ignores* any file in `/etc/apt/sources.list.d/` that doesn't end in `.list` (you'll see `N: Ignoring file 'grafana'...` in your next `apt update` if this happens). If that warning shows up, fix it with `sudo mv /etc/apt/sources.list.d/grafana /etc/apt/sources.list.d/grafana.list` and re-run `apt-get update`.

**Update and install:**

```bash
sudo apt-get update
sudo apt-get install -y grafana
```

Type exactly `grafana` — not `grafana-enterprise`. The OSS package is what we want.

---

## ⚙️ Running Grafana as a systemd service

```bash
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl status grafana-server --no-pager
```

> 💡 **Deliberately not running `enable` here.** `enable` would make Grafana auto-start every time your WSL2 instance boots — convenient, but it turns "start a service" into something that just silently happens. We're keeping it manual: `sudo systemctl start grafana-server` is something you'll run at the start of every session from today onward (same pattern as `docker start vertica-ce` from Day 5) — a small bit of extra typing that keeps the actual skill live instead of invisible.

You want `Active: active (running)`. If `systemctl status` drops you into a pager view, press `q` to get back to your prompt — that's normal, not a hang.

**Confirm it's actually listening on port 3000** (this is your Day 4 `ss` skill, back in action):

```bash
ss -lntp | grep 3000
```

---

## 🌐 First login and UI walkthrough

Open a browser **on Windows** and go to:

```
http://localhost:3000
```

WSL2 forwards this automatically — no extra networking setup needed. Log in with the default credentials:

```
Username: admin
Password: admin
```

Grafana will immediately prompt you to set a new password — do that now.

**Quick tour of the left sidebar:**

| Section | What it's for |
|---|---|
| **Dashboards** | Where your built dashboards live |
| **Explore** | Ad-hoc querying against any data source, without building a full dashboard |
| **Drilldown** | Newer Grafana navigation for interactively drilling into metrics/logs — you'll likely see this in your sidebar too; we won't dig into it this course, but don't be surprised it's there |
| **Connections → Data sources** | Where you'll add Vertica tomorrow |
| **Alerting** | Threshold-based alerts on your data |
| **Administration** | Users, org settings, plugins |

---

## 🧪 Guided hands-on (do this together)

**🐧 Full install sequence, together:**

```bash
sudo apt-get install -y apt-transport-https wget gnupg
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
sudo chmod 644 /etc/apt/keyrings/grafana.asc
echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install -y grafana
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl status grafana-server --no-pager
ss -lntp | grep 3000
```

**Browser:** open `http://localhost:3000`, log in, set your new password.

**Add your first data source — Grafana's built-in `TestData DB`:**

This is Grafana's own "fake data" source, specifically meant for exactly this — learning the UI without needing a real backend yet. Real Vertica connectivity is tomorrow.

1. **Connections → Data sources → Add data source**
2. Search for and select **TestData DB**
3. Click **Save & test**
4. Go to **Explore**, select your new TestData source, and run its default query — you'll see a random-walk-style time series graph appear immediately

That's the entire Grafana mechanic in miniature: pick a data source, run a query, see a visual. Tomorrow you do the exact same thing, just with real Vertica data behind it instead of random test values.

---

## 🔬 Lab — on your own

1. Confirm `grafana-server` is `active (running)` via `systemctl status`, and that port `3000` shows up in `ss -lntp`.
2. Log into `http://localhost:3000`, confirm your password change went through by logging out and back in.
3. Add the **TestData DB** data source (if you haven't already), and build one throwaway panel from it — any panel type, doesn't need to be pretty, this is purely mechanical practice.
4. Explore the **Explore** view with your TestData source — run a query, change its parameters, watch the graph update live.
5. Click through **Administration** and note (don't change anything) what's available there — plugins, users, org settings. You'll come back to the plugins page tomorrow for the real Vertica plugin.
6. **Bonus:** practice the stop/start discipline you'll use daily from here — `sudo systemctl stop grafana-server`, confirm `localhost:3000` stops responding in your browser, then `sudo systemctl start grafana-server` and confirm it's back.

---

## 📎 Copy-paste command reference — Day 8

```bash
# --- Install ---
sudo apt-get install -y apt-transport-https wget gnupg
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
sudo chmod 644 /etc/apt/keyrings/grafana.asc
echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install -y grafana

# --- Run as a service ---
sudo systemctl daemon-reload
sudo systemctl start grafana-server        # run this at the start of every session — not enabled on purpose
sudo systemctl status grafana-server --no-pager
sudo systemctl stop grafana-server        # daily stop, when you're done

# --- Verify ---
ss -lntp | grep 3000
```

**Browser:** `http://localhost:3000` — default login `admin` / `admin`, then set a new password.

---

## 👀 Tomorrow: Day 9 — Grafana: Dashboarding

You'll install the official Vertica datasource plugin, connect Grafana directly to your own running Vertica container from Days 5–7, and build a real multi-panel dashboard — graphs, tables, single-stat visualizations — all driven by live queries against VMart data. This is the day everything from the last two weeks comes together.
