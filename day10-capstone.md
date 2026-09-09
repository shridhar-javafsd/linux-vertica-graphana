# Day 10 — Capstone Project (Updated)

*Thu, 10 Sep 2026*

---

## 🔁 Recap: Days 1–9

Nine days, three tools, one pipeline: Linux got you a working environment (Days 1–4), Vertica got you a real analytical database with real data in it (Days 5–7), Grafana turned that data into something you could actually show someone (Days 8–9). Along the way you also did a quick "hello world" of the node_exporter → Prometheus → Grafana chain — today's the day all of it gets used for real, together, on a problem you haven't seen before.

---

## 🎯 Today works differently

No guided walkthroughs, no "do this together." You get a business scenario, a data model to design, a fresh (and partly messy) dataset, and a checklist of what needs to exist by end of day. Everything else — schema design, loading, projections, dashboard, all of it — is on you.

**This isn't closed-book.** Every day's courseware and all three participant manuals (Linux/Vertica/Grafana) are fair game all day — that's exactly how you'd work on a real job. The goal isn't "recall commands from memory," it's "can you actually get from raw, imperfect data to a working, explainable dashboard using the resources available to you."

**This is a full, long-session capstone — budget 6+ hours.** A suggested pacing guide is at the end, but don't treat it as a hard schedule. Some of you will spend longer on schema design and less on Grafana, or vice versa — that's fine, as long as everything in the deliverables checklist gets done and you can explain your choices.

---

## 📋 The business scenario

**Adaps' internal IT helpdesk wants a live, self-serve view of their support operation** — not just "how many tickets," but which teams are carrying the load, whether categories are meeting their resolution-time targets, and who's actually closing tickets. Right now none of this exists; it's scattered across a spreadsheet and people's memory.

You're building the first version of that system: a small relational data model in Vertica, fed by data you generate yourself, exposed through a Grafana dashboard the helpdesk manager could genuinely use in a stand-up meeting.

### Entities and how they relate

```
teams  (1) ───< employees        one team has many employees
teams  (1) ───< tickets          one team is assigned many tickets
categories (1) ───< tickets      one category classifies many tickets
employees (1) ───< tickets       one employee can be assigned many tickets (nullable — see below)
tickets (1) ───< ticket_history  one ticket has many history/status-change rows
employees (1) ───< ticket_history  one employee can appear as the "changed_by" on many history rows
```

### Business rules (design your schema and your queries around these)

- Every **category** carries an SLA target in hours (e.g. Network issues are expected to resolve faster than a Software licensing request). A ticket **breaches SLA** if its `resolution_time_hours` exceeds its category's `sla_hours`. You'll be asked to report on this later — keep it in mind while choosing data types.
- Every **ticket** must reference a valid category and be assigned to a team. Employee assignment is **optional until someone picks it up** — a brand-new `Open` ticket may have no assigned employee yet. Decide how that shows up in your schema and your load step.
- **`closed_date`** and **`resolution_time_hours`** only make sense for `Closed` tickets — for `Open`/`Pending` tickets they're legitimately absent, not "unknown." You already made this call on Day 7 for a simpler dataset; make it deliberately again here now that there's a second nullable field to think about.
- Every ticket should have **at least one history row** — when it was logged (`New → Open`), and further rows for any status change after that. This is your audit trail and it's what a couple of your join queries will lean on.

### Entities and attributes

You're **not** getting ready-made `CREATE TABLE` statements — designing these five tables, deliberately, is most of the point of today. Below is what each column *means* and a nudge on what to think about; the data type and sizing decisions are yours.

**`teams`**
| Attribute | Meaning | Think about |
|---|---|---|
| team_id | unique team identifier | primary key |
| team_name | e.g. Infra, AppSupport, NetOps, IAM | small fixed set of values — how wide does this really need to be? |
| team_lead | name of the lead | free text |
| location | office location | small fixed set |

**`employees`**
| Attribute | Meaning | Think about |
|---|---|---|
| employee_id | unique employee identifier | primary key |
| employee_name | full name | |
| team_id | which team they belong to | references `teams` |
| role | L1 Support / L2 Support / Team Lead / Analyst | |
| hire_date | date joined | DATE, not VARCHAR |
| email | work email | |

