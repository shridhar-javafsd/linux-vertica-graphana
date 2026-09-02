# 🚀 Installation Guide: Windows 11 → WSL2 → Docker Desktop → Vertica → DBeaver → Grafana

> **Goal:** Start with a fresh Windows 11 PC and build the exact training environment used for the Vertica → Grafana lab.
>
> **Style:** Copy, paste, verify, move on. No wizardry required. 😎
>
> **End result:**
>
> ```text
> Windows 11
> │
> ├── WSL2
> │   └── Ubuntu
> │       └── Grafana
> │
> ├── Docker Desktop
> │   └── WSL2 backend
> │       └── Vertica CE container
> │           └── demo database
> │               └── VMart sample data
> │
> └── DBeaver Community
>     └── connects to Vertica on localhost:5433
> ```
>
> The final application flow will be:
>
> ```text
> DBeaver ───────────────┐
>                        │
>                        ▼
>                    Vertica
>                        ▲
>                        │
> Grafana ───────────────┘
> ```
>
> Grafana will run inside Ubuntu/WSL2. Vertica will run inside Docker Desktop's Linux/WSL2 environment. DBeaver will run natively on Windows.

---

# 0. 🧭 What You Are Installing

We will install these pieces in this order:

```text
1. Windows 11 prerequisites
2. WSL2
3. Ubuntu on WSL2
4. Docker Desktop
5. Docker ↔ Ubuntu WSL integration
6. Vertica CE Docker image
7. Vertica CE container
8. DBeaver Community on Windows
9. Grafana on Ubuntu/WSL2
10. Grafana Vertica datasource plugin
11. Connectivity checks
```

**Do not install Docker Engine separately inside Ubuntu.**

Docker Desktop provides the Docker engine, and WSL Integration makes the `docker` command available inside Ubuntu. Docker explicitly recommends this WSL2 integration approach. 

Official references:

- Microsoft WSL: https://learn.microsoft.com/en-us/windows/wsl/install
- Docker Desktop for Windows: https://docs.docker.com/desktop/setup/install/windows-install/
- Docker WSL2 backend: https://docs.docker.com/desktop/features/wsl/
- DBeaver Community: https://dbeaver.io/download/
- Grafana Ubuntu/Debian installation: https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/

---

# PART 1 — 🪟 Windows 11 Preparation

## 1.1 Check that you are on Windows 11

Press:

```text
Win + R
```

Type:

```text
winver
```

Press Enter.

You should see Windows 11.

---

## 1.2 Make sure virtualization is enabled

WSL2 and Docker Desktop need hardware virtualization.

Open:

```text
Task Manager
```

Go to:

```text
Performance → CPU
```

Look for:

```text
Virtualization: Enabled
```

If it says:

```text
Disabled
```

you may need to enable Intel VT-x / AMD-V / SVM in the PC's BIOS/UEFI.

> If Windows and WSL2 are already working, don't touch BIOS settings. You're good.

---

# PART 2 — 🐧 Install WSL2 + Ubuntu

Microsoft's current WSL installer can install WSL and Ubuntu using one PowerShell command. 

## 2.1 Open PowerShell as Administrator

Start menu:

```text
Start
→ search "PowerShell"
→ right-click Windows PowerShell / PowerShell
→ Run as administrator
```

---

## 2.2 Install WSL

Run:

```powershell
wsl --install
```

If prompted to restart:

```text
Restart Windows.
```

After reboot, Ubuntu may open automatically.

Create your Linux username and password.

Example:

```text
Enter new UNIX username:
vaman

New password:
********

Retype new password:
********
```

> The Linux password is separate from your Windows password.

---

## 2.3 If you specifically want Ubuntu

If `wsl --install` doesn't install Ubuntu automatically, run:

```powershell
wsl --list --online
```

Look for:

```text
Ubuntu
```

Then:

```powershell
wsl --install -d Ubuntu
```

If the installation appears stuck at 0%, Microsoft documents:

```powershell
wsl --install --web-download -d Ubuntu
```

---

## 2.4 Make WSL2 the default

In Administrator PowerShell:

```powershell
wsl --set-default-version 2
```

