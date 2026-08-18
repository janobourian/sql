# Module 08: Transactions, ACID Isolation Levels, MVCC & Concurrency Control

**Track:** SQL Relational Engineering & Distributed Database Architecture  
**Category:** Transactions, Multi-Version Concurrency Control (MVCC), Lock Hierarchies & Deadlock Elimination  
**Standard Identifier:** `DOC-STD-UNIVERSAL-2026`  
**Status:** ✅ Completed

---

## 📑 Table of Contents
1. [High-Level Overview & Executive Summary](#1-high-level-overview--executive-summary)
2. [Multi-Version Concurrency Control (MVCC) Engine Architecture](#2-multi-version-concurrency-control-mvcc-engine-architecture)
3. [ANSI SQL Isolation Levels & Concurrency Anomalies](#3-ansi-sql-isolation-levels--concurrency-anomalies)
4. [Locking Hierarchies: Row Locks, `SKIP LOCKED` & Table Modes](#4-locking-hierarchies-row-locks-skip-locked--table-modes)
5. [Certification & Exam Essentials (Cheat Sheet)](#5-certification--exam-essentials-cheat-sheet)
6. [Comparative Analysis Matrix: Engine Concurrency Architectures](#6-comparative-analysis-matrix-engine-concurrency-architectures)
7. [Performance & Resource Optimization](#7-performance--resource-optimization)
8. [In-Depth Engineering Perspectives](#8-in-depth-engineering-perspectives)
9. [Well-Architected Framework Alignment](#9-well-architected-framework-alignment)
10. [Step-by-Step Hands-On Production Walkthrough](#10-step-by-step-hands-on-production-walkthrough)
11. [Pure CLI / Command Interface](#11-pure-cli--command-interface)
12. [Advanced Architecture & Edge-Case Failure Modes](#12-advanced-architecture--edge-case-failure-modes)
13. [Detailed Sub-Components & Subsystems](#13-detailed-sub-components--subsystems)
14. [References (The 5+5 Rule)](#14-references-the-55-rule)
15. [Universal FinOps & Resource Cost Governance](#15-universal-finops--resource-cost-governance)

---

## 1. High-Level Overview & Executive Summary

Concurrency control in relational database engines resolves the fundamental tension between **transactional correctness** and **high-throughput multi-user concurrency**. Modern engines employ **Multi-Version Concurrency Control (MVCC)**: instead of acquiring exclusive table locks that freeze readers while writers are mutating rows, the engine maintains multiple physical versions of each tuple simultaneously on disk.

```
┌────────────────────────────────────────────────────────────────────────────────┐
│               THE GOLDEN LAW OF MVCC CONCURRENCY CONTROL                       │
├────────────────────────────────────────────────────────────────────────────────┤
│ "READERS NEVER BLOCK WRITERS, AND WRITERS NEVER BLOCK READERS!"                │
│                                                                                │
│ [Reader Transaction (Snapshot @ T1)] ──► Reads Tuple Version 1 (Clean State)   │
│                                              ▲                                 │
│ [Writer Transaction (Active @ T2)]   ──► Inserts Tuple Version 2 (In Progress) │
│                                          (Invisible to Reader until Commit!)   │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 👔 Executive Summary (For Managers & Non-Technical Stakeholders)
* **Business Purpose**: When thousands of customers make simultaneous banking transfers or purchase concert tickets, the database must prevent "double spending" and corrupted inventory counts without slowing down other users browsing the catalog.
* **How It Works**: MVCC provides each user with an isolated, point-in-time "snapshot" of the database. Read queries never wait for write queries, and write queries never wait for read queries.
* **Key Business Value & ROI**: Guarantees 100% financial accuracy and regulatory compliance (SOX, PCI-DSS) while maximizing system throughput, preventing lost sales during high-traffic checkout spikes.

---

## 2. Multi-Version Concurrency Control (MVCC) Engine Architecture

### 2.1 The Physical Tuple Header (`xmin`, `xmax`, `t_ctid`)
In PostgreSQL, every 8KB slotted page stores physical tuple headers containing hidden concurrency metadata:

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                  POSTGRESQL HEAP TUPLE HEADER DATA STRUCTURE                   │
├────────────────────────────────────────────────────────────────────────────────┤
│ `t_xmin` (4 Bytes)     : Transaction ID (XID) that CREATED this tuple version  │
├────────────────────────────────────────────────────────────────────────────────┤
│ `t_xmax` (4 Bytes)     : Transaction ID (XID) that DELETED/UPDATED this tuple  │
├────────────────────────────────────────────────────────────────────────────────┤
│ `t_ctid` (6 Bytes)     : Physical pointer (PageID, Offset) to latest tuple ver │
├────────────────────────────────────────────────────────────────────────────────┤
│ `t_infomask` (2 Bytes) : Bitmask flags (e.g. `HEAP_XMIN_COMMITTED`, `XMAX_ABORT`)│
└────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Tuple Mutation Lifecycle
When an `UPDATE` executes:
1. The engine does **not** overwrite the existing row bytes.
2. It sets `t_xmax` on the old tuple to the current Transaction ID ($XID_{current}$).
3. It writes a brand new physical tuple on the page (or a new page) with `t_xmin = XID_{current}`.
4. It sets the old tuple's `t_ctid` to point to the new physical tuple location.

---

## 3. ANSI SQL Isolation Levels & Concurrency Anomalies

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                 CONCURRENCY PHENOMENA & ISOLATION LEVEL MATRIX                 │
├─────────────────────────┬──────────────┬──────────────┬─────────┬──────────────┤
│ Isolation Level         │ Dirty Read   │ Non-Repeat   │ Phantom │ Serialization│
│                         │              │ Read (Fuzzy) │ Read    │ Anomaly      │
├─────────────────────────┼──────────────┼──────────────┼─────────┼──────────────┤
│ **`READ UNCOMMITTED`**  │ Possible     │ Possible     │ Possible│ Possible     │
├─────────────────────────┼──────────────┼──────────────┼─────────┼──────────────┤
│ **`READ COMMITTED`**    │ **Prevented**│ Possible     │ Possible│ Possible     │
│ (Postgres/Oracle Default)│              │              │         │              │
├─────────────────────────┼──────────────┼──────────────┼─────────┼──────────────┤
│ **`REPEATABLE READ`**   │ **Prevented**│ **Prevented**│**Prevented**| Possible   │
│ (MySQL InnoDB Default)  │              │              │(in PG)  │ (Write Skew) │
├─────────────────────────┼──────────────┼──────────────┼─────────┼──────────────┤
│ **`SERIALIZABLE`**      │ **Prevented**│ **Prevented**│**Prevented**|**Prevented** │
│ (Serializable Snapshot) │              │              │         │ (True SSI)   │
└─────────────────────────┴──────────────┴──────────────┴─────────┴──────────────┘
```

### The Write Skew Anomaly in `REPEATABLE READ`:
Consider two doctors on call (Alice and Bob). The hospital policy requires at least 1 doctor on call.
- Transaction 1 (Alice): Checks active count ($2 \ge 1$), then sets Alice status to `OFF_CALL`.
- Transaction 2 (Bob): Concurrently checks active count ($2 \ge 1$), then sets Bob status to `OFF_CALL`.
- Both transactions commit cleanly in `REPEATABLE READ`, leaving **zero doctors on call!**
- **Solution**: Use `SERIALIZABLE` isolation or explicit `SELECT ... FOR UPDATE` row locks.

---

## 4. Locking Hierarchies: Row Locks, `SKIP LOCKED` & Table Modes

### 4.1 Row-Level Lock Modes

```sql
-- 1. Exclusive Write Lock (Blocks all other readers/writers requesting row locks):
SELECT * FROM accounts WHERE id = 10 FOR UPDATE;

-- 2. Non-Key Update Lock (Allows foreign key checks to proceed):
SELECT * FROM accounts WHERE id = 10 FOR NO KEY UPDATE;

-- 3. Shared Lock (Allows concurrent readers, blocks writers):
SELECT * FROM accounts WHERE id = 10 FOR SHARE;

-- 4. Key Share Lock (Used by foreign key validation):
SELECT * FROM accounts WHERE id = 10 FOR KEY SHARE;
```

---

### 4.2 High-Throughput Job Queues with `FOR UPDATE SKIP LOCKED`
Building high-speed message and task queues directly in PostgreSQL without external brokers (RabbitMQ/Redis):

```sql
-- Worker fetches and locks exactly 1 unclaimed task without waiting:
WITH next_task AS (
    SELECT task_id, payload
    FROM job_queue
    WHERE status = 'QUEUED'
    ORDER BY priority DESC, created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED -- ◄── Skips rows already locked by other concurrent workers!
)
UPDATE job_queue
SET status = 'PROCESSING', started_at = CURRENT_TIMESTAMP
FROM next_task
WHERE job_queue.task_id = next_task.task_id
RETURNING job_queue.task_id, job_queue.payload;
```

---

## 5. Certification & Exam Essentials (Cheat Sheet)

* ⚠️ **Deadlock Detection (`40P01`)**: When two transactions circularly wait on locks held by each other, the background deadlock detector awakens after `deadlock_timeout` (default: 1 second), inspects the lock wait-for graph, and aborts the younger transaction. Applications **must** catch SQLState `40P01` and implement automatic retries with jitter.
* 🔒 **Serializable Snapshot Isolation (SSI)**: PostgreSQL implements true SSI using SIREAD lock trackers in shared memory. It detects **Dangerous Dependencies (rw-antidependencies)** and aborts transactions with `40001: could not serialize access due to read/write dependencies among transactions`.
* ⚙️ **Table Lock Escalation**: Unlike Microsoft SQL Server (which escalates thousands of row locks into a full table lock), **PostgreSQL never escalates row locks to table locks**, eliminating lock escalation thrashing!
* ⚠️ **Long-Running Transactions & Autovacuum Blockade**: An uncommitted transaction holding an old `xmin` snapshot prevents `autovacuum` from cleaning up dead tuples across the entire database, leading to massive table bloat. Configure `idle_in_transaction_session_timeout = '60s'`.

---

## 6. Comparative Analysis Matrix: Engine Concurrency Architectures

| Dimension | PostgreSQL (MVCC + Heap) | MySQL InnoDB (MVCC + Undo) | Oracle Database (Undo Segment) |
| :--- | :--- | :--- | :--- |
| **Old Version Storage** | Main Table Heap (Dead Tuples)| Dedicated Undo Tablespace | Dedicated Undo Tablespace |
| **Garbage Collection** | `VACUUM` worker processes | Background Purge Threads | Automatic Undo Segment Reuse |
| **Table Bloat Risk** | High if autovacuum stalls | Low (Overwrites in place) | Low (Overwrites in place) |
| **Write Amplification** | Moderate (HOT optimization) | High (Doublewrite buffer + Undo)| Moderate |
| **True SSI Support** | **Yes (Full SSI via SIREAD)** | No (Uses Next-Key Locking) | No (Requires explicit locking) |

---

## 7. Performance & Resource Optimization

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                     CONCURRENCY OPTIMIZATION PLAYBOOK                          │
├────────────────────────────────────────────────────────────────────────────────┤
│ 1. Keep transaction execution time $< 100\text{ms}$; never execute external    │
│    HTTP API calls inside an open database transaction block.                  │
│ 2. Always acquire row locks in a consistent primary key order to eliminate     │
│    deadlock cycles (`ORDER BY account_id ASC`).                                │
│ 3. Use `SKIP LOCKED` for queue consumers to eliminate lock contention.         │
│ 4. Set `idle_in_transaction_session_timeout = '30s'` to abort forgotten locks. │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. In-Depth Engineering Perspectives

### Security Perspective
* **Preventing Race Condition Exploitation**: Attackers frequently exploit race conditions in wallet and reward point systems by firing 50 concurrent withdrawal requests within 2 milliseconds. Enforcing `SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE` completely neutralizes concurrent double-spending attacks.

### High Availability Perspective
* **Replication Conflict Resolution**: Long-running read queries on asynchronous read replicas can conflict with incoming WAL recovery updates. Configure `max_standby_streaming_delay = '30s'` to prevent standby read queries from delaying WAL replication apply queues.

### Resilience & Fault Tolerance Perspective
* **Idempotent Retry Wrappers**: Every transaction using `SERIALIZABLE` or `REPEATABLE READ` must be wrapped in an application-level retry loop with exponential backoff and randomized jitter to handle serialization failures gracefully.

### Cost & Efficiency Perspective
* **Bloat Elimination**: By terminating orphaned idle transactions quickly, autovacuum reclaims dead tuple storage before tables expand, preventing unnecessary cloud EBS volume auto-scaling charges.

---

## 9. Step-by-Step Hands-On Production Walkthrough

### Step 1: Initialize Ledger Table for Concurrency Testing

```sql
-- 1. Create Core Banking Ledger
CREATE TABLE bank_accounts (
    account_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_holder VARCHAR(100) NOT NULL,
    balance NUMERIC(14, 2) NOT NULL CHECK (balance >= 0.00),
    version INT NOT NULL DEFAULT 1
);

-- Seed Account Balances:
INSERT INTO bank_accounts (account_holder, balance)
VALUES 
    ('Alice Chen', 1000.00),
    ('Bob Martinez', 500.00);
```

---

### Step 2: Atomic Funds Transfer with Deadlock Prevention

```sql
-- High-Safety Atomic Transfer Function (Prevents Deadlocks by Sorting IDs)
CREATE OR REPLACE FUNCTION transfer_funds(
    p_from_account BIGINT,
    p_to_account BIGINT,
    p_amount NUMERIC(14, 2)
) RETURNS BOOLEAN AS $$
DECLARE
    v_first_acc BIGINT;
    v_second_acc BIGINT;
    v_current_balance NUMERIC(14, 2);
BEGIN
    -- 1. Enforce Global Lock Acquisition Order (Lowest ID First!)
    IF p_from_account < p_to_account THEN
        v_first_acc := p_from_account;
        v_second_acc := p_to_account;
    ELSE
        v_first_acc := p_to_account;
        v_second_acc := p_from_account;
    END IF;

    -- 2. Lock Both Accounts in Deterministic Order
    PERFORM 1 FROM bank_accounts WHERE account_id = v_first_acc FOR UPDATE;
    PERFORM 1 FROM bank_accounts WHERE account_id = v_second_acc FOR UPDATE;

    -- 3. Verify Sufficient Balance
    SELECT balance INTO v_current_balance 
    FROM bank_accounts 
    WHERE account_id = p_from_account;

    IF v_current_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds: Available %, Requested %', v_current_balance, p_amount;
    END IF;

    -- 4. Execute Atomic Balance Mutations
    UPDATE bank_accounts SET balance = balance - p_amount WHERE account_id = p_from_account;
    UPDATE bank_accounts SET balance = balance + p_amount WHERE account_id = p_to_account;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
```

---

### Step 3: Execute Verified Transfer

```sql
-- Execute 100% Safe Atomic Transfer
BEGIN;
SELECT transfer_funds(1, 2, 250.00);
COMMIT;

-- Verify Balances:
SELECT account_id, account_holder, balance FROM bank_accounts ORDER BY account_id;
```

---

## 10. Pure CLI / Command Interface

### 1. Inspect Active Transaction Locks and Blocking Sessions
Identify blocked sessions and the specific PIDs holding blocking locks:
```bash
psql -U postgres -d enterprise_db -c "SELECT blocked_locks.pid AS blocked_pid, blocked_activity.usename AS blocked_user, blocking_locks.pid AS blocking_pid, blocking_activity.usename AS blocking_user, blocked_activity.query AS blocked_statement, blocking_activity.query AS current_statement_in_blocking_process FROM pg_catalog.pg_locks blocked_locks JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid AND blocking_locks.pid != blocked_locks.pid JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid WHERE NOT blocked_locks.granted;"
```

### 2. Detect Long-Running Uncommitted Transactions
Locate transactions holding snapshots that threaten autovacuum:
```bash
psql -U postgres -d enterprise_db -c "SELECT pid, usename, now() - xact_start AS xact_duration, state, query FROM pg_stat_activity WHERE state IN ('idle in transaction', 'active') AND xact_start IS NOT NULL ORDER BY xact_duration DESC LIMIT 5;"
```

### 3. Terminate a Blocked or Stalled Database Backend Process
Gracefully cancel or terminate an offensive locking backend:
```bash
psql -U postgres -d enterprise_db -c "SELECT pg_terminate_backend(12345);"
```

---

## 11. Advanced Architecture & Edge-Case Failure Modes

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    CONCURRENCY FAILURE RECOVERY MATRIX                         │
├──────────────────────┬────────────────────────┬────────────────────────────────┤
│ Failure Scenario     │ Underlying Root Cause  │ Production Mitigation Runbook  │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Deadlock Abort**   │ Unordered lock         │ Sort lock keys in ASC order;   │
│ (`40P01`)            │ acquisition across DML.│ implement exponential backoff. │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Serialization**    │ SSI detected read/write│ Retry transaction in           │
│ **Failure (`40001`)**│ concurrent dependency. │ application retry loop.        │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Idle In Tx Bloat** │ Forgotten uncommitted  │ Set `idle_in_transaction_      │
│                      │ transaction connection.│ session_timeout = '30s'`.      │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Lock Starvation**  │ `ALTER TABLE` waiting  │ Set `lock_timeout = '2s'` on   │
│                      │ behind long read query.│ all schema migration scripts.  │
└──────────────────────┴────────────────────────┴────────────────────────────────┘
```

---

## 12. Detailed Sub-Components & Subsystems

### 1. PostgreSQL Snapshot Manager (`GetSnapshotData`)
* **Key Concepts**: Captures active transaction state vectors (`xmin`, `xmax`, `xip_list`), constructing immutable point-in-time visibility boundaries.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SELECT txid_current_snapshot();"
```

### 2. Lock Manager & Shared Lock Table
* **Key Concepts**: In-memory hash table tracking all granted and pending row, relation, and advisory locks across server backends.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SELECT locktype, mode, granted, count(*) FROM pg_locks GROUP BY locktype, mode, granted;"
```

### 3. Deadlock Detector Subsystem
* **Key Concepts**: Background daemon executing Tarjan's cycle-finding algorithm across the lock wait-for graph upon `deadlock_timeout` expiration.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SHOW deadlock_timeout;"
```

### 4. Serializable Snapshot Isolation (SSI) SIREAD Tracker
* **Key Concepts**: Tracks lock-free read dependencies in shared memory to detect rw-antidependency cycles, enforcing pure mathematical serializability.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SHOW max_pred_locks_per_transaction;"
```

---

## 13. References (The 5+5 Rule)

### Official Documentation & Academic Foundations
1. [PostgreSQL Official Documentation: Chapter 13. Concurrency Control](https://www.postgresql.org/docs/current/mvcc.html)
2. [PostgreSQL Official Documentation: Explicit Locking & Row-Level Lock Modes](https://www.postgresql.org/docs/current/explicit-locking.html)
3. [Hal Berenson, Philip Bernstein, Jim Gray et al.: A Critique of ANSI SQL Isolation Levels (ACM SIGMOD)](https://dl.acm.org/doi/10.1145/223784.223785)
4. [Michael Cahill et al.: Serializable Isolation for Snapshot Databases (ACM TODS)](https://dl.acm.org/doi/10.1145/1559795.1559801)
5. [MySQL 8.0 Reference Manual: InnoDB Locking and Transaction Model](https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-transaction-model.html)

### Authoritative Engineering Blogs & Architecture Deep Dives
6. [Brandur Leach: Postgres Transactions, Isolation Levels, and MVCC](https://brandur.org/postgres-isolation)
7. [Use The Index, Luke: Concurrency, Locking and Isolation](https://use-the-index-luke.com/)
8. [Martin Kleppmann: Transactions and Multi-Version Concurrency Control](https://dataintensive.net/)
9. [Craig Kerstiens: Understanding PostgreSQL Locking and Concurrency](https://www.craigkerstiens.com/)
10. [High-Performance PostgreSQL: Eliminating Deadlocks and Lock Contention](https://www.cybertec-postgresql.com/en/postgresql-deadlocks/)

---

## 14. Universal FinOps & Resource Cost Governance

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    CONCURRENCY FINOPS SAVINGS MATRIX                           │
├──────────────────────────┬──────────────────────────┬──────────────────────────┤
│ Optimization Strategy    │ Technical Mechanism      │ Measurable FinOps ROI    │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **`SKIP LOCKED` Queues** │ Eliminates lock polling  │ Cuts database queue CPU  │
│                          │ contention and waits     │ utilization by up to 85% │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Idle Tx Timeouts**     │ Aborts forgotten locks;  │ Prevents irreversible    │
│                          │ allows vacuum to run     │ cloud storage auto-scale │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Lock Order Sorting**   │ Eliminates deadlocks &   │ Reduces application      │
│                          │ transaction retries      │ compute retry storms     │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Read Committed Default**│ Minimizes SIREAD lock    │ Keeps shared memory      │
│                          │ tracking memory overhead │ footprint predictable    │
└──────────────────────────┴──────────────────────────┴──────────────────────────┘
```

### 1. In-Database Queuing (`SKIP LOCKED`) vs Cloud SQS/Redis Infrastructure
Deploying dedicated external queue infrastructure (AWS SQS, Managed Redis, RabbitMQ) for asynchronous background jobs introduces network hops, operational maintenance, and minimum hourly instance charges ($~\$150–\$500/\text{month}$).
- Implementing task queues directly in PostgreSQL using `FOR UPDATE SKIP LOCKED` handles **up to 15,000 tasks/second** on existing database compute.
- Multiple worker pods consume jobs concurrently with **zero lock contention** and zero CPU spin-wait polling.
- **FinOps ROI**: Eliminates external messaging broker licenses and cloud infrastructure bills, saving **\$3,600–\$6,000/year**.

### 2. Table Bloat Prevention from Stalled Transactions
When a microservice opens a transaction and hangs while waiting for an external third-party payment API (Stripe, PayPal) for 45 minutes:
- The old transaction snapshot blocks `autovacuum` from freeing dead tuples across all active tables.
- A high-velocity database accumulates 10GB of bloated dead rows per hour, triggering automatic cloud storage volume scaling.
- Because cloud storage **never auto-shrinks**, this permanently increases baseline storage costs.
- Setting `idle_in_transaction_session_timeout = '20s'` terminates hung connections automatically, protecting storage margins.
