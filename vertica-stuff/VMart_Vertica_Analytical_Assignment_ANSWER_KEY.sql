-- ============================================================
--  VMART ANALYTICAL SQL ASSIGNMENT — VERTICA
--  ANSWER KEY (TRAINER ONLY — DO NOT DISTRIBUTE)
--
--  Mirrors the trainee assignment file 1:1. Each question is
--  followed immediately by a working query.
--
--  Column names for store.*, customer_dimension, product_dimension
--  and employee_dimension are verified against Vertica's official
--  VMart docs. online_sales.* dimension columns (call center /
--  online page) are the commonly-documented VMart names — run
--  \d online_sales.* on your instance and adjust before class,
--  this schema has drifted slightly across VMart versions.
-- ============================================================

\timing on


-- ============================================================
-- SECTION A — KNOW YOUR SCHEMA (WARM-UP)
-- ============================================================

-- Q1. List every table in the store and online_sales schemas,
--     along with their schema name, using a system table query.
SELECT table_schema, table_name
FROM v_catalog.tables
WHERE table_schema IN ('store','online_sales')
ORDER BY 1,2;


-- Q2. For store.store_sales_fact, list all columns with their
--     data types and whether they allow NULLs.
SELECT column_name, data_type, is_nullable
FROM columns
WHERE table_schema = 'store' AND table_name = 'store_sales_fact'
ORDER BY ordinal_position;


-- Q3. Identify the foreign key columns in store.store_sales_fact
--     and note (as a comment) which dimension table each points to.
-- date_key        -> public.date_dimension
-- product_key + product_version -> public.product_dimension
-- store_key       -> store.store_dimension
-- promotion_key   -> public.promotion_dimension
-- customer_key    -> public.customer_dimension
-- employee_key    -> public.employee_dimension


-- Q4. How many rows are currently in store.store_sales_fact?
--     In online_sales.online_sales_fact?
SELECT (SELECT COUNT(*) FROM store.store_sales_fact) AS store_rows,
       (SELECT COUNT(*) FROM online_sales.online_sales_fact) AS online_rows;


-- Q5. product_dimension uses a composite key (product_key +
--     product_version) instead of a single surrogate key. Write
--     a query proving at least one product_key has more than one
--     product_version. Explain why, in a comment.
SELECT product_key, COUNT(DISTINCT product_version) AS versions
FROM public.product_dimension
GROUP BY product_key
HAVING COUNT(DISTINCT product_version) > 1
LIMIT 5;
-- Products get re-versioned when their description/price/packaging
-- changes; keeping history means old sales still join correctly to
-- the version that was actually sold, instead of silently rewriting
-- history to the current version.


-- ============================================================
-- SECTION B — FILTERING & PROJECTION
-- ============================================================

-- Q6. List all customers from the state of 'CA' who are 'Married'.
SELECT * FROM public.customer_dimension
WHERE customer_state = 'CA' AND marital_status = 'Married';


-- Q7. List all products in the 'Diet Foods' category (check exact
--     spelling in your data first).
SELECT * FROM public.product_dimension
WHERE category_description = 'Diet Foods';


-- Q8. Find all store sales transactions where sales_dollar_amount
--     is greater than $500 in a single line.
SELECT * FROM store.store_sales_fact WHERE sales_dollar_amount > 500;


-- Q9. List employees whose employee_last_name starts with 'S'.
SELECT * FROM public.employee_dimension WHERE employee_last_name LIKE 'S%';


-- Q10. Find all store sales where tender_type was 'Cash' and
--      sales_quantity was more than 5.
SELECT * FROM store.store_sales_fact
WHERE tender_type = 'Cash' AND sales_quantity > 5;


-- ============================================================
-- SECTION C — JOINS ACROSS FACTS & DIMENSIONS
-- ============================================================

-- Q11. List the customer name, product description, and sale
--      amount for the top 10 highest-value store sales transactions.
SELECT c.customer_name, p.product_description, s.sales_dollar_amount
FROM store.store_sales_fact s
JOIN public.customer_dimension c ON s.customer_key = c.customer_key
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
ORDER BY s.sales_dollar_amount DESC
LIMIT 10;


-- Q12. Display total revenue (sales_dollar_amount) by product
--      category, sorted highest to lowest.
SELECT p.category_description, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
GROUP BY p.category_description
ORDER BY revenue DESC;