**`categories`**
| Attribute | Meaning | Think about |
|---|---|---|
| category_id | unique category identifier | primary key |
| category_name | Hardware / Software / Network / Access | |
| default_priority | typical priority for this category | |
| sla_hours | target resolution time in hours for this category | used in your SLA-breach query later |

**`tickets`**
| Attribute | Meaning | Think about |
|---|---|---|
| ticket_id | unique ticket identifier | primary key |
| opened_date | date logged | never null |
| closed_date | date resolved | **nullable** — only for Closed |
| category_id | issue type | references `categories` |
| priority | Low/Medium/High/Critical | |
| status | Open/Pending/Closed | |
| assigned_team_id | owning team | references `teams` |
| assigned_employee_id | owning individual | **nullable** — Open tickets may be unassigned |
| resolution_time_hours | hours to close | **nullable** — only for Closed; integer or numeric? |
| short_description | free-text summary | size it sensibly, don't just default to a huge VARCHAR |

**`ticket_history`**
| Attribute | Meaning | Think about |
|---|---|---|
| history_id | unique row identifier | primary key |
| ticket_id | which ticket this event belongs to | references `tickets` |
| changed_date | when the status changed | |
| changed_by_employee_id | who made the change | references `employees` |
| old_status | status before | |
| new_status | status after | |
| notes | short free-text note | |

Vertica won't enforce these references as hard foreign keys the way some other databases do — but **declare them anyway** (Vertica supports `REFERENCES` as a documented, optimizer-usable constraint even though it isn't enforced at load time). Part of today's evaluation is whether your schema *documents* these relationships properly, not just whether the data happens to line up.

---

## 🐧 Linux: capture everything as you go

Before you touch anything else, start a full session transcript — this becomes your `adaps-capstone.txt` deliverable.

```bash
mkdir -p ~/capstone_data
script -a ~/adaps-capstone.txt
# everything you type and see from here on is being logged.
# when you're completely done for the day, type: exit
```

**Keep everything inside this one logged session — including vsql.** Don't open a fresh terminal tab for your Vertica work; run vsql right here, in the same window `script` is already capturing. `docker exec -it` just gives you an interactive terminal, and anything printed to it lands in your transcript automatically — no separate export needed:

```bash
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```

The first thing you type inside vsql, every time you connect, should be:

```sql
\pset pager off
```

Without this, long result sets get piped through `less`, which can leave odd `--More--` prompts and screen-clear codes in your transcript instead of clean, readable output.

**If you ever open a second terminal window** (e.g. to check Grafana or Prometheus while vsql is running in the first), remember that window is *not* being logged unless you also run `script` in it. Simplest habit: do all your vsql work in the one tab where `script` is already running, rather than spawning a new one.

### Start and verify the environment

Nothing auto-starts (deliberately). Start it, then actually verify — don't assume.

```bash
docker start vertica-ce
sudo systemctl start grafana-server
sudo systemctl start prometheus         # if you set it up as a systemd service
# node_exporter — start however you set it up on Day 8/9 (systemd unit or manual)

docker ps                                          # Vertica container running?
sudo systemctl status grafana-server --no-pager    # Grafana running?
sudo systemctl status prometheus --no-pager        # Prometheus running?
curl -s localhost:9100/metrics | head -5           # node_exporter answering?
ss -lntp | grep -E "3000|5433|9090|9100"           # all four ports listening?
```

Log the versions of everything you're using — worth having in your transcript for troubleshooting and for your own records:

```bash
docker --version
docker exec vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo -c "SELECT version();"
grafana-server -v
prometheus --version
wsl.exe --version   # (run this one from PowerShell/CMD, not inside WSL)
```

### Generate your dataset

Unlike VMart (which came pre-loaded), today's data doesn't exist yet. Below is a ready-to-copy Python script that generates a small, related dataset across all five entities — plus a deliberately messy "batch 2" of tickets you'll use later to demo how Vertica handles bad data. Pure standard library, no internet needed.

