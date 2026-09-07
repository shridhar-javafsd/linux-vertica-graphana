# Interview Prep — Linux

*For client interviews after this training. Mix of fresher-friendly basics and a few deeper questions the more experienced folks in the room should be ready for — tagged so you know what to expect either way. Answers are kept short and interview-ready, not textbook-length.*

---

### 1. What's the difference between Linux and Windows, from a server/ops perspective? *(Fresher)*
Linux is open-source, free, and dominates servers/cloud because it's lightweight, scriptable, and doesn't need a GUI to run. Windows Server is common in enterprise desktop-integrated environments but costs licensing and is heavier for pure server workloads.

### 2. What's the difference between a relative and absolute path? *(Fresher)*
Absolute starts from root (`/home/user/file.txt`); relative is from your current location (`./file.txt` or `../file.txt`). `pwd` tells you where "current" actually is.

### 3. What does `chmod 755 file.sh` actually do? *(Fresher)*
Sets permissions: owner gets read+write+execute (7), group and others get read+execute (5 each). Each digit is a sum: read=4, write=2, execute=1.
> 🎯 **Gotcha follow-up:** "What if you need the file executable only by the owner, not group/others?" → `chmod 700`.

### 4. Difference between `chmod` and `chown`? *(Fresher)*
`chmod` changes *permissions* (what can be done to a file); `chown` changes *ownership* (who owns it — user and/or group).

### 5. What's the difference between a hard link and a symbolic link? *(Experienced)*
A hard link is another directory entry pointing to the same inode — same data, deleting one doesn't affect the other, and it can't cross filesystems. A symlink is a separate file containing a *path* to the target — breaks if the target moves, but can cross filesystems and can link to directories.

### 6. How do you find which process is using a particular port? *(Fresher/Experienced)*
`ss -lntp | grep <port>` (modern) or `netstat -tulnp | grep <port>` (older/deprecated). Gives you the PID, which you can then `kill` if needed.

### 7. What's the difference between `kill`, `kill -9`, and `pkill`? *(Fresher)*
`kill <pid>` sends SIGTERM — a polite "please shut down," which the process can catch and clean up after. `kill -9 <pid>` sends SIGKILL — immediate, un-catchable termination, no cleanup. `pkill <name>` kills by process name instead of PID.
> 🎯 **Gotcha follow-up:** "Why shouldn't you always jump straight to `-9`?" → It skips graceful shutdown — open file handles, in-flight writes, or database transactions can be left in a bad state.

### 8. What does `systemctl` actually manage? *(Fresher)*
`systemd` services — background processes (daemons) like `grafana-server`, `docker`, `ssh`. `systemctl start/stop/restart/status/enable/disable <service>` is the standard toolkit.

### 9. Difference between `systemctl start` and `systemctl enable`? *(Fresher — but commonly asked)*
`start` runs it *now*, for this session. `enable` makes it auto-start on every boot. They're independent — you can enable without starting, or start without enabling.

### 10. How do you check disk usage on Linux? *(Fresher)*
`df -h` for filesystem-level free/used space (human-readable). `du -sh <directory>` for how much a specific folder is consuming.

### 11. What's the difference between `du` and `df` disagreeing on free space? *(Experienced)*
Usually a deleted-but-still-open file — a process still holds a file handle to a "deleted" file, so the disk hasn't actually freed the space (`df`) even though it doesn't show up in any directory listing (`du`). Restarting the process (or `lsof | grep deleted`) usually confirms it.

### 12. What is a package manager, and what does `apt` do specifically? *(Fresher)*
A tool that installs, updates, and removes software along with its dependencies. `apt` is Debian/Ubuntu's — `apt-get install`, `apt-get update` (refreshes the package index), `apt-get upgrade` (installs newer versions).

### 13. What's the difference between `apt update` and `apt upgrade`? *(Fresher — commonly confused)*
`update` refreshes the local list of what's *available* — it doesn't install anything. `upgrade` actually installs newer versions of packages you already have.

### 14. What's a cron job, and how do you schedule one? *(Fresher/Experienced)*
A scheduled, recurring task. `crontab -e` opens your personal schedule file; each line is `minute hour day month weekday command`. E.g., `0 2 * * *` = every day at 2 AM.

