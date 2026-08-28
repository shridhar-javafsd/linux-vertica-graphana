# Trainer's Manual — Linux

*Covers: Day 0/1 environment setup, Days 1–4 Linux Fundamentals*
*Companion to: `day00-program-overview.md`, `day01`–`day04` courseware*

---

## 🎯 What this manual is for

This daywise courseware has the **what** — commands, labs, copy-paste blocks. This manual has the **why** and **how underneath it**, so when a trainee asks "but *why* does it work like that," you're not improvising. It's organized by topic, not by day, since a few of these ideas (permissions, PATH, systemd) get touched multiple times across different days.

Read this once end to end before Day 1, then dip back in per-topic the night before you teach it.

---

## 1. WSL2 and the Windows/Linux boundary

*→ Referenced in: `day01.md`, Hour 0*

### What WSL2 actually is

WSL2 is **not** a virtual machine in the traditional sense (though it uses a lightweight one under the hood via Hyper-V). Microsoft runs a real Linux kernel inside a minimal, purpose-built VM, and then makes that VM feel almost invisible — shared filesystem access via `\\wsl.localhost\`, automatic `localhost` port forwarding into Windows, near-native performance. WSL1, the older approach, tried to translate Linux syscalls into Windows syscalls directly — no real kernel, which meant a lot of things (especially anything low-level, like Docker or full systemd) simply didn't work. That's why we install WSL2, not WSL1, and why the Step 0 check in Day 1 specifically watches for `VERSION 2`.

**Why this matters pedagogically:** trainees coming from a Windows-only background often assume WSL2 = "a Linux window," like a fancy terminal emulator. It's genuinely a different kernel, different filesystem, different everything — just glued to Windows very smoothly. Worth saying explicitly in class, because misunderstanding this causes real confusion later (e.g., "why can't I just double-click this file in Windows Explorer" — they usually can, via the `\\wsl.localhost\` path, but it's not the same filesystem).

### Why `[boot] systemd=true` is needed at all

Here's the part trainees (and honestly most working developers) get surprised by: **WSL2 did not support systemd for years.** When Microsoft first shipped WSL2, the "init" process — the thing that becomes PID 1 and supervises everything else — was a minimal custom process, not systemd. This was a deliberate simplification: WSL2 was originally designed to run development tools, not full Linux services, so a heavyweight service manager like systemd seemed unnecessary.

The problem: **a huge amount of real-world Linux software assumes systemd exists.** Package post-install scripts (like the one Grafana's `.deb` runs) call `systemctl` directly. Vertica's tooling expects proper service supervision. Without systemd, `sudo systemctl status grafana-server` would just fail outright — there'd be no `systemctl` command working meaningfully at all.

Microsoft added **official, built-in systemd support** to WSL2 later via exactly this mechanism: a `/etc/wsl.conf` file, read once at instance boot, with a `[boot]` section:

```ini
[boot]
systemd=true
```

**Mechanically, what happens:** every time a WSL2 Linux instance starts (which happens whenever you run `wsl` after it wasn't already running — not "every time Windows boots," a subtlety worth clarifying), the WSL2 launcher reads `/etc/wsl.conf`. If it sees `systemd=true` under `[boot]`, it launches `systemd` as PID 1 instead of its own minimal init. That's it — one flag, one behavioral switch, but it's the difference between "half a Linux system" and "the real thing."

**Why you can't just enable it and continue in the same terminal:** the setting only takes effect on the *next* instance boot, not live. That's why Step 4 requires `wsl --shutdown` (fully terminates every running WSL2 instance) followed by a fresh `wsl` — a mid-session `systemctl restart` or similar wouldn't do it, because you're not restarting a service, you're restarting the entire Linux instance's init process.

**Anticipate this confusion:** trainees often try to run `wsl --shutdown` *inside* the Ubuntu terminal itself. It has to run from PowerShell — you're telling *Windows* to tear down the WSL2 VM, which isn't something the Linux side can request of itself.

### Why `wsl --unregister` is destructive (and why we still recommend it)

"Unregistering" a WSL distro doesn't just stop it — it deletes the entire virtual disk backing it, i.e., every file inside that Ubuntu instance, gone, no recycle bin. We still recommend it for pre-existing installs in Step 0 because **consistency across a 5-person batch matters more than preserving an unknown prior state.** A laptop that was pre-imaged with dev tools might be on an older Ubuntu release, have systemd already half-configured differently, or have leftover packages that behave unexpectedly during a live Vertica/Grafana install later in the week. A clean, identical starting point for everyone means you're debugging *their* mistakes during labs, not chasing environment drift you can't see.

---

## 2. The Linux filesystem model & FHS

*→ Referenced in: `day01.md`, Concepts*

### Why "one tree," not drive letters

This traces back to Unix's original design philosophy in the 1970s: **everything is a file, and there's exactly one namespace.** Windows evolved from a world where each physical/logical disk got its own letter because DOS needed a simple way to address separate storage devices. Unix instead treats storage devices as things you **mount** *into* the existing tree, at some directory. Your Ubuntu root filesystem happens to be mounted at `/`; if you plugged in a USB drive, it'd show up as a new directory somewhere (often under `/mnt` or `/media`), not as a new drive letter.

This is why WSL2 itself is a good live example: your Windows `D:\Projects` folder is accessible in Ubuntu at `/mnt/d/Projects` — Windows drives get mounted *into* the Linux tree, not the other way around. If a trainee asks "so is `C:\` a thing in Linux," this is the moment to show `ls /mnt/c`.

### Why FHS exists — and why it's worth memorizing landmarks, not everything

The Filesystem Hierarchy Standard isn't a technical requirement enforced by the kernel — it's a **convention**, agreed upon across distros, so that software (and humans) can predict where things live without guessing. `/etc` for config, `/var` for changing data, `/usr` for installed software — none of this is magic, it's just decades of accumulated agreement. That's *why* Vertica installs into `/opt` (the FHS-designated spot for third-party, self-contained software packages) rather than scattering itself across `/usr`.

**The distinction worth drilling into trainees:** `/etc` = static configuration (rarely changes on its own), `/var` = dynamic/runtime data (logs, caches — changes constantly). This distinction becomes concretely useful on Day 4 when they start reading logs via `journalctl`, and again whenever they need to find Vertica's or Grafana's config files later.

### Absolute vs relative paths — the actual mental model

The trick that helps this click for beginners: an absolute path is a *complete address from the top of the world* (`/home/vaman/notes.txt` means the same thing no matter where you're standing). A relative path is *directions from where you're currently standing* — meaningless without knowing your current location (`pwd`) first. The single most common beginner bug is running a relative-path command from the wrong directory and being confused why "the file isn't there" — it's usually there, just not *relative to here*. Drill `pwd` as a reflex before any relative-path operation, especially once they start writing scripts on Day 3 where a script might execute from an unexpected working directory.

---

## 3. Permissions, ownership & `umask`

*→ Referenced in: `day01.md`, Concepts + Lab*

### Why the rwx/owner-group-other model exists

This model dates to early multi-user Unix systems where many people shared one physical machine (a mainframe, a university server) and needed a lightweight way to control who could see/change what — without the complexity of modern access-control lists (which Linux *does* also support via `setfacl`, but that's beyond this course's scope, and worth knowing exists if a curious trainee asks "is that really *all* the control we have?"). Three permission bits, three audience tiers — deliberately simple, deliberately fast for the kernel to check on every single file operation.

### The octal math, explained properly (not just memorized)

`chmod 755` isn't an arbitrary number — it's binary in disguise. Each permission tier gets 3 bits: read=4, write=2, execute=1. You're literally summing which bits are "on":

- `7` = 4+2+1 = read+write+execute (full access)
- `5` = 4+0+1 = read+execute, no write
- `4` = 4+0+0 = read only

Once a trainee sees it as bit-summing rather than a lookup table to memorize, they can derive *any* permission number on the fly instead of guessing. Worth actually writing `111 = 7`, `101 = 5` in binary on the whiteboard the first time — it sticks far better than "755 means this."

### Why `umask` defaults to `022` and what it protects against

A fresh file, if nothing intervened, would default to `666` (rw for everyone) and a fresh directory to `777`. That's a security problem on a shared/multi-user system — anyone could edit anyone else's brand-new files by default. `umask 022` *subtracts* write permission from group and other on every newly created file/directory, automatically, without you thinking about it. This is why new files show up as `644` (666 − 022) and new directories as `755` (777 − 022) without you ever running `chmod`. It's a sensible, sane default — not a magic number.

**Real trainee question to expect:** "Why don't `mkdir` and `touch` just default to something more locked-down like `600`?" Because directories generally *need* to be traversable (`x` bit) by others in a shared system for things to work at all — `umask` strikes a middle ground, not maximum security. If real lockdown is needed, that's what explicit `chmod` (as in the Day 1 lab's `finance` folder) is for.

---

## 4. Users, groups & `sudo`

*→ Referenced in: `day02.md`, Concepts*

### Why UID 0 (root) is special, not just "an admin account"

Unlike Windows, where "Administrator" is a role assigned to an account, Linux's root privilege is tied to a *specific number*: UID 0. The kernel itself checks "is this process's UID exactly 0" for many privileged operations — it's not a permissions flag that could theoretically be granted to multiple different accounts the same way; it's baked into the numbering. Any account with UID 0 *is* root, regardless of what it's named. This is why deleting or breaking `/etc/passwd` carelessly is so dangerous — you could accidentally strip root access from the system entirely, or worse, accidentally grant it.

### `sudo` vs `su` — a distinction worth being crisp about

`su` (switch user) fully swaps your session to another user — you're now *logged in as* them until you `exit`. `sudo` runs a **single command** with elevated privileges, then immediately drops back to your normal user. `sudo` is generally the safer, more auditable pattern (every use gets logged, tied to a specific command, not an open-ended session) — which is why modern practice favors `sudo` over habitually `su`-ing into root.

### Why `visudo` instead of editing `/etc/sudoers` directly

`visudo` isn't a different editor with special features — it's a *wrapper* that opens your normal editor, but **validates the syntax before saving**. If `/etc/sudoers` gets saved with a syntax error via a plain `nano /etc/sudoers`, `sudo` itself can break — and now you can't `sudo nano /etc/sudoers` to fix it, because `sudo` is broken. `visudo` prevents exactly this self-inflicted lockout by refusing to save a broken file.

### `/etc/passwd` and `/etc/shadow` — why passwords aren't actually in `/etc/passwd`

Historically they were — that's why the field is still there, just replaced with a literal `x` today. `/etc/passwd` needs to be world-readable (lots of software needs to look up usernames/UIDs), which made storing real password hashes there a security hole once offline password-cracking got fast. The hashes moved to `/etc/shadow`, which is root-only readable. Worth a one-line mention if a curious trainee asks "wait, where's the actual password then."

---

## 5. Process management & systemd

*→ Referenced in: `day02.md`, Concepts*

### What a process actually is

A process is a running instance of a program, with a unique PID, a parent (PPID — nearly everything traces back to PID 1), and its own memory space. `ps aux` is a snapshot; `top` is the same information, live and auto-refreshing. Trainees sometimes expect `top` to show *only* their own programs — worth clarifying it shows the whole machine, all users, because on WSL2 that's usually just them anyway, but the mental model matters for later (e.g., a real multi-user production server).

### Signals — why `kill` isn't as blunt as it sounds

`kill <PID>` doesn't forcibly terminate anything by default — it sends **SIGTERM**, a polite request: "please shut yourself down." Well-behaved programs catch this signal and clean up (close files, flush buffers) before exiting. `kill -9` sends **SIGKILL**, which the OS enforces immediately, no chance for the process to clean up anything. This distinction becomes very real later: **abruptly force-killing Vertica or Grafana mid-write is a genuinely bad idea** — always prefer `systemctl stop`, which sends the graceful signal and waits, over reaching straight for `kill -9`.

### `systemctl start` vs `enable` — the distinction that confuses everyone at first

- **`start`** — launch it *right now*, this session.
- **`enable`** — create a symlink so it launches automatically on every future systemd boot.

They're independent. You can `start` something without `enable`-ing it (runs now, won't survive a restart) or `enable` without `start` (will launch next boot, isn't running yet). This is exactly why we discussed *not* enabling Grafana/Vertica earlier — the trainees run `start` manually each morning as a deliberate choice to keep reinforcing the mechanic, rather than making it invisible.

Mechanically, `enable` works by creating a symlink inside `/etc/systemd/system/<target>.wants/` pointing back at the actual unit file (usually in `/usr/lib/systemd/system/` or `/etc/systemd/system/`). `systemctl disable` just removes that symlink — nothing about the service itself changes, only whether it auto-starts.

---

## 6. Shell scripting mechanics

*→ Referenced in: `day03.md`, Concepts*

### Why the shebang line actually works

`#!/bin/bash` looks like a comment (starts with `#`), but the kernel treats the very first line specially if it starts with `#!`. It tells the kernel exactly which interpreter to hand the rest of the file to. Without it, running `./script.sh` would try to execute the file as a raw binary and fail — the shebang is what makes a text file "runnable" as a script at all, not just chmod'd executable permission alone (permission makes it *allowed* to run; the shebang makes the kernel know *how*).

