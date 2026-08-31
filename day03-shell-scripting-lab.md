# Day 3 — Shell Scripting Lab 
## Automating IT Onboarding — Acme Analytics

*Estimated time: 2–2.5 hours. Builds directly on Day 2's users/groups/permissions scenario.*

---

## 🎯 Objective

On Day 2 you did everything by hand: created users, created groups, added
users to groups, made shared directories, set permissions, verified.

Today you turn that into **one script** that does it for you. The goal
isn't a big system — it's proving you can combine variables, functions,
loops, and conditionals into something that actually runs and does real
work.

**Deliverable:** one file, `acme_it_admin.sh`, that can onboard and verify
an employee.

---

## 🏢 Scenario recap

| Department | Linux group | Shared directory |
|---|---|---|
| Engineering | `engineering` | `/srv/shared/engineering` |
| Finance | `finance` | `/srv/shared/finance` |
| HR | `hr` | `/srv/shared/hr` |

If your Day 2 groups/directories don't exist anymore, recreate them first:

```bash
sudo groupadd engineering; sudo groupadd finance; sudo groupadd hr
sudo mkdir -p /srv/shared/{engineering,finance,hr}
sudo chown :engineering /srv/shared/engineering
sudo chown :finance /srv/shared/finance
sudo chown :hr /srv/shared/hr
sudo chmod 770 /srv/shared/{engineering,finance,hr}
```

---

## ⚠️ Safety rules

- Don't delete your own account or your trainer's.
- Never `rm -rf /` or use wildcards you don't fully understand.
- Don't hand-edit `/etc/passwd`, `/etc/shadow`, or `/etc/group`.
- Only use training usernames (see Part 6).

---

## Part 1 — Skeleton and banner (15 min)

Create `acme_it_admin.sh`:

```bash
#!/bin/bash

# Acme Analytics — IT Onboarding Automation

show_banner() {
    echo "========================================"
    echo " Acme Analytics IT Administration Tool"
    echo "========================================"
    echo "Administrator : $(whoami)"
    echo "Date          : $(date +'%Y-%m-%d %H:%M:%S')"
    echo "Home          : $HOME"
    echo "========================================"
}

show_banner
```

```bash
chmod +x acme_it_admin.sh
./acme_it_admin.sh
```

**Checkpoint:** the banner prints your real username and current date —
not typed-in values. This is your first taste of command substitution
`$(...)`.

---

## Part 2 — Variables, array, config (15 min)

Add near the top of the script (after the shebang, before the functions):

```bash
COMPANY_NAME="Acme Analytics"
ACME_ROOT="${ACME_ROOT:-/srv/shared}"     # override with: export ACME_ROOT=...
LOG_FILE="$HOME/acme-it-admin.log"

DEPARTMENTS=(engineering finance hr)

# Counters
users_created=0
users_skipped=0
users_failed=0
```

**Checkpoint:** run `export ACME_ROOT=/tmp/shared_test` before calling the
script and confirm (by echoing `$ACME_ROOT` somewhere) that it picks up
the override instead of the default.

---

## Part 3 — Logging function (10 min)

```bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date +'%H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}
```

Call it a few times manually to confirm entries append (`>>`) rather
than overwrite:

```bash
log_message "INFO" "Script started"
cat "$HOME/acme-it-admin.log"
```

Run the script twice and confirm the log has grown, not been replaced.

---

## Part 4 — Validation functions (25 min)

```bash
validate_department() {
    local dept="$1"
    for d in "${DEPARTMENTS[@]}"; do
        if [[ "$d" == "$dept" ]]; then
            return 0
        fi
    done
    return 1
}

validate_username() {
    local uname="$1"
    if [[ -z "$uname" ]]; then
        return 1
    elif [[ "$uname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 0
    else
        return 1
    fi
}
```

Note the pattern: these functions don't print anything — they just
`return 0` (success) or `return 1` (failure), the same way real Linux
commands do with exit codes. The caller decides what to say.

