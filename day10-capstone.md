# Day 10 — Capstone Project

*Thu, 10 Sep 2026*

---

## 🔁 Recap: Days 1–9

Nine days, three tools, one pipeline: Linux got you a working environment (Days 1–4), Vertica got you a real analytical database with real data in it (Days 5–7), Grafana turned that data into something you could actually show someone (Days 8–9). Today there's no new material — today's the day you prove it all actually stuck.

---

## 🎯 Today works differently

No guided walkthroughs, no "do this together." You get a scenario, a fresh dataset, and a checklist of what needs to exist by end of day. Everything else — schema design, loading, projections, dashboard, all of it — is on you.

**This isn't closed-book.** Every day's courseware and all three participant manuals (Linux/Vertica/Grafana) are fair game all day — that's exactly how you'd work on a real job. The goal isn't "recall commands from memory," it's "can you actually get from raw data to a working dashboard using the resources available to you."

---

## 📋 The scenario

**Adaps' internal IT helpdesk team wants visibility into their support ticket workload.** Right now, ticket data just sits in a spreadsheet nobody looks at. They need a live Vertica-backed Grafana dashboard showing ticket volume, resolution times, and team workload — the same kind of ask you'd realistically get in a first analytics project at almost any company.

---

## 🗂️ Your dataset

Unlike VMart (which came pre-loaded), today's data doesn't exist yet — you generate it yourself, then treat it exactly like a fresh dataset landing in your inbox for the first time.

**🐧 Run inside Ubuntu:**

```bash
mkdir -p ~/capstone_data
nano generate_tickets.sh
```

```bash
#!/bin/bash
# Generates synthetic IT helpdesk ticket data for the capstone.

OUTPUT=~/capstone_data/helpdesk_tickets.csv

# Arrays hold a fixed list of values — new syntax, but just a labeled list.
categories=("Hardware" "Software" "Network" "Access")
priorities=("Low" "Medium" "High" "Critical")
teams=("Infra" "AppSupport" "NetOps" "IAM")
statuses=("Closed" "Closed" "Closed" "Open" "Pending")   # weighted toward Closed, on purpose

echo "ticket_id,opened_date,closed_date,category,priority,status,assigned_team,resolution_time_hours" > "$OUTPUT"

for i in $(seq 1 150); do
    category=${categories[$RANDOM % ${#categories[@]}]}
    priority=${priorities[$RANDOM % ${#priorities[@]}]}
    team=${teams[$RANDOM % ${#teams[@]}]}
    status=${statuses[$RANDOM % ${#statuses[@]}]}

    day_offset=$((RANDOM % 90))
    opened_date=$(date -d "2026-06-01 +${day_offset} days" +%Y-%m-%d)

    if [ "$status" == "Closed" ]; then
        resolution_hours=$((RANDOM % 72 + 1))
        closed_date=$(date -d "${opened_date} +$((resolution_hours / 24)) days" +%Y-%m-%d)
    else
        resolution_hours=""
        closed_date=""
    fi

    echo "${i},${opened_date},${closed_date},${category},${priority},${status},${team},${resolution_hours}" >> "$OUTPUT"
done

echo "Generated $(wc -l < "$OUTPUT") lines (including header) at $OUTPUT"
```

```bash
chmod +x generate_tickets.sh
./generate_tickets.sh
head ~/capstone_data/helpdesk_tickets.csv
```

Notice: **`Open` and `Pending` tickets have blank `closed_date`/`resolution_time_hours`.** That's deliberate, and it's realistic — real data has gaps. Part of today's job is deciding how to handle that in your schema and your loading step, not pretending it isn't there.

---

## ✅ Deliverables checklist

By end of day, you should have all of the following. This is your rubric — check honestly against it before presenting.

1. **Environment verified** — Docker, Vertica container, and Grafana all confirmed running (your own choice of commands — you've run these dozens of times by now)
2. **A new schema and table(s) in Vertica** for the helpdesk data, with data types you chose deliberately — not just "everything is VARCHAR"
3. **Data loaded via `COPY`** — handling the blank fields sensibly (decide: `NULL`, or a placeholder — and be ready to explain why)
4. **At least one custom projection**, with a reason you can articulate (which query pattern is it optimized for?)
5. **Grafana connected to your Vertica instance** (already done if it's still running from Day 9 — verify, don't just assume)
6. **A dashboard with at least 3 different panel types** — e.g., a time series of tickets opened per day, a table of open/pending tickets by team, a stat panel for average resolution time
7. **At least one dashboard variable** (e.g., filter by `category` or `assigned_team`)
8. **A 5-minute presentation prepared** (see below)

---

## 🆘 If you get stuck

This is expected — getting stuck and finding your own way out is part of what's being practiced today. Where to look:

| Stuck on... | Go back to |
|---|---|
| Schema/table design, data types | `day06-vertica-sql-fundamentals.md` + Vertica manual §4 |
| `COPY`, handling blank/messy fields | `day07-vertica-loading-performance.md` + Vertica manual §7 |
| Projections | `day07-vertica-loading-performance.md` + Vertica manual §6 |
| Connecting Grafana / plugin issues | `day09-grafana-dashboarding.md` |
| Panel types, `$__timeFilter`, "Data outside time range" | `day09-grafana-dashboarding.md` + Grafana manual §5–6 |
| Dashboard variables | `day09-grafana-dashboarding.md` + Grafana manual §7 |
| Docker/container basics | `day05-vertica-intro-install.md` + Vertica manual §2–3 |

---

## 🎤 Presentation guidance

Keep it to 5 minutes. Cover:

1. **A quick walkthrough of your dashboard** — what each panel shows, and why you picked that visualization type for it
2. **One deliberate decision you made** — a data type choice, why you created the projection you did, how you handled the blank fields — and your reasoning
3. **One thing that broke, and how you fixed it** — everyone hits at least one snag; explaining your own debugging process out loud is a genuinely useful skill, and normalizes the fact that hitting errors is just part of the work

You're not being judged on a perfect dashboard — you're being judged on whether you can reason about *why* you built it the way you did.

---

## 🔬 Self-check reference — commands you already know

Not new syntax — just the checkpoints worth running before you consider yourself "done":

```bash
# Environment
docker ps                                    # Vertica container running?
sudo systemctl status grafana-server --no-pager   # Grafana running?
ss -lntp | grep -E "3000|5433"                # both ports listening?

# Data loaded correctly?
# (in vsql) SELECT COUNT(*) FROM <your_schema>.<your_table>;
# (in vsql) SELECT * FROM <your_schema>.<your_table> WHERE status = 'Open' LIMIT 5;

# Dashboard live-data proof
# Make a change via vsql or DBeaver, refresh the Grafana panel, confirm it updates.
```

---

## 🏁 Closing note

Nine days ago, most of you had never opened a terminal. Today you independently took raw synthetic data, designed a schema for it, loaded it into a real analytical database, reasoned about performance, and built a live dashboard on top of it — the same pipeline real analytics and platform teams run in production every day. That's the whole course, working end to end, unassisted.

Well done. 🚀