### `./script.sh` vs `bash script.sh` vs `source script.sh` — three genuinely different things

- **`./script.sh`** — runs in a brand-new subshell. Any variables it sets, or `cd` commands it runs, vanish once it finishes; your current terminal session is unaffected.
- **`bash script.sh`** — functionally similar, explicitly invoking bash instead of relying on the shebang + execute bit.
- **`source script.sh`** (or `. script.sh`) — runs *in your current shell*, no subshell. Variables and `cd`s it does **persist** after it finishes. This is exactly why `source ~/.bashrc` is used to reload environment changes — running it as `./` or `bash` wouldn't affect your actual current session.

This trips people up constantly once they start wondering "why didn't my exported variable stick around after the script ran" — the answer is almost always "you ran it in a subshell, not sourced it."

### Why quoting variables matters (`"$var"` vs `$var`)

Unquoted variables undergo **word splitting** — bash splits on whitespace and expands wildcards before passing the result along. A variable holding a path with a space in it (`My Documents`) will silently break into two separate arguments if left unquoted. The safe default habit: always quote variable expansions unless you specifically need word-splitting behavior (rare). Worth flagging explicitly in Day 3, since the backup script lab involves paths that could realistically contain spaces in a real environment.

---

## 7. Package management internals

*→ Referenced in: `day03.md`, Concepts*