---

## 2.5 Check WSL

Run:

```powershell
wsl --status
```

Then:

```powershell
wsl --list --verbose
```

Expected:

```text
NAME      STATE    VERSION
Ubuntu    Running  2
```

The important number is:

```text
VERSION 2
```

---

## 2.6 Update WSL

Run from Administrator PowerShell:

```powershell
wsl --update
```

Then:

```powershell
wsl --version
```

---

## 2.7 Start Ubuntu

From Start menu:

```text
Ubuntu
```

Or from PowerShell:

```powershell
wsl
```

You should get a Linux prompt similar to:

```text
vaman@PCNAME:~$
```

From this point onward, when the guide says:

```text
Ubuntu terminal
```

use this terminal.

---

# PART 3 — 🐳 Install Docker Desktop

## 3.1 Download Docker Desktop

Official download:

https://www.docker.com/products/docker-desktop/

Official Windows installation documentation:

https://docs.docker.com/desktop/setup/install/windows-install/

Docker Desktop supports WSL2 on Windows and recommends the WSL2 backend for the typical Windows setup. 

---

## 3.2 Install Docker Desktop

Run:

```text
Docker Desktop Installer.exe
```

During installation, select the option to use:

```text
WSL 2
```

rather than Hyper-V if the installer asks.

Finish the installation.

Restart Windows if requested.

---

# PART 4 — 🔌 Configure Docker Desktop + WSL2

This part is important.

We want:

```text
Ubuntu
   │
   │ docker command
   ▼
Docker Desktop
   │
   ▼
Docker Engine
```

Docker Desktop documents this as **WSL Integration**. 

---

## 4.1 Start Docker Desktop

Open:

```text
Docker Desktop
```

Wait until Docker says it is running.

---

## 4.2 Check the Docker engine mode

Open:

```text
Docker Desktop
→ Settings
→ General
```

Make sure:

```text
Use the WSL 2 based engine
```

is enabled.

Click:

```text
Apply & Restart
```

---

## 4.3 Enable Ubuntu integration

Go to:

```text
Docker Desktop
→ Settings
→ Resources
→ WSL Integration
```

You should see your Ubuntu distribution.

Enable:

```text
Ubuntu
```

Click:

```text
Apply
```

Docker's documentation notes that enabling WSL integration gives the selected Linux distribution direct access to Docker commands. 

---

## 4.4 Verify Docker from Ubuntu

Close and reopen Ubuntu.

Run:

```bash
docker --version
```

Then:

```bash
docker info
```

You should get Docker information rather than:

```text
command not found
```

---

## 4.5 Test Docker

Run:

```bash
docker run hello-world
```

You should see:

```text
Hello from Docker!
```

🎉

At this point:

```text
Windows
  ↓
Docker Desktop
  ↓
WSL2
  ↓
Ubuntu
  ↓
docker command
```

is working.

---

# PART 5 — 🧱 Install Vertica CE Using the Docker Workaround

## 5.1 Important background

For this training lab, we use:

```text
molo17/vertica-ce
```

Docker Hub:

https://hub.docker.com/r/molo17/vertica-ce

The specific image used in this lab is:

```text
molo17/vertica-ce:24.1.0-0
```

Docker Hub currently lists this image as Linux/amd64 and exposes Vertica's port 5433. 

The image also contains the VMart example files used later in this training lab.

> **Important:** This is a third-party Docker Hub image. It is being used as the practical training workaround for this lab. It is not an official Rocket Software Docker image.

The image metadata includes:

```text
VERTICA_DB_NAME=demo
VERTICA_DB_PASSWORD=password
VMART_DIR=/opt/vertica/examples/VMart_Schema
```

and exposes:

```text
5433/tcp
```

---

## 5.2 Pull the Vertica image

From Ubuntu:

```bash
docker pull molo17/vertica-ce:24.1.0-0
```

Wait for the download to finish.

---

## 5.3 Verify the image

Run:

```bash
docker images | grep vertica
```

You should see something similar to:

```text
molo17/vertica-ce    24.1.0-0
```

---

# PART 6 — ▶️ Create the Vertica Container

