# Day 3 — Linux Fundamentals III

*Tue, 1 Sep 2026*

---

## 🔁 Recap: Day 2

You created users and groups, learned `sudo`/`visudo`, managed processes (`ps`, `top`, `kill`), and ran your first `systemctl start`/`stop`/`enable` cycle on `cron`. Today you stop typing commands one at a time and start **automating** them — plus you finally get the full story on how `apt install` actually works under the hood.

---

## 📚 Concepts

### Your first shell script

Every script starts with a **shebang** — tells the OS which interpreter to use:

```bash
#!/bin/bash
```

Save that plus some commands into a `.sh` file, make it executable, run it:

```bash
nano hello.sh
```
```bash
#!/bin/bash
echo "Hello, $(whoami)! Today is $(date)."
```
```bash
chmod +x hello.sh
./hello.sh
```

`./` matters — it tells bash "run the script sitting right here," since your current directory usually isn't in `PATH` (more on `PATH` below).

### Variables

```bash
name="Vaman"          # NO spaces around =
echo "Hello, $name"
echo "Hello, ${name}"  # braces avoid ambiguity when concatenating text
```

**Command substitution** — capture a command's output into a variable:

```bash
today=$(date +%F)
echo "Today is $today"
```

### Reading user input

```bash
read -p "Enter your name: " username
echo "Welcome, $username"
```

### Conditionals

```bash
if [ -d "/home/vaman" ]; then
    echo "Directory exists"
elif [ -f "/home/vaman/notes.txt" ]; then
    echo "It's a file, not a directory"
else
    echo "Neither exists"
fi
```

**Common test operators:**

| Test | Meaning |
|---|---|
| `-f file` | file exists |
| `-d dir` | directory exists |
| `-z string` | string is empty |
| `-n string` | string is NOT empty |
| `-eq`, `-ne`, `-lt`, `-gt` | numeric equal/not-equal/less/greater |
| `==`, `!=` | string equal/not-equal (inside `[[ ]]`) |

> 💡 `[[ ]]` is a bash upgrade over `[ ]` — more forgiving with quoting, supports `&&`/`||` directly. Use `[[ ]]` unless you have a specific reason not to.

### Loops

```bash
for i in 1 2 3 4 5; do
    echo "Count: $i"
done

for file in ~/practice-lab/shared/*.txt; do
    echo "Found: $file"
done

count=0
while [ $count -lt 5 ]; do
    echo "While loop: $count"
    count=$((count + 1))
done
```

> ⚠️ **`*` doesn't search subdirectories.** It's tempting to write `~/practice-lab/*.txt` expecting it to find every `.txt` file anywhere under `practice-lab` — it won't. A glob only matches files **directly inside** the folder you point it at, not anything nested deeper. Every `.txt` file from Day 1 (`payroll.txt`, `README.txt`, etc.) sits inside subfolders like `hr/` and `shared/`, not loose in `practice-lab/` itself — which is exactly why the example above points at `practice-lab/shared/`, the one folder where `.txt` files actually live directly.

### Functions

```bash
greet() {
    local name=$1          # $1 = first argument passed in
    echo "Hey there, $name!"
}

greet "team"
```

`$1`, `$2`... are positional arguments. `$#` is the argument count, `$@` is all arguments. `local` keeps a variable scoped to the function — good habit, avoids polluting your whole script's namespace.

### Exit codes — did it actually work?

```bash
mkdir /tmp/testdir
echo $?          # 0 = success

mkdir /tmp/testdir
echo $?          # non-zero (usually 1) — it already exists this time, so it genuinely failed
```

Running the same `mkdir` twice isn't a mistake here — it's the easiest way to see both a real success and a real failure exit code back to back, without needing to invent a broken command on purpose.

Scripts can set their own: `exit 0` (success) or `exit 1` (failure) — useful for chaining scripts where one needs to know if the last one succeeded.

---

### Package management, properly explained

You've been running `apt install` all week. Here's what's actually happening.

