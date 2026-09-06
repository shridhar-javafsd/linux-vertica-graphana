# Day 10 — Capstone Project

*Thu, 10 Sep 2026*

---

## 🔁 Recap: Days 1–9

Nine days, three tools, one pipeline: Linux got you a working environment (Days 1–4), Vertica got you a real analytical database with real data in it (Days 5–7), Grafana turned that data into something you could actually show someone (Day 8, then Day 9's morning). Day 9's afternoon forked — two of you went deep on Prometheus, the other four sharpened core Grafana skills further. Today there's no new material — today's the day you prove it all actually stuck, whichever afternoon track you were on.

---

## 🎯 Today works differently

No guided walkthroughs, no "do this together." You get a scenario, a fresh dataset, and a checklist of what needs to exist by end of day. Everything else — schema design, loading, projections, dashboard, all of it — is on you.

**This isn't closed-book.** Every day's courseware and all three participant manuals (Linux/Vertica/Grafana) are fair game all day — that's exactly how you'd work on a real job. The goal isn't "recall commands from memory," it's "can you actually get from raw data to a working dashboard using the resources available to you."

**One rubric, two tiers.** There's a **Core** checklist everyone must complete — that's the actual client deliverable, and it's the same bar for all six of you regardless of yesterday afternoon's track. On top of that, there's a **Stretch** list: extra, optional items that let you apply the deeper stuff from Days 8–9 (transformations, chained variables, the full alerting loop, or — if you were on Track A yesterday — an actual live Prometheus panel). Nobody's expected to do all of the stretch list. Pick what interests you.

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

> 💡 **Small heads-up on the script:** for `resolution_hours` under 24, integer division (`resolution_hours / 24`) rounds down to `0` days added — meaning `closed_date` often equals `opened_date`. That's not a bug; same-day resolution is realistic for quick tickets. Just don't be thrown by it when you spot-check your data.

---

## ✅ Core deliverables — required for everyone

This is your baseline rubric. Check honestly against it before presenting — this is the actual client-facing bar, same for all six of you regardless of yesterday's track.

1. **Environment started and verified** — Docker, the Vertica container, and Grafana don't start themselves (deliberately not `enable`d) — start them, then confirm they're actually running (your own choice of commands — you've run these dozens of times by now)
2. **A new schema and table(s) in Vertica** for the helpdesk data, with data types you chose deliberately — not just "everything is VARCHAR"
3. **Data loaded via `COPY`** — handling the blank fields sensibly (decide: `NULL`, or a placeholder — and be ready to explain why)
4. **At least one custom projection**, with a reason you can articulate (which query pattern is it optimized for?)
5. **Grafana connected to your Vertica instance** (already done if it's still running from Day 9 — verify, don't just assume)
6. **A dashboard with at least 4 different panel types**, including at least one *beyond* the "big three" (Time series/Table/Stat) — e.g., a Gauge, Bar gauge, Bar chart, or Pie chart — picked because it actually fits what that panel shows, not just for variety's sake
7. **Proper field formatting on every Stat/Gauge panel** — a real unit (not a raw number) and at least one threshold that changes color based on value
8. **At least one dashboard variable** (e.g., filter by `category` or `assigned_team`)
9. **At least one alert rule**, with a sensible condition and evaluation interval — it doesn't need to fire (this data's as static as VMart once loaded), but you should be able to explain its anatomy
10. **A 5-minute presentation prepared** (see below)

---

## 🌟 Stretch deliverables — optional, pick what interests you

Not required, not scored against you if skipped — these exist so the deeper Day 8–9 content has somewhere to land. Good conversation material for the client presentation too: "here's the baseline, and here's what I additionally tried."

- **A transformation** that genuinely changes what's displayed (e.g., an "average resolution time by team" panel using an *Add field from calculation* transform, rather than baking it into the SQL)
- **A chained (dependent) variable pair** — e.g., `$team` narrowing down a second `$category`-style variable, or vice versa
- **A panel repeated by variable** — one panel, automatically cloned per team or per category
- **One annotation** — manual or query-driven — marking a notable date on your time series (a spike in ticket volume, say)
- **The full alerting loop** — not just the rule from Core #9, but an actual contact point and notification policy wired to it
- **A data link** — click a team or category in a table and drill through to a second, filtered view
- **Organize your dashboard into a folder**, and briefly look at its JSON Model — be ready to point out where your variable definition lives in the raw JSON
- **Vertica query-performance habits** — no `SELECT *`, aggregation done in SQL not in a transformation, `$__timeFilter()` used properly wherever there's a time dimension
- **🅰️ If you were on the Prometheus track yesterday:** add one bonus panel to (or alongside) your dashboard pulling in a live system metric via your Prometheus data source — e.g., current CPU/memory of the machine you're working on, sitting next to your ticket data. It doesn't need to relate to the helpdesk scenario; the point is showing you can maintain and use both data source types in one Grafana instance.

---

## 🆘 If you get stuck

This is expected — getting stuck and finding your own way out is part of what's being practiced today. Where to look:

| Stuck on... | Go back to |
|---|---|
| Schema/table design, data types | `day06-vertica-sql-fundamentals.md` + Vertica manual (schema/data-types section) |
| `COPY`, handling blank/messy fields | `day07-vertica-loading-performance.md` + Vertica manual (loading section) |
| Projections | `day07-vertica-loading-performance.md` + Vertica manual (projections section) |
| Docker/container basics, base Vertica or Grafana install | `day04-vertica-grafana-installation-guide.md` (PARTs 5–9 for Vertica, PARTs 13–18 for Grafana) + Grafana manual §0 |
| Connecting Grafana / plugin issues | `day04-vertica-grafana-installation-guide.md`, PARTs 17–18 + Grafana manual §4 |
| Panel types | `day08-grafana-deep-dive.md`, "Panel types — the full tour" + Grafana manual §6 |
| `$__timeFilter`, "Data outside time range" | `day04-vertica-grafana-installation-guide.md`, PARTs 19–20 + Grafana manual §5 |
| Field formatting, thresholds, units | `day08-grafana-deep-dive.md`, "Field & panel options" + Grafana manual §7 |
| Transformations | `day08-grafana-deep-dive.md`, "Transformations" + Grafana manual §8 |
| Dashboard variables (incl. chained/repeat) | `day08-grafana-deep-dive.md`, "Variables — the deep dive" + Grafana manual §9 |
| Annotations | `day08-grafana-deep-dive.md`, "Annotations" + Grafana manual §10 |
| Alerting (rule anatomy or the full loop) | `day08-grafana-deep-dive.md` (anatomy) + `day09-grafana-advanced-and-prometheus.md`, Track B (full loop) + Grafana manual §11 |
| JSON Model, folders, provisioning | `day09-grafana-advanced-and-prometheus.md`, morning session + Grafana manual §12–14 |
| Data links | `day09-grafana-advanced-and-prometheus.md`, Track B + Grafana manual §19 |
| Prometheus (stretch item) | `day09-grafana-advanced-and-prometheus.md`, Track A + Grafana manual §20 |

> ⚠️ Vertica-side row references (`day05/06/07`, "Vertica manual" section names) haven't been re-verified against the current Vertica courseware/manual — double-check those file names and section numbers still match what you actually have before relying on this table for that part.

---

## 🎤 Presentation guidance

Keep it to 5 minutes. Cover:

1. **A quick walkthrough of your dashboard** — what each panel shows, and why you picked that visualization type for it
2. **One deliberate decision you made** — a data type choice, why you created the projection you did, how you handled the blank fields — and your reasoning
3. **One thing that broke, and how you fixed it** — everyone hits at least one snag; explaining your own debugging process out loud is a genuinely useful skill, and normalizes the fact that hitting errors is just part of the work
4. **Any stretch items you attempted** — even a partial attempt is worth mentioning; this is your chance to show off anything beyond the baseline, Prometheus panel included if that's your track

You're not being judged on a perfect dashboard — you're being judged on whether you can reason about *why* you built it the way you did.

---

## 🔬 Self-check reference — commands you already know

Not new syntax — just the checkpoints worth running before you consider yourself "done":

```bash
# Start (not enabled on purpose - this won't be running yet)
docker start vertica-ce
sudo systemctl start grafana-server

# If you're on the Prometheus stretch item, these two as well:
# ./node_exporter &          (from wherever you extracted it yesterday)
# ./prometheus --config.file=prometheus.yml &

# Environment
docker ps                                    # Vertica container running?
sudo systemctl status grafana-server --no-pager   # Grafana running?
ss -lntp | grep -E "3000|5433|9090|9100"      # Grafana/Vertica ports, plus Prometheus/node_exporter if relevant

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