-- Q13. Display total revenue by store state, joining
--      store_sales_fact -> store_dimension.
SELECT d.store_state, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN store.store_dimension d ON s.store_key = d.store_key
GROUP BY d.store_state
ORDER BY revenue DESC;


-- Q14. For each employee, show their name and the total dollar
--      amount of sales they've rung up. Sort by top performer first.
SELECT e.employee_first_name, e.employee_last_name, SUM(s.sales_dollar_amount) AS total_sales
FROM store.store_sales_fact s
JOIN public.employee_dimension e ON s.employee_key = e.employee_key
GROUP BY e.employee_first_name, e.employee_last_name
ORDER BY total_sales DESC;


-- Q15. Compare store channel vs online channel: total revenue
--      from store_sales_fact vs total revenue from
--      online_sales_fact, side by side in one result set.
SELECT 'Store' AS channel, SUM(sales_dollar_amount) AS revenue FROM store.store_sales_fact
UNION ALL
SELECT 'Online' AS channel, SUM(sales_dollar_amount) FROM online_sales.online_sales_fact;


-- Q16. List the top 5 customers (by name) with the highest total
--      spend combined across both store and online sales.
SELECT customer_key, SUM(amt) AS total_spend FROM (
  SELECT customer_key, sales_dollar_amount AS amt FROM store.store_sales_fact
  UNION ALL
  SELECT customer_key, sales_dollar_amount AS amt FROM online_sales.online_sales_fact
) combined
GROUP BY customer_key
ORDER BY total_spend DESC
LIMIT 5;
-- Join to customer_dimension separately if you want the name printed.


-- ============================================================
-- SECTION D — AGGREGATION & GROUPING
-- ============================================================

-- Q17. Find the total, average, minimum, and maximum sale amount
--      per product department.
SELECT p.department_description,
       SUM(s.sales_dollar_amount) AS total,
       AVG(s.sales_dollar_amount) AS avg_sale,
       MIN(s.sales_dollar_amount) AS min_sale,
       MAX(s.sales_dollar_amount) AS max_sale
FROM store.store_sales_fact s
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
GROUP BY p.department_description;


-- Q18. Count the number of transactions per tender_type.
SELECT tender_type, COUNT(*) FROM store.store_sales_fact GROUP BY tender_type;


-- Q19. Find product categories where total revenue exceeds
--      $1,000,000 (use HAVING).
SELECT p.category_description, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
GROUP BY p.category_description
HAVING SUM(s.sales_dollar_amount) > 1000000;


-- Q20. Find the number of distinct customers who made a purchase
--      in each store.
SELECT store_key, COUNT(DISTINCT customer_key) AS distinct_customers
FROM store.store_sales_fact
GROUP BY store_key
ORDER BY distinct_customers DESC;


-- Q21. Calculate the overall gross profit margin
--      (SUM(gross_profit_dollar_amount) / SUM(sales_dollar_amount))
--      for the whole store chain.
SELECT SUM(gross_profit_dollar_amount) * 1.0 / SUM(sales_dollar_amount) AS gross_margin
FROM store.store_sales_fact;


-- Q22. Find the single best-selling product (by total
--      sales_quantity) across all store transactions.
SELECT product_key, product_version, SUM(sales_quantity) AS total_qty
FROM store.store_sales_fact
GROUP BY product_key, product_version
ORDER BY total_qty DESC
LIMIT 1;


-- ============================================================
-- SECTION E — DATE & TIME ANALYSIS
-- ============================================================

-- Q23. Using date_dimension, find total store sales revenue by year.
SELECT dd.year, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN public.date_dimension dd ON s.date_key = dd.date_key
GROUP BY dd.year
ORDER BY dd.year;


-- Q24. Find total store sales revenue by month, for the most
--      recent year of data available.
SELECT dd.month, SUM(s.sales_dollar_amount) AS revenue
FROM store.store_sales_fact s
JOIN public.date_dimension dd ON s.date_key = dd.date_key
WHERE dd.year = (SELECT MAX(year) FROM public.date_dimension)
GROUP BY dd.month
ORDER BY dd.month;
-- Adjust column name (month vs month_of_year) to match your date_dimension.


-- Q25. Which day of the week generates the highest average
--      transaction value in stores?
SELECT dd.day_of_week, AVG(s.sales_dollar_amount) AS avg_txn
FROM store.store_sales_fact s
JOIN public.date_dimension dd ON s.date_key = dd.date_key
GROUP BY dd.day_of_week
ORDER BY avg_txn DESC;