**The layers:**
- **`dpkg`** — the low-level tool. Installs/removes individual `.deb` files. Doesn't know about the internet or dependencies.
- **`apt`** (and `apt-get`) — the high-level tool. Knows about repositories, resolves dependencies automatically, and is what you should use day-to-day.

```bash
apt search <keyword>              # find a package
apt show <package>                # details before installing
sudo apt install <package>        # install (+ dependencies)
sudo apt remove <package>         # remove, keep config files
sudo apt purge <package>          # remove + delete config files too
sudo apt autoremove                # clean up now-unneeded dependencies
apt list --installed | grep <name>  # is it installed?
```

**Direct `dpkg` usage** (you'll recognize this from Grafana's `.deb`, if you ever go that route):

```bash
sudo dpkg -i package.deb   # install a downloaded .deb directly
dpkg -l | grep <name>       # list installed packages, filter by name
sudo dpkg -r <name>          # remove
```

**Where packages actually come from — repositories:**

```bash
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/
```

Remember adding Grafana's repo earlier this week?

```bash
echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt-get update
```

That's exactly this mechanism — you were manually teaching `apt` about a new source. Every `sudo apt update` re-reads every file in `sources.list.d/` plus the main `sources.list`.

### Environment variables & `PATH`

```bash
printenv               # show all environment variables
echo $HOME
echo $PATH
```

`PATH` is a colon-separated list of directories bash searches, in order, when you type a command name. That's why `./hello.sh` needed the `./` — your home directory isn't in `PATH` by default.

**Setting a variable for this session only:**

```bash
export MY_VAR="hello"
echo $MY_VAR
```

**Making it permanent** — add it to your shell's startup file:

```bash
echo 'export MY_VAR="hello"' >> ~/.bashrc
source ~/.bashrc        # reload without closing the terminal
```

`~/.bashrc` runs every time you open a new terminal — it's *the* place for personal environment tweaks (and where installers sometimes add their own `PATH` entries automatically).

---

## 🧪 Guided hands-on (do this together)

**🐧 Everything below runs inside your Ubuntu terminal.**

**1. Build a backup script together:**

```bash
nano backup_demo.sh
```
```bash
#!/bin/bash

SOURCE_DIR=~/practice-lab
BACKUP_DIR=~/backups
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log_message() {
    echo "[$(date +%T)] $1"
}

if [ ! -d "$SOURCE_DIR" ]; then
    log_message "ERROR: $SOURCE_DIR does not exist. Aborting."
    exit 1
fi

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_DIR/practice-lab_$TIMESTAMP.tar.gz" -C ~ practice-lab

if [ $? -eq 0 ]; then
    log_message "Backup successful: practice-lab_$TIMESTAMP.tar.gz"
else
    log_message "ERROR: Backup failed."
    exit 1
fi
```
```bash
chmod +x backup_demo.sh
./backup_demo.sh
ls -lh ~/backups
```

**2. Package management, live:**

```bash
apt search cowsay
sudo apt install -y cowsay
cowsay "Day 3 done"
dpkg -l | grep cowsay
sudo apt remove -y cowsay
```

**3. PATH, made visible:**

```bash
echo $PATH
which cowsay      # after reinstalling it, if you want — shows exactly which PATH dir it lives in
```

---

## 🔬 Lab — on your own

**Scenario:** Your team needs a repeatable, logged backup process — not a one-off manual copy.