**Checkpoint — test in isolation before moving on:**

```bash
validate_department "engineering"; echo $?   # expect 0
validate_department "marketing"; echo $?     # expect 1
validate_username "priya"; echo $?           # expect 0
validate_username ""; echo $?                # expect 1
validate_username "bad name!"; echo $?       # expect 1
```

---

## Part 5 — Existence checks (15 min)

```bash
user_exists() {
    getent passwd "$1" > /dev/null 2>&1
    return $?
}

group_exists() {
    getent group "$1" > /dev/null 2>&1
    return $?
}
```

**Checkpoint:**

```bash
user_exists "$(whoami)"; echo $?   # 0 — you exist
user_exists "no_such_user_xyz"; echo $?  # 1
group_exists "engineering"; echo $?
```

---

## Part 6 — The ONBOARD operation (40 min)

This is the core of the lab. Command interface:

```bash
./acme_it_admin.sh onboard <username> <department>
```

```bash
onboard_user() {
    local uname="$1"
    local dept="$2"

    # Step 1: validate inputs
    if ! validate_username "$uname"; then
        log_message "ERROR" "Invalid username: $uname"
        echo "ERROR: '$uname' is not a valid username."
        ((users_failed++))
        return 1
    fi

    if ! validate_department "$dept"; then
        log_message "ERROR" "Invalid department: $dept"
        echo "ERROR: '$dept' is not a valid department. Choose from: ${DEPARTMENTS[*]}"
        ((users_failed++))
        return 1
    fi

    # Step 2: check department group exists before doing anything else
    if ! group_exists "$dept"; then
        log_message "ERROR" "Department group missing: $dept"
        echo "ERROR: group '$dept' does not exist. Aborting."
        ((users_failed++))
        return 1
    fi

    # Step 3: check user doesn't already exist
    if user_exists "$uname"; then
        log_message "ERROR" "User already exists: $uname"
        echo "ERROR: user '$uname' already exists. Skipping."
        ((users_skipped++))
        return 1
    fi

    # Step 4: create the user
    if sudo useradd -m -s /bin/bash "$uname"; then
        log_message "ONBOARD" "Created user $uname"
    else
        log_message "ERROR" "useradd failed for $uname"
        ((users_failed++))
        return 1
    fi

    # Step 5: add to department group
    if sudo usermod -aG "$dept" "$uname"; then
        log_message "ONBOARD" "$uname added to group $dept"
    else
        log_message "ERROR" "usermod failed for $uname"
        ((users_failed++))
        return 1
    fi

    # Step 6: verify
    if id "$uname" > /dev/null 2>&1 && getent group "$dept" | grep -q "$uname"; then
        log_message "VERIFY" "$uname confirmed in $dept"
        echo "SUCCESS: $uname onboarded to $dept."
        ((users_created++))
        return 0
    else
        log_message "ERROR" "Verification failed for $uname"
        echo "WARNING: user created but verification failed — check manually."
        ((users_failed++))
        return 1
    fi
}
```

Wire it up with positional arguments at the bottom of the script:

```bash
operation="$1"

case "$operation" in
    onboard)
        onboard_user "$2" "$3"
        ;;
    *)
        echo "Usage: $0 onboard <username> <department>"
        exit 1
        ;;
esac
```

**Checkpoint tests (use throwaway usernames, e.g. `testuser1`):**

```bash
./acme_it_admin.sh onboard testuser1 engineering   # should succeed
./acme_it_admin.sh onboard testuser1 engineering   # should say "already exists"
./acme_it_admin.sh onboard testuser2 marketing     # should reject bad department
./acme_it_admin.sh onboard "" engineering           # should reject empty username
```

After each, run `echo $?` to see the exit code, and `tail -5 ~/acme-it-admin.log`
to see the log entries.

---

## Part 7 — VERIFY operation (20 min)