## 6.1 Create a Docker volume

This gives Vertica persistent storage:

```bash
docker volume create vertica-data
```

Verify:

```bash
docker volume ls | grep vertica
```

Expected:

```text
vertica-data
```

---

## 6.2 Start Vertica

Run:

```bash
docker run -d \
  --name vertica-ce \
  -p 5433:5433 \
  -v vertica-data:/data \
  molo17/vertica-ce:24.1.0-0
```

This means:

```text
--name vertica-ce
```

Container name:

```text
vertica-ce
```

```text
-p 5433:5433
```

Windows/host port 5433 → container port 5433

```text
-v vertica-data:/data
```

Persistent Vertica data volume

---

## 6.3 Check the container

Run:

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

Expected:

```text
NAMES        PORTS
vertica-ce   0.0.0.0:5433->5433/tcp
```

---

## 6.4 Watch Vertica startup

Run:

```bash
docker logs -f vertica-ce
```

Let it start.

When you have seen enough startup information, press:

```text
Ctrl+C
```

This stops viewing the logs.

It does NOT stop the container.

---

# PART 7 — 🔎 Test Vertica

## 7.1 Open vsql

Run:

```bash
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```

You should see:

```text
Welcome to the vsql terminal.
```

Prompt:

```text
dbadmin@...=>
```

---

## 7.2 Check Vertica version

Inside `vsql`:

```sql
SELECT version();
```

Expected for this lab:

```text
Vertica Analytic Database v24.1.0-0
```

---

## 7.3 Check database

```sql
SELECT current_database();
```

Expected:

```text
demo
```

---

## 7.4 Exit vsql

Use:

```text
\q
```

### ⚠️ Important

Do NOT type:

```text
exit
```

inside `vsql`.

Use:

```text
\q
```

If you see:

```text
demo->
```

you are in a multi-line SQL statement.

Press:

```text
Ctrl+C
```

then:

```text
\q
```

---

# PART 8 — 🗃️ Load the VMart Sample Database

At this stage Vertica is running, but the `demo` database may not yet contain the VMart tables.

---

## 8.1 Check the VMart files

Run:

```bash
docker exec -it vertica-ce ls -l /opt/vertica/examples
```

You should see:

```text
VMart_Schema
```

Now:

```bash
docker exec -it vertica-ce ls -l /opt/vertica/examples/VMart_Schema
```

You should see files such as:

```text
01_load_vmart_schema.sh
02_vmart_etl.sql
vmart_define_schema.sql
vmart_load_data.sql
vmart_count_data.sql
vmart_queries.sql
vmart_gen
```

---

## 8.2 Check the VMart README

```bash
docker exec -it vertica-ce cat /opt/vertica/examples/VMart_Schema/README
```

The supplied VMart generator is:

```text
vmart_gen
```

---

## 8.3 Verify the loader environment

Run:

```bash
docker exec -it vertica-ce bash -lc 'echo "VERTICA_DB_USER=$VERTICA_DB_USER"; echo "VMART_DIR=$VMART_DIR"; echo "VMART_ETL_SQL=$VMART_ETL_SQL"; echo "VMART_CONFIRM_LOAD_SCHEMA=$VMART_CONFIRM_LOAD_SCHEMA"; echo "VMART_CONFIRM_LOAD_TABLE=$VMART_CONFIRM_LOAD_TABLE"'
```

Expected:

```text
VERTICA_DB_USER=dbadmin
VMART_DIR=/opt/vertica/examples/VMart_Schema
VMART_ETL_SQL=02_vmart_etl.sql
VMART_CONFIRM_LOAD_SCHEMA=public
VMART_CONFIRM_LOAD_TABLE=vmart_load_success
```

---

## 8.4 Verify the loader's database

Run:

```bash
docker exec -it vertica-ce bash -lc '/opt/vertica/bin/vsql -U dbadmin -Atc "SELECT current_database();"'
```

Expected:

```text
demo
```

---

## 8.5 Load VMart

Run:

```bash
docker exec -it vertica-ce bash -lc 'cd /opt/vertica/examples/VMart_Schema && ./01_load_vmart_schema.sh'
```

