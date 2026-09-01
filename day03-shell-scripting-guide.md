# The Complete Linux Shell Scripting Guide
### (Bash) — Concepts, Syntax, and How to Run Your Scripts

Every example in this guide is built around a single running scenario:
Acme Analytics, a company that needs to onboard new employees into
department groups (`engineering`, `finance`, `hr`) and give them
access to shared drives. The same `DEPARTMENTS` array and the same
onboarding logic reappear throughout, so by the end you'll have seen
most of the pieces of a real onboarding script — even before writing
one yourself.

---

## Table of Contents

1. [What a shell script actually is](#1-what-a-shell-script-actually-is)
2. [Running a script — permissions, methods, arguments](#2-running-a-script)
3. [Variables](#3-variables)
4. [Data "types" in Bash](#4-data-types-in-bash)
5. [Arrays](#5-arrays)
6. [Parameter expansion & defaults](#6-parameter-expansion--defaults)
7. [String operations](#7-string-operations)
8. [Command substitution & arithmetic](#8-command-substitution--arithmetic)
9. [Input and output](#9-input-and-output)
10. [Control structures — if / case](#10-control-structures)
11. [Loops — for / while / until](#11-loops)
12. [Functions](#12-functions)
13. [Positional parameters & script arguments](#13-positional-parameters--script-arguments)
14. [Exit codes and `$?`](#14-exit-codes-and-)
15. [File test operators](#15-file-test-operators)
16. [Redirection & pipes](#16-redirection--pipes)
17. [Logical operators](#17-logical-operators)
18. [Quoting rules (the #1 source of bugs)](#18-quoting-rules)
19. [`[ ]` vs `[[ ]]` vs `(( ))`](#19---vs--vs-)
20. [Common gotchas](#20-common-gotchas)
21. [Quick syntax cheat-sheet](#21-quick-syntax-cheat-sheet)

---

## 1. What a shell script actually is

A shell script is a plain text file containing a sequence of commands
you'd otherwise type one at a time at the prompt. The shell reads it
top to bottom and executes each line as if you'd typed it yourself.

Every script should start with a **shebang** line:

```bash
#!/bin/bash
```

This tells the operating system which interpreter to run the rest of
the file with. `#!/bin/bash` specifically means "run this with Bash,"
even if the user's default shell is something else (zsh, dash, etc.).
Without it, behavior depends on how the script is invoked — always
include it.

Comments start with `#` and are ignored by the shell:

```bash
# This is a comment
echo "This runs"   # This part is also a comment
```

---

## 2. Running a script

### Step 1 — Make it executable

A script file needs the **execute permission** bit set before it can
be run directly:

```bash
chmod +x acme_it_admin.sh
```

Check permissions with:

```bash
ls -l acme_it_admin.sh
# -rwxr-xr-x 1 vaman vaman 5470 Aug 31 16:19 acme_it_admin.sh
#  ^^^
#  r,w,x for owner — the x is what chmod +x added
```

### Step 2 — Run it

There are three common ways, and they behave slightly differently:

```bash
./acme_it_admin.sh onboard priya engineering
```
Runs the script using the interpreter named in its own shebang line.
Requires execute permission. The `./` is required because the current
directory is deliberately not part of `$PATH` (a security default) —
without `./`, Bash searches only the folders listed in `$PATH` and
won't find a script sitting right next to you.

```bash
bash acme_it_admin.sh onboard priya engineering
```
Explicitly tells Bash to run the file's contents. Works even **without**
execute permission, because you're not "running the file" — you're
running `bash` and handing it a file to read.

```bash
sh acme_it_admin.sh onboard priya engineering
```
Runs it with whatever `sh` points to on this system (on many Linux
distros, `sh` is a lighter shell like `dash`, not Bash) — can silently
break Bash-specific syntax like arrays or `[[ ]]`. Avoid this for
Bash-authored scripts unless you're sure `sh` is Bash on your system.

### Step 3 — Run it with root privileges, if needed

Any command inside the script that touches system-level resources
(`useradd`, `usermod`, writing to `/etc/`, etc.) needs root, regardless
of how the script itself is invoked:

```bash
sudo ./acme_it_admin.sh onboard priya engineering
```

Two details worth knowing:

- `sudo` by default does **not** pass your exported environment
  variables through to the elevated session. If your script relies on
  something you `export`ed (like `ACME_ROOT`), use:
  ```bash
  sudo -E ./acme_it_admin.sh onboard priya engineering
  ```
- `sudo` caches successful authentication for a grace period (commonly
  15 minutes) per terminal session — this is why it sometimes asks for
  a password and sometimes doesn't. Force a fresh prompt with:
  ```bash
  sudo -k
  ```

### Passing arguments

Anything typed after the script name becomes an argument, in order,
separated by spaces:

```bash
./acme_it_admin.sh onboard priya engineering
#                    ^1     ^2    ^3
```

Covered in full in [Section 13](#13-positional-parameters--script-arguments).

---

## 3. Variables

### Declaring and using

```bash
COMPANY_NAME="Acme Analytics"
echo "$COMPANY_NAME"
```

Rules:
- **No spaces around `=`.** `NAME = "value"` is a syntax error in
  Bash — it looks like `NAME`, `=`, and `"value"` as three separate
  words.
- Variable names: letters, digits, underscores; can't start with a
  digit. `EMP_ID` is fine, `1EMP` is not.
- To **read** a variable, prefix it with `$` (or wrap in `${ }`).
  To **assign**, no `$` at all.

```bash
DEPT="engineering"     # assignment — no $
echo "$DEPT"             # reading — needs $
echo "${DEPT}"            # same thing, braces make boundaries explicit
echo "${DEPT}_team"        # braces matter here — $DEPT_team would look
                            # for a variable literally named DEPT_team
```

### Local vs. global (inside functions)

By default, variables are global to the whole script, even ones set
inside a function — this surprises people coming from other languages:

```bash
set_dept() {
    DEPT="engineering"   # no 'local' — this leaks out of the function
}
set_dept
echo "$DEPT"   # prints: engineering
```

Use `local` inside functions to keep a variable scoped to that function
only — this is exactly the pattern used throughout `acme_it_admin.sh`:

```bash
onboard_user() {
    local uname="$1"
    local dept="$2"
    # uname and dept only exist inside this function
}
```

### Read-only variables

```bash
readonly MAX_RETRIES=3
MAX_RETRIES=5   # error: MAX_RETRIES: readonly variable
```

### Exported (environment) variables

A plain variable only exists inside the current script/shell. `export`
makes it available to any child process the script launches:

```bash
export ACME_ROOT=/srv/shared
```

This is exactly the mechanism you'd use to let an Acme onboarding
script's shared-drive location be overridden by whoever runs it:

```bash
ACME_ROOT="${ACME_ROOT:-/srv/shared}"
```
"If `ACME_ROOT` was already exported by whoever's running this script,
use their value. Otherwise, default to `/srv/shared`."

---

## 4. Data "types" in Bash

Bash does not have real data types the way Python or Java do.
**Everything is fundamentally a string** — including things that look
like numbers. What changes is how a value gets *interpreted*, not how
it's stored.

```bash
AGE="30"          # this is a string containing "30"
echo $((AGE + 5))  # Bash interprets it as a number here → 35
NAME="Priya"
echo $((NAME + 5))  # NAME isn't numeric → treated as 0 → prints 5
```

### The practical "types" you'll work with

| Concept | Example | Notes |
|---|---|---|
| String | `DEPT="engineering"` | The default — no declaration needed |
| Integer | `declare -i COUNT=5` | Optional; `((...))` handles arithmetic without this |
| Indexed array | `DEPARTMENTS=(engineering finance hr)` | Ordered list, numeric index from 0 |
| Associative array | `declare -A MANAGERS` | Key-value pairs (Bash 4+) |
| Boolean | *(doesn't exist)* | Use exit codes: `0` = true/success, non-zero = false/failure |

### On "Boolean" — the most important mental shift

There's no `true`/`false` type. Instead, Bash conditionals check a
command's **exit code**. `0` means success ("true" for `if`
purposes); anything else means failure. This is why a department
validator would work the way it does:

```bash
validate_department() {
    local dept="$1"
    for d in "${DEPARTMENTS[@]}"; do
        [[ "$d" == "$dept" ]] && return 0
    done
    return 1
}

if validate_department "engineering"; then
    echo "valid"
fi
```
`if` isn't checking a "true/false value" — it's checking whether
`validate_department` exited with status `0`.

---

## 5. Arrays

### Indexed arrays

```bash
DEPARTMENTS=(engineering finance hr)

echo "${DEPARTMENTS[0]}"        # engineering (0-indexed)
echo "${DEPARTMENTS[@]}"         # all elements: engineering finance hr
echo "${#DEPARTMENTS[@]}"         # element count: 3

DEPARTMENTS+=(marketing)           # append
echo "${DEPARTMENTS[@]}"            # engineering finance hr marketing
```

Looping over one (a pattern you'll reach for constantly):

```bash
for dept in "${DEPARTMENTS[@]}"; do
    echo "Department: $dept"
done
```

### Associative arrays (key-value pairs)

Require an explicit declaration, unlike indexed arrays:

```bash
declare -A DEPT_MANAGER
DEPT_MANAGER[engineering]="Arjun Mehta"
DEPT_MANAGER[finance]="Farhan Khan"
DEPT_MANAGER[hr]="Priya Nair"

echo "${DEPT_MANAGER[engineering]}"     # Arjun Mehta

for dept in "${!DEPT_MANAGER[@]}"; do   # ! gives you the KEYS
    echo "$dept -> ${DEPT_MANAGER[$dept]}"
done
```

**`@` vs `!` matters here:** `${ARRAY[@]}` gives values, `${!ARRAY[@]}`
gives keys (or, for indexed arrays, gives indices).

---

## 6. Parameter expansion & defaults

Full detail already covered separately, condensed here for reference:

| Syntax | Meaning |
|---|---|
| `${VAR:-default}` | Use `default` if `VAR` unset/empty. Doesn't change `VAR`. |
| `${VAR:=default}` | Same, but also assigns `default` into `VAR`. |
| `${VAR:?message}` | Print `message` and exit if `VAR` unset/empty. |
| `${VAR:+alt}` | Use `alt` **only if** `VAR` is already set. |

```bash
ACME_ROOT="${ACME_ROOT:-/srv/shared}"   # a config path with a sane default
```

The colon (`:`) in all of these means "treat empty string the same as
unset." Drop the colon (`${VAR-default}`) and an empty string counts
as already "set" — the default is skipped.

---

## 7. String operations

```bash
DEPT="engineering"

echo "${#DEPT}"          # length -> 11
echo "${DEPT:0:4}"        # substring from index 0, length 4 -> engi
echo "${DEPT^^}"           # uppercase -> ENGINEERING
echo "${DEPT,,}"            # lowercase (no-op here, already lowercase)

EMAIL="priya.nair@corp.com"
echo "${EMAIL/corp/acme}"    # replace FIRST match -> priya.nair@acme.com
echo "${EMAIL//./_}"          # replace ALL matches -> priya_nair@corp_com
```

Concatenation is just placing strings next to each other:

```bash
FULL_NAME="$FIRST $LAST"
GREETING="Hello, ${FULL_NAME}!"
```

---

## 8. Command substitution & arithmetic

### Command substitution — capture a command's output into a variable

```bash
CURRENT_DATE=$(date +%F)
USER_COUNT=$(getent passwd | wc -l)
```
`$(...)` runs the command and substitutes its output as text. This is
how a `show_banner` function could build every line dynamically:

```bash
echo "Administrator : $(whoami)"
echo "Date          : $(date +'%Y-%m-%d %H:%M:%S')"
```

### Arithmetic

```bash
a=5
b=3
echo $((a + b))    # 8
echo $((a * b))     # 15
echo $((a / b))      # 1  (integer division — no decimals)
echo $((a % b))       # 2  (remainder)

((a++))                # increment in place
echo "$a"                # 6
```

The `((...))` construct (no `$`) is used for **actions** on numbers —
incrementing, comparing — rather than producing a value:

```bash
((users_failed++))    # exactly how a running failure-counter works
if (( users_failed > 0 )); then
    exit 1
fi
```

---

## 9. Input and output

```bash
echo "Plain text output"
printf "Formatted: %s is %d years old\n" "Priya" 30
```

`printf` gives precise control over formatting; `echo` is simpler for
everyday text.

Reading input from the user:

```bash
read -p "Enter department: " dept
echo "You entered: $dept"
```

`read -p` shows a prompt and waits for input, storing it in the named
variable — this is the mechanism behind any interactive script.

---

## 10. Control structures

### `if` / `elif` / `else`

```bash
if [[ "$dept" == "engineering" ]]; then
    echo "Manager: Arjun Mehta"
elif [[ "$dept" == "finance" ]]; then
    echo "Manager: Farhan Khan"
else
    echo "Unknown department"
fi
```

### `case`

Cleaner than a long `elif` chain when matching one value against many
possibilities — exactly how an onboarding tool might route an
`onboard` command vs. a `verify` command:

```bash
case "$operation" in
    onboard)
        onboard_user "$2" "$3"
        ;;
    verify)
        verify_user "$2"
        ;;
    *)
        echo "Unknown operation"
        exit 1
        ;;
esac
```
Each pattern ends with `;;`. The `*)` catch-all pattern matches
anything not matched above — always include one.

---

## 11. Loops

### `for` — iterate over a known list

```bash
for dept in "${DEPARTMENTS[@]}"; do
    echo "Processing: $dept"
done

for i in {1..5}; do
    echo "Number: $i"
done
```

### `while` — repeat as long as a condition holds

```bash
count=0
while (( count < 3 )); do
    echo "Attempt $count"
    ((count++))
done
```

Reading a file line by line — the standard idiom:

```bash
while read -r line; do
    echo "Line: $line"
done < some_file.txt
```

### `until` — repeat until a condition becomes true (inverse of `while`)

```bash
attempts=0
until (( attempts >= 3 )); do
    echo "Trying..."
    ((attempts++))
done
```

### `break` and `continue`

```bash
for dept in "${DEPARTMENTS[@]}"; do
    if [[ "$dept" == "finance" ]]; then
        continue    # skip this iteration, move to next
    fi
    if [[ "$dept" == "hr" ]]; then
        break        # exit the loop entirely
    fi
    echo "$dept"
done
```

---

## 12. Functions

```bash
function_name() {
    local param1="$1"
    local param2="$2"
    # body
    return 0
}
```
The `function` keyword is optional — `function_name() { ... }` and
`function function_name { ... }` both work; the first style is more
portable and the style used throughout this guide.

### Functions "return" exit codes, not values

This is a common point of confusion coming from other languages.
`return` in Bash sets the function's **exit status** (0–255), it does
not hand back arbitrary data:

```bash
validate_username() {
    local uname="$1"
    if [[ -z "$uname" ]]; then
        return 1     # failure
    fi
    return 0            # success
}

if validate_username "priya"; then
    echo "valid"
fi
```

To get an actual **value** out of a function (a string, a computed
result), use `echo` inside the function and capture it with command
substitution from the caller:

```bash
get_manager() {
    local dept="$1"
    case "$dept" in
        engineering) echo "Arjun Mehta" ;;
        finance)     echo "Farhan Khan" ;;
        hr)          echo "Priya Nair" ;;
        *)           echo "Unknown" ;;
    esac
}

manager=$(get_manager "engineering")
echo "$manager"    # Arjun Mehta
```

### Arguments inside a function are its own `$1`, `$2`, ...

Calling `onboard_user "$2" "$3"` from the main script passes the
**script's** `$2` and `$3` as the **function's own, separate** `$1`
and `$2`:

```bash
onboard_user() {
    local uname="$1"   # this is the function's $1, unrelated to the script's $1
    local dept="$2"
}
```

---

## 13. Positional parameters & script arguments

When you run:

```bash
./acme_it_admin.sh onboard priya engineering
```

Bash automatically populates these variables before the script starts:

| Variable | Value | Meaning |
|---|---|---|
| `$0` | `./acme_it_admin.sh` | the script's own name |
| `$1` | `onboard` | first argument |
| `$2` | `priya` | second argument |
| `$3` | `engineering` | third argument |
| `$#` | `3` | number of arguments |
| `$@` | `onboard priya engineering` | all arguments, each as a separate word (preferred) |
| `$*` | `onboard priya engineering` | all arguments as one single string |

`"$@"` vs `"$*"` matters when arguments contain spaces — `"$@"`
preserves them as separate items, `"$*"` merges everything into one.
Prefer `"$@"` unless you specifically want one merged string.

### `shift` — move the argument list left

```bash
echo "Before: $1 $2 $3"   # onboard priya engineering
shift
echo "After: $1 $2"        # priya engineering
```
Useful for scripts that process an unknown number of arguments one at
a time in a loop.

---

## 14. Exit codes and `$?`

Every command, script, and function returns a numeric **exit code**
when it finishes: `0` means success, any non-zero value (1–255) means
some kind of failure. Check the most recently finished command's exit
code with `$?`:

```bash
./acme_it_admin.sh onboard priya engineering
echo "Exit code was: $?"
```

A script controls its own final exit code with `exit N`:

```bash
if (( users_failed > 0 )); then
    exit 1
else
    exit 0
fi
```
This is what lets other scripts, cron jobs, or CI pipelines check
`echo $?` after calling your script and react accordingly — exit codes
are how scripts communicate success/failure to whatever called them,
the same way `validate_department`'s `return 0`/`return 1` communicates
to `onboard_user`.

---

## 15. File test operators

Used inside `[ ]` or `[[ ]]` to check things about files and paths:

| Operator | True when... |
|---|---|
| `-f path` | path exists and is a regular file |
| `-d path` | path exists and is a directory |
| `-e path` | path exists (any type) |
| `-x path` | path exists and is executable |
| `-r path` | path is readable |
| `-w path` | path is writable |
| `-s path` | path exists and is not empty |

```bash
if [ -f /etc/hostname ]; then
    echo "file exists"
fi

if [[ -d /srv/shared/engineering ]]; then
    echo "shared directory exists"
fi
```

---

## 16. Redirection & pipes

```bash
command > file.txt        # redirect stdout, OVERWRITE file
command >> file.txt        # redirect stdout, APPEND to file
command < file.txt           # use file.txt as stdin
command 2> errors.txt          # redirect stderr only
command > out.txt 2>&1          # redirect BOTH stdout and stderr to out.txt
command &> both.txt              # shorthand for the line above
command > /dev/null 2>&1          # discard all output entirely
```

This is exactly how a `log_message` function would work:

```bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date +'%H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}
```
`>>` ensures every call **adds** a line rather than wiping the log
file each time.

Pipes (`|`) send one command's stdout into another command's stdin:

```bash
getent passwd | wc -l           # count total users on the system
cat file.log | grep "ERROR"       # filter lines containing ERROR
```

---

## 17. Logical operators

```bash
command1 && command2     # run command2 ONLY IF command1 succeeded (exit 0)
command1 || command2       # run command2 ONLY IF command1 FAILED
! command                    # negate a condition
```

```bash
mkdir /tmp/test && echo "created successfully"
useradd testuser || echo "useradd failed"

if ! validate_department "$dept"; then
    echo "invalid department"
fi
```

Inside `[[ ]]`, use `&&` and `||` for combining conditions:

```bash
if [[ "$dept" == "engineering" ]] && [[ -n "$uname" ]]; then
    echo "both conditions true"
fi
```

---

## 18. Quoting rules

This causes more real-world bugs than any other topic in this guide.

```bash
NAME="Priya Nair"

echo $NAME        # WRONG in general — word-splits on the space,
                    # effectively becomes: echo Priya Nair (2 args to echo)
echo "$NAME"        # CORRECT — treated as one value: Priya Nair
```

The practical rule: **always double-quote variable expansions**
(`"$VAR"`, `"$1"`, `"${ARRAY[@]}"`) unless you specifically want word
splitting to happen. This is why a well-written function always
does this:

```bash
onboard_user() {
    local uname="$1"      # quoted, even though $1 is usually one word
    local dept="$2"
```

Single quotes vs. double quotes:

```bash
echo '$NAME'     # prints literally: $NAME  (single quotes block ALL expansion)
echo "$NAME"       # prints the value: Priya Nair (double quotes allow $ expansion)
```

---

## 19. `[ ]` vs `[[ ]]` vs `(( ))`

Three different bracket forms, each for a different job:

| Form | Used for | Notes |
|---|---|---|
| `[ ... ]` | Basic conditionals (POSIX-compatible) | Older, more portable, stricter quoting needed |
| `[[ ... ]]` | Conditionals (Bash-specific) | Safer with unquoted variables, supports `=~` regex, preferred in Bash scripts |
| `(( ... ))` | Arithmetic conditionals/operations | For numbers only: `((a > b))`, `((count++))` |

```bash
[ "$dept" == "engineering" ]        # works, but fragile if $dept is empty/unquoted
[[ "$dept" == "engineering" ]]        # preferred — handles edge cases better
[[ "$uname" =~ ^[a-zA-Z0-9_-]+$ ]]      # regex matching — ONLY works with [[ ]], not [ ]
(( count > 5 ))                          # numeric comparison
```

For new scripts written specifically for Bash (like this lab), prefer
`[[ ]]` for string/logical conditions and `(( ))` for numeric ones.

---

## 20. Common gotchas

**1. Spaces around `=` break assignment.**
```bash
NAME = "Priya"    # ERROR — looks like a command called NAME
NAME="Priya"        # correct
```

**2. Unquoted variables word-split and glob-expand.**
```bash
FILE="my file.txt"
rm $FILE       # tries to remove TWO files: "my" and "file.txt"
rm "$FILE"      # correctly removes the one file
```

**3. `[ ]` fails silently on empty/unset variables.**
```bash
if [ $DEPT == "engineering" ]; then     # breaks if $DEPT is empty/unset
if [[ "$DEPT" == "engineering" ]]; then   # safe either way
```

**4. Functions don't return computed values via `return`.**
```bash
get_total() {
    return $((5 + 3))    # WRONG for values > 255, and semantically confusing
}
# Use echo + command substitution instead, see Section 12
```

**5. `$(( ))` treats non-numeric strings as `0`, not an error.**
```bash
NAME="Priya"
echo $((NAME + 5))    # prints 5, silently — no warning that NAME isn't a number
```

**6. Forgetting `local` inside functions leaks variables globally.**
```bash
my_func() {
    dept="engineering"   # no 'local' — overwrites any existing $dept everywhere
}
```

**7. Colon vs. no colon in `${VAR:-default}` changes empty-string behavior**
(see Section 6) — `${VAR:-x}` treats `VAR=""` as unset; `${VAR-x}`
does not.

---

## 21. Quick syntax cheat-sheet

```bash
#!/bin/bash                             # shebang — always first line

# Variables
NAME="value"
readonly CONST=5
export ENV_VAR=5
local VAR="value"                        # only valid inside functions

# Arrays
ARR=(a b c)
declare -A MAP
MAP[key]="value"

# Parameter expansion
"${VAR:-default}"
"${VAR:=default}"
"${VAR:?error message}"
"${VAR:+alt}"

# Conditionals
if [[ condition ]]; then ... elif [[ condition ]]; then ... else ... fi
case "$var" in
    pattern1) ... ;;
    pattern2) ... ;;
    *) ... ;;
esac

# Loops
for x in "${ARR[@]}"; do ... done
for i in {1..5}; do ... done
while [[ condition ]]; do ... done
until [[ condition ]]; do ... done

# Functions
my_func() {
    local arg1="$1"
    return 0
}
result=$(my_func)     # capture echoed output, not the return code

# Positional parameters
$0 $1 $2 $# "$@" "$*"
shift

# Exit codes
exit 0        # success
exit 1          # failure
echo $?          # check last exit code

# File tests
[ -f path ]  [ -d path ]  [ -e path ]  [ -x path ]

# Redirection
cmd > file    cmd >> file    cmd 2> errfile    cmd &> both    cmd < input

# Logic
cmd1 && cmd2    cmd1 || cmd2    ! cmd

# Running the script
chmod +x script.sh
./script.sh arg1 arg2
sudo ./script.sh arg1 arg2
sudo -E ./script.sh arg1 arg2    # preserve exported env vars under sudo
```