### `dpkg` vs `apt` — the actual relationship

`dpkg` is the low-level package *installer* — it knows how to unpack a `.deb` file and place its contents on disk, run pre/post-install scripts, and track what's installed. It has **no concept of the internet, repositories, or dependencies** — if a package needs something else installed first, `dpkg -i` will just fail and tell you what's missing, leaving you to hunt it down manually. `apt` sits on top of `dpkg`: it knows about repositories, downloads what's needed, and — critically — resolves the entire dependency chain automatically. This is *why* `sudo dpkg -i grafana.deb` (had we gone that route) would need every dependency pre-installed, while `sudo apt-get install grafana` just handles it.

### What a repository actually *is*

Demystify this — it's not magic, it's just a web server hosting two things: the actual `.deb` package files, and an **index** (a `Packages` file, often compressed) listing every package available, its version, and a cryptographic checksum. When you added the Grafana repo (`echo "deb [...] https://apt.grafana.com stable main" | sudo tee ...`), you were literally telling `apt` "here's another URL with a Packages index — go check it too." `sudo apt update` is the moment `apt` re-downloads every configured repo's index; `sudo apt install` is the moment it actually pulls the real package.

### Why we imported a GPG key before adding the repo

Anyone could stand up a fake "Grafana" repository and serve malicious packages. The GPG key we imported (`grafana.asc`) is Grafana's cryptographic signature — `apt` uses it to verify that whatever the repo serves was actually signed by Grafana, not tampered with in transit or spoofed. `signed-by=/etc/apt/keyrings/grafana.asc` in the repo line is what ties the two together — without a matching signature, `apt update` refuses the repo entirely. This is the exact mechanism worth explaining if a trainee asks "why do we have to download a random key file before we can install anything."