This can take a while.

The process is:

```text
Drop old VMart schema
        ↓
Generate data
        ↓
Create schema
        ↓
Load data
        ↓
Run ETL
        ↓
Confirm successful load
```

In the lab setup used for this training, the generator produced:

```text
store_sales_fact        5,000,000
online_sales_fact       5,000,000
store_orders_fact         300,000
inventory_fact            300,000
customer_dimension         50,000
employee_dimension        10,000
product_dimension            500
store_dimension               50
promotion_dimension          100
vendor_dimension              50
warehouse_dimension          100
shipping_dimension           100
online_page_dimension      1,000
call_center_dimension        200
```

The data covers:

```text
2003 → 2027
```

---

# PART 9 — ✅ Verify VMart

Open `vsql`:

```bash
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```

Run:

```sql
SELECT table_schema, table_name
FROM v_catalog.tables
WHERE is_system_table = false
ORDER BY table_schema, table_name;
```

You should see VMart tables such as:

```text
online_sales | online_sales_fact
public       | customer_dimension
public       | date_dimension
public       | employee_dimension
public       | inventory_fact
public       | product_dimension
public       | promotion_dimension
public       | shipping_dimension
public       | vendor_dimension
public       | warehouse_dimension
store        | store_dimension
store        | store_orders_fact
store        | store_sales_fact
```

---

## 9.1 Verify actual sales data

Run:

```sql
SELECT
    COUNT(*) AS number_of_sales,
    SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact;
```

In this lab the result was:

```text
number_of_sales | total_sales
----------------+------------
5000000         | 1363723977
```

This is the first big "YES, it works" checkpoint.

---

# PART 10 — 🖥️ Install DBeaver Community on Windows

DBeaver Community is the GUI database tool used in this lab.

Official download:

https://dbeaver.io/download/

The current DBeaver Community download page provides a Windows installer. DBeaver's Windows installer includes its required Java runtime, so a separate Java installation is normally not required. 

---

## 10.1 Download

Open:

https://dbeaver.io/download/

Select:

```text
Community
→ Windows
→ x86
→ EXE
```

---

## 10.2 Install

Run the downloaded `.exe`.

Follow the installer.

Recommended:

```text
Standard installation
```

Finish.

---

# PART 11 — 🔌 Connect DBeaver to Vertica

Start:

```text
DBeaver
```

---

## 11.1 Create connection

Click:

```text
Database
→ New Database Connection
```

Or click the new connection icon.

Search for:

```text
Vertica
```

Select Vertica.

DBeaver supports Vertica and uses JDBC drivers for database connections. 

---

## 11.2 Enter connection details

Use:

```text
Host:
localhost

Port:
5433

Database:
demo

Username:
dbadmin

Password:
password
```

> If you started your container with a different Vertica password, use that password instead.

The connection should effectively be:

```text
localhost:5433
```

---

## 11.3 Download the JDBC driver if DBeaver asks

DBeaver may show a dialog such as:

```text
Download driver files
```

Click:

```text
Download
```

Let DBeaver download the required driver.

If DBeaver cannot download the driver automatically, use the Vertica JDBC documentation:

https://docs.vertica.com/24.1.x/en/connecting-to/client-libraries/client-drivers/install-config/jdbc/

DBeaver also provides a Driver Manager for manually adding JDBC `.jar` files if necessary.

---

## 11.4 Test connection

Click:

```text
Test Connection
```

You want:

```text
Connected
```

Then:

```text
Finish
```

---

## 11.5 Browse Vertica

In DBeaver's left panel:

```text
Vertica connection
→ demo
→ Schemas
→ public
```

You should eventually see tables such as:

```text
customer_dimension
date_dimension
product_dimension
...
```

and:

```text
store
    store_dimension
    store_sales_fact
```

---

# PART 12 — 🧪 Test Vertica from DBeaver

Open a SQL editor for the Vertica connection.

Run:

```sql
SELECT
    COUNT(*) AS number_of_sales,
    SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact;
```

Expected:

```text
5000000 | 1363723977
```

Now DBeaver is successfully talking to:

```text
Docker → Vertica
```

---

