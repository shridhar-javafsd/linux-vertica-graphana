#!/bin/bash

# ============================================================
# Acme Analytics — IT Onboarding Automation
# Day 3 Shell Scripting Lab — Complete Solution
# ============================================================

# ---------- Configuration ----------
COMPANY_NAME="Acme Analytics"
ACME_ROOT="${ACME_ROOT:-/srv/shared}"     # override with: export ACME_ROOT=...
REAL_USER="${SUDO_USER:-$(whoami)}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
LOG_FILE="${REAL_HOME}/acme-it-admin.log"

DEPARTMENTS=(engineering finance hr)

# ---------- Counters ----------
users_created=0
users_skipped=0
users_failed=0

# ============================================================
# Functions
# ============================================================

show_banner() {
    echo "========================================"
    echo " $COMPANY_NAME IT Administration Tool"
    echo "========================================"
    echo "Administrator : $(whoami)"
    echo "Date          : $(date +'%Y-%m-%d %H:%M:%S')"
    echo "Home          : $HOME"
    echo "Log file      : $LOG_FILE"
    echo "ACME_ROOT     : $ACME_ROOT"
    echo "========================================"
}

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date +'%H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

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

user_exists() {
    getent passwd "$1" > /dev/null 2>&1
    return $?
}

group_exists() {
    getent group "$1" > /dev/null 2>&1
    return $?
}

onboard_user() {
    local uname="$1"
    local dept="$2"

    # Step 1: validate inputs
    if ! validate_username "$uname"; then
        log_message "ERROR" "Invalid username: '$uname'"
        echo "ERROR: '$uname' is not a valid username."
        ((users_failed++))
        return 1
    fi

    if ! validate_department "$dept"; then
        log_message "ERROR" "Invalid department: '$dept'"
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
    if useradd -m -s /bin/bash "$uname"; then
        log_message "ONBOARD" "Created user $uname"
    else
        log_message "ERROR" "useradd failed for $uname"
        echo "ERROR: useradd failed for '$uname'."
        ((users_failed++))
        return 1
    fi

    # Step 5: add to department group
    if usermod -aG "$dept" "$uname"; then
        log_message "ONBOARD" "$uname added to group $dept"
    else
        log_message "ERROR" "usermod failed for $uname"
        echo "ERROR: usermod failed for '$uname'."
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

# ============================================================
# Main — positional arguments + case routing
# ============================================================

show_banner

operation="$1"

case "$operation" in
    onboard)
        onboard_user "$2" "$3"
        ;;
    verify)
        verify_user "$2"
        ;;
    *)
        echo "Usage: $0 onboard <username> <department>"
        echo "       $0 verify <username>"
        echo "Valid departments: ${DEPARTMENTS[*]}"
        exit 1
        ;;
esac

echo ""
echo "Session summary: created=$users_created skipped=$users_skipped failed=$users_failed"
log_message "SUMMARY" "created=$users_created skipped=$users_skipped failed=$users_failed"

if (( users_failed > 0 )); then
    exit 1
else
    exit 0
fi