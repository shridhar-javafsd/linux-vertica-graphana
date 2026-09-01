# Day 2 Afternoon Extension — IT Onboarding & Offboarding Simulation

*Bonus session — combines everything from Day 1 (filesystem, permissions) with today's users/groups/processes*

---

## 🎯 Why this session

Today's planned topics are done — this is reinforcement, not new material. Everything below reuses commands you already know; the goal is doing them together, for real, in a realistic scenario, until they stop feeling like separate topics and start feeling like one connected skill.

**The scenario:** you're the sysadmin at a small company. Three new hires start today. You need to set up their accounts, department group access, and shared drive permissions — properly, the way a real IT team would. By the end, one of them is already leaving (it happens), so you'll offboard them too.

---

## Part 1: Onboard three new hires

Three new employees, three departments:

| Username | Department |
|---|---|
| `priya` | Engineering |
| `rahul` | Finance |
| `meera` | HR |

**For each one:**

```bash
sudo useradd -m -s /bin/bash priya
sudo passwd priya
sudo useradd -m -s /bin/bash rahul
sudo passwd rahul
sudo useradd -m -s /bin/bash meera
sudo passwd meera
```

Create the three department groups:

```bash
sudo groupadd engineering
sudo groupadd finance
sudo groupadd hr
```

Add each person to their department group — **`-a`, always**:

```bash
sudo usermod -aG engineering priya
sudo usermod -aG finance rahul
sudo usermod -aG hr meera
```

**Verify all three, two different ways:**

```bash
id priya
id rahul
id meera
```

```bash
getent group engineering
getent group finance
getent group hr
```

> 💡 **New command: `getent`.** `getent group engineering` does the same job as `grep engineering /etc/group`, but it's the more correct tool — it queries whatever the system's actual user/group database is (which on a real production server might be LDAP or another directory service, not just the local `/etc/group` file), not just one specific file. `id` and `getent` together are your two go-to verification commands from now on.

---

## Part 2: Build each department's shared drive

Real departments need a shared space only their own people can access.

```bash
sudo mkdir -p /srv/shared/engineering
sudo mkdir -p /srv/shared/finance
sudo mkdir -p /srv/shared/hr

sudo chown :engineering /srv/shared/engineering
sudo chown :finance /srv/shared/finance
sudo chown :hr /srv/shared/hr

sudo chmod 770 /srv/shared/engineering
sudo chmod 770 /srv/shared/finance
sudo chmod 770 /srv/shared/hr
```

**Quick recap of what `770` means (Day 1):** owner (`7` = rwx) and group (`7` = rwx) get full access, everyone else (`0`) gets nothing. Combined with the group ownership above, this means: only people *in that department's group* can touch that folder at all.

---

## Part 3: Prove the permissions actually work

This is the part that makes it click — don't skip it.

```bash
su - priya
```

```bash
echo "Q3 architecture notes" > /srv/shared/engineering/notes.txt
cat /srv/shared/engineering/notes.txt
```
✅ Works — `priya` is in the `engineering` group.

Now, still as `priya`, try the finance drive:

```bash
echo "trying to peek" > /srv/shared/finance/notes.txt
```
❌ **`Permission denied`** — exactly what should happen. `priya` isn't in `finance`.

```bash
exit
```

Back to your own session. Repeat the same spot-check with `rahul` (works in `finance`, denied in `hr`) if you want a second confirmation.

---

## Part 4: A process/user connection

Before we offboard anyone, let's simulate something realistic: checking what a user is actively running.

```bash
su - meera
sleep 600 &
exit
```

Back in your own session, find everything `meera` is running:

```bash
ps -u meera
```

> 💡 **New flag: `pkill -u`.** You've used `pkill <name>` to kill by process name. `pkill -u meera` kills **every process owned by a specific user** — genuinely the first thing a real sysadmin does before offboarding someone, so nothing keeps running under a deleted account.

```bash
sudo pkill -u meera
ps -u meera        # should now show nothing
```

---

## Part 5: Offboard `meera`

**Step 1 — back up her home directory first, always:**

```bash
sudo mkdir -p /srv/archived-users
sudo cp -r /home/meera /srv/archived-users/meera_backup
ls /srv/archived-users/meera_backup
```

**Step 2 — remove the account.** Two ways, worth knowing both:

```bash
sudo userdel meera        # removes the ACCOUNT only — home directory is left behind, orphaned
```

vs. what you actually want here, since you've already backed up:

```bash
sudo userdel -r meera      # removes the account AND deletes the home directory
```

Use `sudo userdel -r meera` now (skip the first one, or if you ran it as a demo, there's no home dir left to worry about anyway).

**Verify she's really gone:**

```bash
id meera                    # should error: "no such user"
getent group hr              # meera should no longer be listed
ls /home                       # meera's home directory should be gone
```

> 💡 **`adduser` / `deluser` — the friendlier alternative.** `sudo adduser sonu` and `sudo deluser sonu` (which you saw earlier today) are Debian/Ubuntu-specific interactive wrappers around `useradd`/`userdel` — they prompt you for details and handle a few extra steps (like home directory creation) automatically. We used the lower-level `useradd`/`userdel` here because that's what you'll actually script with — but `adduser`/`deluser` are genuinely fine for quick manual admin work.

---

## Part 6: Final verification checklist

Confirm the end state matches reality:

```bash
id priya              # exists, in engineering group
id rahul               # exists, in finance group
id meera                 # gone
getent group engineering   # priya listed
getent group finance         # rahul listed
getent group hr                # empty (or without meera)
ls /srv/shared                   # engineering, finance, hr all present
ls /srv/archived-users              # meera_backup present
```

---

## 📎 New commands from this session

```bash
# --- Lookup (safer than grep-ing /etc/passwd or /etc/group directly) ---
getent group <groupname>
getent passwd <username>

# --- Kill everything owned by a specific user ---
sudo pkill -u <username>

# --- Remove a user ---
sudo userdel <username>          # account only, home dir left behind
sudo userdel -r <username>        # account + home directory

# --- Friendlier interactive alternatives ---
sudo adduser <username>
sudo deluser <username>

# --- Group ownership + shared-access permissions (Day 1 + Day 2 combined) ---
sudo chown :<groupname> <path>
sudo chmod 770 <path>              # owner + group full access, others none
```

---

## 🗣️ Discussion, if there's still time

- Why back up *before* `userdel -r`, not after? (Once the home directory's gone, it's gone — no undo.)
- What would happen if you ran `sudo usermod -G engineering priya` (no `-a`) on someone already in three other groups? Walk through it out loud.
- `770` gives group members full read/write/execute on the shared folder. When would you want `750` instead (group can read/execute, but not write)? Real scenario: a folder full of finalized reports the whole department should be able to read, but only a couple of specific people should edit.