# PART 13 — 📊 Install Grafana in Ubuntu/WSL2

Grafana will run **inside Ubuntu**, not inside Docker.

Official Grafana Ubuntu/Debian documentation:

https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/

We will use the Grafana APT repository.

---

## 13.1 Open Ubuntu

Start:

```text
Ubuntu
```

---

## 13.2 Update packages

```bash
sudo apt-get update
```

Then:

```bash
sudo apt-get upgrade -y
```

---

## 13.3 Install Grafana prerequisites

```bash
sudo apt-get install -y apt-transport-https wget gnupg
```

---

## 13.4 Add Grafana signing key

```bash
sudo mkdir -p /etc/apt/keyrings
```

```bash
sudo wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
```

```bash
sudo chmod 644 /etc/apt/keyrings/grafana.asc
```

---

## 13.5 Add the Grafana stable repository

```bash
echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
```

---

## 13.6 Update APT

```bash
sudo apt-get update
```

---

## 13.7 Install Grafana OSS

```bash
sudo apt-get install -y grafana
```

The official Grafana documentation currently lists `grafana` as the OSS package for the stable APT repository. 

---

# PART 14 — ⚙️ Make Sure systemd Works in WSL

Modern WSL supports systemd, and the Grafana package can run as a systemd service.

Check:

```bash
systemctl --version
```

If this works, continue.

---

## 14.1 If `systemctl` does NOT work

You may see something like:

```text
System has not been booted with systemd
```

Fix it as follows.

Open:

```bash
sudo nano /etc/wsl.conf
```

Add:

```ini
[boot]
systemd=true
```

Save:

```text
Ctrl+O
Enter
Ctrl+X
```

Then from **PowerShell**:

```powershell
wsl --shutdown
```

Start Ubuntu again.

Test:

```bash
systemctl --version
```

---

# PART 15 — ▶️ Start Grafana

Run:

```bash
sudo systemctl enable --now grafana-server
```

Check:

```bash
sudo systemctl status grafana-server --no-pager
```

You want:

```text
Active: active (running)
```

---

## 15.1 Check port 3000

Run:

```bash
ss -lntp | grep 3000
```

You should see:

```text
LISTEN ... *:3000
```

---

# PART 16 — 🌐 Open Grafana

Open Windows Chrome/Edge.

Go to:

```text
http://localhost:3000
```

You should see the Grafana login/welcome page.

---

## 16.1 Log in

Use the credentials you configured during the Grafana first-run process.

If you are using a fresh installation and Grafana asks for the initial credentials, follow the login prompt.

---

# PART 17 — 🔌 Install the Vertica Grafana Plugin

Grafana itself does not automatically know how to query Vertica.

Install the official Vertica datasource plugin.

Current plugin:

```text
vertica-grafana-datasource
```

Grafana's plugin catalog currently lists Vertica plugin version 3.2.1, with Grafana >=13.0.0 as its dependency. 

Official plugin page:

https://grafana.com/grafana/plugins/vertica-grafana-datasource/

---

## 17.1 Install from Ubuntu

Run:

```bash
sudo grafana cli plugins install vertica-grafana-datasource
```

If your installation uses the newer command name, this may also be available:

```bash
grafana cli plugins ls
```

---

## 17.2 Verify

Run:

```bash
grafana cli plugins ls | grep -i vertica
```

You should see something similar to:

```text
vertica-grafana-datasource
```

---

## 17.3 Restart Grafana

```bash
sudo systemctl restart grafana-server
```

Then:

```bash
sudo systemctl status grafana-server --no-pager
```

---

# PART 18 — 🔗 Add Vertica as a Grafana Data Source

Open:

```text
http://localhost:3000
```

In Grafana:

```text
Connections
    ↓
Data sources
    ↓
Add data source
```

Search:

```text
Vertica
```

Select:

```text
Vertica
```

---

## 18.1 Use these connection settings

### Name

```text
Vertica-VMart
```

### Host

```text
localhost:5433
```

### Database

```text
demo
```

### User

```text
dbadmin
```

### Password

```text
password
```

### SSL Mode

For this local training environment:

```text
Disable
```

