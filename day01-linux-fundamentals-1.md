# Day 1 — Environment Setup + Linux Fundamentals I

*Fri, 28 Aug 2026*

---

## 🔁 Where we left off

`day00` gave you the big picture — 10 days, Linux → Vertica → Grafana → Capstone, all free/open-source. Today's the day that stops being theory. First we get you a working Linux box, then we start living in it.

---

## 🕘 Hour 0: Environment Setup (live, ~45–60 min)

You're walking in with a stock Windows 11 laptop. Let's fix that.

### Step 0 — Check if WSL/Ubuntu is already there

Some laptops come pre-imaged with dev tools. Check before you install anything.

**🪟 Run in PowerShell** (Start → search "PowerShell" → open it, admin not required just to check):

```powershell
wsl -l -v
```

**Read the output:**

| What you see | What it means | What to do |
|---|---|---|
| `wsl.exe : command not found` or similar error | WSL isn't installed at all | Skip to Step 1, install fresh |
| Empty list, no distros | WSL feature is on, but no Linux distro yet | Skip to Step 1, install fresh |
| `Ubuntu` listed, `VERSION 2` | Already installed and on the right version | See "reuse or reset?" below |
| `Ubuntu` listed, `VERSION 1` | Installed but on the older, slower WSL1 | Run `wsl --set-version Ubuntu 2`, then re-check with `wsl -l -v` |

**Reuse or reset?** If `Ubuntu` is already there, don't just assume it's fine to build on. A pre-existing instance might have leftover packages, a different Ubuntu version, or configs that don't match the rest of the batch — and for a 5-person class, everyone starting from the *same* known-good baseline matters more than saving 10 minutes. Recommended: wipe it and start clean.

**🪟 Run in PowerShell:**

```powershell
wsl --unregister Ubuntu
```

> ⚠️ This deletes that Ubuntu instance entirely — any files inside it are gone. Fine for a training laptop with nothing important in there yet; **not** fine if it's someone's personal machine with real work in that WSL instance. If in doubt, ask before running this.

Once unregistered (or if nothing existed to begin with), continue to Step 1 — it'll now be a clean install either way.

### Step 1 — Enable WSL2 + install Ubuntu

Open **PowerShell as Administrator** (Start → search "PowerShell" → Run as administrator).

**🪟 Run in PowerShell (as Administrator):**

```powershell
wsl --install -d Ubuntu
```

One command does three things: turns on the Windows features WSL2 needs, grabs the WSL2 kernel, and installs Ubuntu. **Restart when prompted — don't skip it.**

### Step 2 — First launch

After restart, open **Ubuntu** from the Start menu. First boot takes a minute, then asks for a **UNIX username and password**.

> 💡 This is separate from your Windows login. Pick something memorable — `sudo` will ask for it constantly.

### Step 3 — Update everything

**🐧 Run inside Ubuntu** (the terminal that opened after Step 2):

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 4 — Turn on systemd

Vertica (Day 5) and Grafana (Day 8) both run as systemd services. Switch it on.

**🐧 Run inside Ubuntu:**

```bash
sudo nano /etc/wsl.conf
```

Add (or append) this block:

```ini
[boot]
systemd=true
```

Save and exit: `Ctrl+O`, `Enter`, `Ctrl+X`, `Exit` and restart WSL2.

**🪟 Run in PowerShell**:

```powershell
wsl --shutdown
```

```powershell
wsl
```

That second `wsl` drops you right back into your Ubuntu terminal, now with systemd running.

### Step 5 — Verify systemd is alive

**🐧 Run inside Ubuntu:**

```bash
ps -p 1
```

Expected:
```
    PID TTY          TIME CMD
      1 ?        00:00:00 systemd
```

If it says `systemd`, move on. If it doesn't, re-check Step 4 and repeat.

### Step 6 — Install today's basics

**🐧 Run inside Ubuntu:**

```bash
sudo apt install -y curl wget gnupg2 ca-certificates tree
```

### ✅ Checklist — don't proceed until this passes

**🐧 Run inside Ubuntu:**

```bash
whoami          # your UNIX username
```

```bash
lsb_release -a  # confirms Ubuntu version
```

```bash
ps -p 1         # must show systemd
```

```bash
pwd             # should be /home/<your-username>
```

All four clean? You're in. Let's talk filesystem.

---

## 📚 Concepts

### What even is Linux?

Three layers, one mental model:
- **Kernel** — the core engine talking to hardware
- **Distro** (Ubuntu, in our case) — kernel + tools + package manager, packaged for humans
- **Shell** (`bash`) — the command interpreter you're about to live in

Linux runs most of the world's servers, cloud infra, and — relevantly — Vertica and Grafana both assume a Linux environment under the hood. This is why we start here.

### The Filesystem Hierarchy Standard (FHS)

