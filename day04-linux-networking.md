# Day 4 — Linux Networking & Environment Deep-Dive

*Wed, 2 Sep 2026*

---

## 🔁 Recap: Day 3

You wrote your first real shell scripts (variables, conditionals, loops, functions) and got the full story on `apt`/`dpkg`/repositories/`PATH`. Today's the last pure-Linux day before Vertica shows up tomorrow — networking basics, firewall rules, log inspection, and a full health-check on the WSL2 environment you set up on Day 1.

---

## 📚 Concepts

### Networking basics — the vocabulary

- **IP address** — a numeric address identifying a machine on a network. `127.0.0.1` (aka `localhost`) always means "this machine, talking to itself" — how you'll reach Grafana (`localhost:3000`) and Vertica (`localhost:5433`) later this week.
- **Port** — a number (0–65535) identifying *which service* on that machine you want. One machine, many services, each claiming its own port. `443` = HTTPS, `22` = SSH, and — worth memorizing now — `5433` = Vertica, `3000` = Grafana.
- **DNS** — the system that turns human-friendly names (`google.com`) into IP addresses. `/etc/hosts` is your local override file — checked *before* DNS, useful for pointing a name at a specific IP manually.

### Practical tools

```bash
ping google.com          # tests reachability + DNS resolution (Ctrl+C to stop)
ping -c 4 8.8.8.8         # same, but by raw IP (skips DNS) — 4 pings then stop

curl -I https://example.com     # fetch just the HTTP headers — quick "is it alive" check
curl -I https://apt.grafana.com  # you'll recognize this URL from later this week

ss -tulpn                # show every port currently listening on this machine
```

