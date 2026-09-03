# VMart Analytical SQL Assignment — ANSWER KEY (Trainer Only)

⚠️ Column names for `store.*` and `public.customer_dimension` / `product_dimension` / `employee_dimension` are verified against Vertica's official VMart docs. Column names in `online_sales.*` (call center / online page dimensions) are the commonly-documented VMart names but **run a `\d online_sales.*` on your instance and adjust before class** — this schema has drifted slightly across VMart versions.

---

## Section A

**1.**
```sql
SELECT table_schema, table_name
FROM v_catalog.tables
WHERE table_schema IN ('store','online_sales')
ORDER BY 1,2;
```

**2.**
```sql
SELECT column_name, data_type, is_nullable
FROM columns
WHERE table_schema = 'store' AND table_name = 'store_sales_fact'
ORDER BY ordinal_position;
```

**3.** FKs in `store_sales_fact`: `date_key`→date_dimension, `product_key`+`product_version`→product_dimension, `store_key`→store_dimension, `promotion_key`→promotion_dimension, `customer_key`→customer_dimension, `employee_key`→employee_dimension.

**4.**
```sql
SELECT (SELECT COUNT(*) FROM store.store_sales_fact) AS store_rows,
       (SELECT COUNT(*) FROM online_sales.online_sales_fact) AS online_rows;
```

**5.**
```sql
SELECT product_key, COUNT(DISTINCT product_version) AS versions
FROM public.product_dimension
GROUP BY product_key
HAVING COUNT(DISTINCT product_version) > 1
LIMIT 5;
-- Products get re-versioned when their description/price/packaging changes;
-- keeping history means old sales still join correctly to the version that was
-- actually sold, instead of silently rewriting history to the current version.
```

---

## Section B

**6.**
```sql
SELECT * FROM public.customer_dimension
WHERE customer_state = 'CA' AND marital_status = 'Married';
```

**7.**
```sql
SELECT * FROM public.product_dimension
WHERE category_description = 'Diet Foods';
```

**8.**
```sql
SELECT * FROM store.store_sales_fact WHERE sales_dollar_amount > 500;
```

**9.**
```sql
SELECT * FROM public.employee_dimension WHERE employee_last_name LIKE 'S%';
```

**10.**
```sql
SELECT * FROM store.store_sales_fact
WHERE tender_type = 'Cash' AND sales_quantity > 5;
```

---

## Section C

**11.**
```sql
SELECT c.customer_name, p.product_description, s.sales_dollar_amount
FROM store.store_sales_fact s
JOIN public.customer_dimension c ON s.customer_key = c.customer_key
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
ORDER BY s.sales_dollar_amount DESC
LIMIT 10;
```

**12.**
```sql
SELECT p.category_description, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
GROUP BY p.category_description
ORDER BY revenue DESC;
```

**13.**
```sql
SELECT d.store_state, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN store.store_dimension d ON s.store_key = d.store_key
GROUP BY d.store_state
ORDER BY revenue DESC;
```

**14.**
```sql
SELECT e.employee_first_name, e.employee_last_name, SUM(s.sales_dollar_amount) AS total_sales
FROM store.store_sales_fact s
JOIN public.employee_dimension e ON s.employee_key = e.employee_key
GROUP BY e.employee_first_name, e.employee_last_name
ORDER BY total_sales DESC;
```

**15.**
```sql
SELECT 'Store' AS channel, SUM(sales_dollar_amount) AS revenue FROM store.store_sales_fact
UNION ALL
SELECT 'Online' AS channel, SUM(sales_dollar_amount) FROM online_sales.online_sales_fact;
```

**16.**
```sql
SELECT customer_key, SUM(amt) AS total_spend FROM (
  SELECT customer_key, sales_dollar_amount AS amt FROM store.store_sales_fact
  UNION ALL
  SELECT customer_key, sales_dollar_amount AS amt FROM online_sales.online_sales_fact
) combined
GROUP BY customer_key
ORDER BY total_spend DESC
LIMIT 5;
-- Join to customer_dimension separately if you want the name printed.
```

---

## Section D

**17.**
```sql
SELECT p.department_description,
       SUM(s.sales_dollar_amount) AS total,
       AVG(s.sales_dollar_amount) AS avg_sale,
       MIN(s.sales_dollar_amount) AS min_sale,
       MAX(s.sales_dollar_amount) AS max_sale
FROM store.store_sales_fact s
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
GROUP BY p.department_description;
```

