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

SELECT table_schema, table_name
FROM v_catalog.tables
WHERE table_schema IN ('store','online_sales')
ORDER BY 1,2;


-- Q2. For store.store_sales_fact, list all columns with their
--     data types and whether they allow NULLs.

SELECT column_name, data_type, is_nullable FROM columns
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

--SELECT column_name, data_type, ordinal_position FROM columns
--WHERE table_schema = 'public' AND table_name = 'customer_dimension';
--ORDER BY ordinal_position;

SELECT customer_name  FROM public.customer_dimension where marital_status = 'Married' and customer_state = 'CA';

-- Q7. List all products in the 'Diet Foods' category (check exact
--     spelling in your data first).

--select * from public.product_dimension where department_description  = 'Frozen Goods';
--select count(*) from public.product_dimension;
--select * from public.product_dimension;

select * from public.product_dimension where diet_type is not null;

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












-- RDBMS 
--
-- OLTP - MySQL - car 
-- OLAP - Vertica - bus 
--
--SELECT version();
--
-- how many table are there in this database?
--
--SELECT count(*) FROM Employees WHERE NAME = "Sonu"; 
--SELECT count(*) FROM eMployees WHERE name = 'SONU'; 
--
--Select count(*) FROM All_tables WHERE table_name = 'SAM'; 
--select count(*) FROM all_tables; 
--
--select * from employees;
--
--delete from employees;
--
--drop table employees;
--
--CREATE TABLE employees 
--( id INT, name VARCHAR(10), salary NUMBER(10, 2), 
--PRIMARY KEY (id)
--);
--
--select * from employees;
--
--insert into employees (id, name, salary) values (101, 'Sonu', 10.50);
--insert into employees (id, name, salary) values (102, 'Monu', 12.25);
--
--select * from employees;
--
--insert into employees (id, name, salary) values (101, 'Sonu', 10.50);
--
--update employees set salary = 15.75 where id = 102;
--
--delete from employees where id = 102;
--
--
--
--
--Databases, schemas, tables — the hierarchy
-- ----------------------------------------- 
--
--CREATE SCHEMA IF NOT EXISTS training;
--
--
--CREATE TABLE training.customers (
--    customer_id  INTEGER,
--    name         VARCHAR(50),
--    city         VARCHAR(50),
--    signup_date  DATE
--);
--
--CREATE TABLE training.products (
--    product_id    INTEGER,
--    product_name  VARCHAR(50),
--    category      VARCHAR(30),
--    price         NUMERIC(10,2)
--);
--
--CREATE TABLE training.orders (
--    order_id     INTEGER,
--    customer_id  INTEGER,
--    product_id   INTEGER,
--    quantity     INTEGER,
--    order_date   DATE
--);
--
--SELECT * FROM training.customers; 
--SELECT * FROM training.products; 
--SELECT * FROM training.orders; 
--
--INSERT INTO training.customers VALUES (1, 'Asha Rao', 'Hyderabad', '2024-01-15');
--INSERT INTO training.customers VALUES (2, 'Vikram Shah', 'Mumbai', '2024-02-20');
--UPDATE training.customers SET city = 'Bengaluru' WHERE customer_id = 2;
--DELETE FROM training.customers WHERE customer_id = 99;   -- no-op if it doesn't exist, that's fine
--
-- some more inserts -- 
--
--INSERT INTO training.customers VALUES
--    (3, 'Neha Verma', 'Bengaluru', '2024-01-10'),
--    (4, 'Rahul Gupta', 'Hyderabad', '2024-02-05'),
--    (5, 'Sonia Kapoor', 'Mumbai', '2024-03-12'),
--    (6, 'Arjun Mehta', 'Bengaluru', '2024-04-01');
--
--INSERT INTO training.products VALUES
--    (1, 'Wireless Mouse', 'Electronics', 799.00),
--    (2, 'Notebook Set', 'Stationery', 149.00),
--    (3, 'Bluetooth Speaker', 'Electronics', 1999.00),
--    (4, 'Desk Lamp', 'Home', 599.00),
--    (5, 'Backpack', 'Accessories', 1299.00);
--
--INSERT INTO training.orders VALUES
--    (1, 1, 1, 2, '2024-03-01'),
--    (2, 2, 2, 5, '2024-03-02'),
--    (3, 2, 3, 1, '2024-03-03'),
--    (4, 3, 1, 2, '2024-03-04'),
--    (5, 3, 4, 1, '2024-03-05'),
--    (6, 6, 5, 1, '2024-03-06'),
--    (7, 4, 2, 3, '2024-03-07'),
--    (8, 1, 3, 1, '2024-03-08'),
--    (9, 5, 1, 1, '2024-03-09');
--
--SELECT * FROM training.customers; 
--SELECT * FROM training.customers; 
--SELECT * FROM training.products; 
--SELECT * FROM training.orders; 
--
--SELECT * FROM training.customers WHERE city = 'Bengaluru';
--
-- All Orders details with customer name, quantity, and products
--
--SELECT c.name, o.order_id, o.quantity, p.product_name
--FROM training.orders o
--JOIN training.customers c ON o.customer_id = c.customer_id
--JOIN training.products p ON o.product_id = p.product_id;
--
-- cities generating the most order volume, highest first  
--
--SELECT c.city, COUNT(*) AS total_orders
--FROM training.orders o
--JOIN training.customers c ON o.customer_id = c.customer_id
--GROUP BY c.city
--ORDER BY total_orders DESC;
--
-- Total number of sales transactions and overall revenue across all stores
--
--SELECT
--    COUNT(*) AS number_of_sales,
--    SUM(sales_dollar_amount) AS total_sales
--FROM store.store_sales_fact;
--
-- Which product categories generate the most revenue, highest first
--
--SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
--FROM store.store_sales_fact f
--JOIN public.product_dimension p ON f.product_key = p.product_key
--GROUP BY p.category_description
--ORDER BY category_sales DESC;
--
--
-- All orders along with the name of the customer who placed each one 
--
--SELECT
--	c.customer_id,
--    c.name AS cust_name,
--    o.order_id,
--    o.order_date
--FROM training.customers AS c
--JOIN training.orders AS o
--    ON c.customer_id = c.customer_id;
--
--SELECT
--    training.customers.name,
--    training.orders.order_id,
--    training.orders.order_date
--FROM training.customers
--JOIN training.orders
--    ON training.customers.customer_id = training.orders.customer_id;
--
--
--SELECT current_schema();
--SET search_path TO training;
--
-- How many orders Rahul Gupta placed so far? 
--
--SELECT
--	COUNT(training.orders.order_id) AS order_count
--FROM
--	training.customers
--JOIN training.orders
--    ON
--	training.customers.customer_id = training.orders.customer_id
--WHERE
--	training.customers.name = 'Rahul Gupta';
--
--SELECT
--    training.customers.customer_id,
--    training.customers.name,
--    COUNT(training.orders.order_id) AS order_count
--FROM training.customers
--JOIN training.orders
--    ON training.customers.customer_id = training.orders.customer_id
--GROUP BY training.customers.customer_id, training.customers.name;
--
--SELECT
--    COUNT(*) AS number_of_sales,
--    SUM(sales_dollar_amount) AS total_sales
--FROM store.store_sales_fact;
--
--SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
--FROM store.store_sales_fact f
--JOIN public.product_dimension p ON f.product_key = p.product_key
--GROUP BY p.category_description
--ORDER BY category_sales DESC
--LIMIT 5;
--
--
--
--
--
--
--
--
\d training.customers;