```bash
verify_user() {
    local uname="$1"

    if ! user_exists "$uname"; then
        echo "User '$uname' does not exist."
        return 1
    fi

    local uid home shell
    uid=$(id -u "$uname")
    home=$(getent passwd "$uname" | cut -d: -f6)
    shell=$(getent passwd "$uname" | cut -d: -f7)

    echo "========================================"
    echo " USER REPORT"
    echo "========================================"
    echo "Username : $uname"
    echo "UID      : $uid"
    echo "Home     : $home"
    echo "Shell    : $shell"
    echo "Groups   : $(id -Gn "$uname")"

    for dept in "${DEPARTMENTS[@]}"; do
        if id -nG "$uname" | grep -qw "$dept"; then
            echo "Department: $dept"
            echo "Shared dir: $ACME_ROOT/$dept ($(stat -c '%A owner=%U group=%G' "$ACME_ROOT/$dept" 2>/dev/null))"
        fi
    done
}
```

Add to the `case` statement:

```bash
    verify)
        verify_user "$2"
        ;;
```

**Checkpoint:**

```bash
./acme_it_admin.sh verify testuser1
./acme_it_admin.sh verify no_such_user
```

---

## Part 8 — Summary and exit codes (15 min)

At the very end of the script, after the `case` block:

```bash
echo ""
echo "Session summary: created=$users_created skipped=$users_skipped failed=$users_failed"
log_message "SUMMARY" "created=$users_created skipped=$users_skipped failed=$users_failed"

if (( users_failed > 0 )); then
    exit 1
else
    exit 0
fi
```

**Checkpoint:** run a batch of three onboard calls (one valid, one
duplicate, one bad department) in a row, then check `echo $?` after the
whole script run — it should be `1` because at least one failed.

---

## 🎁 Optional stretch (only if you finish early)

Pick **one**, not all:

**A. Batch onboarding with a loop.** Add a `batch` operation that reads
three username/department pairs from an array and calls `onboard_user`
on each in a `for` loop — proving loops remove repetition instead of
copy-pasting three `onboard` calls.

**B. Retry with `while`.** In interactive mode (no arguments given),
use a `while` loop to keep re-prompting for a department until
`validate_department` returns success, instead of failing on the first
bad entry.

**C. Offboarding.** Add `./acme_it_admin.sh offboard <username>` that
backs up the home directory to `/srv/archived-users/`, then runs
`userdel -r`, following the same validate → check-exists → act → verify
→ log pattern as `onboard_user`.

Don't attempt more than one — the point of this lab is the core
workflow, not feature count.

---

## ✅ What "done" looks like

- [ ] Script has a shebang, is executable, runs via `./acme_it_admin.sh`
- [ ] Banner uses command substitution, not hard-coded values
- [ ] `DEPARTMENTS` array exists and is used in a `for` loop for validation
- [ ] `validate_username`, `validate_department`, `user_exists`,
      `group_exists` all communicate success/failure via exit code
      (`return 0` / `return 1`), not by printing text
- [ ] `onboard_user` validates, checks existence, creates, adds to group,
      verifies, and logs — in that order, stopping early on failure
- [ ] `verify_user` reports dynamically obtained values
- [ ] Positional arguments (`$1`, `$2`) and a `case` statement route
      to the right operation
- [ ] Log file grows across runs (`>>`, not `>`)
- [ ] Script exits `0` on full success, `1` if anything failed
- [ ] You tested at least: one success, one duplicate user, one bad
      department, one empty username

---

## 🗣️ Be ready to explain (pick a few, don't drill all)

1. Why do `validate_username` and `user_exists` `return` a code instead
   of printing "yes"/"no"?
2. Why check `group_exists` *before* creating the user, not after?
3. What's the difference between `$1` and `$#` in your script?
4. Why `usermod -aG` and not `usermod -G`?
5. Why does the script use `>>` for the log but plain assignment for
   counters?
6. What would happen if you ran `onboard_user` without checking
   `validate_department` first?
