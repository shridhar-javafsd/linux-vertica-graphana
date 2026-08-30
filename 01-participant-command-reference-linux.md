# Linux Command Reference — The Commonest Commands, Explained

*A broader reference beyond just this course — every command here is genuinely high-frequency in real day-to-day Linux use, not just what we've covered in class.*

---

## 📑 Quick navigation

- [Navigation & Filesystem Info](#navigation--filesystem-info)
- [File & Directory Operations](#file--directory-operations)
- [Viewing & Editing File Content](#viewing--editing-file-content)
- [Searching & Text Processing](#searching--text-processing)
- [Permissions & Ownership](#permissions--ownership)
- [Users & Groups](#users--groups)
- [Process Management](#process-management)
- [System Info & Monitoring](#system-info--monitoring)
- [Package Management](#package-management)
- [Networking](#networking)
- [Archives & Compression](#archives--compression)
- [Services (systemd)](#services-systemd)
- [Redirection & Piping](#redirection--piping)
- [Environment & Shell](#environment--shell)

---

## Navigation & Filesystem Info

### `pwd`
Prints your current directory — "where am I?"
```bash
pwd
# /home/vaman/practice-lab
```

### `ls`
Lists what's in a directory.
```bash
ls              # just names
ls -l           # long format: permissions, owner, size, date
ls -la          # long format + hidden (dotfiles)
ls -lh          # long format, human-readable sizes (K/M/G instead of bytes)
```

### `cd`
Change directory.
```bash
cd /etc          # absolute path
cd project        # relative path
cd ..              # up one level
cd ~                # home, always
cd -                 # jump back to your PREVIOUS directory — genuinely useful
```

### `tree`
Visual directory tree (needs `sudo apt install tree` first — not built in by default).
```bash
tree
tree -L 2         # only 2 levels deep
```

### `find`
Searches for files/directories matching criteria — much more powerful than `ls`.
```bash
find ~/practice-lab -name "*.txt"          # by name pattern
find ~/practice-lab -type f                 # files only
find ~/practice-lab -type d                 # directories only
find . -mtime -1                             # modified in the last 1 day
```

### `locate`
Fast filename search using a pre-built index (needs `sudo apt install mlocate`, then `sudo updatedb` once).
```bash
locate nginx.conf
```
Faster than `find` for "does this file exist anywhere," but the index can be stale if the file was just created — `find` is always accurate, `locate` is always faster.

---

## File & Directory Operations

### `mkdir`
Make a directory.
```bash
mkdir project
mkdir -p a/b/c      # create nested dirs in one shot, no error if they already exist
```

### `touch`
Create an empty file, or update an existing file's timestamp.
```bash
touch notes.txt
```

### `cp`
Copy files/directories.
```bash
cp source.txt dest.txt
cp -r folder1 folder2       # -r required for directories
cp -v file1.txt file2.txt    # -v = verbose, shows what's happening
```

### `mv`
Move and/or rename — same command does both.
```bash
mv old.txt new.txt                    # rename in place
mv notes.txt ~/documents/              # move to a new location
mv draft.txt ~/documents/final.txt     # move AND rename together
```

### `rm`
Delete. **No recycle bin — this is permanent.**
```bash
rm file.txt
rm -r folder         # -r required for directories
rm -i file.txt        # ask before deleting — good habit
rm -f file.txt         # force, no confirmation even if normally prompted — use carefully
```

### `rmdir`
Delete an **empty** directory only (use `rm -r` for non-empty ones).
```bash
rmdir empty_folder
```

### `ln`
Create links between files.
```bash
ln -s /path/to/original /path/to/symlink   # symbolic link — a "shortcut" pointing elsewhere
```

---

## Viewing & Editing File Content

### `cat`
Print a file's entire contents to the screen. Also useful for quickly combining files.
```bash
cat file.txt
cat file1.txt file2.txt > combined.txt
```

### `less`
View a file page by page — much better than `cat` for anything long. `q` to quit, `/word` to search.
```bash
less /var/log/syslog
```

### `head` / `tail`
First or last N lines of a file.
```bash
head -20 file.txt
tail -20 file.txt
tail -f /var/log/app.log      # -f = follow, watch new lines appear live (Ctrl+C to stop)
```

### `nano`
Simple beginner-friendly terminal text editor.
```bash
nano file.txt
# Ctrl+O to save, Enter to confirm, Ctrl+X to exit
```

### `echo`
Print text — used constantly for quick output and building files via redirection.
```bash
echo "Hello, world"
echo "config line" >> settings.conf
```

---

## Searching & Text Processing

### `grep`
Search for lines matching a pattern. One of the most-used commands, period.
```bash
grep "error" logfile.txt
grep -i "error" logfile.txt        # -i = case-insensitive
grep -r "TODO" ~/project             # -r = recursive, search every file in a directory tree
grep -v "debug" logfile.txt           # -v = INVERT — show lines that DON'T match
ls -l | grep ".txt"                    # classic use in a pipe
```

### `sed`
Stream editor — most commonly used for find-and-replace.
```bash
sed 's/old/new/' file.txt              # replace first match per line, print result
sed -i 's/old/new/g' file.txt           # -i = edit the file in place, g = every match per line
```

### `awk`
Pattern-scanning and text-processing language — most commonly used for picking out columns.
```bash
awk '{print $1}' file.txt         # print the first whitespace-separated column
ps aux | awk '{print $2, $11}'     # PID and command name from ps output
```

### `sort`
Sort lines of text.
```bash
sort names.txt
sort -r names.txt        # reverse
sort -n numbers.txt        # numeric sort, not alphabetical (matters: "10" < "9" alphabetically!)
```

### `uniq`
Remove adjacent duplicate lines — almost always used right after `sort`.
```bash
sort file.txt | uniq
sort file.txt | uniq -c        # -c = count how many times each line appeared
```

### `wc`
Word/line/character count.
```bash
wc -l file.txt          # line count — extremely common
wc -w file.txt          # word count
find . -type f | wc -l    # "how many files are there" — classic combo
```

### `cut`
Extract specific columns/fields from text.
```bash
cut -d',' -f1 data.csv        # -d = delimiter, -f = field number
```

---

## Permissions & Ownership

### `chmod`
Change file/directory permissions.
```bash
chmod 755 script.sh        # numeric mode
chmod u+x script.sh          # symbolic mode: add execute for owner
chmod -R 755 folder/          # -R = recursive, apply to everything inside
```

### `chown`
Change owner (and optionally group).
```bash
sudo chown vaman file.txt
sudo chown vaman:vaman file.txt
sudo chown -R vaman:vaman folder/
```

### `umask`
Shows/sets the default permission mask applied to newly created files.
```bash
umask
```

---

## Users & Groups

### `whoami`
Prints your current username.
```bash
whoami
```

### `id`
Shows UID, GID, and all group memberships for a user.
```bash
id
id someuser
```

### `useradd` / `usermod` / `passwd`
Create and manage user accounts.
```bash
sudo useradd -m -s /bin/bash newuser
sudo passwd newuser
sudo usermod -aG groupname newuser      # -a is critical — see note below
```
> ⚠️ Never drop `-a` from `usermod -G` — without it, you *replace* every group the user is in, not add to them.

### `su`
Switch to another user's session.
```bash
su - username        # the - loads their full environment too, not just the shell
```

### `sudo`
Run a single command with elevated (root) privileges.
```bash
sudo apt update
sudo -i            # open a root shell — use sparingly, exit as soon as you're done
```

---

## Process Management

### `ps`
Snapshot of currently running processes.
```bash
ps                # just your current shell's processes
ps aux             # every process, every user, full detail
```

### `top` / `htop`
Live, auto-refreshing process viewer. `htop` (needs installing) is a friendlier, colorized version of `top`.
```bash
top          # q to quit
htop         # sudo apt install htop first
```

### `kill` / `pkill`
Stop a running process.
```bash
kill 1234          # polite request (SIGTERM) by PID
kill -9 1234        # force kill (SIGKILL), no cleanup — last resort
pkill firefox         # kill by process NAME instead of hunting for a PID
```

### `jobs` / `fg` / `bg`
Manage background/foreground jobs in your current shell session.
```bash
sleep 100 &        # & backgrounds it immediately
jobs                 # list background jobs
fg %1                  # bring job 1 to the foreground
```

### `nice`
Start a process with a lower/higher CPU priority (rarely needed day-to-day, but good to know exists).
```bash
nice -n 10 some_heavy_command
```

---

## System Info & Monitoring

### `df`
Disk space usage, per filesystem/mount point.
```bash
df -h        # -h = human-readable (G/M instead of raw blocks)
```

### `du`
Disk usage of a specific file/directory.
```bash
du -sh ~/practice-lab       # -s = summary total, -h = human-readable
```

### `free`
Memory (RAM) usage.
```bash
free -h
```

### `uname`
System/kernel information.
```bash
uname -a         # everything: kernel, hostname, architecture, etc.
```

### `uptime`
How long the system's been running, plus load averages.
```bash
uptime
```

### `history`
Your command history for the current shell.
```bash
history
history | grep docker      # find that one command you ran three days ago
```

---

## Package Management

*(Debian/Ubuntu — `apt`/`dpkg`. Other distros use different tools: `yum`/`dnf` on RHEL/Fedora, `pacman` on Arch.)*

```bash
sudo apt update                    # refresh the package index
sudo apt upgrade -y                 # upgrade everything installed
sudo apt install -y <package>        # install
sudo apt remove <package>              # remove, keep config
sudo apt purge <package>                # remove + delete config too
apt search <keyword>                      # find a package
dpkg -l | grep <name>                       # is it installed?
```

---

## Networking

### `ping`
Test reachability of a host.
```bash
ping -c 4 google.com       # -c 4 = send 4 pings and stop
```

### `curl`
Fetch a URL — HTTP requests from the command line.
```bash
curl https://example.com                # fetch full page content
curl -I https://example.com               # -I = headers only, quick "is it alive" check
curl -O https://example.com/file.zip        # -O = save output to a file
```

### `wget`
Download a file from a URL — simpler than `curl` when all you want is "save this file."
```bash
wget https://example.com/file.zip
```

### `ss`
Show listening ports and network connections (the modern replacement for `netstat`).
```bash
ss -tulpn        # TCP+UDP, listening only, show process, numeric ports
```

### `ssh`
Securely log into a remote machine.
```bash
ssh username@remote-host
```

### `scp`
Securely copy files to/from a remote machine over SSH.
```bash
scp file.txt username@remote-host:/path/to/destination
```

---

## Archives & Compression

### `tar`
The standard archiving tool — bundles multiple files/directories into one.
```bash
tar -czf archive.tar.gz folder/       # -c create, -z gzip-compress, -f filename
tar -xzf archive.tar.gz                 # -x extract
tar -tzf archive.tar.gz                   # -t list contents without extracting
```

### `zip` / `unzip`
Zip-format archives (Windows-friendly).
```bash
zip -r archive.zip folder/
unzip archive.zip
```

### `gzip` / `gunzip`
Compress/decompress a single file.
```bash
gzip file.txt          # produces file.txt.gz, replaces the original
gunzip file.txt.gz
```

---

## Services (systemd)

```bash
sudo systemctl status <service>
sudo systemctl start <service>
sudo systemctl stop <service>
sudo systemctl restart <service>
sudo systemctl enable <service>       # auto-start on boot
sudo systemctl disable <service>       # turn off auto-start
journalctl -u <service>                  # logs for a specific service
journalctl -f                              # follow live logs, all services
```

---

## Redirection & Piping

```bash
command > file.txt          # overwrite file with output
command >> file.txt          # append output to file
command1 | command2            # pipe: command1's output becomes command2's input
command 2> errors.txt            # redirect ERRORS specifically (stderr), not normal output
command 2>&1                       # merge errors into normal output stream
```

### `tee`
Writes output to a file **and** the screen simultaneously — useful mid-pipe when you want to both see and save output.
```bash
some_command | tee output.txt
```

---

## Environment & Shell

### `export`
Set an environment variable for your current session (and anything it launches).
```bash
export MY_VAR="value"
```

### `env` / `printenv`
Show all current environment variables.
```bash
env
echo $PATH
```

### `which`
Shows the full path of the executable that would run for a given command name.
```bash
which python3
```

### `alias`
Create a shortcut for a longer command.
```bash
alias ll='ls -la'
# add to ~/.bashrc to make it permanent
```

### `source`
Re-run a script in your CURRENT shell (not a subshell) — most commonly used to reload `~/.bashrc` after editing it.
```bash
source ~/.bashrc
```

---

## 💡 A note on scope

This list is deliberately broad — plenty of commands here (`awk`, `sed`, `ssh`, `scp`, `htop`, `tar`) go beyond what's formally taught day-by-day in this course. That's intentional: real Linux work pulls from all of these constantly, and having them in one place means you're not starting from zero the first time you need one on the job.
