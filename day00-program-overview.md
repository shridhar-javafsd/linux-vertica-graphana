# Day 0 — Program Overview

*Adaps Fresher Training | Linux → Vertica → Grafana → Capstone*
*Delivery Location: Hyderabad (In-Classroom, Full-Day)*

---

## 📑 Table of Contents

| File | Day | Module |
|---|---|---|
| `day00-program-overview.md` | — | Program Overview (you're here) |
| `day01-linux-fundamentals-1.md` | 1 | Environment Setup + Linux Fundamentals I |
| `day02-linux-fundamentals-2.md` | 2 | Linux Fundamentals II |
| `day03-linux-fundamentals-3.md` | 3 | Linux Fundamentals III |
| `day04-linux-networking.md` | 4 | Linux Networking & Environment Deep-Dive |
| `day05-vertica-intro-install.md` | 5 | Vertica — Intro & Install |
| `day06-vertica-sql-fundamentals.md` | 6 | Vertica — SQL Fundamentals |
| `day07-vertica-loading-performance.md` | 7 | Vertica — Loading & Performance |
| `day08-grafana-intro-install.md` | 8 | Grafana — Intro & Install |
| `day09-grafana-dashboarding.md` | 9 | Grafana — Dashboarding |
| `day10-capstone.md` | 10 | Capstone Project |

Keep all 11 files in one folder. Each one is self-contained — recap, concepts, hands-on, lab, and a copy-paste command reference — so you can jump back to any day later without hunting through slides.

---

## 🎯 Program Overview

| | |
|---|---|
| **Batch Size** | 5 participants |
| **Target Audience** | Entry-level freshers (basic → intermediate coverage) |
| **Format** | Full-day, in-classroom, Hyderabad |
| **Duration** | 10 working days |
| **Timings** | 10 AM - 5 PM |
| **Start Date** | Friday, 28 August 2026 |
| **Training Completion** | Thursday, 10 September 2026 |
| **Topic Sequence** | Linux → Vertica → Grafana → Capstone (Integration Project) |

**Why this order?** Grafana is a visualization layer — it's only meaningful once real data exists underneath it. Teaching Vertica before Grafana means every Grafana exercise runs against *live Vertica tables*, not dummy sample data. That turns the last two days into genuine integration practice instead of an isolated tool walkthrough.

No prior Linux, database, or dashboarding experience is assumed. By Day 10, you'll independently load a fresh dataset into Vertica *and* build a working dashboard on it — no hand-holding.

---

## ✅ Prerequisites

What's expected coming in:

- Basic computer literacy — comfortable with file management and a terminal/command prompt at a beginner level
- A fundamental grip on programming logic: variables, loops, conditionals (typical of any fresher engineering/CS background)
- Your own laptop meeting the hardware/software requirements below, available for the full 10 days
- Willingness to work hands-on in a terminal-driven environment, especially during the Linux and Vertica modules

That's it. Everything Linux/Vertica/Grafana-specific starts from zero on Day 1.

---

## 💻 Hardware & Software Requirements

### Hardware (your machine)

- **Windows 11, x86_64 (Intel/AMD)** — required for native Vertica compatibility. Vertica has **no native ARM64/Apple Silicon build**, so this isn't optional.
- **Hardware virtualization enabled** (Intel VT-x / AMD-V) — required by both WSL2 and Docker Desktop. Check via Task Manager → Performance → CPU → "Virtualization: Enabled." If disabled, it needs turning on in BIOS/UEFI before Day 1.
- **16 GB RAM minimum** — running Linux + Docker + a database alongside Windows adds up fast.
- **20–30 GB free disk space** — for WSL2 Ubuntu, Docker Desktop, the Vertica CE image, Grafana, and sample datasets.
- Stable internet, especially Day 1 (package downloads) and Day 5 (Docker image pull).

### Software stack (100% free / open-source — zero licensing cost)

| Component | Purpose | Licensing |
|---|---|---|
| WSL2 + Ubuntu | Linux environment running natively on Windows 11 (WSLg gives GUI app support) | Free — built into Windows 11 |
| Docker Desktop | Runs the Vertica CE container via its WSL2 backend, with WSL Integration exposing `docker` inside Ubuntu | Free for this use case |
| Vertica Community Edition | Analytical database — runs as a Docker container (`molo17/vertica-ce:24.1.0-0`), pre-loaded with the VMart sample dataset | Free — CE license terms apply |
| Grafana OSS | Dashboarding & visualization — installed natively via official APT repo, runs as a systemd service inside Ubuntu | Free, open source |
| DBeaver Community Edition | GUI SQL client for Vertica (Vertica has no native Workbench-style tool); connects to `localhost:5433` | Free, open source |
| Web Browser | Accessing Grafana UI at `localhost:3000` | N/A — no separate client needed |

> 💡 **Mixed native + containerized setup.** Grafana runs natively inside Ubuntu/WSL2 as a systemd service — reinforcing the exact Linux admin skills built in Days 1–4. Vertica runs inside a Docker container (via Docker Desktop's WSL2 backend), using a **third-party Community Edition image** (`molo17/vertica-ce`) rather than Rocket Software's official `.deb` package. This was adopted as a practical workaround after Vertica's free self-service CE download became unavailable following its Feb–May 2026 change of ownership from OpenText to Rocket Software. It is not an officially Rocket-published image — worth keeping in mind if this environment is ever considered for anything beyond this training lab. A clean WSL2 image gets exported after setup as a reset safety net in case anything breaks mid-session.

---

## 🗓️ Day-Wise Delivery Schedule

| Day | Date | Module | Learning Outcome |
|---|---|---|---|
| 1 | Fri, 28 Aug 2026 | Environment Setup + Linux Fundamentals I | Comfortable navigating and manipulating the Linux filesystem entirely from the command line |
| 2 | Mon, 31 Aug 2026 | Linux Fundamentals II | Able to manage users, monitor running processes, and control services confidently |
| 3 | Tue, 1 Sep 2026 | Linux Fundamentals III | Able to automate simple repetitive tasks and manage software installation independently |
| 4 | Wed, 2 Sep 2026 | Linux Networking & Environment Deep-Dive | Comfortable with core networking tools, log inspection, and a fully verified WSL2 environment ready for Vertica |
| 5 | Thu, 3 Sep 2026 | Vertica — Intro & Install | A working, independently-installed, verified single-node Vertica CE instance on your own machine |
| 6 | Fri, 4 Sep 2026 | Vertica — SQL Fundamentals | Comfortable writing and executing Vertica SQL via both CLI (`vsql`) and GUI (DBeaver) |
| 7 | Mon, 7 Sep 2026 | Vertica — Loading & Performance | Able to load real-world data into Vertica and explain the basic levers behind query performance |
| 8 | Tue, 8 Sep 2026 | Grafana — Intro & Install | Grafana installed, running as a service, comfortable navigating the interface |
| 9 | Wed, 9 Sep 2026 | Grafana — Dashboarding | Able to build a functional Grafana dashboard against live Vertica data |
| 10 | Thu, 10 Sep 2026 | Capstone Project | Demonstrated, independently-verified end-to-end competency: Linux → Vertica → Grafana |

---

## 📖 How the daily notes work

Every `day01`–`day10` file follows the same shape:

1. **Recap** — 3 lines on what you did the previous day
2. **Concepts** — what you're learning today, explained plainly
3. **Hands-on** — guided walkthroughs, done *with* the trainer
4. **Lab** — the "now you do it alone" exercise
5. **Copy-paste reference** — every command/query from the day, in one block, for revision later
6. **Tomorrow** — a 2-line preview

Day 1 has one extra section right up front: **environment setup**. You'll walk in with a stock Windows 11 laptop, and the first ~45–60 minutes of Day 1 gets you a working WSL2 + Ubuntu environment before any Linux content starts. Everything after that follows the standard shape above.

---

## 📝 Notes

- All software used is free/open-source — no licensing budget required from you or Adaps.
- Windows 11 (x86_64) laptops are mandatory for every participant and the trainer. Vertica has no native ARM64 build, so Apple Silicon Macs won't work for this program.
- Duration can flex to 12 working days if extra depth is needed (e.g., deeper Vertica performance tuning or a second capstone), without significantly affecting the go-live buffer.

---

## 🚀 Let's go

Head to `day01-linux-fundamentals-1.md` when you're ready to start. See you Day 1.
