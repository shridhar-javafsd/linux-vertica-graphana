# Day 2 — Linux Fundamentals II

*Mon, 31 Aug 2026*

---

## 🔁 Recap: Day 1

You got a working WSL2/Ubuntu box, learned to navigate the filesystem (`pwd`, `cd`, `ls`, `tree`), manipulate files (`mkdir`, `cp`, `mv`, `rm`), and lock things down with `chmod`/`chown`/`umask`. Today: Linux stops being single-player. Users, groups, sudo, and the processes/services running underneath it all.

---

## 📚 Concepts

### Linux is multi-user by design

Every process, every file, belongs to *someone*. Even on your solo WSL2 box, Linux still thinks in terms of multiple accounts — which matters the moment you need to run something with restricted access (exactly what you'll do for Vertica's `dbadmin` account on Day 5).

### Where user info actually lives: `/etc/passwd`

```bash
cat /etc/passwd | head -5
```

Each line is colon-separated:

```
username:x:UID:GID:comment:home_directory:shell
```

| Field | Meaning |
|---|---|
| `username` | login name |
| `x` | password placeholder (real hash lives in `/etc/shadow`, root-only) |
| `UID` | user ID number |
| `GID` | primary group ID |
| `comment` | optional full name / notes |
| `home_directory` | usually `/home/<username>` |
| `shell` | what runs when they log in — usually `/bin/bash` |

Groups work the same way, in `/etc/group`:

```bash
cat /etc/group | head -5
```

### Creating users and groups

```bash
sudo useradd -m -s /bin/bash traineeuser   # -m creates a home dir, -s sets the shell
sudo passwd traineeuser                     # set their password
sudo groupadd devteam                        # create a new group
sudo usermod -aG devteam traineeuser         # add traineeuser to devteam (-a = append, don't overwrite)
```

> ⚠️ **Never drop the `-a`.** `usermod -G devteam traineeuser` (no `-a`) doesn't *add* `traineeuser` to `devteam` — it **replaces every supplementary group they're in** with just `devteam`, silently kicking them out of everything else. `-a` (append) is what makes it additive instead of destructive. This is a genuinely common real-world mistake — always double-check `-a` is there before running `usermod -G`.

> 💡 `useradd` is the low-level, scriptable command — no prompts, does exactly what you tell it. (You'll sometimes see `adduser` on Debian-based systems, a friendlier interactive wrapper around the same thing. We're sticking with `useradd` since it's what you'll actually script with.)

Check your work:

```bash
id traineeuser              # shows UID, GID, and all group memberships
groups traineeuser          # just the group list
```

### `sudo` and the principle of least privilege

Nobody should operate as `root` all the time — one typo in `root` and you can wreck the whole system. `sudo` lets a permitted user run *one command* with elevated privileges, then drops back down.

Who's allowed to `sudo`? Controlled by `/etc/sudoers` — never edit this file directly, always use:

```bash
sudo visudo
```

`visudo` checks your syntax before saving, so a typo can't lock everyone out of `sudo` entirely. The common shortcut to grant a user full sudo rights is adding them to the `sudo` group instead of touching the file:

```bash
sudo usermod -aG sudo traineeuser
```

### Process management

Every running program is a **process**, with a PID (process ID).

```bash
ps                # processes in YOUR current shell
ps aux             # every process, every user, full detail
top                # live, auto-refreshing process viewer (press q to quit)
```

**Foreground vs background:**

```bash
sleep 100          # runs in the foreground — terminal is stuck until it finishes
sleep 100 &        # the & backgrounds it immediately — you get your prompt back
jobs               # list background jobs in this shell
fg %1               # bring job 1 back to the foreground
```

