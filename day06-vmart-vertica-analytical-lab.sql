-- ============================================================
--  VMART ANALYTICAL SQL ASSIGNMENT — VERTICA
--  Database   : VMart (public / store / online_sales schemas)
--  Trainee    : ____________________
--  Batch      : ____________________
--
--  HOW TO WORK THIS FILE:
--  1. Each question is a commented block below.
--  2. Write your query directly UNDER the question, in the blank space.
--  3. Run it. If it errors or gives wrong results, fix it and rerun.
--  4. Once it works correctly, leave the FINAL working query
--     UNCOMMENTED (do not comment it out). Delete any broken
--     attempts — don't leave dead code behind.
--  5. Do NOT touch the question comments — keep them as markers.
--  6. When done, this whole file should run clean top-to-bottom
--     with: vsql -f VMart_Vertica_Analytical_Assignment.sql
-- ============================================================

\timing on

-- Before you start: run \d public.*, \d store.*, \d online_sales.*
-- (or query the columns system table) to confirm exact column
-- names on YOUR install. Don't copy-paste from memory.


-- ============================================================
-- SECTION A — KNOW YOUR SCHEMA (WARM-UP)
-- ============================================================

-- Q1. List every table in the store and online_sales schemas,
--     along with their schema name, using a system table query.


-- Q2. For store.store_sales_fact, list all columns with their
--     data types and whether they allow NULLs.


-- Q3. Identify the foreign key columns in store.store_sales_fact
--     and note (as a comment) which dimension table each points to.


-- Q4. How many rows are currently in store.store_sales_fact?
--     In online_sales.online_sales_fact?


-- Q5. product_dimension uses a composite key (product_key +
--     product_version) instead of a single surrogate key. Write
--     a query proving at least one product_key has more than one
--     product_version. Explain why, in a comment.


-- ============================================================
-- SECTION B — FILTERING & PROJECTION
-- ============================================================

-- Q6. List all customers from the state of 'CA' who are 'Married'.


-- Q7. List all products in the 'Diet Foods' category (check exact
--     spelling in your data first).


-- Q8. Find all store sales transactions where sales_dollar_amount
--     is greater than $500 in a single line.


-- Q9. List employees whose employee_last_name starts with 'S'.


-- Q10. Find all store sales where tender_type was 'Cash' and
--      sales_quantity was more than 5.


-- ============================================================
-- SECTION C — JOINS ACROSS FACTS & DIMENSIONS
-- ============================================================

-- Q11. List the customer name, product description, and sale
--      amount for the top 10 highest-value store sales transactions.


-- Q12. Display total revenue (sales_dollar_amount) by product
--      category, sorted highest to lowest.


-- Q13. Display total revenue by store state, joining
--      store_sales_fact -> store_dimension.


-- Q14. For each employee, show their name and the total dollar
--      amount of sales they've rung up. Sort by top performer first.


-- Q15. Compare store channel vs online channel: total revenue
--      from store_sales_fact vs total revenue from
--      online_sales_fact, side by side in one result set.


-- Q16. List the top 5 customers (by name) with the highest total
--      spend combined across both store and online sales.


-- ============================================================
-- SECTION D — AGGREGATION & GROUPING
-- ============================================================

-- Q17. Find the total, average, minimum, and maximum sale amount
--      per product department.


-- Q18. Count the number of transactions per tender_type.


-- Q19. Find product categories where total revenue exceeds
--      $1,000,000 (use HAVING).


-- Q20. Find the number of distinct customers who made a purchase
--      in each store.


-- Q21. Calculate the overall gross profit margin
--      (SUM(gross_profit_dollar_amount) / SUM(sales_dollar_amount))
--      for the whole store chain.


-- Q22. Find the single best-selling product (by total
--      sales_quantity) across all store transactions.


-- ============================================================
-- SECTION E — DATE & TIME ANALYSIS
-- ============================================================

-- Q23. Using date_dimension, find total store sales revenue by year.


-- Q24. Find total store sales revenue by month, for the most
--      recent year of data available.


-- Q25. Which day of the week generates the highest average
--      transaction value in stores?


-- Q26. Find all store sales transactions that happened after
--      6:00 PM (transaction_time), and count them by hour.


-- Q27. Calculate the number of days between date_ordered and
--      date_delivered for every row in store_orders_fact, and
--      find the average fulfillment time in days.


-- ============================================================
-- SECTION F — STRING & DATA CLEANUP
-- ============================================================

-- Q28a. Display customer names in UPPERCASE.


-- Q28b. Display product descriptions in lowercase.


-- Q29. Extract the first 3 characters of every sku_number in
--      product_dimension and count how many products share each
--      3-character prefix.


-- Q30. Find all customers whose occupation contains the word
--      'Manager' anywhere in the string.


-- Q31. Display employee full name as a single column:
--      LastName, FirstName (comma-separated, no extra spaces).


-- ============================================================
-- SECTION G — SUBQUERIES & SET LOGIC
-- ============================================================

-- Q32. List all products that have never been sold in-store
--      (i.e., don't appear in store_sales_fact at all).


-- Q33. Find all customers whose total spend is greater than the
--      average total spend across all customers.


-- Q34. List all stores where average transaction value is higher
--      than the company-wide average transaction value.


-- Q35. Using a set operation, find product keys that were sold
--      both in-store and online (INTERSECT).


-- Q36. Using a set operation, find product keys that were sold
--      online but never in-store (EXCEPT / MINUS).


-- ============================================================
-- SECTION H — WINDOW & ANALYTIC FUNCTIONS
-- (this is where Vertica shines — go slow, get this right)
-- ============================================================

-- Q37. For each store sale, show sales_dollar_amount alongside a
--      running total of revenue for that store, ordered by date
--      (SUM() OVER (PARTITION BY ... ORDER BY ...)).


-- Q38. Rank products within each category by total revenue using
--      RANK() — show only the top 3 per category.


-- Q39. For each store, calculate its revenue and its percentage
--      contribution to total company revenue using
--      RATIO_TO_REPORT (Vertica-specific — look it up).


-- Q40. Using LAG(), compare each month's total revenue to the
--      previous month's revenue and calculate the month-over-month
--      % change.


-- Q41. Use NTILE(4) to split all customers into four spending
--      quartiles based on their total purchase amount.


-- Q42. Find, for each customer, their most recent purchase date
--      and how many days ago that was, using a window function
--      rather than a correlated subquery.


-- ============================================================
-- SECTION I — VIEWS & WRAP-UP
-- ============================================================

-- Q43. Create a view vw_category_performance showing category
--      name, total revenue, and total quantity sold.


-- Q44. Create a view vw_customer_360 that unions each customer's
--      store purchases and online purchases into one
--      row-per-transaction feed, with a column indicating the
--      channel ('Store' or 'Online').


-- Q45. Using the view from Q44, find the top 10 customers by total
--      spend across both channels. Add a one-line comment: which
--      approach (this vs. Q16) is better for a dashboard that gets
--      queried repeatedly, and why?


-- ============================================================
-- STRETCH GOALS (OPTIONAL — flag if you finish early)
-- ============================================================

-- Q46 [stretch]. Use TIMESERIES to fill in gaps for days with zero
--                sales, so a revenue trend chart doesn't show
--                misleading breaks.


-- Q47 [stretch]. Use APPROXIMATE_COUNT_DISTINCT to estimate
--                distinct customers in store_sales_fact, and
--                compare result/runtime against an exact
--                COUNT(DISTINCT ...).


-- Q48 [stretch]. No query needed — explain in a comment why
--                joining on (product_key, product_version) matters
--                for correctness, and what breaks if you join on
--                product_key alone.