### `PATH`, demystified

When you type a bare command name (`ls`, `cowsay`), bash doesn't search the entire filesystem — it checks each directory listed in `$PATH`, **in order**, and runs the first match it finds. This is exactly why a locally-written script needs `./` — your current directory (`.`) deliberately isn't in `PATH` by default (a long-standing security convention — otherwise a malicious file named `ls` sitting in some folder you `cd` into could silently hijack a common command). Editing `~/.bashrc` to add a directory to `PATH` is *why* some installers ask you to "restart your terminal" afterward — the running shell already has last session's `PATH` cached in memory; a new shell (or a `source ~/.bashrc`) is what picks up the change.

---

## 8. Networking fundamentals (Day 4 preview)

*→ Referenced in: `day04.md` (Linux Networking & Environment Deep-Dive)*

A few concepts worth having ready before Day 4, since this is where "how does `localhost:3000` from Windows even reach something running inside WSL2 Ubuntu" finally gets a real answer:

- **Ports** are how one machine juggles multiple simultaneous network services — Grafana claims port `3000`, Vertica claims `5433`. Two processes can't bind the same port at once, which is a genuinely useful debugging fact ("port already in use" errors trace directly back to this).
- **WSL2's networking is unusually convenient** compared to a traditional VM: Microsoft specifically built automatic `localhost` forwarding, so a service running inside Ubuntu on port `3000` is transparently reachable from Windows at `localhost:3000` — no port-forwarding configuration needed, unlike a "real" VM where you'd have to explicitly set up NAT/bridged networking rules. Worth naming this explicitly as a WSL2-specific convenience, not a universal Linux/VM behavior.
- **`ufw`** (Uncomplicated Firewall) isn't its own firewall engine — it's a friendlier command-line frontend over the kernel's real firewall (`iptables`/`nftables`). Worth knowing so trainees don't think `ufw` and `iptables` are unrelated competing tools.
- **`journalctl`** replaces the older pattern of scattered plain-text log files under `/var/log`. systemd centralizes logs from every service it manages into a single structured, queryable journal — `journalctl -u grafana-server`, for instance, will become genuinely useful once Grafana or Vertica misbehaves later in the course.