**18.**
```sql
SELECT tender_type, COUNT(*) FROM store.store_sales_fact GROUP BY tender_type;
```

**19.**
```sql
SELECT p.category_description, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
GROUP BY p.category_description
HAVING SUM(s.sales_dollar_amount) > 1000000;
```

**20.**
```sql
SELECT store_key, COUNT(DISTINCT customer_key) AS distinct_customers
FROM store.store_sales_fact
GROUP BY store_key
ORDER BY distinct_customers DESC;
```

**21.**
```sql
SELECT SUM(gross_profit_dollar_amount) * 1.0 / SUM(sales_dollar_amount) AS gross_margin
FROM store.store_sales_fact;
```

**22.**
```sql
SELECT product_key, product_version, SUM(sales_quantity) AS total_qty
FROM store.store_sales_fact
GROUP BY product_key, product_version
ORDER BY total_qty DESC
LIMIT 1;
```

---

## Section E

**23.**
```sql
SELECT dd.year, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN public.date_dimension dd ON s.date_key = dd.date_key
GROUP BY dd.year
ORDER BY dd.year;
```

**24.**
```sql
SELECT dd.month, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN public.date_dimension dd ON s.date_key = dd.date_key
WHERE dd.year = (SELECT MAX(year) FROM public.date_dimension)
GROUP BY dd.month
ORDER BY dd.month;
-- Adjust column name (`month` vs `month_of_year`) to match your date_dimension.
```

**25.**
```sql
SELECT dd.day_of_week, AVG(s.sales_dollar_amount) AS avg_txn
FROM store.store_sales_fact s
JOIN public.date_dimension dd ON s.date_key = dd.date_key
GROUP BY dd.day_of_week
ORDER BY avg_txn DESC;
```

**26.**
```sql
SELECT EXTRACT(HOUR FROM transaction_time) AS hr, COUNT(*) AS txns
FROM store.store_sales_fact
WHERE transaction_time > '18:00:00'
GROUP BY hr
ORDER BY hr;
```

**27.**
```sql
SELECT AVG(date_delivered - date_ordered) AS avg_fulfillment_days
FROM store.store_orders_fact
WHERE date_delivered IS NOT NULL;
```

---

## Section F

**28.**
```sql
SELECT UPPER(customer_name) FROM public.customer_dimension;
SELECT LOWER(product_description) FROM public.product_dimension;
```

**29.**
```sql
SELECT LEFT(sku_number, 3) AS prefix, COUNT(*) AS product_count
FROM public.product_dimension
GROUP BY prefix
ORDER BY product_count DESC;
```

**30.**
```sql
SELECT * FROM public.customer_dimension WHERE occupation ILIKE '%Manager%';
```

**31.**
```sql
SELECT employee_last_name || ', ' || employee_first_name AS full_name
FROM public.employee_dimension;
```

---

## Section G

**32.**
```sql
SELECT p.product_key, p.product_description
FROM public.product_dimension p
LEFT JOIN store.store_sales_fact s
  ON p.product_key = s.product_key AND p.product_version = s.product_version
WHERE s.product_key IS NULL;
```

**33.**
```sql
SELECT customer_key, SUM(sales_dollar_amount) AS spend
FROM store.store_sales_fact
GROUP BY customer_key
HAVING SUM(sales_dollar_amount) > (
  SELECT AVG(cust_total) FROM (
    SELECT SUM(sales_dollar_amount) AS cust_total
    FROM store.store_sales_fact GROUP BY customer_key
  ) t
);
```

**34.**
```sql
SELECT store_key, AVG(sales_dollar_amount) AS avg_txn
FROM store.store_sales_fact
GROUP BY store_key
HAVING AVG(sales_dollar_amount) > (SELECT AVG(sales_dollar_amount) FROM store.store_sales_fact);
```

**35.**
```sql
SELECT product_key FROM store.store_sales_fact
INTERSECT
SELECT product_key FROM online_sales.online_sales_fact;
```

**36.**
```sql
SELECT product_key FROM online_sales.online_sales_fact
EXCEPT
SELECT product_key FROM store.store_sales_fact;
```

---

## Section H

**37.**
```sql
SELECT store_key, date_key, sales_dollar_amount,
       SUM(sales_dollar_amount) OVER (
         PARTITION BY store_key ORDER BY date_key
         ROWS UNBOUNDED PRECEDING
       ) AS running_total
FROM store.store_sales_fact
ORDER BY store_key, date_key;
```

