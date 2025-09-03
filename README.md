# All SQL

## Normalization

| CustomerID | Customer Name | Purchased Products |
|------------|---------------|--------------------|
| 1          | John Doe      | Laptop, Mouse      |
| 2          | Jane Smith    | Keyboard           |
| 3          | Alice Johnson | Monitor, Laptop    |
| 4          | Bob Brown     | Mouse              |
| 5          | Charlie Davis | Laptop, Keyboard   |
| 6          | Eve Wilson    | Monitor            |
| 7          | Frank Miller  | Mouse, Keyboard    |
| 8          | Grace Lee     | Laptop             |
| 9          | Henry Clark   | Monitor, Mouse     |
| 10         | Irene Scott   | Keyboard, Laptop   |

### 1NF 

* Eliminate Repeating Groups
* Ensures that each column contains only atomic values
* Each record is unique

| CustomerID | Customer Name | Purchased Products |
|------------|---------------|--------------------|
| 1          | John Doe      | Laptop             |
| 1          | John Doe      | Mouse              |
| 2          | Jane Smith    | Keyboard           |
| 3          | Alice Johnson | Monitor            |
| 3          | Alice Johnson | Laptop             |
| 4          | Bob Brown     | Mouse              |
| 5          | Charlie Davis | Laptop             |
| 5          | Charlie Davis | Keyboard           |
| 6          | Eve Wilson    | Monitor            |
| 7          | Frank Miller  | Mouse              |
| 7          | Frank Miller  | Keyboard           |
| 8          | Grace Lee     | Laptop             |
| 9          | Henry Clark   | Monitor            |
| 9          | Henry Clark   | Mouse              |
| 10         | Irene Scott   | Keyboard           |
| 10         | Irene Scott   | Laptop             |

### 2NF

* Meet all the requirements of 1NF
* Eliminates partial dependencies

| OrderID  | Customer ID | Customer Name | Purchased Products |
|----------|--------------|---------------|--------------------|
| 1001     | 1            | John Doe      | Laptop             |
| 1002     | 1            | John Doe      | Mouse              |
| 1003     | 2            | Jane Smith    | Keyboard           |
| 1004     | 3            | Alice Johnson | Monitor            |
| 1005     | 3            | Alice Johnson | Laptop             |
| 1006     | 4            | Bob Brown     | Mouse              |
| 1007     | 5            | Charlie Davis | Laptop             |
| 1008     | 5            | Charlie Davis | Keyboard           |
| 1009     | 6            | Eve Wilson    | Monitor            |
| 1010     | 7            | Frank Miller  | Mouse              |
| 1011     | 7            | Frank Miller  | Keyboard           |
| 1012     | 8            | Grace Lee     | Laptop             |
| 1013     | 9            | Henry Clark   | Monitor            |
| 1014     | 9            | Henry Clark   | Mouse              |
| 1015     | 10           | Irene Scott   | Keyboard           |
| 1016     | 10           | Irene Scott   | Laptop             |

* Now, apply the 2NF

**Customers Table**

| Customer ID | Customer Name |
|--------------|---------------|
| 1            | John Doe      |
| 2            | Jane Smith    |
| 3            | Alice Johnson |
| 4            | Bob Brown     |
| 5            | Charlie Davis |
| 6            | Eve Wilson    |
| 7            | Frank Miller  |
| 8            | Grace Lee     |
| 9            | Henry Clark   |
| 10           | Irene Scott   |

**Orders Table**

| OrderID  | Customer ID | Purchased Products |
|----------|--------------|--------------------|
| 1001     | 1            | Laptop             |
| 1002     | 1            | Mouse              |
| 1003     | 2            | Keyboard           |
| 1004     | 3            | Monitor            |
| 1005     | 3            | Laptop             |
| 1006     | 4            | Mouse              |
| 1007     | 5            | Laptop             |
| 1008     | 5            | Keyboard           |
| 1009     | 6            | Monitor            |
| 1010     | 7            | Mouse              |
| 1011     | 7            | Keyboard           |
| 1012     | 8            | Laptop             |
| 1013     | 9            | Monitor            |
| 1014     | 9            | Mouse              |
| 1015     | 10           | Keyboard           |
| 1016     | 10           | Laptop             |

### 3NF

* Meet all the requirements of 2NF
* Eliminate columns not dependent on the key
* Eliminates transitive dependencies