-- Q26. Find all store sales transactions that happened after
--      6:00 PM (transaction_time), and count them by hour.
SELECT EXTRACT(HOUR FROM transaction_time) AS hr, COUNT(*) AS txns
FROM store.store_sales_fact
WHERE transaction_time > '18:00:00'
GROUP BY hr
ORDER BY hr;


-- Q27. Calculate the number of days between date_ordered and
--      date_delivered for every row in store_orders_fact, and
--      find the average fulfillment time in days.
SELECT AVG(date_delivered - date_ordered) AS avg_fulfillment_days
FROM store.store_orders_fact
WHERE date_delivered IS NOT NULL;


-- ============================================================
-- SECTION F — STRING & DATA CLEANUP
-- ============================================================

-- Q28a. Display customer names in UPPERCASE.
SELECT UPPER(customer_name) FROM public.customer_dimension;


-- Q28b. Display product descriptions in lowercase.
SELECT LOWER(product_description) FROM public.product_dimension;


-- Q29. Extract the first 3 characters of every sku_number in
--      product_dimension and count how many products share each
--      3-character prefix.
SELECT LEFT(sku_number, 3) AS prefix, COUNT(*) AS product_count
FROM public.product_dimension
GROUP BY prefix
ORDER BY product_count DESC;


-- Q30. Find all customers whose occupation contains the word
--      'Manager' anywhere in the string.
SELECT * FROM public.customer_dimension WHERE occupation ILIKE '%Manager%';


-- Q31. Display employee full name as a single column:
--      LastName, FirstName (comma-separated, no extra spaces).
SELECT employee_last_name || ', ' || employee_first_name AS full_name
FROM public.employee_dimension;


-- ============================================================
-- SECTION G — SUBQUERIES & SET LOGIC
-- ============================================================