1. Write a script `my_backup.sh` that:
   - Backs up `~/practice-lab` into `~/backups`, named with a timestamp (reuse the pattern above, don't just copy-paste it verbatim — change the log message wording)
   - Checks the source directory exists *before* attempting the backup, exits with a clear error if not
   - Logs every run (success or failure) by **appending** (`>>`) to `~/backups/backup.log`, not just printing to screen
2. Add a **function** that counts how many files are inside `~/practice-lab` (hint: `find ~/practice-lab -type f | wc -l`) and logs that count alongside the backup confirmation.
3. Run your script twice. Check `~/backups/backup.log` — you should see two log entries, not one overwriting the other.
4. Install a package of your choice for fun (`figlet`, `sl`, `cowsay` — anything harmless), confirm it's installed with `dpkg -l`, then fully `purge` it and confirm it's gone.
5. **Bonus:** Add a permanent environment variable `BACKUP_HOME` pointing to `~/backups` in your `~/.bashrc`, `source` it, and reference `$BACKUP_HOME` inside your script instead of the hardcoded path.

---

## 📎 Copy-paste command reference — Day 3

```bash
# --- Script basics ---
#!/bin/bash                     # shebang, first line of every script
chmod +x script.sh
./script.sh

# --- Variables & substitution ---
name="value"
echo "$name"
today=$(date +%F)
read -p "Prompt: " variable

# --- Conditionals ---
if [ -d "path" ]; then ... elif [ -f "path" ]; then ... else ... fi
[[ "$a" == "$b" ]]

# --- Loops ---
for i in 1 2 3; do ... done
for file in *.txt; do ... done
while [ condition ]; do ... done

# --- Functions ---
my_func() {
    local var=$1
    ...
}
my_func "argument"

# --- Exit codes ---
echo $?
exit 0   # success
exit 1   # failure

# --- Package management ---
apt search <keyword>
apt show <package>
sudo apt install -y <package>
sudo apt remove <package>
sudo apt purge <package>
sudo apt autoremove
apt list --installed | grep <name>
sudo dpkg -i package.deb
dpkg -l | grep <name>

# --- Repositories ---
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/

# --- Environment variables & PATH ---
printenv
echo $PATH
export MY_VAR="value"
echo 'export MY_VAR="value"' >> ~/.bashrc
source ~/.bashrc
```

---

## 👀 Tomorrow: Day 4 — Linux Networking & Environment Deep-Dive

Networking basics (`ping`, `curl`, `ss`), a firewall intro with `ufw`, log inspection via `journalctl`, and a full verification pass on your WSL2 environment — including WSLg (GUI app support) — to make sure everything's rock-solid before Vertica shows up on Day 5.

--- 

## Training Notes - 

shell scripting 

script.sh 

ps 
ls -l 
pwd 

copy - 

bash```
cp /mnt/d/Projects/adaps/linux-vertica-graphana-manual/linux-stuff/acme_it_admin.sh .
```

bash```
cp /mnt/d/Projects/adaps/linux-vertica-graphana-manual/linux-stuff/acme_it_admin.sh /home/vaman/scripts/acme-lab/ 
```

--- 

CLA - script.py arg arg2 arg2 


var1="val1"

fun () {
    var2="val2"
    local var3="val3"
    echo "$var1"
    echo "$var2"
    echo "$var3"
}

fun()

echo "$var1" # yes 
echo "$var2" # yes 
echo "$var3" # not

VAR2="VAL"

cowsay "${VAR2}

parent.sh 

#!/bin/bash
PLAIN_VAR="I am NOT exported"
export EXPORTED_VAR="I AM exported"

echo "Inside parent.sh, before calling child:"
echo "  PLAIN_VAR = [$PLAIN_VAR]"
echo "  EXPORTED_VAR = [$EXPORTED_VAR]"
echo ""
echo "Now calling child.sh (a separate process)..."
echo ""
./child.sh

child.sh 

#!/bin/bash
# set -u 

echo "Inside child.sh:"
echo "  PLAIN_VAR = [$PLAIN_VAR]"
echo "  EXPORTED_VAR = [$EXPORTED_VAR]"



declare -A DEPT_MANAGER
DEPT_MANAGER[engineering]="Arjun Mehta"
DEPT_MANAGER[finance]="Farhan Khan"
DEPT_MANAGER[hr]="Priya Nair"

echo "${DEPT_MANAGER[engineering]}"     # Arjun Mehta

for dept in "${!DEPT_MANAGER[@]}"; do   # ! gives you the KEYS
    echo "$dept -> ${DEPT_MANAGER[$dept]}"
done


--- 

Core java - 
Adv java - 












GET 
curl "https://jsonplaceholder.typicode.com/users/2"

POST 

curl "https://jsonplaceholder.typicode.com/users/2" -d "{"name" : "Sonu"}" 

curl -X "https://jsonplaceholder.typicode.com/users/2" -d "{"name" : "Sonu"}" 