**Customers Table**
| Customer ID | Customer Name |
|--------------|---------------|
| 1            | John Doe      |
| 2            | Jane Smith    |
| 3            | Alice Johnson |
| 4            | Bob Brown     |
| 5            | Charlie Davis |
| 6            | Eve Wilson    |
| 7            | Frank Miller  |
| 8            | Grace Lee     |
| 9            | Henry Clark   |
| 10           | Irene Scott   |

**Suppliers Table**
| Supplier ID | Supplier Name |
|-------------|---------------|
| 1           | Tech Supplies |
| 2           | Office Goods  |
| 3           | Gadget World  |

**Products Table**
| Product ID | Product Name |
|------------|--------------|
| 1          | Laptop       |
| 2          | Mouse        |
| 3          | Keyboard     |
| 4          | Monitor      |

**Products by Supplier**
| ItemID | Product ID | Supplier ID |
|--------|------------|-------------|
| 501    | 1          | 1           |
| 502    | 2          | 2           |
| 503    | 3          | 2           |
| 504    | 4          | 3           |

**Orders Table**
| OrderID | Customer ID | Product_Supplier |
|---------|--------------|------------------|
| 1001    | 1            | 501              |
| 1002    | 1            | 502              |
| 1003    | 2            | 503              |
| 1004    | 3            | 504              |
| 1005    | 3            | 501              |
| 1006    | 4            | 502              |
| 1007    | 5            | 501              |
| 1008    | 5            | 503              |
| 1009    | 6            | 504              |
| 1010    | 7            | 502              |
| 1011    | 7            | 503              |
| 1012    | 8            | 501              |
| 1013    | 9            | 504              |
| 1014    | 9            | 502              |
| 1015    | 10           | 503              |
| 1016    | 10           | 501              |


### 4FN

* Meet all the requirements of 3NF
* No multi-valued dependencies

### 5FN

* Meet all the requirements of 4NF
* Addresses join dependencies

## Crash Course information

* Three different ways to write the same query

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
USE my_new_db;
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
    * SELECT
* Data Definition Language
    * CREATE, ALTER, DROP
* Data Manipulation Language
    * INSERT, UPDATE, DELETE
* Data Control Language
    * GRANT, REVOKE
* Transaction Control Language
    * COMMIT, ROLLBACK

* Database is a place to store data in an organized way.
* Star Schema: which is a basic way of organizing tables in a database:
    * It has a fact table
    * It is surrounded by dimension tables (lookup tables)
* Data Model: is how you want to organize your database
* Schema: is to take action with your data model
* Constraints: It is a rule that specifies what data can be insert into a table
    * NOT NULL
        * `id VARCHAR(100) NOT NULL`
    * DEFAULT
        * `name VARCHAR(2) DEFAULT 'CA'`
    * CHECK
        * `country VARCHAR(2), CHECK (coutry in ('CA', 'US'))`
        * `CHECK (id > 100 AND country IN ('CA', 'US'))`
    * UNIQUE
        * `id INTEGER UNIQUE`
        * `UNIQUE (id)`
        * `CONSTRAINT unq_country_name UNIQUE (country, name)`
    * PRIMARY KEY
        * `id VARCHAR(36) PRIMARY KEY DEFAULT (UUID())`
        * `CONSTRAINT pk_id_name PRIMARY KEY (id, name)`
    * FOREIGN KEY
        * `FOREIGN KEY (order_id) REFERENCES orders (o_id)`
        * `CONSTRAINT fk_id_name FOREIGN KEY (order_id, location) REFERENCES orders (o_id, o_location)`
* Automatic Creation
    * `u_id INTEGER PRIMARY KEY AUTO_INCREMENT`

* Also you can insert the results from a query into a new table

```sql
INSERT INTO new_table_two_columns (id, name)
SELECT id, name FROM old_table WHERE id < 100;
```

## Insert Data From a file

```csv
order_status_name, description
"P", "Pending"
"C", "Completed"
"F", "Failed"
"R", "Refunded"
```

* If MySQL gives you an error that sayes that loading data is disabled

```sql
SET GLOBAL local_infile = 1;
quit
```

```sql
LOAD DATA LOCAL INFILE '/Users/frgonzal/Desktop/order_status_name.csv'
INTO TABLE orders_status FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
```