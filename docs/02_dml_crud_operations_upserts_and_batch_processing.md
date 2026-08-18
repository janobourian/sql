# Module 02: DML, CRUD Operations, Atomic UPSERTs & High-Throughput Batch Processing

**Track:** SQL Relational Engineering & Distributed Database Architecture  
**Category:** Data Manipulation Language, Ingestion Pipelines, Atomic UPSERTs & Bulk Processing  
**Standard Identifier:** `DOC-STD-UNIVERSAL-2026`  
**Status:** ✅ Completed

---

## 📑 Table of Contents
1. [High-Level Overview & Executive Summary](#1-high-level-overview--executive-summary)
2. [Core Architecture & DML Write Mechanics](#2-core-architecture--dml-write-mechanics)
3. [Atomic UPSERT Architectures: `ON CONFLICT` vs `MERGE`](#3-atomic-upsert-architectures-on-conflict-vs-merge)
4. [Certification & Exam Essentials (Cheat Sheet)](#4-certification--exam-essentials-cheat-sheet)
5. [Comparative Analysis Matrix: Ingestion & Mutation Techniques](#5-comparative-analysis-matrix-ingestion--mutation-techniques)
6. [Performance & Resource Optimization](#6-performance--resource-optimization)
7. [In-Depth Engineering Perspectives](#7-in-depth-engineering-perspectives)
8. [Well-Architected Framework Alignment](#8-well-architected-framework-alignment)
9. [Step-by-Step Hands-On Production Walkthrough](#9-step-by-step-hands-on-production-walkthrough)
10. [Pure CLI / Command Interface](#10-pure-cli--command-interface)
11. [Advanced Architecture & Edge-Case Failure Modes](#11-advanced-architecture--edge-case-failure-modes)
12. [Detailed Sub-Components & Subsystems](#12-detailed-sub-components--subsystems)
13. [References (The 5+5 Rule)](#13-references-the-55-rule)
14. [Universal FinOps & Resource Cost Governance](#14-universal-finops--resource-cost-governance)

---

## 1. High-Level Overview & Executive Summary

Data Manipulation Language (DML)—consisting of `INSERT`, `UPDATE`, `DELETE`, `MERGE`, and `TRUNCATE`—governs the mutation lifecycle of relational data. In enterprise architectures handling high-concurrency e-commerce order spikes, real-time IoT telemetry, or financial ledger settlements, naive row-by-row SQL statements cause network saturation, connection exhaustion, lock contention, and excessive Write-Ahead Log (WAL) overhead.

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                   DML INGESTION THROUGHPUT HIERARCHY (ROWS / SEC)              │
├────────────────────────────────────────────────────────────────────────────────┤
│ 1. Binary / Streaming COPY (`COPY FROM STDIN`):   ████████████ 150,000+ rows/s │
│ 2. Multi-Row Batched Insert (1,000 values/batch):  ███████       45,000  rows/s │
│ 3. Atomic UPSERT (`ON CONFLICT DO UPDATE`):        ████          20,000  rows/s │
│ 4. Naive Individual `INSERT` (1 row per SQL query): █               800  rows/s │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 👔 Executive Summary (For Managers & Non-Technical Stakeholders)
* **Business Purpose**: DML operations allow business applications to record transactions, update customer balances, and process order fulfillment. Suboptimal data ingestion leads to slow application checkouts, database lockouts during flash sales, and bloated cloud server costs.
* **How It Works**: Modern relational engines support atomic UPSERTs (insert if new, update if already present) and high-speed streaming protocols (`COPY`) that bypass the query parser to write data directly into memory blocks. This eliminates race conditions where two customers attempt to claim the same hotel room or inventory item simultaneously.
* **Key Business Value & ROI**: Increases data processing speed by up to 100x, eliminates duplicate record conflicts, and avoids provisioning expensive oversized database clusters for daily ETL data loading jobs.

---

## 2. Core Architecture & DML Write Mechanics

### 2.1 The Internal SQL Write Lifecycle (Step-by-Step)
When an `INSERT` or `UPDATE` statement executes in PostgreSQL or MySQL InnoDB:

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                     THE INTERNAL RELATIONAL WRITE PIPELINE                     │
└────────────────────────────────────────────────────────────────────────────────┘
                                  Client Query
                                       │
                                [INSERT/UPDATE]
                                       ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│ 1. LOCK ACQUISITION: Acquires `RowExclusiveLock` on target table               │
└──────────────────────────────────────┬─────────────────────────────────────────┘
                                       ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│ 2. BUFFER ACQUISITION: Searches Shared Buffers for target 8KB page;            │
│    Reads page from disk into RAM if not currently cached                      │
└──────────────────────────────────────┬─────────────────────────────────────────┘
                                       ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│ 3. WAL LOG GENERATION: Constructs WAL record describing tuple delta;           │
│    Appends WAL record to in-memory `wal_buffers` and advances LSN             │
└──────────────────────────────────────┬─────────────────────────────────────────┘
                                       ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│ 4. TUPLE MUTATION: Inserts tuple into slotted page; marks page as "DIRTY";     │
│    Updates all associated B-Tree indexes (unless HOT optimization applies)     │
└──────────────────────────────────────┬─────────────────────────────────────────┘
                                       ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│ 5. TRANSACTION COMMIT: Synchronously flushes WAL buffers to physical disk      │
│    via `fsync` (Data page remains dirty in RAM until next checkpoint)         │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

### 2.2 `TRUNCATE` vs `DELETE` vs Partition Dropping

| Operation | Locking Level | Transaction Logging | Index Cleanup | Execution Time |
| :--- | :--- | :--- | :--- | :--- |
| **`DELETE FROM table`** | `RowExclusiveLock` (Per Row) | Full WAL logging per deleted tuple | Marks B-Tree index items as dead | $O(N)$ — Linear with row count |
| **`TRUNCATE table`** | `AccessExclusiveLock` (Whole Table) | Minimal WAL (Truncate log record) | Replaces index filenode entirely | $O(1)$ — Instantaneous metadata swap |
| **`DROP PARTITION`** | `AccessExclusiveLock` (Partition only) | Metadata update only | Drops partition data file on disk | $O(1)$ — Zero impact on main table |

---

## 3. Atomic UPSERT Architectures: `ON CONFLICT` vs `MERGE`

### 3.1 PostgreSQL Native `ON CONFLICT` (The `EXCLUDED` Pseudo-Table)
The `ON CONFLICT` clause guarantees atomic idempotency. It requires an underlying `UNIQUE` constraint or unique index to detect conflicts:

```sql
-- Atomic Inventory Upsert:
INSERT INTO product_inventory (sku, warehouse_id, available_stock, reserved_stock)
VALUES ('SKU-SSD-2TB', 10, 150, 0)
ON CONFLICT (sku, warehouse_id) 
DO UPDATE SET 
    available_stock = product_inventory.available_stock + EXCLUDED.available_stock,
    last_restocked_at = CURRENT_TIMESTAMP
WHERE EXCLUDED.available_stock > 0
RETURNING inventory_id, available_stock;
```

- **`EXCLUDED`**: A virtual pseudo-table containing the exact row values that were proposed for insertion.
- **Atomic Speculative Insertion**: PostgreSQL attempts to insert the row; if an index unique conflict is detected, it rolls back the tuple insertion internally and executes the `DO UPDATE` branch within the same atomic engine step.

---

### 3.2 Standard ANSI SQL `MERGE` Statement (PostgreSQL 15+, Oracle, MS SQL Server)
The `MERGE` statement synchronizes a target table with a source dataset (e.g. daily staging delta) using explicit join logic:

```sql
MERGE INTO customer_accounts AS target
USING staging_account_updates AS source
ON (target.account_number = source.account_number)
WHEN MATCHED AND source.is_deleted = TRUE THEN
    DELETE
WHEN MATCHED THEN
    UPDATE SET 
        balance = source.new_balance,
        status = source.new_status,
        updated_at = CURRENT_TIMESTAMP
WHEN NOT MATCHED THEN
    INSERT (account_number, customer_id, balance, status)
    VALUES (source.account_number, source.customer_id, source.new_balance, source.new_status);
```

---

## 4. Certification & Exam Essentials (Cheat Sheet)

* ⚠️ **`RETURNING` Clause Performance**: Always use `INSERT ... RETURNING id` or `UPDATE ... RETURNING *` when creating or modifying records. This eliminates the need for an immediate follow-up `SELECT` query, cutting network round trips in half.
* 🔒 **Deadlocks in Multi-Row Batches**: If Transaction A executes `UPDATE table WHERE id IN (1, 2)` while Transaction B executes `UPDATE table WHERE id IN (2, 1)`, a deadlock is guaranteed under concurrency. **Applications must sort IDs in ascending order before executing batched DML**.
* ⚙️ **Hot Updates (Heap-Only Tuples - HOT)**: In PostgreSQL, if an `UPDATE` does not modify any indexed columns and the target 8KB page has enough free space, PostgreSQL creates the new tuple version on the same page and chains it directly from the old line pointer without modifying any B-Tree indexes!
* ⚠️ **`DELETE` Table Bloat**: Executing `DELETE FROM large_table` does **not** shrink the physical file size on disk. It merely marks tuples as dead for `VACUUM` to reuse. To reclaim disk space to the OS immediately, use `TRUNCATE` or `pg_repack`.

---

## 5. Comparative Analysis Matrix: Ingestion & Mutation Techniques

| Ingestion Method | Network Roundtrips | SQL Parser Overhead | WAL Volume Generated | Typical Max Throughput |
| :--- | :--- | :--- | :--- | :--- |
| **Individual SQL `INSERT`** | 1 per row (1,000 RTTs/1k rows)| High (Parsed on every statement) | High (Separate transaction headers) | 500 – 1,200 rows/sec |
| **Multi-Row `INSERT VALUES`**| 1 per batch (1 RTT/1k rows) | Moderate (Single large AST) | Moderate (Shared transaction header) | 25,000 – 50,000 rows/sec |
| **Streaming `COPY / STDIN`** | Streamed byte blocks | **Zero** (Bypasses SQL Parser) | Optimized sequential page writes | **150,000 – 300,000 rows/sec** |
| **`pg_bulkload` Extension** | Direct binary blocks | **Zero** (Bypasses Shared Buffers) | Minimal (Can bypass WAL with caution)| **500,000+ rows/sec** |

---

## 6. Performance & Resource Optimization

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                       BATCH INGESTION TUNING LEVERS                            │
├────────────────────────────────────────────────────────────────────────────────┤
│ 1. Use `COPY table FROM STDIN` for bulk loading > 10,000 rows.                 │
│ 2. Batch multi-row inserts in chunks of 500 to 2,000 rows per statement.       │
│ 3. Wrap bulk DML in an explicit `BEGIN ... COMMIT` transaction block.          │
│ 4. Drop non-critical secondary indexes prior to multi-million bulk loads.      │
│ 5. Set `synchronous_commit = off` for non-critical high-speed audit logs.      │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. In-Depth Engineering Perspectives

### Security Perspective
* **Parameterized DML (SQL Injection Elimination)**: Never concatenate client inputs into dynamic DML strings (e.g. `UPDATE users SET name = '` + input + `'`). Always use prepared statement parameters (`$1`, `$2` or `?`) to guarantee strict separation of code and data.
* **Row-Level Security (RLS) on DML**: PostgreSQL automatically applies `WITH CHECK` policies to `INSERT` and `UPDATE` statements, preventing users from inserting rows outside their authorized tenant scope.

### High Availability & Replication Perspective
* **Write Amplification on Replicas**: Mass bulk `UPDATE` operations generate millions of WAL bytes that must be transmitted across the network to read replicas. Chunking updates into batches of 5,000 rows with a 50ms pause prevents replication lag spikes.

### Resilience & Fault Tolerance Perspective
* **Idempotent Consumers**: In distributed event-driven systems (Kafka, RabbitMQ), message duplicates are common. Structuring all consumer DML as atomic `ON CONFLICT DO UPDATE` statements ensures that replaying event streams never corrupts database state.

### Cost & Efficiency Perspective
* **IOPS Reduction via Batching**: Executing 10,000 individual `INSERT` statements with autocommit forces 10,000 synchronous disk `fsync` operations. Wrapping them in a single batch executes **exactly 1 `fsync`**, reducing disk write IOPS by 99.99%.

---

## 8. Well-Architected Framework Alignment

* **Operational Excellence**: Using deterministic, idempotent batch ingestion scripts with comprehensive error logging and rollback safeguards.
* **Security**: Enforcing parameterized queries and Row-Level Security policies across all data modification channels.
* **Reliability**: Avoiding long-running uncommitted transactions that lock tables and prevent autovacuum progress.
* **Performance Efficiency**: Using streaming `COPY` protocols and multi-row batching to maximize hardware throughput.
* **Cost Optimization**: Drastically reducing provisioned cloud IOPS and disk write cycles through transactional batching.
* **Sustainability**: Efficient batch processing minimizes CPU core utilization and reduces carbon footprint during heavy data ingestion.

---

## 9. Step-by-Step Hands-On Production Walkthrough

### Step 1: Initialize Operational Inventory & Staging Schema

```sql
-- 1. Master Inventory Table
CREATE TABLE warehouse_stock (
    stock_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku VARCHAR(64) NOT NULL,
    warehouse_code VARCHAR(16) NOT NULL,
    quantity_on_hand INT NOT NULL CHECK (quantity_on_hand >= 0),
    reorder_threshold INT NOT NULL DEFAULT 50,
    last_received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unq_sku_warehouse UNIQUE (sku, warehouse_code)
);

-- 2. Staging Batch Ingestion Table (Unlogged for Maximum Speed)
CREATE UNLOGGED TABLE staging_stock_feed (
    sku VARCHAR(64) NOT NULL,
    warehouse_code VARCHAR(16) NOT NULL,
    received_quantity INT NOT NULL,
    batch_reference VARCHAR(64) NOT NULL
);
```

---

### Step 2: High-Speed Batch Ingestion into Staging

```sql
-- Simulate high-speed batch load into unlogged staging table:
INSERT INTO staging_stock_feed (sku, warehouse_code, received_quantity, batch_reference)
VALUES 
    ('SKU-CPU-X99', 'WH-US-EAST', 500, 'BATCH-20260818-01'),
    ('SKU-GPU-RTX', 'WH-US-EAST', 120, 'BATCH-20260818-01'),
    ('SKU-MEM-32G', 'WH-US-WEST', 800, 'BATCH-20260818-01'),
    ('SKU-CPU-X99', 'WH-US-EAST', 200, 'BATCH-20260818-01'); -- Duplicate SKU in same batch
```

---

### Step 3: Atomic Batch Merge & Upsert into Master Inventory

```sql
-- Aggregate Staging Delta and Execute Atomic UPSERT with RETURNING Audit
WITH aggregated_batch AS (
    SELECT 
        sku,
        warehouse_code,
        SUM(received_quantity) AS total_received
    FROM staging_stock_feed
    WHERE batch_reference = 'BATCH-20260818-01'
    GROUP BY sku, warehouse_code
)
INSERT INTO warehouse_stock (sku, warehouse_code, quantity_on_hand, last_received_at)
SELECT 
    sku,
    warehouse_code,
    total_received,
    CURRENT_TIMESTAMP
FROM aggregated_batch
ON CONFLICT (sku, warehouse_code)
DO UPDATE SET 
    quantity_on_hand = warehouse_stock.quantity_on_hand + EXCLUDED.quantity_on_hand,
    last_received_at = CURRENT_TIMESTAMP
RETURNING stock_id, sku, warehouse_code, quantity_on_hand, last_received_at;
```

---

### Step 4: Verify and Clean Up Staging

```sql
-- Query verified inventory state:
SELECT sku, warehouse_code, quantity_on_hand, last_received_at 
FROM warehouse_stock 
ORDER BY sku, warehouse_code;

-- Fast metadata wipe of staging table:
TRUNCATE TABLE staging_stock_feed;
```

---

## 10. Pure CLI / Command Interface

### 1. High-Speed Streaming CSV Ingestion via `psql \copy`
Stream multi-gigabyte CSV data directly to database table:
```bash
psql -U postgres -d enterprise_db -c "\copy warehouse_stock(sku, warehouse_code, quantity_on_hand) FROM 'inventory_manifest.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');"
```

### 2. Export Query Results Directly to Compressed CSV File
Extract filtered analytical records without holding table locks:
```bash
psql -U postgres -d enterprise_db -c "\copy (SELECT sku, warehouse_code, quantity_on_hand FROM warehouse_stock WHERE quantity_on_hand > 100) TO 'high_stock_export.csv' WITH (FORMAT csv, HEADER true);"
```

### 3. Monitor Active Long-Running DML Operations
Detect blocked or stalled DML statements:
```bash
psql -U postgres -d enterprise_db -c "SELECT pid, now() - query_start AS duration, query, state FROM pg_stat_activity WHERE state != 'idle' AND query ~* '^(INSERT|UPDATE|DELETE|MERGE)' ORDER BY duration DESC;"
```

---

## 11. Advanced Architecture & Edge-Case Failure Modes

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                      DML FAILURE & CONCURRENCY MATRIX                          │
├──────────────────────┬────────────────────────┬────────────────────────────────┤
│ Failure Scenario     │ Underlying Mechanism   │ Production Mitigation Runbook  │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **UPSERT Race Trap** │ `ON CONFLICT` missing  │ Explicitly define `UNIQUE`     │
│                      │ unique index constraint│ index on conflict target keys. │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Deadlock Storm**   │ Unordered concurrent   │ Always sort primary keys in    │
│                      │ multi-row updates.     │ ascending order prior to DML.  │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Replication Lag**  │ Single multi-million   │ Chunk massive deletes/updates  │
│ **Explosion**        │ row `UPDATE` statement.│ into batches of 5,000 rows.    │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Lock Starvation**  │ `TRUNCATE` blocked by  │ Terminate idle transactions;   │
│                      │ open long-running read.│ enforce strict `lock_timeout`. │
└──────────────────────┴────────────────────────┴────────────────────────────────┘
```

---

## 12. Detailed Sub-Components & Subsystems

### 1. Heap Insertion Engine & Free Space Map (FSM)
* **Key Concepts**: Maintains a binary tree of page free space (`.fsm` fork) to locate an 8KB block with sufficient space for incoming tuple insertions in $O(\log N)$ time.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SELECT * FROM pg_freespace('warehouse_stock');"
```

### 2. Speculative Insertion Engine
* **Key Concepts**: Engine subsystem powering `ON CONFLICT`, executing tentative tuple placement and unique index validation before finalizing row insertion.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SELECT locktype, mode, granted FROM pg_locks WHERE locktype = 'speculative token';"
```

### 3. Heap-Only Tuples (HOT) Engine
* **Key Concepts**: Optimizes `UPDATE` statements by storing updated tuples on the same physical 8KB page, bypassing index updates and reducing write I/O.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SELECT n_tup_upd, n_tup_hot_upd, round((n_tup_hot_upd::numeric / (n_tup_upd + 1)) * 100, 2) AS hot_update_pct FROM pg_stat_user_tables WHERE relname = 'warehouse_stock';"
```

### 4. Direct Buffer Writer (BGWriter)
* **Key Concepts**: Background daemon scanning shared buffers and writing dirty pages to disk asynchronously to ensure server backends always find free memory pages for fast `INSERT` execution.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SELECT checkpoints_timed, checkpoints_req, buffers_checkpoint, buffers_clean, maxwritten_clean FROM pg_stat_bgwriter;"
```

---

## 13. References (The 5+5 Rule)

### Official Documentation & Specifications
1. [PostgreSQL Official Documentation: Chapter 7. Queries & Data Manipulation (DML)](https://www.postgresql.org/docs/current/dml.html)
2. [PostgreSQL Official Documentation: SQL INSERT Statement & ON CONFLICT Clause](https://www.postgresql.org/docs/current/sql-insert.html)
3. [PostgreSQL Official Documentation: SQL MERGE Statement (PG 15+)](https://www.postgresql.org/docs/current/sql-merge.html)
4. [PostgreSQL Official Documentation: SQL COPY Command](https://www.postgresql.org/docs/current/sql-copy.html)
5. [MySQL 8.0 Reference Manual: INSERT ... ON DUPLICATE KEY UPDATE Statement](https://dev.mysql.com/doc/refman/8.0/en/insert-on-duplicate.html)

### Authoritative Engineering Blogs & Architecture Deep Dives
6. [Use The Index, Luke: High-Performance Batch Insert and Upsert Strategies](https://use-the-index-luke.com/)
7. [Brandur Leach: Postgres Batching, COPY vs INSERT, and Lock Contention](https://brandur.org/postgres-batch-copy)
8. [Martin Kleppmann: Transactions and Write Paths in Relational Systems](https://dataintensive.net/)
9. [Craig Kerstiens: Understanding PostgreSQL HOT (Heap-Only Tuples) Updates](https://www.craigkerstiens.com/)
10. [High-Performance PostgreSQL: Eliminating Deadlocks in High-Throughput DML](https://www.cybertec-postgresql.com/en/postgresql-deadlocks/)

---

## 14. Universal FinOps & Resource Cost Governance

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                       DML FINOPS COST LEVERS MATRIX                            │
├──────────────────────────┬──────────────────────────┬──────────────────────────┤
│ Optimization Strategy    │ Technical Mechanism      │ Direct FinOps Impact     │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **`COPY` vs `INSERT`**   │ Bypasses SQL parsing and │ 80% reduction in CPU core│
│                          │ multi-transaction logging│ hours during bulk ETL    │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Transactional Batch**  │ Amortizes `fsync` across │ Cuts cloud disk write    │
│ **Grouping (500 rows)**  │ hundreds of row mutations│ IOPS charges by 99%      │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **HOT Updates**          │ Keeps updates in-page;   │ Reduces disk write       │
│                          │ bypasses index churn     │ amplification by 70%     │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **`TRUNCATE` Staging**   │ Reclaims physical disk   │ Prevents continuous cloud│
│                          │ extents instantly        │ storage volume growth    │
└──────────────────────────┴──────────────────────────┴──────────────────────────┘
```

### 1. Ingestion Protocol Compute & IOPS Savings (COPY vs Individual Inserts)
In nightly ETL pipelines loading 20 million financial or log records:
- Executing individual `INSERT` queries requires approximately **4.5 hours of 100% CPU on a 16-vCPU instance** and consumes 20,000,000 disk IOPS.
- Switching to batched streaming `COPY` ingests the identical 20 million records in **under 3.5 minutes**, consuming fewer than 150,000 IOPS.
- **FinOps ROI**: Eliminates the need to provision expensive high-IOPS provisioned cloud storage (AWS `io2` or GCP Extreme Persistent Disks), saving **\$600–\$1,400/month** in storage infrastructure fees.

### 2. Preventing Table Bloat & Storage Scaling Fees
Executing massive `DELETE` statements on multi-gigabyte tables without vacuuming generates dead tuples that continue consuming billable disk space. In cloud databases with automatic storage scaling (e.g. AWS Aurora / RDS Storage Auto-scaling), storage scales upwards automatically but **never scales down**. Replacing bulk `DELETE` with `TRUNCATE` or dropping monthly partitions prevents irreversible cloud storage expansion.