-- Q32. List all products that have never been sold in-store
--      (i.e., don't appear in store_sales_fact at all).
SELECT p.product_key, p.product_description
FROM public.product_dimension p
LEFT JOIN store.store_sales_fact s
  ON p.product_key = s.product_key AND p.product_version = s.product_version
WHERE s.product_key IS NULL;


-- Q33. Find all customers whose total spend is greater than the
--      average total spend across all customers.
SELECT customer_key, SUM(sales_dollar_amount) AS spend
FROM store.store_sales_fact
GROUP BY customer_key
HAVING SUM(sales_dollar_amount) > (
  SELECT AVG(cust_total) FROM (
    SELECT SUM(sales_dollar_amount) AS cust_total
    FROM store.store_sales_fact GROUP BY customer_key
  ) t
);


-- Q34. List all stores where average transaction value is higher
--      than the company-wide average transaction value.
SELECT store_key, AVG(sales_dollar_amount) AS avg_txn
FROM store.store_sales_fact
GROUP BY store_key
HAVING AVG(sales_dollar_amount) > (SELECT AVG(sales_dollar_amount) FROM store.store_sales_fact);


-- Q35. Using a set operation, find product keys that were sold
--      both in-store and online (INTERSECT).
SELECT product_key FROM store.store_sales_fact
INTERSECT
SELECT product_key FROM online_sales.online_sales_fact;


-- Q36. Using a set operation, find product keys that were sold
--      online but never in-store (EXCEPT / MINUS).
SELECT product_key FROM online_sales.online_sales_fact
EXCEPT
SELECT product_key FROM store.store_sales_fact;


-- ============================================================
-- SECTION H — WINDOW & ANALYTIC FUNCTIONS
-- ============================================================

-- Q37. For each store sale, show sales_dollar_amount alongside a
--      running total of revenue for that store, ordered by date
--      (SUM() OVER (PARTITION BY ... ORDER BY ...)).
SELECT store_key, date_key, sales_dollar_amount,
       SUM(sales_dollar_amount) OVER (
         PARTITION BY store_key ORDER BY date_key
         ROWS UNBOUNDED PRECEDING
       ) AS running_total
FROM store.store_sales_fact
ORDER BY store_key, date_key;


-- Q38. Rank products within each category by total revenue using
--      RANK() — show only the top 3 per category.
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


-- Q39. For each store, calculate its revenue and its percentage
--      contribution to total company revenue using
--      RATIO_TO_REPORT (Vertica-specific — look it up).
SELECT store_key, SUM(sales_dollar_amount) AS revenue,
       RATIO_TO_REPORT(SUM(sales_dollar_amount)) OVER () AS pct_of_total
FROM store.store_sales_fact
GROUP BY store_key
ORDER BY pct_of_total DESC;


-- Q40. Using LAG(), compare each month's total revenue to the
--      previous month's revenue and calculate the month-over-month
--      % change.
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


-- Q41. Use NTILE(4) to split all customers into four spending
--      quartiles based on their total purchase amount.
SELECT customer_key, total_spend,
       NTILE(4) OVER (ORDER BY total_spend) AS spend_quartile
FROM (
  SELECT customer_key, SUM(sales_dollar_amount) AS total_spend
  FROM store.store_sales_fact
  GROUP BY customer_key
) t;


-- Q42. Find, for each customer, their most recent purchase date
--      and how many days ago that was, using a window function
--      rather than a correlated subquery.
SELECT DISTINCT customer_key,
       FIRST_VALUE(date_key) OVER (PARTITION BY customer_key ORDER BY date_key DESC) AS most_recent_date_key,
       CURRENT_DATE - FIRST_VALUE(date_key) OVER (PARTITION BY customer_key ORDER BY date_key DESC) AS days_ago
FROM store.store_sales_fact;
-- Note: assumes date_key is stored as an actual DATE; if it's a
-- surrogate integer key, join to date_dimension first and use the
-- real date column.


-- ============================================================
-- SECTION I — VIEWS & WRAP-UP
-- ============================================================

-- Q43. Create a view vw_category_performance showing category
--      name, total revenue, and total quantity sold.
CREATE VIEW public.vw_category_performance AS
SELECT p.category_description,
       SUM(s.sales_dollar_amount) AS total_revenue,
       SUM(s.sales_quantity) AS total_quantity
FROM store.store_sales_fact s
JOIN public.product_dimension p
  ON s.product_key = p.product_key AND s.product_version = p.product_version
GROUP BY p.category_description;


-- Q44. Create a view vw_customer_360 that unions each customer's
--      store purchases and online purchases into one
--      row-per-transaction feed, with a column indicating the
--      channel ('Store' or 'Online').
CREATE VIEW public.vw_customer_360 AS
SELECT customer_key, date_key, sales_dollar_amount, 'Store' AS channel FROM store.store_sales_fact
UNION ALL
SELECT customer_key, date_key, sales_dollar_amount, 'Online' AS channel FROM online_sales.online_sales_fact;


-- Q45. Using the view from Q44, find the top 10 customers by total
--      spend across both channels. Add a one-line comment: which
--      approach (this vs. Q16) is better for a dashboard that gets
--      queried repeatedly, and why?
SELECT customer_key, SUM(sales_dollar_amount) AS total_spend
FROM public.vw_customer_360
GROUP BY customer_key
ORDER BY total_spend DESC
LIMIT 10;
-- Talking point: the view doesn't make the query itself faster (it's
-- not materialized), but it makes the dashboard/BI layer simpler and
-- consistent — analysts stop hand-writing the UNION ALL every time.
-- If this got queried constantly, the follow-up discussion is
-- materialized views / projections.


-- ============================================================
-- STRETCH GOALS (OPTIONAL)
-- ============================================================

-- Q46 [stretch]. Use TIMESERIES to fill in gaps for days with zero
--                sales, so a revenue trend chart doesn't show
--                misleading breaks.
SELECT slice_time, SUM(sales_dollar_amount) AS revenue
FROM store.store_sales_fact TIMESERIES slice_time AS '1 day' OVER (ORDER BY transaction_time)
GROUP BY slice_time
ORDER BY slice_time;
-- Confirm exact TIMESERIES syntax against the Vertica version
-- installed — good "read the docs live" moment for trainees.


-- Q47 [stretch]. Use APPROXIMATE_COUNT_DISTINCT to estimate
--                distinct customers in store_sales_fact, and
--                compare result/runtime against an exact
--                COUNT(DISTINCT ...).
SELECT APPROXIMATE_COUNT_DISTINCT(customer_key) FROM store.store_sales_fact;
SELECT COUNT(DISTINCT customer_key) FROM store.store_sales_fact;
-- Compare both value and execution time (\timing is already on).


-- Q48 [stretch]. No query needed — explain in a comment why
--                joining on (product_key, product_version) matters
--                for correctness, and what breaks if you join on
--                product_key alone.
-- If you join on product_key alone, a re-versioned product fans out
-- -- one sale could match multiple product_version rows in
-- product_dimension, silently duplicating revenue in the join.
-- Always join on the full composite key.
