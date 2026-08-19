# Module 06: Subqueries, Correlated Queries, CTEs & Recursive Graph Traversal

**Track:** SQL Relational Engineering & Distributed Database Architecture
**Category:** Query Modularity, Recursive CTEs, Graph Traversal & CTE Inlining Mechanics
**Standard Identifier:** `DOC-STD-UNIVERSAL-2026`
**Status:** ✅ Completed

---

## 📑 Table of Contents

1. [High-Level Overview & Executive Summary](#1-high-level-overview--executive-summary)

2. [Subquery Typology: Scalar, Multi-Row & Correlated](#2-subquery-typology-scalar-multi-row--correlated)

3. [Common Table Expressions (CTEs) & Optimization Inlining](#3-common-table-expressions-ctes--optimization-inlining)

4. [Recursive CTE Architecture & Graph Traversal](#4-recursive-cte-architecture--graph-traversal)

5. [Certification & Exam Essentials (Cheat Sheet)](#5-certification--exam-essentials-cheat-sheet)

6. [Comparative Analysis Matrix: Subqueries vs CTEs vs Temp Tables](#6-comparative-analysis-matrix-subqueries-vs-ctes-vs-temp-tables)

7. [Performance & Resource Optimization](#7-performance--resource-optimization)

8. [In-Depth Engineering Perspectives](#8-in-depth-engineering-perspectives)

9. [Step-by-Step Hands-On Production Walkthrough](#9-step-by-step-hands-on-production-walkthrough)

10. [Pure CLI / Command Interface](#10-pure-cli--command-interface)

11. [Advanced Architecture & Edge-Case Failure Modes](#11-advanced-architecture--edge-case-failure-modes)

12. [Detailed Sub-Components & Subsystems](#12-detailed-sub-components--subsystems)

13. [References (The 5+5 Rule)](#13-references-the-55-rule)

14. [Universal FinOps & Resource Cost Governance](#14-universal-finops--resource-cost-governance)

---

## 1. High-Level Overview & Executive Summary

Subqueries and Common Table Expressions (`WITH` CTEs) provide the modular building blocks of complex SQL data transformations. Beyond standard syntactic readability, modern relational engines leverage **Subquery Unnesting** (decorrelation) to transform correlated subqueries into high-performance Hash Joins, while **Recursive CTEs (`WITH RECURSIVE`)** allow SQL developers to traverse arbitrary directed acyclic graphs (DAGs), bill-of-materials trees, and hierarchical permission models directly in the database engine without external graph traversal libraries.

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                   RECURSIVE CTE ENGINE STATE MACHINE                           │
├────────────────────────────────────────────────────────────────────────────────┤
│ 1. ANCHOR QUERY: Evaluates base relation (e.g. Root nodes where manager IS NULL)│
│    └──► Populates initial WORKING TABLE and RESULT SET                         │
│                                                                                │
│ 2. RECURSIVE LOOP (Repeats until Working Table is Empty):                      │
│    ┌────────────────────────────────────────────────────────────────────────┐  │
│    │ a. Executes Recursive Query joining Working Table with base relation   │  │
│    │ b. Appends matching child tuples to RESULT SET                         │  │
│    │ c. Replaces Working Table with NEW child tuples generated in step (a)  │  │
│    └────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│ 3. TERMINATION: Emits accumulated RESULT SET to downstream query operators     │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 👔 Executive Summary (For Managers & Non-Technical Stakeholders)

* **Business Purpose**: Hierarchical relationships exist across every enterprise—organizational reporting structures, multi-level product category trees, bill-of-materials manufacturing parts, and multi-tenant permission hierarchies.
* **How It Works**: Instead of executing dozens of recursive API calls back and forth between your application servers and database, Recursive CTEs compute the entire tree path, hierarchy depth, and rolled-up metrics inside a single database query.
* **Key Business Value & ROI**: Eliminates the "N+1 query problem" across microservices, reduces application network overhead by over 90%, and simplifies complex business reporting logic into maintainable, modular SQL blocks.

---

## 2. Subquery Typology: Scalar, Multi-Row & Correlated

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                           SUBQUERY CLASSIFICATION                              │
├───────────────────┬──────────────────────────┬─────────────────────────────────┤
│ Subquery Type     │ Output Cardinality       │ Optimization Behavior           │
├───────────────────┼──────────────────────────┼─────────────────────────────────┤
│ **Scalar**        │ Exactly 1 Row, 1 Column  │ Evaluated as a constant scalar  │
│ **Multi-Row**     │ Multiple Rows, 1 Column  │ Evaluated via `IN`, `ANY`, `ALL`│
│ **Correlated**    │ Evaluates outer row data │ Decorrelated into Semi/Anti-Join│
│ **Lateral Join**  │ Subquery per outer row   │ Parameterized subquery stream   │
└───────────────────┴──────────────────────────┴─────────────────────────────────┘
```

### 2.1 The Correlated Subquery Decorrelation Engine

In legacy database engines, a correlated subquery executed in a nested loop once for every single row in the outer table ($O(N \times M)$ complexity). Modern query planners automatically **unnest and decorrelate** these subqueries into fast **Hash Semi-Joins** or **Hash Anti-Joins**:

```sql
-- Correlated Subquery (Auto-decorrelated by modern CBO into a Hash Semi-Join):
SELECT c.customer_id, c.full_name
FROM customers c
WHERE (
    SELECT SUM(o.order_total)
    FROM orders o
    WHERE o.customer_id = c.customer_id
) > 5000.00;
```

---

## 3. Common Table Expressions (CTEs) & Optimization Inlining

### 3.1 CTE Inlining vs The Optimization Fence (`MATERIALIZED` vs `NOT MATERIALIZED`)

Historically (PostgreSQL 11 and earlier), all CTEs acted as an **Optimization Fence**: the engine materialized the CTE into a temporary memory table, preventing the optimizer from pushing downstream `WHERE` filters into the CTE.

In modern PostgreSQL (12+), CTEs are **inlined by default** unless specified otherwise:

```sql
-- 1. Inlined CTE (Default in PG 12+): Predicate 'created_at >= 2026-01-01'
-- is pushed down directly into the CTE's table scan!
WITH active_users AS (
    SELECT user_id, email, created_at FROM users WHERE is_active = TRUE
)
SELECT * FROM active_users WHERE created_at >= '2026-01-01';

-- 2. Explicitly MATERIALIZED CTE (Forces single evaluation for expensive CTEs):
WITH heavy_calculation AS MATERIALIZED (
    SELECT complex_math_function(id) AS score FROM large_table
)
SELECT * FROM heavy_calculation WHERE score > 90;
```

---

## 4. Recursive CTE Architecture & Graph Traversal

A **Recursive CTE** consists of three formal components:

1. **Anchor Query**: The non-recursive base case initializing the tree.
2. **`UNION ALL`**: Set operator combining iterations.
3. **Recursive Query**: Self-referencing step joining the CTE with the base table.

### Infinite Loop Protection & Cycle Detection

When traversing graphs with circular dependencies (e.g. Node A ──► Node B ──► Node A), a recursive CTE will loop infinitely until memory or disk space is exhausted.

**Cycle Detection with Path Tracking Arrays**:

```sql
WITH RECURSIVE graph_walk AS (
    -- Anchor:
    SELECT
        node_id,
        target_id,
        1 AS depth,
        ARRAY[node_id] AS path_visited,
        FALSE AS is_cycle
    FROM graph_edges
    WHERE node_id = 1

    UNION ALL

    -- Recursive Step:
    SELECT
        e.node_id,
        e.target_id,
        w.depth + 1,
        w.path_visited || e.node_id,
        e.node_id = ANY(w.path_visited) -- Cycle Detected!
    FROM graph_edges e
    JOIN graph_walk w ON e.node_id = w.target_id
    WHERE NOT w.is_cycle AND w.depth < 20 -- Safety Depth Limit!
)
SELECT depth, path_visited, is_cycle FROM graph_walk;
```

---

## 5. Certification & Exam Essentials (Cheat Sheet)

* ⚠️ **`IN (Subquery)` vs `EXISTS (Subquery)` with NULLs**: If the subquery in `WHERE id NOT IN (SELECT foreign_id FROM table)` contains a `NULL`, the entire query returns **zero rows**. Always use **`NOT EXISTS`** for safety.
* 🔒 **CTE Optimization Fences**: To prevent the query planner from re-evaluating a non-deterministic CTE (e.g. `random()` or `now()`), mark it explicitly as `WITH cte AS MATERIALIZED (...)`.
* ⚙️ **`UNION` vs `UNION ALL` in Recursive CTEs**:
  * `UNION ALL` evaluates faster because it appends child tuples directly without checking for duplicates.
  * `UNION` performs an expensive deduplication sort on every recursion step, but automatically terminates simple cycles.
* ⚠️ **LATERAL Joins vs Correlated Subqueries**: Use `JOIN LATERAL (SELECT ... LIMIT 3) ON TRUE` when you need to fetch the "Top N items per parent group" (e.g. Top 3 recent orders for each customer) efficiently with index seeks.

---

## 6. Comparative Analysis Matrix: Subqueries vs CTEs vs Temp Tables

| Dimension | Subquery (Inlined) | Common Table Expression (CTE) | Temporary Table (`CREATE TEMP`) |
| :--- | :--- | :--- | :--- |
| **Scope** | Single statement | Single statement (`WITH`) | Entire database session |
| **Readability** | Poor (Deep nesting) | **High (Modular top-down)** | Moderate (Multiple statements) |
| **Statistics** | Derived from base tables | Derived from base tables | **Full statistics (`ANALYZE`)** |
| **Indexable** | No | No | **Yes (Can add B-Tree indexes)** |
| **Disk/WAL Overhead** | Zero | Zero (unless disk spill) | Moderate (Allocates catalog/temp file) |
| **Best For** | Simple scalar lookups | Complex multi-step queries & trees | Multi-step nightly batch ETL |

---

## 7. Performance & Resource Optimization

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                         CTE PERFORMANCE PLAYBOOK                               │
├────────────────────────────────────────────────────────────────────────────────┤
│ 1. Use `NOT MATERIALIZED` when you want outer `WHERE` clauses to push down.    │
│ 2. Use `MATERIALIZED` when an expensive CTE is referenced $\ge 2$ times.       │
│ 3. Always include a recursion depth cutoff (`WHERE depth < 50`) in graphs.     │
│ 4. Replace correlated scalar subqueries in `SELECT` with `LEFT JOIN` or CTEs.  │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. In-Depth Engineering Perspectives

### Security Perspective

* **Hierarchical Access Control (RBAC)**: Use Recursive CTEs to compute transitive role inheritance (e.g. determining if a user has `Admin` rights because their team belongs to a parent department that inherits the role).

### High Availability Perspective

* **Preventing Unbounded Recursion Lockups**: Unbounded recursive queries consume 100% of a CPU core and allocate gigabytes of RAM in temporary working tables. Enforce strict `SET statement_timeout = '5s';` across all reporting databases.

### Resilience & Fault Tolerance Perspective

* **Modular Code Maintenance**: Refactoring complex 300-line monolithic SQL queries into structured CTE pipelines reduces cognitive load during operational incidents, allowing SREs to isolate slow nodes rapidly.

### Cost & Efficiency Perspective

* **Top-N Per Group via `LATERAL`**: Using `CROSS JOIN LATERAL (SELECT * FROM orders o WHERE o.user_id = u.id ORDER BY created_at DESC LIMIT 2)` leverages the index on `(user_id, created_at)` to fetch 2 rows per user in 0.05ms, avoiding a full table scan and window function sort across 50 million historical rows.

---

## 9. Step-by-Step Hands-On Production Walkthrough

### Step 1: Initialize Multi-Level Category & Org Hierarchy

```sql
-- 1. E-Commerce Product Category Hierarchy (Tree DAG)
CREATE TABLE product_categories (
    category_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_category_id INT REFERENCES product_categories(category_id),
    category_name VARCHAR(100) NOT NULL,
    slug VARCHAR(120) NOT NULL UNIQUE
);

-- 2. Seed Deep Tree Structure
INSERT INTO product_categories (parent_category_id, category_name, slug)
VALUES
    (NULL, 'Electronics', 'electronics'),
    (1,    'Computers & Networking', 'computers-networking'),
    (2,    'Laptops & Portables', 'laptops-portables'),
    (3,    'Enterprise Workstations', 'enterprise-workstations'),
    (1,    'Smartphones & Audio', 'smartphones-audio');
```

---

### Step 2: Implement Breadcrumb Path & Depth Traversal via Recursive CTE

```sql
-- Compute Complete Breadcrumb Hierarchy for SEO Navigation
WITH RECURSIVE CategoryTree AS (
    -- Anchor: Root categories (no parent)
    SELECT
        category_id,
        parent_category_id,
        category_name,
        1 AS depth_level,
        CAST(category_name AS TEXT) AS breadcrumb_path,
        ARRAY[category_id] AS id_path
    FROM product_categories
    WHERE parent_category_id IS NULL

    UNION ALL

    -- Recursive Member: Child Categories
    SELECT
        c.category_id,
        c.parent_category_id,
        c.category_name,
        ct.depth_level + 1,
        ct.breadcrumb_path || ' > ' || c.category_name,
        ct.id_path || c.category_id
    FROM product_categories c
    JOIN CategoryTree ct ON c.parent_category_id = ct.category_id
    WHERE NOT (c.category_id = ANY(ct.id_path)) -- Cycle Defense
)
SELECT
    category_id,
    depth_level,
    category_name,
    breadcrumb_path
FROM CategoryTree
ORDER BY id_path;
```

---

### Step 3: Top-N Per Group Query using `JOIN LATERAL`

```sql
-- Fetch Top 2 Recent Orders for Every Active Customer
SELECT
    c.customer_id,
    c.full_name,
    recent_orders.order_id,
    recent_orders.order_total,
    recent_orders.created_at
FROM customers c
CROSS JOIN LATERAL (
    SELECT o.order_id, o.order_total, o.created_at
    FROM orders o
    WHERE o.customer_id = c.customer_id
    ORDER BY o.created_at DESC
    LIMIT 2
) AS recent_orders
ORDER BY c.customer_id, recent_orders.created_at DESC;
```

---

## 10. Pure CLI / Command Interface

### 1. Inspect CTE Execution Strategy and Inlining with EXPLAIN

Verify whether PostgreSQL inlines or materializes the CTE:

```bash
psql -U postgres -d enterprise_db -c "EXPLAIN (ANALYZE, BUFFERS) WITH summary AS (SELECT customer_id, count(*) AS total FROM orders GROUP BY customer_id) SELECT * FROM summary WHERE total > 5;"
```

### 2. Monitor Memory Usage of Recursive Query Execution

Inspect `work_mem` utilization during recursive tree traversal:

```bash
psql -U postgres -d enterprise_db -c "EXPLAIN (ANALYZE, BUFFERS, VERBOSE) WITH RECURSIVE t AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM t WHERE n < 10000) SELECT * FROM t;"
```

### 3. Check for Stalled Subqueries in Query Catalog

Detect long-running subqueries via `pg_stat_activity`:

```bash
psql -U postgres -d enterprise_db -c "SELECT pid, now() - query_start AS active_time, query FROM pg_stat_activity WHERE state = 'active' AND query ~* 'WITH RECURSIVE' ORDER BY active_time DESC;"
```

---

## 11. Advanced Architecture & Edge-Case Failure Modes

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                   SUBQUERY & CTE FAILURE RECOVERY MATRIX                       │
├──────────────────────┬────────────────────────┬────────────────────────────────┤
│ Failure Scenario     │ Underlying Root Cause  │ Production Mitigation Runbook  │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Infinite Loop**    │ Circular parent_id     │ Add path array check (`ARRAY`) │
│ **Recursion Lock**   │ reference in graph.    │ and hard `depth < 50` limit.   │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Scalar Subquery**  │ Subquery returns $> 1$ │ Add `LIMIT 1` or ensure unique │
│ **Cardinality Error**│ row during execution.  │ constraint on subquery key.    │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Optimization**     │ `MATERIALIZED` CTE     │ Mark CTE `NOT MATERIALIZED` to │
│ **Fence Trap**       │ blocking index pushdown│ allow predicate pushdown.      │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Working Table**    │ Multi-million node tree│ Batch recursion in chunks;     │
│ **OOM Spill**        │ overflows `work_mem`.  │ increase `work_mem` in session.│
└──────────────────────┴────────────────────────┴────────────────────────────────┘
```

---

## 12. Detailed Sub-Components & Subsystems

### 1. Subquery Decorrelation Engine (SubLink / SubPlan)

* **Key Concepts**: Transforms correlated scalar subqueries (`SubLink`) into physical join operators (`SubPlan` / `InitPlan`), eliminating $O(N \times M)$ nested loop evaluation.
* **CLI / Tool Snippet**:

```bash
psql -U postgres -d enterprise_db -c "EXPLAIN (COSTS OFF) SELECT * FROM customers c WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);"
```

### 2. Recursive WorkTable Controller

* **Key Concepts**: Manages the transient working table buffer during `WITH RECURSIVE` evaluation, swapping active read/write tuples on each iteration.
* **CLI / Tool Snippet**:

```bash
psql -U postgres -d enterprise_db -c "EXPLAIN (ANALYZE, BUFFERS) WITH RECURSIVE x(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM x WHERE n < 5) SELECT * FROM x;"
```

### 3. LATERAL Subquery Parameterizer

* **Key Concepts**: Allows subqueries in the `FROM` clause to access columns from preceding table expressions, generating parameterized index scans per row.
* **CLI / Tool Snippet**:

```bash
psql -U postgres -d enterprise_db -c "EXPLAIN SELECT * FROM customers c, LATERAL (SELECT * FROM orders o WHERE o.customer_id = c.customer_id LIMIT 1) o;"
```

### 4. CTE Inlining Rewriter

* **Key Concepts**: AST transformation module evaluating whether a CTE qualifies for macro-expansion inlining or requires an explicit `Materialize` node.
* **CLI / Tool Snippet**:

```bash
psql -U postgres -d enterprise_db -c "EXPLAIN (VERBOSE) WITH cte AS (SELECT * FROM customers) SELECT * FROM cte WHERE customer_id = 10;"
```

---

## 13. References (The 5+5 Rule)

### Official Documentation & Academic Papers

1. [PostgreSQL Official Documentation: Chapter 7. Queries & The WITH Clause (CTEs)](https://www.postgresql.org/docs/current/queries-with.html)
2. [PostgreSQL Official Documentation: Subqueries and Subquery Expressions](https://www.postgresql.org/docs/current/functions-subquery.html)
3. [Won Kim: On Optimizing an SQL-like Nested Query (ACM TODS Classics)](https://dl.acm.org/doi/10.1145/319628.319645)
4. [C. Galindo-Legaria et al.: Orthogonal Optimization of Subqueries and Aggregation (ACM SIGMOD)](https://dl.acm.org/doi/10.1145/375663.375748)
5. [MySQL 8.0 Reference Manual: Common Table Expressions (CTEs)](https://dev.mysql.com/doc/refman/8.0/en/with.html)

### Authoritative Engineering Blogs & Architecture Deep Dives

1. [Use The Index, Luke: Subquery Performance and Join Unnesting](https://use-the-index-luke.com/)
2. [Brandur Leach: Advanced Postgres CTEs and Recursive Graph Algorithms](https://brandur.org/postgres-recursive)
3. [Modern SQL: Common Table Expressions and Inlining Optimization in Modern Engines](https://modern-sql.com/feature/with)
4. [Craig Kerstiens: LATERAL Joins in PostgreSQL: The Secret Weapon](https://www.craigkerstiens.com/)
5. [High-Performance PostgreSQL: CTE Optimization Fences in PostgreSQL 12+](https://www.cybertec-postgresql.com/en/cte-inlining-in-postgresql-12/)

---

## 14. Universal FinOps & Resource Cost Governance

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                       CTE FINOPS COST SAVINGS MATRIX                           │
├──────────────────────────┬──────────────────────────┬──────────────────────────┤
│ Optimization Strategy    │ Technical Mechanism      │ Measurable FinOps ROI    │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **`LATERAL` Top-N**      │ Replaces full-table      │ Cuts CPU query execution │
│                          │ window sort with seek    │ time by up to 95%        │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Single Recursive CTE** │ Replaces 50 recursive    │ Eliminates 98% of network│
│                          │ microservice API roundtrips│ egress & latency delays│
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **CTE Inlining (PG12+)** │ Pushes down predicates   │ Reduces buffer page read │
│                          │ into subquery scans      │ requirements by 80%      │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Cycle Termination**    │ Prevents unbounded       │ Eliminates OOM crashes & │
│                          │ recursive loops          │ unplanned instance reboots│
└──────────────────────────┴──────────────────────────┴──────────────────────────┘
```

### 1. Top-N Per Group (LATERAL vs Window Function Scan)

In an application fetching the latest 3 activities for 100,000 active users:

* Using a standard window function (`ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) WHERE rn <= 3`) scans all **30 million historical activity rows**, sorting them in a multi-gigabyte disk operation taking **26.4 seconds**.
* Refactoring to `CROSS JOIN LATERAL (SELECT * FROM activities WHERE user_id = u.id ORDER BY created_at DESC LIMIT 3)` executes 100,000 index seeks ($300,000\text{ rows fetched}$ directly), completing in **140 milliseconds**.
* **FinOps ROI**: Reduces analytical cluster compute requirements by $99\%$, saving **\$1,200/month** in dedicated compute node costs.

### 2. In-Database Tree Traversal vs Microservice N+1 Queries

When a frontend requests an enterprise organization chart with 5,000 employees across 8 management tiers:

* A naive microservice architecture makes **5,000 individual HTTP/database queries** sequentially, consuming 8 seconds of API gateway time and generating 15MB of repetitive JSON over the wire.
* Consolidating into a single **`WITH RECURSIVE`** query executes entirely within the database in **3.8 milliseconds**, transferring a single compressed 120KB payload.
* This eliminates API gateway connection pool exhaustion and lowers container CPU limits across backend services.
