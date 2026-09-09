# Prometheus on WSL2 — The Full Install, and Every Bug We Actually Hit

*This isn't a "here's the theory" doc. This is "here's exactly what happened when a real person on a real Windows 11 + WSL2 machine actually did this," bugs and all. If you hit any of these tomorrow, you're not doing it wrong — you're doing it exactly right, because this is what actually happens.*

---

## 🗺️ The picture, one more time

```
┌────────────────────────────────────────────────────────────────┐
│ Windows 11                                                     │
│                                                                │
│  ┌────────────┐   ┌────────────────────────────┐ ┌───────────┐ │
│  │ DBeaver    │   │ WSL2 · Ubuntu               │ │ Docker    │ │
│  │ Vertica    │   │                             │ │ Desktop   │ │
│  │ client     │   │ ┌───────────────┐           │ │(WSL2      │ │
│  │            │   │ │ Grafana :3000 │◄──queries──┼─┤ backend)  │ │
│  │            │   │ └───────┬───────┘           │ │┌─────────┐│ │
│  │            │   │         │  ▲                │ ││Vertica  ││ │
│  │            │   │         │  │ queries         │ ││CE demo  ││ │
│  │            │   │  ┌──────▼──┴────┐            │ ││:5433    ││ │
│  │            │   │  │ Prometheus   │            │ │└─────────┘│ │
│  │            │   │  │ :9090        │            │ └───────────┘ │
│  │            │   │  └──────▲───────┘            │               │
│  │            │   │         │ scrapes            │               │
│  │            │   │  ┌──────┴───────┐            │               │
│  │            │   │  │ node_exporter│            │               │
│  │            │   │  │ :9100        │            │               │
│  │            │   │  └──────────────┘            │               │
│  └─────┬──────┘   └─────────────────────────────┘               │
└──────────────────────────────────────────────────────────────────┘
```

Two new binaries, both native, both running straight inside WSL2 — no Docker needed here, unlike Vertica. Why native? Because `node_exporter` needs to read your actual OS's `/proc` filesystem, and a container would need extra flags/mounts to see that cleanly. Native = simplest = correct for this specific job.

> 💡 **Why node_exporter needs to exist at all:** neither Prometheus nor Grafana can read your OS's CPU/RAM/disk stats directly — nothing "just knows" that stuff by default. `node_exporter`'s entire job is reading Linux's own `/proc` and `/sys` files (the kernel's own internal counters) and republishing them as a simple web page of numbers at `:9100/metrics`. It's the translator between "raw kernel internals" and "something Prometheus can actually scrape." No exporter running = nothing for Prometheus to pull from, full stop.

---

## 🛠️ The clean install (do it this way, skip our detour)

**node_exporter:**
```bash
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
cd node_exporter-1.8.2.linux-amd64
./node_exporter --collector.filesystem.mount-points-exclude='^/(dev|proc|run/credentials/.+|run/user|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)' &
curl localhost:9100/metrics | head -20
```

