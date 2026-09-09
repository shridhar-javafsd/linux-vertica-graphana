# Grafana Alerting Lab

## What even is alerting? 🚨

Think of it like this: a dashboard is you *staring* at your data hoping to catch a problem. Alerting is you telling the system "hey, tap me on the shoulder if something goes wrong" — so you can go touch grass instead of babysitting a screen 24/7.

Mechanically it's simple: Grafana runs a query on a schedule (every 1 min, every 5 min, whatever), checks the result against a condition you set (`IS ABOVE 80`, `IS BELOW 10`, etc.), and if that condition holds true for long enough, it flips the alert to **firing** and pings whoever/whatever you told it to.

**Why it actually matters (real use cases):**
- 🔥 Server CPU/memory maxing out → get pinged before the app crashes, not after
- 📉 Sales/orders count dropping to zero → checkout might be broken and nobody noticed
- 🐌 API response times creeping up → catch it before customers start complaining
- 💾 Disk space running low → avoid the classic "prod is down bc disk full" 3am disaster
- 📦 Failed job/order counts spiking → something upstream broke

**Where do alerts actually go?** Wherever you want — that's the flexible part. Common destinations ("contact points" in Grafana):
- **Email** — classic, works everywhere, a bit slow for urgent stuff
- **Slack / Microsoft Teams** — most common for teams, shows up right where people already are
- **PagerDuty / Opsgenie** — for "wake someone up at 3am" level urgency, has on-call rotations
- **Webhook** — sends a raw JSON payload to any URL you want; this is what we'll use in this lab (via webhook.site) since it needs zero setup and you can literally watch the payload land in real time
- **SMS / phone call** — for the "drop everything" tier of alerts

That's the whole game: **watch a number → compare it to a threshold → notify a human (or another system) the moment it crosses the line.** Everything below is just Grafana's specific way of wiring that up.

---

Two versions of the same core idea — an alert rule that watches a number and fires when it crosses a threshold. Pick whichever fits the day's flow, or run both to contrast a deterministic demo against a real system-metrics one.

- **Section 1 — No Prometheus (Vertica-based):** deterministic, trainee-controlled, ties directly back to Vertica.
- **Section 2 — With Prometheus (host CPU):** real system metric via node_exporter → Prometheus, closer to a production monitoring setup.

---

# Section 1: Alerting without Prometheus (Vertica)

Uses the existing **Vertica-VMart** data source already connected in Grafana — no new install, no timing games, no core-count math. Trainees make it fire on command with a single `INSERT`.

## 1. Create a demo table in Vertica

Using DBeaver or `vsql`, connect to the `demo` database and run:

```sql
CREATE TABLE public.metrics (value INT);
INSERT INTO public.metrics VALUES (10);
```

Alternative, more realistic query if you'd rather alert on real VMart data instead of a synthetic table:

```sql
SELECT COUNT(*) FROM store.store_orders_fact WHERE order_status = 'FAILED'
```

## 2. Confirm the query works in Grafana

**Explore** → data source **Vertica-VMart** → run:

```sql
SELECT value FROM public.metrics ORDER BY 1 DESC LIMIT 1
```

You should see a single row back with the current value (`10`).

## 3. Create the alert rule

**Alerting → Alert rules → + New alert rule**

| Field | Value |
|---|---|
| Name | `vertica-demo-alert` |
| Query A | same SQL as above, data source **Vertica-VMart** |
| Expression | Reduce (Last) → Threshold: `IS ABOVE 50` |
| Folder | `adaps-demo` |
| Group | `adaps-group` |
| Evaluation | every `1m`, for `0m` or `1m` |
| Labels | `severity = warning` |

## 4. Point it at a contact point