Forget `C:\`, `D:\`, drive letters. Linux has **one tree**, rooted at `/`. Everything — disks, USB drives, network shares — gets *mounted* somewhere under that single tree.

| Path | What lives there |
|---|---|
| `/` | The root. Everything hangs off this. |
| `/home` | Your personal space — `/home/<you>` is your "My Documents" |
| `/etc` | System-wide config files (think: every app's settings.ini, in one place) |
| `/var` | Variable data — logs, caches, stuff that changes constantly |
| `/usr` | Installed programs and their supporting files |
| `/bin`, `/usr/bin` | Executable commands (`ls`, `cp`, etc. literally live here) |
| `/tmp` | Scratch space — wiped on reboot |
| `/opt` | Optional/third-party software (Vertica installs here on Day 5) |
| `/root` | The `root` (superuser)'s home — not yours, don't touch |

You'll type `/etc` and `/var` so often this week they'll stop feeling like paths and start feeling like landmarks.

### Navigating the filesystem

```bash
pwd              # "print working directory" — where am I?
ls                # list what's here
ls -l             # long format — permissions, owner, size, date
ls -la            # long format + hidden files (dotfiles)
cd /etc           # jump to an absolute path
cd ..             # up one level
cd ~              # home, always
tree              # visual folder tree (we just installed this)
tree -L 2         # only 2 levels deep — keeps big trees readable
```

**Absolute vs relative paths — the one thing that trips everyone up:**

- **Absolute**: starts with `/`, always means the same thing no matter where you are. `/home/vaman/notes.txt`
- **Relative**: starts from wherever you *currently* are. `notes.txt` or `../notes.txt`

Rule of thumb: if you're not 100% sure where you are, `pwd` first, then decide.

### Basic file & directory operations

```bash
mkdir project           # make a directory
mkdir -p a/b/c           # make nested dirs in one shot, no complaints if they exist
touch notes.txt          # create an empty file (or update its timestamp)
cp source.txt dest.txt   # copy
cp -r folder1 folder2    # copy recursively (needed for directories)
mv old.txt new.txt              # rename — same location, new name
mv notes.txt ~/practice-lab/     # move — same name, new location (target ending in / is a directory)
mv draft.txt ~/practice-lab/final.txt   # move AND rename in one shot — new location, new name
rm file.txt              # delete a file — no recycle bin, no undo
rm -r folder             # delete a directory and everything in it
rm -i file.txt           # ask before deleting — good habit early on
rmdir empty_folder        # delete an EMPTY directory only
```

> ⚠️ **`rm` is forever.** There's no Recycle Bin in a terminal. When in doubt, use `-i`.

### Wildcards — pattern-matching shortcuts

```bash
ls *.txt          # every file ending in .txt
ls report?.csv    # report1.csv, reportA.csv — exactly one character in place of ?
rm draft_*        # delete everything starting with "draft_"
```

> ⚠️ **Wildcards + `rm` only delete files, not directories — even if the pattern matches a directory name.** If `draft_*` happens to match both files and a directory (say, a folder called `draft_backup`), plain `rm` deletes the files fine but errors on the directory with `cannot remove 'draft_backup': Is a directory` — it won't silently skip it, and it won't delete it either. You'd need `rm -r draft_*` to sweep up both files and directories matching the pattern. Worth checking what a wildcard actually matches before running `rm` on it, especially with `-r` in the mix.

### Basic redirection — your first taste of piping

```bash
echo "hello" > file.txt     # write (overwrite) into a file
echo "again" >> file.txt    # append to a file
ls -l | grep ".txt"          # pipe: send ls's output INTO grep as input
```

`grep` searches its input for lines matching a pattern and prints only those — so `ls -l | grep ".txt"` lists everything in the current directory, then keeps only the lines containing ".txt". You'll use `grep` constantly from here on; this is its simplest possible form.

`>` overwrites. `>>` adds on. `|` chains commands together — the output of the left becomes the input of the right. You'll use `|` constantly from here on.

### Permissions, ownership & the rwx model

Run `ls -l` on anything and you'll see something like:

```
-rwxr-xr-- 1 vaman vaman  220 Aug 28 09:00 deploy.sh
```

Break it down:

| Segment | Meaning |
|---|---|
| `-` | File type (`-` = file, `d` = directory) |
| `rwx` | **Owner's** permissions: read, write, execute |
| `r-x` | **Group's** permissions |
| `r--` | **Everyone else's** permissions |
| `vaman vaman` | Owner, then group |

**Changing permissions — symbolic mode:**

```bash
chmod u+x script.sh     # add execute for the owner (user)
chmod g-w file.txt       # remove write for the group
chmod o-r secret.txt     # remove read for everyone else
```

**Changing permissions — numeric mode (the one you'll actually use most):**

Each permission is a bit: `r=4, w=2, x=1`. Add them up per group.

```bash
chmod 755 script.sh   # owner: rwx(7)  group: r-x(5)  other: r-x(5)
chmod 644 notes.txt    # owner: rw-(6)  group: r--(4)  other: r--(4)
chmod 600 secret.txt   # owner: rw-(6)  group: ---(0)  other: ---(0)
```

**Changing ownership:**

```bash
sudo chown vaman file.txt         # change owner
sudo chown vaman:vaman file.txt   # change owner AND group
```

**`umask` — the default permissions new files get:**

```bash
umask        # shows current mask, e.g. 0022
```

A mask of `022` means new files get `644` and new directories get `755` by default (full permissions minus the mask). You won't change this often, but knowing it exists explains *why* every new file you create shows up with the same starting permissions.

---

## 🧪 Guided hands-on (do this together)

We'll build a small "company file server" and mess with it together before you're on your own.

```bash
mkdir -p ~/practice-lab/hr/policies
mkdir -p ~/practice-lab/engineering/project-phoenix/src
mkdir -p ~/practice-lab/engineering/project-phoenix/docs
mkdir -p ~/practice-lab/engineering/project-atlas
mkdir -p ~/practice-lab/finance
mkdir -p ~/practice-lab/shared