The Vertica plugin documentation specifies that Host should be entered as `host:port` and the database name should be entered separately. 

---

## 18.2 Save and test

Click:

```text
Save & test
```

You want a successful connection message.

At this point:

```text
Grafana
   ↓
Vertica datasource plugin
   ↓
localhost:5433
   ↓
Docker
   ↓
Vertica
   ↓
demo
```

is working.

---

# PART 19 — 🧪 First Grafana Query

Go to:

```text
Explore
```

Select:

```text
Vertica-VMart
```

Use SQL/raw query mode.

Set:

```text
Format as:
Time Series
```

Enter:

```sql
SELECT
    store_sales_date AS time,
    SUM(sales_dollar_amount) AS sales
FROM store.store_sales_fact
WHERE $__timeFilter(store_sales_date)
GROUP BY store_sales_date
ORDER BY store_sales_date;
```

Click:

```text
Run query
```

---

# PART 20 — 🕒 Fix "Data outside time range"

If you see:

```text
Data outside time range
```

don't panic.

It usually means:

```text
SQL worked
   ↓
Vertica returned data
   ↓
But Grafana's selected time range
doesn't contain those dates
```

VMart contains historical dates beginning in 2003.

---

## 20.1 Set a useful time range

In Grafana's time picker, choose a custom/absolute range:

```text
From:
2003-01-01 00:00:00

To:
2003-01-31 23:59:59
```

Apply it.

Run the query again.

You should now get a graph showing daily January 2003 sales.

---

# PART 21 — 🎉 Final Verification

At this point you should have:

```text
Windows 11
   │
   ├── WSL2
   │     └── Ubuntu
   │           └── Grafana :3000
   │
   ├── Docker Desktop
   │     └── Vertica CE :5433
   │           └── demo
   │                 └── VMart
   │
   └── DBeaver
         └── Vertica connection
```

And:

```text
DBeaver ───────► Vertica
                    ▲
                    │
Grafana ────────────┘
```

The first successful Grafana chart should look like:

```text
Sales
300K ┤        ╭╮
250K ┤    ╭───╯╰╮
200K ┤ ╭──╯      ╰──╮
150K ┤─╯             ╰─
100K ┤
     └────────────────────
       Jan 1        Jan 31
```

---

# PART 22 — 🧯 Troubleshooting Cheat Sheet

## Problem 1: `wsl --install` doesn't work

Try:

```powershell
wsl --list --online
```

Then:

```powershell
wsl --install -d Ubuntu
```

If download hangs at 0%:

```powershell
wsl --install --web-download -d Ubuntu
```

---

## Problem 2: Ubuntu is WSL1

Check:

```powershell
wsl --list --verbose
```

If you see:

```text
Ubuntu    Running    1
```

run:

```powershell
wsl --set-version Ubuntu 2
```

Then verify:

```powershell
wsl --list --verbose
```

---

## Problem 3: `docker: command not found` inside Ubuntu

Check Docker Desktop:

```text
Docker Desktop
→ Settings
→ Resources
→ WSL Integration
→ Ubuntu = ON
```

Then:

```powershell
wsl --shutdown
```

Start Ubuntu again.

Test:

```bash
docker --version
```

---

## Problem 4: Docker works in Windows but not Ubuntu

This almost always means WSL Integration isn't enabled for Ubuntu.

Remember:

```text
Docker Desktop
→ Settings
→ Resources
→ WSL Integration
→ Enable Ubuntu
```

---

## Problem 5: Docker is in Windows container mode

Switch Docker Desktop to:

```text
Linux containers
```

The Vertica image is a Linux image.

---

## Problem 6: Vertica container is not running

Run:

```bash
docker ps -a
```

Look for:

```text
vertica-ce
```

Then:

```bash
docker start vertica-ce
```

Check:

```bash
docker ps
```

---

## Problem 7: Port 5433 already in use

Check:

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

On Windows PowerShell:

```powershell
netstat -ano | findstr :5433
```

If another application owns port 5433, either stop it or choose another host port.

Example:

```bash
docker run -d \
  --name vertica-ce \
  -p 15433:5433 \
  -v vertica-data:/data \
  molo17/vertica-ce:24.1.0-0
```