---

## 📌 Quick-reference: "why" answers you'll get asked most

A condensed cheat-sheet for the handful of questions that come up in nearly every cohort:

| Trainee asks | Short answer |
|---|---|
| Why do I need `[boot] systemd=true`? | WSL2 didn't ship with systemd historically; this flag turns it on. Vertica/Grafana both need it. |
| Why does `wsl --shutdown` need PowerShell, not Ubuntu? | You're tearing down the whole Linux instance from the Windows side — Linux can't do that to itself mid-session. |
| Why `chmod 755` and not just "give it permission"? | 7/5/5 is bit-math (4+2+1), not a magic number — owner/group/other, each summed independently. |
| Why can't I just run `myscript.sh`? | Your current directory isn't in `PATH` on purpose (security convention) — use `./myscript.sh`. |
| Why did my exported variable disappear after the script ran? | You ran it in a subshell (`./` or `bash`). Use `source` if you need it to persist. |
| Why do we `sudo apt update` before `install`? | `update` refreshes the local index of what's available; `install` acts on that cached index — skip it and you might install a stale/missing version. |
| Why `kill` before `kill -9`? | `kill` asks nicely (SIGTERM, allows cleanup); `-9` is a hard force-stop with no cleanup. Never reach for `-9` first, especially with Vertica/Grafana. |