touch ~/practice-lab/hr/payroll.txt
touch ~/practice-lab/hr/policies/leave-policy.md
touch ~/practice-lab/engineering/project-phoenix/src/main.py
touch ~/practice-lab/engineering/project-phoenix/docs/readme.md
touch ~/practice-lab/finance/budget-2026.csv
touch ~/practice-lab/shared/README.txt

cd ~/practice-lab
tree
```

Now navigate it and get comfortable:

```bash
cd engineering/project-phoenix/src
pwd
cd ../../../finance
ls -l
cd ~/practice-lab
```

---

## 🔬 Lab — on your own

**Scenario:** `practice-lab` is your company's shared drive. Different departments need different access levels. Set it up.

1. **HR data is sensitive.** Payroll should only be readable/writable by the owner — nobody else, not even group members.
   ```bash
   chmod 600 ~/practice-lab/hr/payroll.txt
   ```

2. **Engineering source code** should be fully open to the owner, but read+execute only for everyone else (so it can be run, not edited).
   ```bash
   chmod 755 ~/practice-lab/engineering/project-phoenix/src/main.py
   ```

3. **Finance folder** should be locked down entirely — owner only, nobody else gets in.
   ```bash
   chmod 700 ~/practice-lab/finance
   ```

4. **Shared folder** should be fully open — read/write for everyone (a real free-for-all, on purpose).
   ```bash
   chmod 777 ~/practice-lab/shared
   ```

5. Verify all four with `ls -l` at each level, and confirm you can explain **out loud** what each permission number means before moving on. If you can't explain it, you don't own it yet — ask.

6. **Bonus round:** create `draft_v1.txt`, `draft_v2.txt`, and `draft_final.txt` in `shared/`, then delete **only** `draft_v1.txt` and `draft_v2.txt` — keep `draft_final.txt` — using a single wildcard command (not separate `rm` commands for each).
   - Careful: `draft_*` matches all three (they all start with `draft_`) — that would wipe out `draft_final.txt` too. You need a pattern specific enough to catch only the two you want, and this is exactly the kind of mistake worth making once in a sandbox rather than on something real.

---

## 📎 Copy-paste command reference — Day 1

```bash
# --- Environment setup ---
sudo apt update && sudo apt upgrade -y
sudo nano /etc/wsl.conf              # add [boot] \n systemd=true
# from PowerShell: wsl --shutdown && wsl
ps -p 1                               # verify systemd
sudo apt install -y curl wget gnupg2 ca-certificates tree

# --- Navigation ---
pwd
ls / ls -l / ls -la
cd <path> / cd .. / cd ~
tree / tree -L 2

# --- File & directory ops ---
mkdir <name> / mkdir -p a/b/c
touch <file>
cp <src> <dest> / cp -r <src> <dest>
mv <old> <new>              # rename or move (or both at once)
rm <file> / rm -r <dir> / rm -i <file>   # rm alone = files only; -r needed for directories
rmdir <empty-dir>

# --- Wildcards ---
ls *.txt
rm draft_v*        # only files matching draft_v* — rm alone skips directories, errors if one matches

# --- Redirection ---
echo "text" > file.txt     # overwrite
echo "text" >> file.txt    # append
cmd1 | cmd2                 # pipe

# --- Permissions & ownership ---
chmod 755|644|600|700|777 <path>
chmod u+x / g-w / o-r <path>
sudo chown <user>:<group> <path>
umask
```

---

## 👀 Tomorrow: Day 2 — Linux Fundamentals II

You'll create actual users and groups, get comfortable with `sudo` and the sudoers concept, then move into process management (`ps`, `top`, `kill`) and your first real look at `systemd` — the exact service-management skill you'll lean on for both Vertica and Grafana later this week.

---

Additional Commands - 

```bash 
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -Command "Set-Location 'D:\linux'" 
```

```bash 
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -Command "Set-Location 'C:\lalit'" 
```

---

## Additional Commands - 

```bash 
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -Command "Set-Location 'D:\linux'" 
```

```bash 
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -Command "Set-Location 'C:\lalit'" 
```

--- 

| Command | Short definition                |
| ------- | ------------------------------- |
| `nano`  | open to edit                    |
| `echo`  | create/write `>` or append `>>` |
| `touch` | create if not existing          |
| `cat`   | display file contents           |
| `head`  | display first N lines           |
| `tail`  | display last N lines            |
| `more`  | view page by page               |
| `less`  | view, scroll & search           |
| `grep`  | search for matching text        |

--- 