`ss` reads: `-t` (TCP), `-u` (UDP), `-l` (listening only), `-p` (which process owns it), `-n` (numeric ports, don't resolve names). This is the modern replacement for the older `netstat` — you'll still see `netstat` in older tutorials, but `ss` is faster and what's actually installed by default now.

### Firewall basics with `ufw`

```bash
sudo ufw status            # is it even on?
sudo ufw enable             # turn it on
sudo ufw allow 3000/tcp     # allow traffic on a specific port
sudo ufw allow 5433/tcp
sudo ufw status verbose     # see your rules
```

Default behavior once enabled: **deny incoming, allow outgoing** — nothing can reach in unless you explicitly allow it, but you can still reach out to the internet freely. We're allowing `3000` and `5433` now, ahead of time, because that's exactly what Grafana and Vertica will need — no surprises on Day 5 or Day 8.

> 💡 **Worth knowing:** in WSL2 specifically, `ufw`'s enforcement sits behind an extra layer — Windows' own network stack, which handles the `localhost` port-forwarding into WSL2 automatically. That forwarding largely happens *before* `ufw`'s rules come into play, so don't expect `sudo ufw deny 3000` to actually block your own browser tab at `localhost:3000` the way it would block an *external* connection on a real bare-metal server. The syntax and mental model are exactly what you'd use on a real Linux server — this WSL2 quirk is specific to the lab environment, not a reason to skip learning it properly.

### Log inspection — `journalctl`

Every systemd-managed service's logs flow into one place:

```bash
journalctl -u cron              # logs for a specific unit (cron, from Day 2)
journalctl -u cron --since "today"
journalctl -f                    # follow live, like `tail -f` (Ctrl+C to stop)
```

Older-style plain-text logs still exist too — on a full Linux install, at least:

```bash
ls /var/log
cat /var/log/syslog | tail -20
```

> 💡 **If `syslog` isn't in that `ls /var/log` listing**, that's fine — minimal images like WSL2's default Ubuntu often don't ship `rsyslog` (the tool that bridges journald into flat log files), so there's no `/var/log/syslog` to `cat`. That's not broken; it just means `journalctl` above is your actual source of truth here, which is genuinely the modern norm anyway — plenty of real production systems today rely on journald alone. Only run the `cat` line if `syslog` actually showed up in the listing.

`journalctl -u <service>` will become one of your most-used debugging commands the moment Vertica or Grafana misbehaves later this week — get comfortable with it now while the stakes are low.

### Environment deep-dive: verifying WSL2 properly

You set this up on Day 1. Today, we verify it thoroughly — because tomorrow, Vertica needs a rock-solid foundation.

**🪟 Run in PowerShell:**

```powershell
wsl -l -v
```

Confirm `Ubuntu` shows `VERSION 2`.

**🐧 Run inside Ubuntu:**

```bash
ps -p 1                # must still show systemd
lsb_release -a           # confirm Ubuntu version
```

### WSLg — GUI apps from Linux, on your Windows desktop

WSLg is what lets a Linux GUI application open as a normal-looking window directly on your Windows desktop — no separate VM window, no extra remote-desktop tool. It's built into WSL2 by default on Windows 11. Let's prove it works.

```bash
sudo apt install -y x11-apps
xeyes
```

`xeyes` is the classic, decades-old test app for exactly this purpose — a pair of eyes that track your mouse cursor. If a window pops up on your Windows desktop, WSLg is confirmed working.

---

## 🧪 Guided hands-on (do this together)

**🐧 Run inside Ubuntu, unless labeled otherwise.**

```bash
ping -c 4 google.com
ping -c 4 8.8.8.8
curl -I https://example.com
ss -tulpn
```

Notice `ss -tulpn` probably shows very little right now — that's expected. Compare this output again on Day 5 (after Vertica) and Day 8 (after Grafana) — you'll see `5433` and `3000` show up.

```bash
sudo ufw enable
sudo ufw allow 3000/tcp
sudo ufw allow 5433/tcp
sudo ufw status verbose

journalctl -u cron --since "today"
journalctl -f
# (Ctrl+C to stop following)
```

**🪟 In PowerShell:**
```powershell
wsl -l -v
```

**🐧 Back in Ubuntu:**
```bash
ps -p 1
sudo apt install -y x11-apps
xeyes
```
(Close the `xeyes` window when you're done — click its X like any other Windows window.)

---

## 🔬 Lab — on your own

1. `ping` both a domain name and a raw IP (pick your own examples). Note the difference in what each one tells you — one confirms DNS resolution works, the other doesn't need DNS at all.
2. Use `curl -I` to check the response headers of any website of your choice. Screenshot or note down the `HTTP/…` status line.
3. Run `ss -tulpn` and identify every port currently listening. Note what you see (even if it's minimal).
4. Enable `ufw`, allow ports `3000` and `5433`, and confirm both rules show up in `ufw status verbose`.
5. Run `journalctl -u cron --since "1 hour ago"` and describe in one sentence what you see.
6. Full environment verification:
   - `wsl -l -v` (PowerShell) → confirm `VERSION 2`
   - `ps -p 1` (Ubuntu) → confirm `systemd`
   - Install `x11-apps`, run `xeyes`, confirm the window appears on your Windows desktop
7. **Bonus:** open a second terminal, run `journalctl -f` in one, then in the other manually trigger `sudo systemctl restart cron` — watch the log entry appear live in the first terminal the moment you restart it.

---

## 📎 Copy-paste command reference — Day 4

```bash
# --- Networking basics ---
ping -c 4 <host-or-ip>
curl -I <url>
ss -tulpn

# --- Firewall (ufw) ---
sudo ufw status
sudo ufw enable
sudo ufw allow <port>/tcp
sudo ufw status verbose

# --- Log inspection ---
journalctl -u <service>
journalctl -u <service> --since "today"
journalctl -f
ls /var/log
cat /var/log/syslog | tail -20

# --- Environment verification ---
# 🪟 PowerShell:
wsl -l -v

# 🐧 Ubuntu:
ps -p 1
lsb_release -a
sudo apt install -y x11-apps
xeyes
```

---

## 👀 Tomorrow: Day 5 — Vertica: Intro & Install

Linux is done — tomorrow you meet the actual database. You'll learn what makes Vertica different (columnar storage, MPP architecture) and get it running on your own machine via Docker, using the `molo17/vertica-ce` Community Edition image, pre-loaded with sample data. Everything you did today — ports, `ufw`, `journalctl` — is about to get real use.
