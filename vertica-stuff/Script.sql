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

--Databases, schemas, tables — the hierarchy
-- ----------------------------------------- 

CREATE SCHEMA IF NOT EXISTS training;


CREATE TABLE training.customers (
    customer_id  INTEGER,
    name         VARCHAR(50),
    city         VARCHAR(50),
    signup_date  DATE
);

CREATE TABLE training.products (
    product_id    INTEGER,
    product_name  VARCHAR(50),
    category      VARCHAR(30),
    price         NUMERIC(10,2)
);

CREATE TABLE training.orders (
    order_id     INTEGER,
    customer_id  INTEGER,
    product_id   INTEGER,
    quantity     INTEGER,
    order_date   DATE
);

SELECT * FROM training.customers; 
SELECT * FROM training.products; 
SELECT * FROM training.orders; 

INSERT INTO training.customers VALUES (1, 'Asha Rao', 'Hyderabad', '2024-01-15');
INSERT INTO training.customers VALUES (2, 'Vikram Shah', 'Mumbai', '2024-02-20');
UPDATE training.customers SET city = 'Bengaluru' WHERE customer_id = 2;
DELETE FROM training.customers WHERE customer_id = 99;   -- no-op if it doesn't exist, that's fine

-- some more inserts -- 

-- Customers: original 2 (Asha, Vikram/Bengaluru after UPDATE) plus 4 more
INSERT INTO training.customers VALUES
    (3, 'Neha Verma', 'Bengaluru', '2024-01-10'),
    (4, 'Rahul Gupta', 'Hyderabad', '2024-02-05'),
    (5, 'Sonia Kapoor', 'Mumbai', '2024-03-12'),
    (6, 'Arjun Mehta', 'Bengaluru', '2024-04-01');

-- Products, all 5 in one statement
INSERT INTO training.products VALUES
    (1, 'Wireless Mouse', 'Electronics', 799.00),
    (2, 'Notebook Set', 'Stationery', 149.00),
    (3, 'Bluetooth Speaker', 'Electronics', 1999.00),
    (4, 'Desk Lamp', 'Home', 599.00),
    (5, 'Backpack', 'Accessories', 1299.00);

-- Orders, all 9 in one statement
INSERT INTO training.orders VALUES
    (1, 1, 1, 2, '2024-03-01'),
    (2, 2, 2, 5, '2024-03-02'),
    (3, 2, 3, 1, '2024-03-03'),
    (4, 3, 1, 2, '2024-03-04'),
    (5, 3, 4, 1, '2024-03-05'),
    (6, 6, 5, 1, '2024-03-06'),
    (7, 4, 2, 3, '2024-03-07'),
    (8, 1, 3, 1, '2024-03-08'),
    (9, 5, 1, 1, '2024-03-09');

SELECT * FROM training.customers; 
SELECT * FROM training.products; 
SELECT * FROM training.orders; 

SELECT * FROM training.customers WHERE city = 'Bengaluru';

SELECT c.name, o.order_id, o.quantity, p.product_name
FROM training.orders o
JOIN training.customers c ON o.customer_id = c.customer_id
JOIN training.products p ON o.product_id = p.product_id;

SELECT c.city, COUNT(*) AS total_orders
FROM training.orders o
JOIN training.customers c ON o.customer_id = c.customer_id
GROUP BY c.city
ORDER BY total_orders DESC;

SELECT
    COUNT(*) AS number_of_sales,
    SUM(sales_dollar_amount) AS total_sales
FROM store.store_sales_fact;

SELECT p.category_description, SUM(f.sales_dollar_amount) AS category_sales
FROM store.store_sales_fact f
JOIN public.product_dimension p ON f.product_key = p.product_key
GROUP BY p.category_description
ORDER BY category_sales DESC;


