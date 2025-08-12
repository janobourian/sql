# All SQL

## Crash Course information

* Three different ways to write the same query0

```sql
SELECT * FROM birthdays LIMIT 10;
SELECT TOP 10 * FROM birthdays;
SELECT * FROM birthdays WHERE ROWNUM <= 10;
```

* Another example

```sql
SELECT *
FROM my_table
WHERE column1 >= 10
ORDER BY column2;
```

* The general order

```sql
SELECT    -- columns to display
FROM      -- table(s) to pull from
WHERE     -- filter rows
GROUP BY  -- split rows into groups
HAVING    -- filter grouped rows
ORDER BY  -- columns to sort
```

## Start MySQL

```bash
brew services start mysql
mysql -u root
show databases;
show tables;
quit
```

* First commands

```sql
CREATE TABLE test (id int, num int);
INSERT INTO test VALUES (1, 100), (2, 200);
SELECT * FROM test LIMIT 1;
```

* A semi-complex query using keywords, functions, identifiers, and aliases.

```sql
SELECT e.name, COUNT(s.sale_id) AS num_sales
FROM employee e
    LEFT JOIN sales s ON e.emp_id = s.emp_id
WHERE YEAR(s.sale_date) = 2021
    AND s.closed IS NOT NULL
GROUP BY e.name;
```

## Sublanguages

* Data Query Language
* Data Definition Language
* Data Manipulation Language
* Data Control Language
* Transaction Control Language