`Ctrl+C` kills a foreground process. `Ctrl+Z` *pauses* it (doesn't kill it — use `bg` to resume it in the background).

**Killing processes:**

```bash
kill <PID>          # polite request to stop (SIGTERM)
kill -9 <PID>        # force kill, no cleanup (SIGKILL) — last resort
pkill sleep           # kill by process NAME instead of hunting for a PID
```

### systemd — the service manager

You already confirmed `systemd` is PID 1 on Day 1. It's the thing that starts, stops, and supervises every long-running service on your system — including Vertica and Grafana later this week.

```bash
sudo systemctl status <service>    # is it running? recent logs?
sudo systemctl start <service>     # start it now
sudo systemctl stop <service>      # stop it now
sudo systemctl restart <service>   # stop then start
sudo systemctl enable <service>    # auto-start on every systemd boot
sudo systemctl disable <service>   # turn off auto-start
```

This exact pattern — `status` → `start`/`stop` → `enable` — is what you'll run for Vertica on Day 5 and Grafana on Day 8. Get comfortable with it now.

---

## 🧪 Guided hands-on (do this together)

**🐧 Everything below runs inside your Ubuntu terminal.**

**1. Create a limited-privilege user, together:**

```bash
sudo useradd -m -s /bin/bash demoUser
sudo passwd demoUser
cat /etc/passwd | grep demoUser
id demoUser
```

Switch into that user's session to prove it's real, then come back:

```bash
su - demoUser
whoami
exit
```

> 💡 `su - demoUser` will prompt for **demoUser's** password — the one you just set with `passwd`, not your own. Typing your own password here won't work.

**2. Play with processes:**

```bash
sleep 300 &
jobs
ps aux | grep sleep
kill %1
jobs
```

**3. Install and control a real service — `cron`:**

```bash
sudo apt install -y cron
sudo systemctl status cron
sudo systemctl stop cron
sudo systemctl status cron
sudo systemctl start cron
sudo systemctl enable cron
sudo systemctl status cron
```

Watch the `Active:` line flip between `active (running)` and `inactive (dead)` as you stop/start it — that's your confirmation the command actually did something.

---

## 🔬 Lab — on your own

**Scenario:** You're setting up access for a new intern joining the "Analytics" team.

1. Create a new user called `intern1` with a home directory and `/bin/bash` as the shell.
2. Set a password for `intern1`.
3. Create a new group called `analytics`.
4. Add `intern1` to the `analytics` group (don't remove any existing group membership).
5. Confirm with `id intern1` — you should see both their primary group and `analytics` listed.
6. Using `ps aux`, find the PID of your own shell process, and screenshot/note it — you'll want to recognize this pattern when troubleshooting later.
7. Using `systemctl`, stop `cron`, confirm it's stopped, then start it again and `enable` it so it survives a restart.
8. **Bonus:** background a `sleep 600 &`, note its PID from `jobs -l`, then kill it using `kill` (not `pkill`) — practice going PID-first instead of name-first.

---

## 📎 Copy-paste command reference — Day 2

```bash
# --- Users & groups ---
cat /etc/passwd
cat /etc/group
sudo useradd -m -s /bin/bash <username>
sudo passwd <username>
sudo groupadd <groupname>
sudo usermod -aG <groupname> <username>
id <username>
groups <username>
su - <username>          # switch into that user's session
exit                       # back to your own session

# --- sudo ---
sudo visudo                          # edit sudoers safely
sudo usermod -aG sudo <username>     # grant full sudo rights

# --- Processes ---
ps
ps aux
top                        # q to quit
sleep 100 &                # background a process
jobs
jobs -l                    # jobs with PIDs
fg %1
kill <PID>
kill -9 <PID>
pkill <process-name>

# --- systemd / systemctl ---
sudo apt install -y cron
sudo systemctl status <service>
sudo systemctl start <service>
sudo systemctl stop <service>
sudo systemctl restart <service>
sudo systemctl enable <service>
sudo systemctl disable <service>
```

---

## 👀 Tomorrow: Day 3 — Linux Fundamentals III

Shell scripting: variables, `if`/`else`, `for`/`while` loops, and writing your first real `.sh` scripts to automate repetitive tasks. Afternoon shifts to package management — `apt`/`dpkg`, repositories, and environment variables/`PATH` — the exact skills behind every install you've done so far, now explained properly instead of just copy-pasted.

--- 

## Training Notes - 

sudo adduser sonu

sudo deluser sonu

useradd deluser userdel

--- 

Caution! 

### Don't do this !

sudo usermod -G devteam sonu # added to this broup but removed fro the other groups 

### Do this 

sudo usermod -aG hrteam sonu # adde to this group 


---

getent groups 

--- 

sudo useradd -m -s /bin/bash demo1

sudo useradd demo2 


