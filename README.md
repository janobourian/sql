# Relational Database Engineering & Enterprise SQL Curriculum

Welcome to the **Relational Database Engineering & Enterprise SQL** repository. This repository provides a complete 16-module enterprise encyclopedia and hands-on curriculum covering relational schema design, 1NF to 5NF normalization, SQL sublanguages, indexing strategies, transactions, query optimization (`EXPLAIN ANALYZE`), security, and high availability.

---

## 📚 Complete Documentation Curriculum

The comprehensive modular guides are available in the [`docs/`](docs/) directory:

1. [Module 00: Relational Database Foundations, RDBMS Engines & ACID Guarantees](docs/00_relational_database_foundations_rdbms_engines_and_acid.md)
2. [Module 01: DDL, Table Design, Data Types & Normalization (1NF to 5NF)](docs/01_ddl_table_design_data_types_and_constraints.md)
3. [Module 02: DML, CRUD Operations, Upserts & Batch Processing](docs/02_dml_crud_operations_upserts_and_batch_processing.md)
4. [Module 03: Query Fundamentals, Filtering, Sorting & NULL 3-Valued Logic](docs/03_query_fundamentals_filtering_sorting_and_null_semantics.md)
5. [Module 04: Joins Deep Dive: Inner, Outer, Cross, Self & Anti-Joins](docs/04_joins_deep_dive_inner_outer_cross_self_and_anti_joins.md)
6. [Module 05: Aggregations, GROUP BY, HAVING, GROUPING SETS & ROLLUP](docs/05_aggregations_group_by_having_and_cube_rollup.md)
7. [Module 06: Subqueries, Correlated Queries & Common Table Expressions (CTEs)](docs/06_subqueries_correlated_queries_and_common_table_expressions_ctes.md)
8. [Module 07: Advanced Window Functions: Ranking, Analytics & Window Frames](docs/07_advanced_window_functions_ranking_analytics_and_frames.md)
9. [Module 08: Transactions, ACID Guarantees, Isolation Levels & MVCC](docs/08_transactions_acid_guarantees_isolation_levels_and_mvcc.md)
10. [Module 09: Indexing Strategies: B-Tree, Hash, GIN, GiST, BRIN & Covering Indexes](docs/09_indexing_strategies_btree_hash_gin_gist_and_covering_indexes.md)
11. [Module 10: Query Optimization, Cost-Based Optimizers & EXPLAIN ANALYZE](docs/10_query_optimization_execution_plans_and_explain_analyze.md)
12. [Module 11: Stored Procedures, User-Defined Functions (PL/pgSQL) & Triggers](docs/11_stored_procedures_user_defined_functions_and_triggers.md)
13. [Module 12: Views, Materialized Views & Declarative Table Partitioning](docs/12_views_materialized_views_and_declarative_partitioning.md)
14. [Module 13: Database Security: RBAC, Row-Level Security (RLS) & Encryption](docs/13_database_security_rbac_row_level_security_and_encryption.md)
15. [Module 14: High Availability, Streaming Replication, Connection Pooling & Sharding](docs/14_high_availability_streaming_replication_and_sharding.md)
16. [Module 15: Real-World Enterprise SQL Case Studies & Performance Blueprints](docs/15_real_world_enterprise_sql_case_studies_and_blueprints.md)
17. [Master Curriculum Index](docs/index.md)

---

## 📌 Original Repository Guides & Quick-Start Notes (Preserved)

### Normalization

| CustomerID | Customer Name | Purchased Products |
| :--- | :--- | :--- |
| 1 | John Doe | Laptop, Mouse |
| 2 | Jane Smith | Keyboard |
| 3 | Alice Johnson | Monitor, Laptop |
| 4 | Bob Brown | Mouse |
| 5 | Charlie Davis | Laptop, Keyboard |
| 6 | Eve Wilson | Monitor |
| 7 | Frank Miller | Mouse, Keyboard |
| 8 | Grace Lee | Laptop |
| 9 | Henry Clark | Monitor, Mouse |
| 10 | Irene Scott | Keyboard, Laptop |

#### 1NF

* Eliminate Repeating Groups
* Ensures that each column contains only atomic values
* Each record is unique

