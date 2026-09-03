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
