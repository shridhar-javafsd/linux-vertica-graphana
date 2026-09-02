# Day 5 — Vertica: Intro & Install

*Thu, 3 Sep 2026*

---

## 🔁 Recap: Day 4

You closed out Linux with networking basics, `ufw` (you already opened ports `3000` and `5433` — that wasn't random, it was for today and Day 8), `journalctl`, and a full WSL2/WSLg health check. Today, all of that groundwork gets used for real: you're installing an actual analytical database.

---

## 📚 Concepts

### What even is Vertica?

Vertica is a **columnar, massively parallel processing (MPP) analytical database.** Two ideas worth actually understanding, not just memorizing:

**Columnar, not row-based.** A traditional database (MySQL, PostgreSQL for typical use) stores data row-by-row on disk — great for "give me everything about customer #4521," bad for "give me the average of one column across 5 million rows" (it still has to read every row in full). Vertica stores data **column-by-column** instead — so a query that only touches `sale_amount` and `sale_date` only reads those two columns off disk, skipping everything else entirely. That's *why* Vertica is built for analytics/reporting, not for powering a live checkout page.

**MPP — massively parallel processing.** In a real production Vertica cluster, a single query gets split across many nodes, each crunching a slice of the data simultaneously. We're running a single-node setup for this course (one container, no real cluster), so you won't see the "massively parallel" part directly — but understanding *why* Vertica exists (fast aggregate queries over huge datasets) matters more than the cluster mechanics at this stage.

### Community Edition — and an honest note on how we're installing it

Vertica CE is normally installed as a native `.deb` package with a free license. As of this course, Vertica's official free self-service download has been unavailable — Vertica changed ownership from OpenText to Rocket Software earlier in 2026, and the free CE distribution path is still in flux (a licensing request is separately in progress, but we're not waiting on it).

**For this lab, we're using a practical workaround:** a community-maintained Docker image, `molo17/vertica-ce`, running inside Docker Desktop. This is **not an official Rocket Software image** — worth knowing, and worth remembering if this environment is ever considered for anything beyond this training. It comes pre-loaded with the **VMart** sample dataset (a fictional retail company's sales data) — exactly what we need for realistic SQL practice from Day 6 onward.

---

## 🧱 Part A: Install Docker Desktop

**🪟 On Windows** (not inside Ubuntu):

1. Download Docker Desktop: https://www.docker.com/products/docker-desktop/
2. Run the installer.
3. When asked, choose **WSL 2** as the backend (not Hyper-V).
4. Finish installation, restart Windows if prompted.
5. Open **Docker Desktop** from the Start menu and wait until it says it's running (the whale icon in your system tray stops animating).

### Configure the WSL2 engine + Ubuntu integration

**🪟 In Docker Desktop:**

1. Go to **Settings → General**, confirm **"Use the WSL 2 based engine"** is checked. Click **Apply & Restart** if you had to change it.
2. Go to **Settings → Resources → WSL Integration**.
3. Enable the toggle next to **Ubuntu**.
4. Click **Apply**.

This is the step that makes the `docker` command actually usable *inside* your Ubuntu terminal — without it, Docker only exists on the Windows side.

### Verify Docker from Ubuntu

Close and reopen your Ubuntu terminal, then:

**🐧 Run inside Ubuntu:**

```bash
docker --version
docker info
docker run hello-world
```

You should see `Hello from Docker!` in the output. If `docker: command not found` — go back and double check the WSL Integration toggle in Docker Desktop, then `wsl --shutdown` (PowerShell) and reopen Ubuntu.

---

## 🐳 Part B: Pull & run the Vertica CE container

**🐧 Run inside Ubuntu:**

```bash
docker pull molo17/vertica-ce:24.1.0-0
docker images | grep vertica
```

Create a persistent storage volume — this means your data survives even if the container itself gets removed and recreated:

```bash
docker volume create vertica-data
docker volume ls | grep vertica
```

Now start the container:

```bash
docker run -d \
  --name vertica-ce \
  -p 5433:5433 \
  -v vertica-data:/data \
  molo17/vertica-ce:24.1.0-0
```

What each flag means:

| Flag | Meaning |
|---|---|
| `-d` | detached — runs in the background |
| `--name vertica-ce` | a friendly name instead of a random container ID |
| `-p 5433:5433` | maps host port `5433` → container port `5433` (this is the port you already opened in `ufw` on Day 4) |
| `-v vertica-data:/data` | mounts the persistent volume into the container |

Confirm it's running:

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

Expected: `vertica-ce` with `0.0.0.0:5433->5433/tcp`.

Watch it finish starting up (Vertica takes a minute or two on first boot):

```bash
docker logs -f vertica-ce
```

Press `Ctrl+C` when you've seen enough — this only stops *watching* the logs, the container itself keeps running.

---

## 🔎 Part C: Connect and explore with `vsql`

`vsql` is Vertica's command-line SQL client — think of it as `psql` for Postgres, or `mysql` for MySQL, just Vertica's own version.

```bash
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```

You're now inside `vsql` — your prompt changes to `dbadmin=>`. Try:

```sql
SELECT version();
SELECT current_database();
```

**⚠️ Exiting `vsql`:** type `\q`, never `exit`. If your prompt ever shows `demo->` instead of `demo=>`, `vsql` thinks you're mid-statement — press `Ctrl+C`, then `\q`.

---

## 🗃️ Part D: Load the VMart sample dataset

The container ships with the VMart loader scripts, but the tables aren't loaded automatically. From Ubuntu (**not** inside `vsql` — exit first with `\q` if you're still in there):

```bash
docker exec -it vertica-ce ls -l /opt/vertica/examples/VMart_Schema
docker exec -it vertica-ce bash -lc 'cd /opt/vertica/examples/VMart_Schema && ./01_load_vmart_schema.sh'
```

This takes a few minutes — it drops any old schema, generates fresh sample data, creates tables, loads them, and runs ETL. When it finishes, you'll have a realistic retail dataset spanning 2003–2027: sales facts, customer/product/store dimensions, several million rows in the larger fact tables.

**Verify it worked:**

```bash
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```
```sql
SELECT table_schema, table_name
FROM v_catalog.tables
WHERE is_system_table = false
ORDER BY table_schema, table_name;
```

You should see tables like `store_sales_fact`, `customer_dimension`, `product_dimension`, and more.

---

## 🧪 Guided hands-on recap (do this together, start to finish)

**🐧 All inside Ubuntu, in order:**

```bash
docker --version
docker run hello-world
docker pull molo17/vertica-ce:24.1.0-0
docker volume create vertica-data
docker run -d --name vertica-ce -p 5433:5433 -v vertica-data:/data molo17/vertica-ce:24.1.0-0
docker ps --format "table {{.Names}}\t{{.Ports}}"
docker logs -f vertica-ce
# Ctrl+C once startup looks done
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```
```sql
SELECT version();
\q
```
```bash
docker exec -it vertica-ce bash -lc 'cd /opt/vertica/examples/VMart_Schema && ./01_load_vmart_schema.sh'
```

---

## 🔬 Lab — on your own

1. Confirm your container is running and healthy: `docker ps`, note the exact `PORTS` output and compare it against your neighbor's — it should match.
2. Connect via `vsql` and run:
   ```sql
   SELECT current_database();
   SELECT version();
   ```
   Write down the exact version string you get.
3. List every table across every schema (reuse the `v_catalog.tables` query from Part D — notice it has no schema filter, so it'll show you tables from both `public` and `store` together). Count how many tables you see, and note which schema each one belongs to.
4. Run this row-count check on the two biggest fact tables:
   ```sql
   SELECT COUNT(*) FROM store_sales_fact;
   SELECT COUNT(*) FROM online_sales_fact;
   ```
   Both should return **5,000,000**. If either is far off (or zero), the VMart load didn't complete — re-run the loader script from Part D.
5. From your Ubuntu terminal (not `vsql`), confirm the port is genuinely reachable using the networking skills from Day 4:
   ```bash
   ss -tulpn | grep 5433
   ```
6. **Bonus — stop/start discipline:** practice the exact skill you'll rely on every morning going forward:
   ```bash
   docker stop vertica-ce
   docker ps -a          # notice it still LISTS, just not running
   docker start vertica-ce
   docker ps               # now it's back
   ```

---

## 📎 Copy-paste command reference — Day 5

```bash
# --- Docker verification ---
docker --version
docker info
docker run hello-world

# --- Pull & prep Vertica ---
docker pull molo17/vertica-ce:24.1.0-0
docker images | grep vertica
docker volume create vertica-data
docker volume ls | grep vertica

# --- Run the container ---
docker run -d \
  --name vertica-ce \
  -p 5433:5433 \
  -v vertica-data:/data \
  molo17/vertica-ce:24.1.0-0

docker ps --format "table {{.Names}}\t{{.Ports}}"
docker logs -f vertica-ce         # Ctrl+C to stop watching (container keeps running)

# --- Connect via vsql ---
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
#   SELECT version();
#   SELECT current_database();
#   \q       <-- always use \q, never "exit"

# --- Load VMart sample data ---
docker exec -it vertica-ce ls -l /opt/vertica/examples/VMart_Schema
docker exec -it vertica-ce bash -lc 'cd /opt/vertica/examples/VMart_Schema && ./01_load_vmart_schema.sh'

# --- Verify VMart loaded ---
# (inside vsql)
# SELECT table_schema, table_name FROM v_catalog.tables WHERE is_system_table = false ORDER BY 1,2;
# SELECT COUNT(*) FROM store_sales_fact;   -- expect 5,000,000

# --- Daily start/stop discipline ---
docker stop vertica-ce
docker start vertica-ce
docker ps
```

---

## 👀 Tomorrow: Day 6 — Vertica: SQL Fundamentals

You've got a live database full of real-looking retail data. Tomorrow you write actual SQL against it — `SELECT`, `WHERE`, `JOIN`, `GROUP BY` — both via `vsql` on the command line and DBeaver's GUI, which we'll install first thing.