| CustomerID | Customer Name | Purchased Products |
| :--- | :--- | :--- |
| 1 | John Doe | Laptop |
| 1 | John Doe | Mouse |
| 2 | Jane Smith | Keyboard |
| 3 | Alice Johnson | Monitor |
| 3 | Alice Johnson | Laptop |
| 4 | Bob Brown | Mouse |
| 5 | Charlie Davis | Laptop |
| 5 | Charlie Davis | Keyboard |
| 6 | Eve Wilson | Monitor |
| 7 | Frank Miller | Mouse |
| 7 | Frank Miller | Keyboard |
| 8 | Grace Lee | Laptop |
| 9 | Henry Clark | Monitor |
| 9 | Henry Clark | Mouse |
| 10 | Irene Scott | Keyboard |
| 10 | Irene Scott | Laptop |

#### 2NF

* Meet all the requirements of 1NF
* Eliminates partial dependencies

| OrderID | Customer ID | Customer Name | Purchased Products |
| :--- | :--- | :--- | :--- |
| 1001 | 1 | John Doe | Laptop |
| 1002 | 1 | John Doe | Mouse |
| 1003 | 2 | Jane Smith | Keyboard |
| 1004 | 3 | Alice Johnson | Monitor |
| 1005 | 3 | Alice Johnson | Laptop |
| 1006 | 4 | Bob Brown | Mouse |
| 1007 | 5 | Charlie Davis | Laptop |
| 1008 | 5 | Charlie Davis | Keyboard |
| 1009 | 6 | Eve Wilson | Monitor |
| 1010 | 7 | Frank Miller | Mouse |
| 1011 | 7 | Frank Miller | Keyboard |
| 1012 | 8 | Grace Lee | Laptop |
| 1013 | 9 | Henry Clark | Monitor |
| 1014 | 9 | Henry Clark | Mouse |
| 1015 | 10 | Irene Scott | Keyboard |
| 1016 | 10 | Irene Scott | Laptop |

* Now, apply the 2NF

**Customers Table**

| Customer ID | Customer Name |
| :--- | :--- |
| 1 | John Doe |
| 2 | Jane Smith |
| 3 | Alice Johnson |
| 4 | Bob Brown |
| 5 | Charlie Davis |
| 6 | Eve Wilson |
| 7 | Frank Miller |
| 8 | Grace Lee |
| 9 | Henry Clark |
| 10 | Irene Scott |

**Orders Table**

| OrderID | Customer ID | Purchased Products |
| :--- | :--- | :--- |
| 1001 | 1 | Laptop |
| 1002 | 1 | Mouse |
| 1003 | 2 | Keyboard |
| 1004 | 3 | Monitor |
| 1005 | 3 | Laptop |
| 1006 | 4 | Mouse |
| 1007 | 5 | Laptop |
| 1008 | 5 | Keyboard |
| 1009 | 6 | Monitor |
| 1010 | 7 | Mouse |
| 1011 | 7 | Keyboard |
| 1012 | 8 | Laptop |
| 1013 | 9 | Monitor |
| 1014 | 9 | Mouse |
| 1015 | 10 | Keyboard |
| 1016 | 10 | Laptop |

#### 3NF

* Meet all the requirements of 2NF
* Eliminate columns not dependent on the key
* Eliminates transitive dependencies

**Customers Table**
| Customer ID | Customer Name |
| :--- | :--- |
| 1 | John Doe |
| 2 | Jane Smith |
| 3 | Alice Johnson |
| 4 | Bob Brown |
| 5 | Charlie Davis |
| 6 | Eve Wilson |
| 7 | Frank Miller |
| 8 | Grace Lee |
| 9 | Henry Clark |
| 10 | Irene Scott |

**Suppliers Table**
| Supplier ID | Supplier Name |
| :--- | :--- |
| 1 | Tech Supplies |
| 2 | Office Goods |
| 3 | Gadget World |

**Products Table**
| Product ID | Product Name |
| :--- | :--- |
| 1 | Laptop |
| 2 | Mouse |
| 3 | Keyboard |
| 4 | Monitor |

**Products by Supplier**
| ItemID | Product ID | Supplier ID |
| :--- | :--- | :--- |
| 501 | 1 | 1 |
| 502 | 2 | 2 |
| 503 | 3 | 2 |
| 504 | 4 | 3 |