**Your dataset must be personally seeded — not the default.** Before you run the script, set `SEED_TEXT` (near the top of the file) to your own name exactly as your trainer has it on the roster, e.g. `"rahul_sharma"`. This means your tickets, your employee names, and even which rows land in your messy batch will be different from everyone else's in the room — your data is *yours*, and it's checkable as yours.

```bash
nano ~/generate_capstone_data.py
```

```python
#!/usr/bin/env python3
"""
generate_capstone_data.py
Generates a related set of CSV files for the Day 10 capstone:
teams, employees, categories, tickets, ticket_history
plus a deliberately messy 'tickets_batch2' file to demo COPY exception handling.
"""

import csv
import hashlib
import os
from datetime import date, timedelta
import random

OUT_DIR = os.path.expanduser("~/capstone_data")
os.makedirs(OUT_DIR, exist_ok=True)

# --- PERSONALIZE THIS: your name, exactly as on the trainer's roster ---
SEED_TEXT = "your_name_here"
SEED = int(hashlib.md5(SEED_TEXT.encode()).hexdigest(), 16) % 100000
random.seed(SEED)
print(f"Seeded with '{SEED_TEXT}' -> {SEED}. Your dataset is unique to you.")

# ---------- Reference data ----------

teams = [
    (1, "Infra", "Radha Krishnan", "Hyderabad"),
    (2, "AppSupport", "Meera Iyer", "Bengaluru"),
    (3, "NetOps", "Arjun Nair", "Hyderabad"),
    (4, "IAM", "Divya Rao", "Pune"),
]

first_names = ["Aditi", "Rahul", "Sneha", "Karthik", "Priya", "Vikram", "Ananya",
               "Suresh", "Neha", "Manoj", "Pooja", "Rajesh", "Kavya", "Sandeep", "Isha"]
last_names = ["Sharma", "Reddy", "Iyer", "Patel", "Nair", "Gupta", "Menon", "Rao",
              "Verma", "Krishnan"]

employees = []
emp_id = 1
for team_id, *_ in teams:
    for _ in range(3):  # 3 employees per team = 12 total
        name = f"{random.choice(first_names)} {random.choice(last_names)}"
        role = random.choice(["L1 Support", "L2 Support", "Team Lead", "Analyst"])
        hire_date = date(2022, 1, 1) + timedelta(days=random.randint(0, 900))
        email = name.lower().replace(" ", ".") + "@adaps.com"
        employees.append((emp_id, name, team_id, role, hire_date.isoformat(), email))
        emp_id += 1

categories = [
    (1, "Hardware", "Medium", 24),
    (2, "Software", "Medium", 48),
    (3, "Network", "High", 12),
    (4, "Access", "High", 8),
]

# ---------- Tickets ----------

priorities = ["Low", "Medium", "High", "Critical"]
statuses_weighted = ["Closed"] * 6 + ["Open"] * 2 + ["Pending"] * 2

descriptions = {
    1: ["Laptop won't power on", "Monitor flickering", "Keyboard not responding", "Docking station fault"],
    2: ["Application crash on login", "License activation failing", "Software update stuck", "Report export error"],
    3: ["VPN dropping intermittently", "Slow network in building B", "Wi-Fi not connecting", "DNS resolution failure"],
    4: ["Access request for shared drive", "Password reset needed", "New joiner account setup", "Access revoke request"],
}

tickets = []
for ticket_id in range(1, 201):  # 200 tickets
    category_id = random.choice([c[0] for c in categories])
    priority = random.choice(priorities)
    status = random.choice(statuses_weighted)
    team_id = random.choice([t[0] for t in teams])
    team_employees = [e for e in employees if e[2] == team_id]
    assigned_employee_id = random.choice(team_employees)[0] if (status != "Open" and team_employees) else ""

    day_offset = random.randint(0, 90)
    opened = date(2026, 6, 1) + timedelta(days=day_offset)

    if status == "Closed":
        resolution_hours = random.randint(1, 72)
        closed_date = (opened + timedelta(hours=resolution_hours)).date().isoformat()
    else:
        resolution_hours = ""
        closed_date = ""

    desc = random.choice(descriptions[category_id])
    tickets.append((ticket_id, opened.isoformat(), closed_date, category_id, priority,
                     status, team_id, assigned_employee_id, resolution_hours, desc))

# ---------- Ticket history (status trail) ----------

history = []
h_id = 1
for t in tickets:
    (ticket_id, opened_date, closed_date, category_id, priority, status,
     team_id, assigned_employee_id, resolution_hours, desc) = t
    opened_dt = date.fromisoformat(opened_date)
    team_employees = [e for e in employees if e[2] == team_id]
    changer = random.choice(team_employees)[0] if team_employees else ""

    history.append((h_id, ticket_id, opened_date, changer, "New", "Open", "Ticket logged"))
    h_id += 1

    if status in ("Pending", "Closed"):
        pending_date = (opened_dt + timedelta(days=random.randint(0, 2))).isoformat()
        history.append((h_id, ticket_id, pending_date, changer, "Open", "Pending", "Picked up by team"))
        h_id += 1

    if status == "Closed" and closed_date:
        history.append((h_id, ticket_id, closed_date, changer, "Pending", "Closed", "Resolved and closed"))
        h_id += 1

# ---------- Write CSVs ----------

def write_csv(filename, header, rows):
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"Wrote {len(rows)} rows -> {path}")

write_csv("teams.csv", ["team_id", "team_name", "team_lead", "location"], teams)
write_csv("employees.csv",
          ["employee_id", "employee_name", "team_id", "role", "hire_date", "email"], employees)
write_csv("categories.csv",
          ["category_id", "category_name", "default_priority", "sla_hours"], categories)
write_csv("tickets.csv",
          ["ticket_id", "opened_date", "closed_date", "category_id", "priority", "status",
           "assigned_team_id", "assigned_employee_id", "resolution_time_hours", "short_description"],
          tickets)
write_csv("ticket_history.csv",
          ["history_id", "ticket_id", "changed_date", "changed_by_employee_id",
           "old_status", "new_status", "notes"],
          history)

# ---------- Deliberately messy "batch 2" — for the reject/exception demo ----------

messy_rows_raw = [
    "201,2026-08-15,,2,High,Open,3,,,VPN keeps disconnecting",
    "202,15-08-2026,2026-08-17,1,Medium,Closed,1,3,48,Laptop battery not charging",       # bad date format
    "203,2026-08-16,2026-08-18,9,Low,Closed,2,6,N/A,Report formatting issue",              # non-numeric hours
    "204,2026-08-17,,3,Critical,Open,3,,,DNS failing across floor 4,extra,columns,here",   # extra columns
    "205,2026-08-18,2026-08-19,4,High,Closed,4,10,24",                                     # missing last column
    "not,even,a,proper,csv,line,at,all,here,really",                                       # garbage row
]

path = os.path.join(OUT_DIR, "tickets_batch2_messy.csv")
with open(path, "w") as f:
    f.write("ticket_id,opened_date,closed_date,category_id,priority,status,assigned_team_id,"
            "assigned_employee_id,resolution_time_hours,short_description\n")
    for row in messy_rows_raw:
        f.write(row + "\n")
print(f"Wrote {len(messy_rows_raw)} deliberately messy rows -> {path}")
```