Then your clients must use:

```text
localhost:15433
```

instead of:

```text
localhost:5433
```

---

## Problem 8: `vsql` says database doesn't exist

Check:

```bash
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```

If that fails, inspect:

```bash
docker logs vertica-ce
```

---

## Problem 9: `\dt` says "No relations found"

That means the database exists but VMart tables aren't loaded.

Run:

```bash
docker exec -it vertica-ce bash -lc 'cd /opt/vertica/examples/VMart_Schema && ./01_load_vmart_schema.sh'
```

Then verify:

```sql
SELECT table_schema, table_name
FROM v_catalog.tables
WHERE is_system_table = false
ORDER BY table_schema, table_name;
```

---

## Problem 10: You accidentally type Docker commands inside `vsql`

If your prompt looks like:

```text
dbadmin@...=>
```

you are inside `vsql`.

Exit:

```text
\q
```

Docker commands such as:

```bash
docker exec ...
```

belong in the Ubuntu shell:

```text
vaman@PCNAME:~$
```

not inside `vsql`.

---

## Problem 11: You see `demo->`

This means `vsql` thinks your SQL statement is incomplete.

Press:

```text
Ctrl+C
```

Then:

```text
\q
```

---

## Problem 12: Grafana service won't start

Run:

```bash
sudo systemctl status grafana-server --no-pager
```

Then:

```bash
sudo journalctl -u grafana-server -n 100 --no-pager
```

Check that port 3000 isn't already occupied:

```bash
ss -lntp | grep 3000
```

---

## Problem 13: `systemctl` doesn't work in Ubuntu

Enable systemd.

Edit:

```bash
sudo nano /etc/wsl.conf
```

Add:

```ini
[boot]
systemd=true
```

Then from PowerShell:

```powershell
wsl --shutdown
```

Reopen Ubuntu.

Test:

```bash
systemctl --version
```

---

## Problem 14: Grafana opens but Vertica isn't listed

Check the plugin:

```bash
grafana cli plugins ls | grep -i vertica
```

If missing:

```bash
sudo grafana cli plugins install vertica-grafana-datasource
```

Restart:

```bash
sudo systemctl restart grafana-server
```

---

## Problem 15: Grafana says it cannot connect to Vertica

First check Vertica:

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

You need:

```text
vertica-ce   ...5433->5433...
```

Then test from Ubuntu:

```bash
docker exec -it vertica-ce /opt/vertica/bin/vsql -U dbadmin -d demo
```

Then test the port from Ubuntu:

```bash
nc -vz localhost 5433
```

If `nc` is not installed:

```bash
sudo apt-get install -y netcat-openbsd
```

Then:

```bash
nc -vz localhost 5433
```

---

## Problem 16: Grafana shows "Data outside time range"

Set the Grafana time range to:

```text
2003-01-01
→
2003-01-31
```

The SQL is probably working.

---

## Problem 17: DBeaver can't connect

Check:

```text
Host:     localhost
Port:     5433
Database: demo
User:     dbadmin
Password: password
```

Also check:

```bash
docker ps
```

Vertica must be running.

---

## Problem 18: DBeaver asks for a driver

Click:

```text
Download
```

If automatic download fails, use the Vertica JDBC driver documentation:

https://docs.vertica.com/24.1.x/en/connecting-to/client-libraries/client-drivers/install-config/jdbc/

---

# PART 23 — 🧠 The Mental Model Trainees Should Remember

Don't memorize random commands. Remember the architecture.

### WSL2

```text
Windows
  ↓
Linux environment
```

### Docker Desktop

```text
Windows
  ↓
Docker Desktop
  ↓
WSL2 backend
  ↓
Linux containers
```

### Ubuntu integration

```text
Ubuntu terminal
       ↓
docker command
       ↓
Docker Desktop engine
```

### Vertica

```text
Docker container
       ↓
Vertica CE
       ↓
demo database
       ↓
VMart schemas/tables
```

### DBeaver

```text
Windows application
       ↓
localhost:5433
       ↓
Vertica
```

### Grafana