Reuse or create a webhook contact point (see Section 2, step 3, for the full webhook.site setup — identical process, data source doesn't matter to Alerting once the query returns a number).

## 5. Trigger it — fully deterministic

```sql
INSERT INTO public.metrics VALUES (99);
```

Wait for the next evaluation cycle (up to 1 minute) and watch the **Instances** tab move **Normal → Pending → Alerting**. Check webhook.site for the firing payload.

To resolve it:
```sql
INSERT INTO public.metrics VALUES (5);
```

## Why this version is useful

- No dependency on system load, VM core counts, or `stress-ng` cooperating
- Trainees see exactly when and why it will fire — cause and effect is one `INSERT` away
- Reinforces Vertica from earlier in the course instead of introducing a second system just for this lab
- Sets up cleanly into a capstone that queries real VMart tables

---

# Section 2: Alerting with Prometheus (Host CPU)

A hands-on example built on the existing training stack: **node_exporter → Prometheus → Grafana**, running inside WSL2 with Docker Desktop backing the Vertica CE container. No new data sources or installs are needed — this lab only adds an alert rule, a contact point, and a notification policy.

**Goal:** alert when host CPU usage crosses a threshold, and see the alert reach an external endpoint end to end.

## 1. Confirm the metric exists

Go to **Explore** (compass icon in the left sidebar) → set the data source dropdown to **prometheus**.

Paste this query and run it (Shift+Enter, or the Run query button):

```
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)
```

This computes CPU usage % by inverting idle time. You should see a single series labeled `{instance="localhost:9100"}` with the current usage value plotted over time.

## 2. Create the alert rule

**Alerting → Alert rules → + New alert rule**

| Field | Value |
|---|---|
| Name | `demo-alert` (or `High CPU Usage`) |
| Query A | same PromQL as above, in **Code** mode |
| Expression | Reduce (Last) → Threshold: `IS ABOVE 40` |
| Folder | `adaps-demo` |
| Group | `adaps-group` |
| Evaluation | every `1m`, for `1m` |
| Labels | `severity = warning` |

> Threshold note: 80% is a reasonable production-like value, but is hard to sustain reliably from inside WSL2 (see Troubleshooting). **40%** is safely above idle baseline (~1%) and easy to cross with a modest stress test — better for a live classroom demo.

Save the rule. It should show **State: Normal** with **Last evaluated** ticking over every minute — if "Last evaluated" stays blank, the rule isn't actually running (see Troubleshooting).

## 3. Create a contact point

**Alerting → Notification configuration → Contact points → New contact point**

1. **Name:** `webhook-demo`
2. **Integration:** change from `Email` to **Webhook**
3. **URL:** open [webhook.site](https://webhook.site) in a separate tab — it auto-generates a unique URL. Copy it into the URL field.
4. Leave **HTTP Method** as `POST`
5. Click **Test** — confirm a sample payload lands on your webhook.site tab within seconds
6. **Save contact point**

> ⚠️ webhook.site URLs are public and anonymous — anyone with the link can see the payloads. Fine for a classroom demo, never for real data.

## 4. Point the alert at the contact point

Either:
- Set `webhook-demo` as the rule's **contact point override** when creating/editing the rule (simplest for a single demo rule), or
- Route it through **Notification policies**: add a route matching `severity = warning` → `webhook-demo`

Confirm on the alert rule's detail page that **"Notifications are delivered to"** shows `webhook-demo`.

## 5. Trigger it

Check how many logical cores WSL2 sees first:

```bash
nproc
```

Then stress all of them, not a fixed number — matching stressor count to core count matters (see Troubleshooting):

```bash
sudo apt install stress-ng -y && stress-ng --cpu $(nproc) --cpu-load 100 --timeout 120s
```

While it runs, watch the **Instances** tab on the alert rule page (refresh periodically):

- **Normal → Pending** (query is above threshold but hasn't held for the full "for" duration yet)
- **Pending → Alerting/Firing** once the condition holds long enough

Then check the webhook.site tab — a POST request should land with a JSON payload showing `"status": "firing"`, the rule's real labels (`severity: warning`, `instance: localhost:9100`), and a `startsAt` timestamp with actual metric values under `"values"`.

**Confirmed working example payload** (from a live run against this exact setup, threshold 80, actual value 84.3):

```json
{
  "receiver": "webhook-demo",
  "status": "firing",
  "alerts": [{
    "status": "firing",
    "labels": {
      "alertname": "demo-alert",
      "grafana_folder": "adaps-demo",
      "instance": "localhost:9100",
      "severity": "warning"
    },
    "values": {"A": 84.30821314013467, "C": 1},
    "valueString": "[ var='A' labels={instance=localhost:9100} type='query' value=84.30821314013467 ], [ var='C' labels={instance=localhost:9100} type='threshold' value=1 ]"
  }],
  "state": "alerting",
  "title": "[FIRING:1] demo-alert adaps-demo (localhost:9100 warning)"
}
```

## 6. Resolve and observe

Once `stress-ng` finishes and CPU drops back down, the alert returns to **Normal** after the next evaluation cycle — the payload's `"status"` field will flip to `"resolved"`. Show trainees this landing on webhook.site to complete the firing/resolving lifecycle.

---

## Troubleshooting (Prometheus/CPU version)

**"Last evaluated" stays as `-` / state never changes**
The rule may be paused, or its evaluation group isn't scheduled. Open **Edit** on the rule and check for a pause toggle; hard-refresh (Ctrl+F5) the rule detail page before assuming it's stuck — the UI doesn't always auto-refresh.

**Test payload keeps showing on webhook.site instead of the real alert**
The contact point's own **Test** button sends a canned payload with `alertname: "TestAlert"`, `instance: "Grafana"`, and a fake `valueString` like `metric='foo' ... value=10`. This is not your real rule firing — check the payload's `labels` block to tell them apart. Your real `demo-alert` firing will show `severity: warning` and `instance: localhost:9100`.

**Alert never fires even though `stress-ng` is clearly running**
The query averages CPU usage **across the whole host**. If WSL2 has more logical processors than the stressor count you gave, you only load a fraction of total capacity.

If `nproc` returns more than 4 (e.g. 12), `stress-ng --cpu 4` will only push the average to roughly `4 / nproc` — around 33% in that example — never near an 80% threshold.

**Fix:** stress all cores:
```bash
stress-ng --cpu $(nproc) --cpu-load 100 --timeout 120s
```

**Faster classroom alternative:** instead of fixing the stress command, use a lower threshold (25–40%) that 4 stressed cores will reliably cross, and use the mismatch as a teaching moment about `avg by (instance)` vs. per-core load rather than a blocker.

**stress-ng warning: "for stable load results, select a specific cpu stress method"**
Cosmetic — the default `all` method cycles through many stress algorithms with variable load. For steadier, more predictable load in a demo, use:
```bash
stress-ng --cpu $(nproc) --cpu-method matrixprod --timeout 120s
```

---

## Quick reference

| Item | Vertica version | Prometheus version |
|---|---|---|
| Query | `SELECT value FROM public.metrics ORDER BY 1 DESC LIMIT 1` | `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)` |
| Threshold | `IS ABOVE 50` | `IS ABOVE 40` (or 80 for production-realistic, harder to sustain) |
| Trigger | `INSERT INTO public.metrics VALUES (99);` | `stress-ng --cpu $(nproc) --cpu-load 100 --timeout 120s` |
| Resolve | `INSERT INTO public.metrics VALUES (5);` | let `stress-ng` finish |
| Check core count | n/a | `nproc` |