```bash
python3 ~/generate_capstone_data.py
ls -la ~/capstone_data/
```

### Get your data into the container

Same reason as Day 7: `vsql` runs via `docker exec`, which means `COPY ... FROM LOCAL` looks for files **inside the container**, not on your Ubuntu host. You generated everything on the host, so it needs to go in — one `docker cp` for the whole folder this time, since you've got five CSVs plus the messy batch:

```bash
docker cp ~/capstone_data vertica-ce:/tmp/capstone_data
docker exec vertica-ce ls -la /tmp/capstone_data
```

Every `COPY` statement from here on should point at `/tmp/capstone_data/<file>.csv` — a container path, not the `~/capstone_data/...` host path you've been using in Linux commands.

### Pre-load sanity checks (Linux, not SQL)

Before loading anything, use the Linux tools you already know to sanity-check the data — this is exactly the kind of check a real data engineer does *before* trusting a `COPY` to run cleanly.

```bash
# Row count including header
wc -l ~/capstone_data/tickets.csv

# How many tickets per status? (column 6)
awk -F',' 'NR>1 {print $6}' ~/capstone_data/tickets.csv | sort | uniq -c

# Do all Open tickets really have a blank closed_date (column 3)?
awk -F',' 'NR>1 && $6=="Open" && $3!="" {print}' ~/capstone_data/tickets.csv
# ^ this should print NOTHING if the data generation logic is consistent — if it prints rows, investigate

# Quick peek at the messy batch before you load it
cat -A ~/capstone_data/tickets_batch2_messy.csv | head
```