**38.**
```sql
SELECT category_description, product_key, revenue, rnk FROM (
  SELECT p.category_description, s.product_key,
         SUM(s.sales_dollar_amount) AS revenue,
         RANK() OVER (PARTITION BY p.category_description ORDER BY SUM(s.sales_dollar_amount) DESC) AS rnk
  FROM store.store_sales_fact s
  JOIN public.product_dimension p
    ON s.product_key = p.product_key AND s.product_version = p.product_version
  GROUP BY p.category_description, s.product_key
) ranked
WHERE rnk <= 3
ORDER BY category_description, rnk;
```

**39.**
```sql
SELECT store_key, SUM(sales_dollar_amount) AS revenue,
       RATIO_TO_REPORT(SUM(sales_dollar_amount)) OVER () AS pct_of_total
FROM store.store_sales_fact
GROUP BY store_key
ORDER BY pct_of_total DESC;
```

**40.**
```sql
WITH monthly AS (
  SELECT dd.year, dd.month, SUM(s.sales_dollar_amount) AS revenue
  FROM store.store_sales_fact s
  JOIN public.date_dimension dd ON s.date_key = dd.date_key
  GROUP BY dd.year, dd.month
)
SELECT year, month, revenue,
       LAG(revenue) OVER (ORDER BY year, month) AS prev_month_revenue,
       (revenue - LAG(revenue) OVER (ORDER BY year, month)) * 100.0
         / LAG(revenue) OVER (ORDER BY year, month) AS pct_change
FROM monthly
ORDER BY year, month;
```

**41.**
```sql
SELECT customer_key, total_spend,
       NTILE(4) OVER (ORDER BY total_spend) AS spend_quartile
FROM (
  SELECT customer_key, SUM(sales_dollar_amount) AS total_spend
  FROM store.store_sales_fact
  GROUP BY customer_key
) t;
```

**42.**
```sql
SELECT DISTINCT customer_key,
       FIRST_VALUE(date_key) OVER (PARTITION BY customer_key ORDER BY date_key DESC) AS most_recent_date_key,
       CURRENT_DATE - FIRST_VALUE(date_key) OVER (PARTITION BY customer_key ORDER BY date_key DESC) AS days_ago
FROM store.store_sales_fact;
-- Note: this assumes date_key is stored as an actual DATE; if it's a surrogate
-- integer key, join to date_dimension first and use the real date column.
```

---

## Section I

**43.**
```sql
CREATE VIEW public.vw_category_performance AS
SELECT p.category_description,
       SUM(s.sales_dollar_amount) AS total_revenue,
       SUM(s.sales_quantity) AS total_quantity
FROM store.store_sales_fact s
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
GROUP BY p.category_description;
```

**44.**
```sql
CREATE VIEW public.vw_customer_360 AS
SELECT customer_key, date_key, sales_dollar_amount, 'Store' AS channel FROM store.store_sales_fact
UNION ALL
SELECT customer_key, date_key, sales_dollar_amount, 'Online' AS channel FROM online_sales.online_sales_fact;
```

**45.**
```sql
SELECT customer_key, SUM(sales_dollar_amount) AS total_spend
FROM public.vw_customer_360
GROUP BY customer_key
ORDER BY total_spend DESC
LIMIT 10;
-- Talking point: the view doesn't make the query itself faster (it's not
-- materialized), but it makes the *dashboard/BI layer* simpler and consistent
-- — analysts stop hand-writing the UNION ALL every time. If this got queried
-- constantly, the follow-up discussion is materialized views / projections.
```

---

## Stretch goals

**46.** Uses `TIMESERIES` clause, e.g.:
```sql
SELECT slice_time, SUM(sales_dollar_amount) AS revenue
FROM store.store_sales_fact TIMESERIES slice_time AS '1 day' OVER (ORDER BY transaction_time)
GROUP BY slice_time
ORDER BY slice_time;
-- Confirm exact TIMESERIES syntax against the Vertica version installed —
-- this is a good "read the docs live" moment for trainees.
```

**47.**
```sql
SELECT APPROXIMATE_COUNT_DISTINCT(customer_key) FROM store.store_sales_fact;
SELECT COUNT(DISTINCT customer_key) FROM store.store_sales_fact;
-- Compare both value and execution time (\timing on).
```

**48.** Discussion answer: if you join on `product_key` alone, a product that's been re-versioned (Q5) will fan out — one sale could match multiple `product_version` rows in `product_dimension`, silently duplicating revenue in the join. Always join on the full composite key.