```text
Ubuntu/WSL2
       ↓
Grafana :3000
       ↓
Vertica datasource plugin
       ↓
localhost:5433
       ↓
Vertica
```

---

# PART 24 — 🏁 One-Shot Verification Checklist

Before starting the training, every trainee should be able to answer **YES** to these:

```text
[ ] Windows 11 is running
[ ] WSL2 is installed
[ ] Ubuntu is installed
[ ] Ubuntu is VERSION 2
[ ] Docker Desktop is running
[ ] Docker uses WSL2
[ ] Ubuntu WSL Integration is enabled
[ ] docker --version works inside Ubuntu
[ ] docker run hello-world works
[ ] molo17/vertica-ce image exists
[ ] vertica-ce container is running
[ ] port 5433 is exposed
[ ] vsql connects to demo
[ ] SELECT version() works
[ ] VMart is loaded
[ ] store.store_sales_fact exists
[ ] VMart has 5,000,000 store sales rows
[ ] DBeaver is installed
[ ] DBeaver connects to localhost:5433
[ ] Grafana is installed
[ ] Grafana service is running
[ ] Grafana opens at localhost:3000
[ ] Vertica Grafana plugin is installed
[ ] Grafana connects to Vertica
[ ] Grafana Explore executes SQL
[ ] January 2003 sales graph is visible
```

If all boxes are checked:

# 🎉 Your Vertica + Grafana training lab is ready.

---

# Official Links / Bookmarks

### Microsoft

WSL installation:

https://learn.microsoft.com/en-us/windows/wsl/install

### Docker

Docker Desktop for Windows:

https://www.docker.com/products/docker-desktop/

Docker Desktop Windows installation:

https://docs.docker.com/desktop/setup/install/windows-install/

Docker + WSL2:

https://docs.docker.com/desktop/features/wsl/

### Vertica Docker workaround

Docker Hub:

https://hub.docker.com/r/molo17/vertica-ce

Specific image used:

https://hub.docker.com/layers/molo17/vertica-ce/24.1.0-0/

### Vertica

Vertica 24.1 documentation:

https://docs.vertica.com/24.1.x/

Vertica JDBC:

https://docs.vertica.com/24.1.x/en/connecting-to/client-libraries/client-drivers/install-config/jdbc/

### DBeaver

DBeaver Community download:

https://dbeaver.io/download/

DBeaver installation documentation:

https://dbeaver.com/docs/dbeaver/Installation/

### Grafana

Grafana download:

https://grafana.com/grafana/download/

Grafana Ubuntu/Debian installation:

https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/

Vertica Grafana datasource plugin:

https://grafana.com/grafana/plugins/vertica-grafana-datasource/

Vertica plugin installation:

https://grafana.com/grafana/plugins/vertica-grafana-datasource/installation/


--- 

## Overall Installation Picture  

```bash 
┌────────────────────────────────────────────────────────────────┐
│ Windows 11                                                     │
│                                                                │
│  ┌────────────┐   ┌───────────────────┐ ┌───────────────────┐  │
│  │ DBeaver    │   │ WSL2 · Ubuntu     │ │ Docker Desktop    │  │
│  │ Vertica    │   │                   │ │ (WSL2 backend)    │  │
│  │ client     │   │ ┌───────────────┐ │ │ ┌───────────────┐ │  │
│  │            │   │ │ Grafana :3000 │ │ │ │ Vertica CE    │ │  │
│  │            │   │ └───────┬───────┘ │ │ │ demo · :5433  │ │  │
│  └─────┬──────┘   └─────────┼─────────┘ │ └───────┬───────┘ │  │
│        │                    │           └─────────┼─────────┘  │
│        │                    └─────────────────────┘            │
│        └──────────────────────────────────────────┘            │
│                             │                                  │
│                    ┌────────▼────────┐                         │
│                    │ Browser         │                         │
│                    │ localhost:3000  │                         │
│                    └────────┬────────┘                         │
│                             │                                  │
└─────────────────────────────┼──────────────────────────────────┘
                              ▼
                       ┌─────────────┐
                       │  End user   │
                       └─────────────┘
```

--- 