---

## 🗄️ Vertica: schema, load, projections, and a reject demo

### 1. Create your schema and tables

Using the entity/attribute spec above, write and run your own `CREATE SCHEMA` and five `CREATE TABLE` statements. Declare the relationships with `REFERENCES` even though Vertica won't enforce them at load time — they still document intent and can help the optimizer.

### 2. Load reference data first, then the transactional data

Load `teams`, `employees`, and `categories` first (small, no dependencies) — then `tickets`, then `ticket_history`. Every file lives at `/tmp/capstone_data/<file>.csv` inside the container (per the `docker cp` step above), not the host path. For example:

```sql
COPY helpdesk.teams FROM LOCAL '/tmp/capstone_data/teams.csv' DELIMITER ',' SKIP 1;
```

Repeat that pattern for the other four tables — same `/tmp/capstone_data/...` convention each time. Decide deliberately how you're representing the blanks in `closed_date`, `assigned_employee_id`, and `resolution_time_hours` (Vertica's `NULL` clause vs. a placeholder value) — same decision you made on a simpler dataset in Day 7, now with more nullable columns to think through.

### 3. Verify

Run row counts and a handful of targeted `SELECT`s to prove the load did what you expect — including that Open tickets really came in with NULLs where they should.

### 4. Custom projections — beyond the super projection

Vertica auto-creates a super projection per table. Today you design and create **at least two custom projections**, each aimed at a specific, named query pattern:

- **Projection A** — optimize for a dashboard-style query that filters/aggregates `tickets` by `assigned_team_id` and `status` (e.g. "open + pending tickets per team, right now"). Think about which column should lead your `ORDER BY`/segmentation for that access pattern.
- **Projection B** — optimize for a reporting-style query that joins `tickets` to `categories` and aggregates by category/priority over a date range (e.g. "SLA performance by category, last 90 days").

For each, write a short comment in your `.sql` file explaining which query pattern it targets and why you chose that column order. Use `EXPLAIN` on your matching queries afterward and confirm (and note in a comment) that Vertica is actually picking your projection over the super projection.

**Add one query of your own that isn't in this document anywhere** — something you're personally curious about in your own (personally-seeded) data. Comment it clearly as `-- MY OWN QUERY` so it's easy to spot. This is the one part of the SQL file nobody handed you, and it's the fastest way for you (or your trainer) to tell your work apart from someone else's.

### 5. The reject/exception demo

Real pipelines get messy data. Load your `tickets_batch2_messy.csv` on top of the `tickets` table using `EXCEPTIONS` and `REJECTED DATA` so Vertica writes the problem rows out instead of just failing silently or aborting the whole load. The input file is the container path from your `docker cp` step; the output files, same as Day 7, go straight to `/tmp/` on the container (world-writable, no permission headaches):

```sql
COPY helpdesk.tickets FROM LOCAL '/tmp/capstone_data/tickets_batch2_messy.csv'
DELIMITER ','
SKIP 1
NULL ''
EXCEPTIONS  '/tmp/capstone_exceptions.txt'
REJECTED DATA '/tmp/capstone_rejects.txt';
```

Those two output files are written by the Vertica server, so they land inside the container too — bring them back out to your host folder before you can inspect them normally or hand them in:

```bash
docker cp vertica-ce:/tmp/capstone_exceptions.txt ~/capstone_data/capstone_exceptions.txt
docker cp vertica-ce:/tmp/capstone_rejects.txt ~/capstone_data/capstone_rejects.txt
```

Afterward, inspect both output files (`cat` / `less` them) and, in a comment block in your `.sql` file, explain **which rows got rejected and why** — bad date format, wrong column count, non-numeric value where a number was expected, etc. This is one of the more useful real-world skills in the whole course: knowing how to load messy data *without* losing visibility into what didn't make it in.

### 6. Verification queries, including complex joins

A few to get you started (you're expected to add more of your own to your `.sql` deliverable — at least three, and at least one that exercises a projection you created):

```sql
-- Row counts sanity check
SELECT COUNT(*) FROM helpdesk.tickets;
SELECT COUNT(*) FROM helpdesk.ticket_history;

-- Do we have the expected Open tickets with NULL closed_date?
SELECT ticket_id, status, closed_date FROM helpdesk.tickets WHERE status = 'Open' LIMIT 5;

-- 3-way join: tickets + categories + teams
SELECT t.ticket_id, c.category_name, tm.team_name, t.priority, t.status
FROM helpdesk.tickets t
JOIN helpdesk.categories c ON t.category_id = c.category_id
JOIN helpdesk.teams tm ON t.assigned_team_id = tm.team_id
LIMIT 10;

-- SLA-breach report by team and category (the business question that matters most)
SELECT tm.team_name,
       c.category_name,
       COUNT(*) AS closed_tickets,
       SUM(CASE WHEN t.resolution_time_hours > c.sla_hours THEN 1 ELSE 0 END) AS sla_breaches,
       ROUND(AVG(t.resolution_time_hours), 1) AS avg_resolution_hours
FROM helpdesk.tickets t
JOIN helpdesk.categories c ON t.category_id = c.category_id
JOIN helpdesk.teams tm ON t.assigned_team_id = tm.team_id
WHERE t.status = 'Closed'
GROUP BY tm.team_name, c.category_name
ORDER BY sla_breaches DESC;

-- Who's actually closing tickets? (join through ticket_history)
SELECT e.employee_name, tm.team_name, COUNT(*) AS resolutions
FROM helpdesk.ticket_history h
JOIN helpdesk.employees e ON h.changed_by_employee_id = e.employee_id
JOIN helpdesk.teams tm ON e.team_id = tm.team_id
WHERE h.new_status = 'Closed'
GROUP BY e.employee_name, tm.team_name
ORDER BY resolutions DESC;
```

### 7. Export your query log — your last Vertica step of the day

Vertica keeps its own server-side record of every statement anyone runs against it, in `v_monitor.query_requests` — timestamped, full SQL text, independent of whether you ran it through vsql or DBeaver. As your last Vertica action today, export today's log:

```bash
docker exec vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo -c "SELECT statement_id, start_timestamp, end_timestamp, request_type, request \
FROM v_monitor.query_requests \
WHERE start_timestamp::date = CURRENT_DATE \
ORDER BY start_timestamp;" > ~/capstone_data/query_requests_log.txt
```

This redirects the command's output on your Ubuntu host (`>`), so the file lands directly in `~/capstone_data/` — no `docker cp` needed this time, since the redirect happens outside the container, on the shell that invoked `docker exec`.

This gives a true chronological record of your day — schema creation, loads, projections, verification queries, the reject demo, all in the order you actually ran them, written by the database itself rather than pasted into a file. Do this **after** you're done experimenting, so it captures the full day.

---

## 📊 Grafana: the dashboard

**Connect Grafana to your Vertica instance** (already done if it's still running from Day 9 — verify, don't assume).

Build **one dashboard with at least 5 different panel types** pulling from your new tables, for example:

- **Time series** — tickets opened per day
- **Table** — open/pending tickets by team, with columns for priority and age
- **Stat** — average resolution time (hours), maybe with a threshold color for SLA-breach territory
- **Gauge / bar gauge** — SLA compliance rate (% of closed tickets within SLA) per category
- **Pie / donut** — ticket volume by category

Add **at least two dashboard variables** (e.g. `assigned_team` and `category`) so the whole dashboard can be filtered without editing a single query.

**Add one panel of your own** — something not listed above, showing whatever you find interesting in your own data (top category by ticket count, oldest still-open ticket, whatever). Title it starting with `My:` so it's obviously yours in the exported JSON.

**Write a real comment every time you save.** Grafana's save dialog has a message field — use it, every save, with an actual description of what changed ("added SLA gauge", "fixed team variable query", "added Host Health row"), not "update" or a blank field. This builds Grafana's own dashboard version history (Dashboard settings → Version history) into a real build log with timestamps — the Grafana equivalent of your Vertica query log. Save incrementally as you build rather than once at the end; a dashboard with one version and no history looks very different from one that was actually built over the afternoon.

### Bring in the Prometheus chain, lightly

You already did a "hello world" of node_exporter → Prometheus → Grafana earlier in the course — today, use it for real, but keep it simple (no deep PromQL needed):

1. Confirm `node_exporter`, `prometheus`, and `grafana-server` are all up (you already checked this in the Linux section above).
2. If Prometheus isn't already a Grafana datasource, add it.
3. Add one new row to your dashboard, **"Host Health,"** with two small panels:
   - **Stat panel:** `up{job="node"}` — is the exporter reachable right now
   - **Time series panel:** something like `node_memory_MemAvailable_bytes` or `rate(node_cpu_seconds_total{mode="idle"}[5m])` — whichever reads more cleanly to you

The point isn't PromQL depth — it's proving the whole exporter → Prometheus → Grafana chain works end-to-end, sitting alongside your Vertica-backed panels on the same dashboard.

---

## ✅ Deliverables checklist

This is your rubric — check honestly against it before presenting. Everything below should exist by end of day, ideally bundled into one folder/archive named after you.

**Linux**
1. `adaps-capstone.txt` — the full session transcript captured via `script`, covering environment start/verification, tool versions, data generation, and pre-load checks
2. The `~/capstone_data/` folder itself (all generated CSVs, including the messy batch) — kept as evidence of what you actually loaded
3. A `tar.gz` archive bundling your deliverables folder — one command, your choice of flags, but be ready to explain what it captured

**Vertica**
4. `adaps-capstone.sql` — every DDL statement, every `COPY`, both projections with their explanatory comments, your verification/join queries, and your own `-- MY OWN QUERY` addition, all with comments explaining *why*, not just *what*
5. `capstone_exceptions.txt` and `capstone_rejects.txt` — the output of your reject/exception demo, with your own comment in the `.sql` file explaining what went wrong in each rejected row
6. Some form of before/after row-count or `EXPLAIN` proof that your projections are actually being used (a screenshot, a pasted query result, or a comment block — your call)
7. `query_requests_log.txt` — the exported `v_monitor.query_requests` log, run as your last Vertica step of the day

**Grafana**
8. `adaps-capstone.json` — the exported dashboard definition, including your `My:` panel
9. A screenshot (or two) of the finished, populated dashboard — the JSON alone won't show anyone what it actually looks like
10. A one- or two-line note on which Prometheus datasource/PromQL you used for the Host Health panels
11. A screenshot of your dashboard's Version history (Dashboard settings → Version history), showing your incremental save comments

**Demo**
12. A live, working demo and explanation (see presentation guidance below)
13. Short "decisions & trade-offs" notes — a few bullet points on your data type choices, your projection design, your NULL-handling call, and what the reject demo taught you. These double as your talking points for the presentation.
14. *(Nice to have, not mandatory)* a one-page `adaps-capstone-summary.md` that just lists what's in your submission and where — useful for whoever's reviewing a batch of these later, and good practice for how real handoffs get documented.

---

## 🎤 Presentation guidance

Keep it to about 7 minutes. Cover:

1. **A walkthrough of your dashboard** — what each panel shows, why you picked that visualization type, and what the SLA-breach numbers actually tell you about the (synthetic) helpdesk
2. **Two deliberate decisions you made** — pick from: a data type choice, how you handled the nullable columns, why you designed the two projections the way you did, how you interpreted a rejected row
3. **One thing that broke, and how you fixed it** — everyone hits at least one snag; explaining your own debugging process out loud is a genuinely useful skill, and normalizes the fact that hitting errors is just part of the work

You're not being judged on a perfect dashboard — you're being judged on whether you can reason about *why* you built it the way you did.

**Be ready for a small live change.** Your trainer may ask you to make one small, unrehearsed tweak on the spot — add a filter, change a variable default, resize a column and explain the type you picked. If you built it yourself, this takes under a minute.

---

## ⏱️ Suggested pacing (not a hard schedule)

| Block | Suggested time |
|---|---|
| Environment start + verification (Linux) | 20–30 min |
| Read business requirement, design schema on paper | 45–60 min |
| Generate data + pre-load Linux checks | 30 min |
| Create tables, load, verify | 60–90 min |
| Design and create 2 projections, verify with EXPLAIN | 45–60 min |
| Reject/exception demo + investigate output | 30 min |
| Build Grafana dashboard (5 panel types + 2 variables) | 90–120 min |
| Add Host Health (Prometheus) row | 20–30 min |
| Presentation prep | 20–30 min |
| **Total** | **≈ 6–7.5 hrs** |

---

## 🆘 If you get stuck

This is expected — getting stuck and finding your own way out is part of what's being practiced today. Where to look:

| Stuck on... | Go back to |
|---|---|
| Schema/table design, data types | `day06-vertica-sql-fundamentals.md` + Vertica manual §4 |
| `COPY`, handling blank/messy fields | `day07-vertica-loading-performance.md` + Vertica manual §7 |
| `EXCEPTIONS` / `REJECTED DATA` syntax | Vertica manual §7 (COPY reference) |
| Projections | `day07-vertica-loading-performance.md` + Vertica manual §6 |
| Join queries across multiple tables | `day06-vertica-sql-fundamentals.md` + Vertica manual §5 |
| Connecting Grafana / plugin issues | `day09-grafana-dashboarding.md` |
| Panel types, `$__timeFilter`, "Data outside time range" | `day09-grafana-dashboarding.md` + Grafana manual §5–6 |
| Dashboard variables | `day09-grafana-dashboarding.md` + Grafana manual §7 |
| Prometheus datasource / PromQL basics | Day 8/9 "hello world" notes + Grafana manual §8 |
| Docker/container basics | `day05-vertica-intro-install.md` + Vertica manual §2–3 |

---

## 🔬 Self-check reference — commands you already know

Not new syntax — just the checkpoints worth running before you consider yourself "done":

```bash
# Start (not enabled on purpose - this won't be running yet)
docker start vertica-ce
sudo systemctl start grafana-server
sudo systemctl start prometheus

# Environment
docker ps                                          # Vertica container running?
sudo systemctl status grafana-server --no-pager    # Grafana running?
sudo systemctl status prometheus --no-pager        # Prometheus running?
curl -s localhost:9100/metrics | head -5           # node_exporter answering?
ss -lntp | grep -E "3000|5433|9090|9100"           # all four ports listening?

# Data loaded correctly?
# (in vsql) SELECT COUNT(*) FROM helpdesk.tickets;
# (in vsql) SELECT COUNT(*) FROM helpdesk.ticket_history;
# (in vsql) SELECT * FROM helpdesk.tickets WHERE status = 'Open' LIMIT 5;

# Reject demo proof
cat ~/capstone_data/capstone_rejects.txt
cat ~/capstone_data/capstone_exceptions.txt

# Dashboard live-data proof
# Make a change via vsql or DBeaver, refresh the Grafana panel, confirm it updates.
```

---

## 🏁 Closing note

After nine days of learning, today, you independently designed a small relational data model from a business requirement, generated and sanity-checked your own dataset, loaded it into a real analytical database (including handling data that was deliberately broken), reasoned about projections and performance, and built a live, filterable dashboard on top of it — with a second live data source, Prometheus, feeding the same screen. That's the whole course, working end to end, unassisted, on a problem you designed the solution for yourself.

Well done. 🚀
