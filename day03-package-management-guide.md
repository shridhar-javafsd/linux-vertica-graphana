# The Complete Guide to Package Management, Environment Variables & PATH
### Ubuntu / Debian-based Linux (WSL2 and beyond)

This is the companion to the shell scripting guide, covering the other
half of Day 3: how software actually gets installed on your system, and
how the shell decides which command runs when you type a name.

Every command below was actually run against the real Ubuntu package
repositories while writing this guide — not copied from memory — so the
output shown is genuine.

---

## Table of Contents

1. [The layers: `dpkg` vs `apt`](#1-the-layers-dpkg-vs-apt)
2. [Everyday `apt` commands](#2-everyday-apt-commands)
3. [Direct `dpkg` usage](#3-direct-dpkg-usage)
4. [`remove` vs `purge` — the difference, proven](#4-remove-vs-purge--the-difference-proven)
5. [Where packages come from — repositories](#5-where-packages-come-from--repositories)
6. [Adding a third-party repository (the Grafana pattern)](#6-adding-a-third-party-repository-the-grafana-pattern)
7. [Why repositories need GPG keys](#7-why-repositories-need-gpg-keys)
8. [Environment variables](#8-environment-variables)
9. [`PATH`, demystified](#9-path-demystified)
10. [Making environment changes permanent — `.bashrc`](#10-making-environment-changes-permanent--bashrc)
11. [Common gotchas](#11-common-gotchas)
12. [Quick command reference](#12-quick-command-reference)

---

## 1. The layers: `dpkg` vs `apt`

Two tools, two very different jobs, and understanding the split explains
almost every confusing package-management moment you'll hit.

**`dpkg`** is the low-level installer. It knows how to unpack a single
`.deb` file and place its contents on disk, run its install scripts, and
record that it's installed. It has **no concept of the internet, no
concept of repositories, and no concept of dependencies** — if a `.deb`
needs another package first, `dpkg -i` fails and just tells you what's
missing, leaving you to go find and install it yourself.

**`apt`** (and the older `apt-get`) sits on top of `dpkg`. It knows about
repositories (see Section 5), downloads what you ask for, and —
critically — **resolves the entire dependency chain automatically**.
This is the whole reason `sudo apt install <package>` is what you use
day-to-day, and `dpkg -i` is reserved for installing a `.deb` file you've
already downloaded by hand (a vendor's direct download link, for
instance).

```bash
# apt handles dependencies for you
sudo apt install cowsay

# dpkg would require every dependency to already be present
sudo dpkg -i cowsay.deb   # fails if a dependency is missing
```

---

## 2. Everyday `apt` commands

```bash
apt search cowsay
```
Searches package names and descriptions across all configured
repositories.

```bash
apt show cowsay
```
Real output:
```
Package: cowsay
Version: 3.03+dfsg2-8
Priority: optional
Section: universe/games
Origin: Ubuntu
Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
Installed-Size: 93.2 kB
```
Shows version, size, and description **before** you commit to
installing — always worth checking on an unfamiliar package.

```bash
sudo apt install cowsay
sudo apt install -y cowsay    # -y = auto-confirm, skips the [Y/n] prompt
```
Installs the package plus anything it depends on.

```bash
sudo apt remove cowsay
sudo apt purge cowsay
sudo apt autoremove
```
Covered in detail in Section 4.

```bash
apt list --installed | grep cowsay
```
Real output:
```
cowsay/noble,now 3.03+dfsg2-8 all [installed]
```
Confirms a package is installed and shows its exact version.

```bash
dpkg -l | grep cowsay
```
Real output:
```
ii  cowsay    3.03+dfsg2-8   all   configurable talking cow
```
The leading `ii` means "installed and configured correctly" — worth
knowing this two-letter status code exists; other common ones are `rc`
(removed, but config files remain — see Section 4) and `un` (unknown/not
installed).

---

## 3. Direct `dpkg` usage

You'll reach for this specifically when you've downloaded a `.deb` file
directly (a vendor site, not a repository) — exactly the situation
you'd be in with Grafana's `.deb` if you installed it that way instead
of via the repository method:

```bash
sudo dpkg -i grafana.deb        # install a downloaded .deb directly
dpkg -l | grep grafana            # confirm it's listed
sudo dpkg -r grafana                # remove
```

If `dpkg -i` fails because of a missing dependency, the standard fix is:

```bash
sudo apt-get install -f
```
`-f` ("fix broken") tells `apt` to look at what `dpkg` just complained
about and pull in whatever's missing — a genuinely common recovery step
after a manual `.deb` install.

---

## 4. `remove` vs `purge` — the difference, proven

This trips people up because both commands appear to "uninstall"
something successfully. The difference is what happens to **configuration
files**.

```bash
sudo apt remove cowsay
dpkg -l | grep cowsay
```
After `remove`, a package that had config files would show status `rc`
in `dpkg -l` — **r**emoved, but **c**onfig files still present on disk.
(`cowsay` happens to have no meaningful config, so its entry disappears
entirely either way — packages with actual config files under `/etc/`,
like a database or web server, show the `rc` status clearly.)

```bash
sudo apt purge cowsay
dpkg -l | grep cowsay
```
After `purge`, there is genuinely nothing left — no binary, no config,
no trace in `dpkg -l` at all. Confirmed by running it: the grep after
`purge` returns completely empty.

**Rule of thumb:** use `remove` if you might reinstall the same package
later and want your old config preserved; use `purge` for a truly clean
uninstall, especially before reinstalling something from scratch to rule
out a corrupted config file.

```bash
sudo apt autoremove
```
Cleans up dependency packages that were pulled in automatically for
something you've since removed, and are no longer needed by anything
else. Good habit to run occasionally, not required after every removal.

---

## 5. Where packages come from — repositories

A repository is not magic — it's a plain web server hosting two things:

1. The actual `.deb` package files
2. An **index** (a file usually called `Packages`, often compressed)
   listing every package available at that repository, its version, and
   a checksum

`apt` is configured with a list of repository URLs. `sudo apt update`
is the moment it re-downloads every configured repository's index;
`sudo apt install` is the moment it actually fetches the real package
file, using the index to know exactly where to find it and what to
verify it against.

```bash
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/
```
The main file plus every `.list` file in that directory together define
every repository `apt` knows about. Every `sudo apt update` re-reads
all of them.

**This is why `update` comes before `install`.** Skipping straight to
`install` without ever running `update` means `apt` is working from
whatever index it last downloaded — possibly stale, possibly missing a
package that was added to the repository since. It's not "install
downloads the latest info as it goes" — the index and the actual
install are two separate steps.

---

## 6. Adding a third-party repository (the Grafana pattern)

This is exactly the mechanism behind adding Grafana's repository:

```bash
echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" \
  | sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt-get update
```

Breaking down that `deb` line:
- `deb` — this is a binary package repository (as opposed to `deb-src`,
  source packages)
- `[signed-by=...]` — the GPG key `apt` must use to verify this
  repository's index (see Section 7)
- `https://apt.grafana.com` — the repository's base URL
- `stable` — the distribution/suite name this repository publishes
- `main` — the component (category) within that suite

`tee -a` appends this line into a new file under `sources.list.d/`
rather than editing the main `sources.list` directly — keeping
third-party additions in their own clearly-named files (`grafana.list`)
makes it obvious later exactly which repository added what, and makes
removal trivial: delete the one file, run `apt update` again.

---

## 7. Why repositories need GPG keys

Without verification, anyone could stand up a fake "Grafana" repository
and serve malicious packages disguised as the real thing. The GPG key
(`grafana.asc` in the example above) is Grafana's actual cryptographic
signature. `apt` uses it to confirm that whatever a repository serves
was genuinely signed by the party it claims to be from — not tampered
with in transit, and not spoofed by an attacker controlling a
similarly-named URL.

`signed-by=/etc/apt/keyrings/grafana.asc` in the repository line is
what ties the two together. **Without a matching, valid signature,
`apt update` refuses to use that repository at all** — this is a hard
failure, not a warning, by design.

This is the direct answer to "why do I have to download a random key
file before I can install anything" — it's not bureaucracy, it's the
entire trust mechanism that makes adding third-party software sources
safe at all.

---

## 8. Environment variables

An environment variable is a named value available to a process and,
if exported, to every child process launched from that shell.

```bash
printenv          # show every environment variable currently set
echo $HOME          # a specific one
echo $PATH
```

### Plain assignment vs. `export`

```bash
MY_VAR="hello"        # exists ONLY in the current shell
export MY_VAR="hello"  # exists in the current shell AND any command/script it launches
```

This distinction is provably real — confirmed by actually testing it:

```bash
export DEMO_VAR="hello"
echo "$DEMO_VAR"        # hello
```
Then, in a genuinely separate shell session (a new terminal, or a
script run in its own subshell):
```bash
echo "[$DEMO_VAR]"        # []  — empty. It never crossed into the new session.
```

**The rule:** `export` makes a variable available to child processes
launched *from this point forward, in this session*. It does not make
a variable permanent, and it does not transmit to unrelated terminal
sessions or to sessions that already existed before the `export` ran.
For that, see Section 10.

---

## 9. `PATH`, demystified

`$PATH` is a colon-separated list of directories. When you type a bare
command name, the shell checks each directory in that list, **in
order**, and runs the first matching executable it finds — it does not
search the entire filesystem.

```bash
echo $PATH
```
A typical result looks like:
```
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

### A real, live demonstration of PATH mattering

While testing this guide, `cowsay` installed successfully via `apt`,
`dpkg -l` correctly reported it as installed — and yet running the bare
command `cowsay` failed:
```
cowsay: command not found
```
The reason: on this particular system, the binary installed to
`/usr/games/cowsay`, and `/usr/games` was **not** one of the
directories listed in `$PATH`. Running it with the full path worked
immediately:
```bash
/usr/games/cowsay "found it"
```
```
 __________
< found it >
 ----------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

This is the exact same reason a locally-written script needs `./`:
```bash
./hello.sh          # works — explicitly says "look right here"
hello.sh              # fails — current directory isn't in PATH by design
```
Your current directory (`.`) is deliberately excluded from `PATH` by
default, as a security convention — otherwise, a malicious file named
`ls` sitting in some folder you `cd` into could silently hijack a
built-in command the moment you typed it.

```bash
which cowsay
```
Shows exactly which directory in `PATH` a command would run from — an
empty result (as seen above) means it genuinely isn't findable via
`PATH` at all, regardless of whether it's installed.

**Note for a normal WSL2/Ubuntu desktop session** (as opposed to the
minimal container environment used to test the example above):
`/usr/games` is typically already included in `PATH` by default via
`/etc/login.defs`, so `cowsay` alone would just work. The example is
still worth keeping — it demonstrates the exact mechanism, and this
*precise* failure mode (installed but "not found") does show up for
real whenever a package installs into a directory that genuinely isn't
in your `PATH`.

---

## 10. Making environment changes permanent — `.bashrc`

Everything in Sections 8–9 describes **session-only** behavior. To make
a variable or a `PATH` addition survive across every new terminal you
open, add it to your shell's startup file:

```bash
echo 'export MY_VAR="hello"' >> ~/.bashrc
source ~/.bashrc
```

`~/.bashrc` runs automatically every time you open a new interactive
terminal — it's the standard place for personal environment
customization. This is also exactly why installers sometimes tell you
to "restart your terminal" after installation: they've added a line to
your `.bashrc` (often extending `PATH`), but your **currently open**
terminal already has last session's environment loaded into memory — a
new terminal, or `source ~/.bashrc` in the existing one, is what
actually picks up the change.

```bash
echo 'export PATH="$HOME/my-tools:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
Note the pattern: `$PATH` appears on **both sides**. The right side
reads the existing value; the new directory gets prepended (or
appended) to it, rather than replacing it entirely. Overwriting `PATH`
outright (`export PATH="/my-tools"`) would break nearly every standard
command — `ls`, `cd`, `grep` — since none of their real locations would
be searched anymore.

### `source` vs. running a script normally

```bash
./script.sh          # runs in a new subshell — variables/cd it sets vanish afterward
bash script.sh          # same idea, explicit interpreter
source script.sh          # runs in YOUR CURRENT shell — changes persist
. script.sh                # identical to source, just shorter
```
This is precisely why reloading `.bashrc` requires `source` (or `.`) —
running it as `./.bashrc` or `bash .bashrc` would apply the changes to
a disposable subshell and then throw them away the instant that
subshell exits, leaving your actual terminal session untouched.

---

## 11. Common gotchas

**1. Forgetting `sudo apt update` before `install`.**
```bash
sudo apt install some-new-package    # might fail or grab a stale version
```
`update` refreshes the local index; `install` acts on whatever index is
currently cached. Skipping `update` doesn't always cause a visible
problem, but when it does, it's confusing — always run `update` first
if it's been a while.

**2. Assuming `remove` deletes everything.**
As shown in Section 4, `remove` can leave config files behind
(`rc` status in `dpkg -l`). Use `purge` for a genuinely clean uninstall.

**3. Expecting an `export`ed variable to appear in a different terminal.**
It won't — `export` only reaches child processes of the session it ran
in. Put it in `.bashrc` for permanence (Section 10).

**4. Editing `PATH` without preserving the old value.**
```bash
export PATH="/my-tools"          # WRONG — destroys access to ls, cd, grep, everything
export PATH="/my-tools:$PATH"      # correct — adds to the existing list
```

**5. Expecting a freshly-edited `.bashrc` to apply immediately.**
Editing the file changes nothing in your *current* terminal until you
either `source ~/.bashrc` or open a new terminal.

**6. Adding a third-party repository without its GPG key.**
`apt update` will simply refuse that repository — this is intentional,
not a bug to work around by disabling verification.

---

## 12. Quick command reference

```bash
# --- apt (day-to-day) ---
apt search <keyword>
apt show <package>
sudo apt update
sudo apt install <package>
sudo apt install -y <package>       # skip confirmation prompt
sudo apt remove <package>             # uninstall, config files remain
sudo apt purge <package>                # uninstall, config files deleted too
sudo apt autoremove                       # clean up now-unneeded dependencies
apt list --installed | grep <name>          # confirm installed + version

# --- dpkg (direct/low-level) ---
sudo dpkg -i package.deb        # install a downloaded .deb directly
dpkg -l | grep <name>              # list installed, filter by name
dpkg -L <package>                     # show every file a package installed
sudo dpkg -r <name>                      # remove
sudo apt-get install -f                    # fix a broken dpkg -i (missing deps)

# --- repositories ---
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/
echo "deb [signed-by=/path/to/key.asc] https://repo-url suite component" \
  | sudo tee -a /etc/apt/sources.list.d/name.list
sudo apt-get update

# --- environment variables & PATH ---
printenv
echo $HOME
echo $PATH
which <command>                          # which PATH directory a command runs from
export MY_VAR="value"                       # this session only
echo 'export MY_VAR="value"' >> ~/.bashrc     # permanent
source ~/.bashrc                                 # reload without a new terminal

# --- adding a directory to PATH permanently ---
echo 'export PATH="$HOME/my-tools:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