> ⚠️ **Check version numbers before you `wget`.** `v1.8.2` was current when this doc was written — a quick look at the [releases page](https://github.com/prometheus/node_exporter/releases) takes ten seconds and saves you downloading something already outdated.

> 🐛 **That `--collector.filesystem.mount-points-exclude` flag isn't optional on WSL2 — build it in from the start.** More on exactly why below. Skip it and you'll see a wall of `error gathering metrics` spam every 15 seconds. It's not fatal, but it's noisy and worth avoiding entirely.

**Prometheus:**
```bash
cd ~
wget https://github.com/prometheus/prometheus/releases/download/v2.54.1/prometheus-2.54.1.linux-amd64.tar.gz
tar xvf prometheus-2.54.1.linux-amd64.tar.gz
cd prometheus-2.54.1.linux-amd64
nano prometheus.yml
```

In `prometheus.yml`, add under `scrape_configs:`
```yaml
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```
Save (`Ctrl+O`, Enter, `Ctrl+X` in nano), then **actually launch it** — the step it's genuinely easy to skip:
```bash
./prometheus --config.file=prometheus.yml &
```

**Verify both, from the same terminal:**
```bash
ss -lntp | grep -E "9090|9100"
```
You want **two** lines back — one process per port. If you only see one, something didn't start.

---

## 🔁 Starting and stopping everything, next time onwards

Here's the thing worth knowing before you close your laptop today: **node_exporter and Prometheus don't auto-start, and they don't remember they existed once the terminal that launched them is gone.** Unlike Grafana (which is a proper `systemd` service you just `start`/`stop`) and Vertica (which is a Docker container you `docker start`/`docker stop`), these two are just raw binaries you launched by hand with `&` — no service wrapper, no memory of their own. Every session, you're starting them fresh.

### ▶️ Full startup routine, in order

```bash
# 1. Vertica (if not already running)
docker start vertica-ce

# 2. Grafana
sudo systemctl start grafana-server

# 3. node_exporter — from its own folder
cd ~/node_exporter-1.8.2.linux-amd64
./node_exporter --collector.filesystem.mount-points-exclude='^/(dev|proc|run/credentials/.+|run/user|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)' &

# 4. Prometheus — from its own folder
cd ~/prometheus-2.54.1.linux-amd64
./prometheus --config.file=prometheus.yml &
```

**Confirm all four are actually up:**
```bash
docker ps                                          # Vertica container running?
sudo systemctl status grafana-server --no-pager    # Grafana running?
ss -lntp | grep -E "3000|5433|9090|9100"           # all four ports listening?
```

### ⏹️ Stopping everything cleanly

```bash
# Grafana (proper service, proper stop)
sudo systemctl stop grafana-server

# Vertica (proper container, proper stop)
docker stop vertica-ce

# Prometheus and node_exporter — find the PID, then kill it
ss -lntp | grep -E "9090|9100"
kill <PID from that output>
kill <the other PID>
```

There's no `stop node_exporter` command — it's not a service, it's just a running process. Find its PID (the number in the `ss` output), then `kill` that number. Same for Prometheus.

> 💡 **Why doesn't this feel as clean as Grafana's `start`/`stop`?** Because it genuinely isn't, on purpose, for this training setup. In a real production install, someone would write proper `systemd` unit files for both — `sudo systemctl start node_exporter`, `sudo systemctl start prometheus`, same polish as Grafana already has. That's a legitimate next step if you ever want this running long-term, but it's outside the scope of what we needed for this course — a `&` in a terminal was the fastest way to get you seeing real metrics today.

---

## 🐛 Every real bug from today, and why it happened

### 1. "I edited the config but Prometheus never came up" — skipped a step, not broken

**What happened:** `nano prometheus.yml` → save → straight to `ss -lntp` to check — but the actual `./prometheus --config.file=prometheus.yml &` command in between never got typed. Editing a config file doesn't start anything; it's just a text edit until something reads it.

**How you'd notice:** `ss -lntp | grep 9090` comes back with nothing. `localhost:9090` in the browser says "This site can't be reached."

**Fix:** just run the start command. That's it, no cap.

### 2. The WSL2 duplicate-mountpoint bug — a real environment quirk, not your fault

**What happened:** node_exporter kept logging `error gathering metrics` every 15 seconds, always about `/run/user` being reported twice with the same values.

**Why:** WSL2's systemd/session emulation double-exposes that one specific mountpoint. node_exporter's metric collector doesn't like seeing the same metric+labels twice and throws an error rather than silently picking one. This is a known WSL2-specific quirk, not something you configured wrong.

**Fix, attempt 1 (didn't work):**
```bash
--collector.filesystem.mount-points-exclude='^/(dev|proc|run/credentials/.+|run/user/.+|sys|...)($|/)'
```
Look closely: `run/user/.+` requires *something after* the slash (like `run/user/1000`). The actual problem path is the bare `/run/user` with **nothing** after it — so this pattern never matched it, and the errors kept coming.

**Fix, attempt 2 (this one worked):**
```bash
--collector.filesystem.mount-points-exclude='^/(dev|proc|run/credentials/.+|run/user|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)'
```
Dropped the `/.+` after `run/user` — now it matches the bare path too. One character's worth of regex, big difference.

**How to confirm it's actually fixed:** `curl localhost:9100/metrics | head -20` — real metric lines only, zero `error gathering metrics` text mixed in.

### 3. "No such file or directory" — wrong folder, not a broken install

**What happened:** typed `./node_exporter` while sitting inside the `prometheus-2.54.1...` folder.

**Why:** `./` means "right here, in my current directory." The binary lives in a totally different folder (`~/node_exporter-1.8.2-linux-amd64/`). Bash isn't smart enough to go looking elsewhere — it just tells you flat-out the file isn't *here*.

**Fix:** `cd` into the correct folder first, every time, before running `./whatever`. Sounds obvious in hindsight — happens to literally everyone at least once.

### 4. `kill %1` said "no such job" — you were in a different terminal window

**What happened:** opened a second WSL window to check on things, then tried `kill %1` from there.

**Why:** `%1` refers to *this shell session's own* job table — background jobs launched in window 1 don't show up in window 2's job list at all, even though they're still running fine.

**Fix:** use the actual PID instead of `%1` — grab it from `ss -lntp | grep 9100`, then `kill <that number>`. PIDs work from any terminal; job numbers (`%1`, `%2`) only work in the exact shell that launched them.

### 5. "curl: Failed writing body" — a total non-issue

**What happened:** `curl localhost:9100/metrics | head -20` printed a scary-looking error at the very end.

**Why:** `head -20` grabs its 20 lines and immediately closes its input, while `curl` is still mid-way through writing the rest of a much longer response. `curl` then complains the pipe closed on it. This happens on literally any healthy endpoint piped into `head` — it's not evidence of anything broken.

**How to tell it's fine:** look at what actually printed before that message. If it's real content (not an error block), you're good — ignore the tail-end complaint entirely.

### 6. Checking the wrong page — Graph tab vs. Status → Targets

**What happened:** landed on Prometheus's Graph tab, saw "No data queried yet," assumed something was broken.

**Why:** the Graph/Table tab is Prometheus's own query playground — it shows nothing until *you* type a PromQL expression into it. It was never going to show anything on its own; that's not what it's for.

**The actual health check:** **Status → Targets**. That page lists every scrape target Prometheus knows about, with a `State` column — `UP` (green) means it's genuinely scraping successfully; `DOWN` (red) comes with a real error message telling you why.

### 7. Old scrollback log ≠ a new problem

**What happened:** pasted a huge wall of terminal output showing `error gathering metrics` messages, worried it was still broken.

**Why:** every single timestamp in that block was *before* the moment the fixed version actually started. It was the dying old process's last few log lines, scrolled past in the terminal — not anything currently happening.

**The tell:** check the timestamps against when you actually ran the fix. If everything alarming is *earlier* than your fix, you're looking at history, not a live issue.

### 8. Don't close the terminal — background jobs die with it

Both `node_exporter &` and `prometheus &` are tied to the shell session that launched them (no `nohup`, no `systemd` service — this is the quick-and-dirty training version, not production). **Closing that WSL window kills both.** Need a clean terminal? Open a *new* WSL tab instead of closing the one running your services.

---

## ✅ How you actually know it's all working

1. `ss -lntp | grep -E "9090|9100"` → two processes, two ports
2. `curl localhost:9100/metrics | head -20` → real metrics, zero `error gathering` noise
3. `localhost:9090` → **Status → Targets** → job `node` shows **State: UP**
4. Grafana → **Connections → Data sources → Add data source → Prometheus** → URL `http://localhost:9090` → **Save & test** → green success banner

---

## 📊 Getting an actual dashboard out of it

Fastest path — **import, don't hand-build:**
```
Dashboards → New → Import
Dashboard ID: 1860   ("Node Exporter Full")
→ pick your Prometheus data source
→ Import
```
You get a full CPU/Memory/Disk/Network dashboard, live off your own machine, zero manual panel-building. This is the exact "Task Manager, but with history" result from way back at the start of this whole Grafana journey.

**Want to poke at raw numbers first?** Explore (left sidebar) → pick Prometheus → try these:

| Metric | What it shows |
|---|---|
| `node_memory_MemAvailable_bytes` | RAM currently available |
| `node_load1` | 1-minute load average |
| `node_filesystem_avail_bytes` | Disk space free, per mountpoint |
| `rate(node_cpu_seconds_total{mode="idle"}[5m])` | CPU idle % over the last 5 min — PromQL's version of "how busy is this box" |

Note the last one uses `rate(...[5m])` — that's PromQL's way of turning a constantly-climbing counter into "how fast is it climbing right now," the rough equivalent of Vertica's `$__timeFilter()` doing time-range math for you, just a completely different syntax for a completely different kind of database.

---

## 🎯 tl;dr — the one-liner version of this whole doc

Two binaries, run natively in WSL2, not Docker. Always `cd` into the right folder before `./`-running anything. Always actually run the start command, not just edit the config. Add the mount-exclude flag to node_exporter from the start on WSL2. Check `Status → Targets` for real health, not the Graph tab. Don't close the terminal. And if a wall of red terminal text has timestamps from before your fix — it's not a new problem, it's just history scrolling by.