**Orders Table**
| OrderID | Customer ID | Product_Supplier |
| :--- | :--- | :--- |
| 1001 | 1 | 501 |
| 1002 | 1 | 502 |
| 1003 | 2 | 503 |
| 1004 | 3 | 504 |
| 1005 | 3 | 501 |
| 1006 | 4 | 502 |
| 1007 | 5 | 501 |
| 1008 | 5 | 503 |
| 1009 | 6 | 504 |
| 1010 | 7 | 502 |
| 1011 | 7 | 503 |
| 1012 | 8 | 501 |
| 1013 | 9 | 504 |
| 1014 | 9 | 502 |
| 1015 | 10 | 503 |
| 1016 | 10 | 501 |

#### 4NF

* Meet all the requirements of 3NF
* No multi-valued dependencies

#### 5NF

* Meet all the requirements of 4NF
* Addresses join dependencies

---

### Crash Course Information

* Three different ways to write the same query:

```sql
SELECT * FROM birthdays LIMIT 10;
SELECT TOP 10 * FROM birthdays;
SELECT * FROM birthdays WHERE ROWNUM <= 10;
```

* Another example:

```sql
SELECT *
FROM my_table
WHERE column1 >= 10
ORDER BY column2;
```

* The general order:

```sql
SELECT    -- columns to display
FROM      -- table(s) to pull from
WHERE     -- filter rows
GROUP BY  -- split rows into groups
HAVING    -- filter grouped rows
ORDER BY  -- columns to sort
```

---

### Start MySQL

```bash
brew services start mysql
mysql -u root
show databases;
show tables;
USE my_new_db;
quit
```

* First commands:

```sql
CREATE TABLE test (id int, num int);
INSERT INTO test VALUES (1, 100), (2, 200);
SELECT * FROM test LIMIT 1;
```

* A semi-complex query using keywords, functions, identifiers, and aliases:

```sql
SELECT e.name, COUNT(s.sale_id) AS num_sales
FROM employee e
    LEFT JOIN sales s ON e.emp_id = s.emp_id
WHERE YEAR(s.sale_date) = 2021
    AND s.closed IS NOT NULL
GROUP BY e.name;
```

---

### Sublanguages

* **Data Query Language (DQL)**: `SELECT`
* **Data Definition Language (DDL)**: `CREATE`, `ALTER`, `DROP`
* **Data Manipulation Language (DML)**: `INSERT`, `UPDATE`, `DELETE`
* **Data Control Language (DCL)**: `GRANT`, `REVOKE`
* **Transaction Control Language (TCL)**: `COMMIT`, `ROLLBACK`

* **Database**: A place to store data in an organized way.
* **Star Schema**: A basic way of organizing tables in a database:
  * Fact table surrounded by dimension tables (lookup tables).
* **Data Model**: How you want to organize your database.
* **Schema**: Taking action with your data model.
* **Constraints**: Rules specifying what data can be inserted into a table:
  * `NOT NULL`: `id VARCHAR(100) NOT NULL`
  * `DEFAULT`: `name VARCHAR(2) DEFAULT 'CA'`
  * `CHECK`: `CHECK (country IN ('CA', 'US'))`, `CHECK (id > 100 AND country IN ('CA', 'US'))`
  * `UNIQUE`: `id INTEGER UNIQUE`, `CONSTRAINT unq_country_name UNIQUE (country, name)`
  * `PRIMARY KEY`: `id VARCHAR(36) PRIMARY KEY DEFAULT (UUID())`, `CONSTRAINT pk_id_name PRIMARY KEY (id, name)`
  * `FOREIGN KEY`: `FOREIGN KEY (order_id) REFERENCES orders (o_id)`, `CONSTRAINT fk_id_name FOREIGN KEY (order_id, location) REFERENCES orders (o_id, o_location)`
* **Automatic Creation**: `u_id INTEGER PRIMARY KEY AUTO_INCREMENT`

* Insert the results from a query into a new table:

```sql
INSERT INTO new_table_two_columns (id, name)
SELECT id, name FROM old_table WHERE id < 100;
```

---

### Insert Data From a File

```csv
order_status_name, description
"P", "Pending"
"C", "Completed"
"F", "Failed"
"R", "Refunded"
```

* If MySQL gives you an error saying loading data is disabled:

```sql
SET GLOBAL local_infile = 1;
quit
```

```sql
LOAD DATA LOCAL INFILE '/Users/frgonzal/Desktop/order_status_name.csv'
INTO TABLE orders_status FIELDS TERMINATED BY ','
ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
```