### 15. What's the difference between `grep`, `awk`, and `sed`? *(Experienced)*
`grep` searches/filters lines matching a pattern. `awk` processes structured/column data (great for extracting specific fields). `sed` does stream editing — find-and-replace on the fly, without opening a file in an editor.

### 16. How would you find all `.log` files modified in the last 24 hours? *(Experienced)*
`find / -name "*.log" -mtime -1`

### 17. What are environment variables, and how do you set one permanently? *(Fresher)*
Key-value pairs available to processes (`$PATH`, `$HOME`). `export VAR=value` sets it for the current session; adding that line to `~/.bashrc` (or `~/.profile`) makes it persist across sessions.

### 18. What's the difference between a process and a thread? *(Experienced)*
A process has its own memory space and resources; threads run *within* a process and share its memory. Threads are lighter-weight but riskier — a bug in one thread can corrupt shared memory used by another.

### 19. How do you check what's consuming the most CPU/RAM right now? *(Fresher)*
`top` or `htop` (interactive, real-time). `ps aux --sort=-%mem` for a one-time sorted snapshot.

### 20. What is a symbolic link used for, practically? *(Fresher)*
Pointing to a file/directory from elsewhere without duplicating it — e.g., `/usr/bin/python` symlinked to `python3.11`, so multiple names resolve to the same actual binary.

### 21. What's the purpose of `/etc/`, `/var/`, and `/tmp/`? *(Fresher)*
`/etc/` — configuration files. `/var/` — variable/changing data: logs, caches, spooled mail. `/tmp/` — temporary files, often cleared on reboot.

### 22. What's SSH, and what's the difference between password and key-based authentication? *(Fresher/Experienced)*
SSH is a secure remote-login protocol. Password auth is simpler but brute-forceable; key-based auth uses a public/private keypair — the server only ever sees the public key, and the private key never leaves your machine, which is why it's considered far more secure and is the standard for production servers.

### 23. What is WSL2, and how is it different from a traditional virtual machine? *(Fresher — relevant to this course)*
WSL2 runs a real, lightweight Linux kernel inside a managed VM, tightly integrated with Windows (shared filesystem access, automatic port forwarding to `localhost`). It's much faster to start and lighter on resources than a full VM like VirtualBox/VMware, though it is technically still a VM underneath.

### 24. What does `sudo` do, and why shouldn't you just run everything as root? *(Fresher)*
`sudo` temporarily elevates a command to root privileges. Running *everything* as root removes the safety net that stops accidental system-breaking commands (`rm -rf /`, etc.) — least-privilege is the principle: only elevate when you actually need to.

### 25. How do Docker containers relate to the Linux kernel? *(Experienced)*
Containers aren't full VMs — they share the host's Linux kernel but get isolated filesystem, process, and network namespaces. That's *why* containers start almost instantly compared to a VM (no separate kernel to boot) and why "Docker on Windows" actually needs WSL2 or Hyper-V underneath — Docker needs a real Linux kernel to share.

### 26. What's the difference between `TCP` and `UDP`, briefly? *(Experienced)*
TCP is connection-oriented and guarantees delivery/order (used for things like databases, web traffic). UDP is connectionless, faster, no delivery guarantee (used for streaming, DNS lookups) — a trade of reliability for speed.

### 27. What happens when you run a command and it says "command not found"? *(Fresher)*
Either it's not installed, or it's not in your `$PATH` — the list of directories the shell searches for executables. `which <command>` or `echo $PATH` helps debug.

---

## 🎯 A few extra gotcha-style follow-ups to be ready for

- **"You ran `chmod 777` on a file to fix a permissions error — what's wrong with that?"** → It gives everyone read/write/execute, including users/processes that shouldn't have access. It "fixes" the symptom while creating a security hole — you should find the *actual* owner/group mismatch instead.
- **"Your service works when you `start` it manually but not after a reboot — why?"** → It was never `enable`d, so `systemd` never re-launches it on boot.
- **"`df` says you're out of disk space but `du` on `/` doesn't add up — what do you check next?"** → Look for deleted-but-open file handles (`lsof | grep deleted`), and check for hidden large directories `du` might not have been pointed at.
- **"Why would a `cron` job that works fine when you run the command manually fail when scheduled?"** → Cron jobs run with a minimal environment — no `$PATH`, no user profile loaded. Always use absolute paths and don't rely on environment variables cron won't have.
