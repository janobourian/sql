# Module 14: High Availability, Streaming Replication, Connection Pooling & Sharding

**Track:** SQL Relational Engineering & Distributed Database Architecture
**Category:** High Availability, Streaming Replication, Connection Multiplexing & Distributed Scaling
**Standard Identifier:** `DOC-STD-UNIVERSAL-2026`
**Status:** ✅ Completed

---

## 📑 Table of Contents

1. [High-Level Overview & Executive Summary](#1-high-level-overview--executive-summary)

2. [Physical vs Logical Streaming Replication Internals](#2-physical-vs-logical-streaming-replication-internals)

3. [Connection Pooling Architecture: PgBouncer Deep Dive](#3-connection-pooling-architecture-pgbouncer-deep-dive)

4. [Automated Failover & High Availability Clustering (Patroni + Raft)](#4-automated-failover--high-availability-clustering-patroni--raft)

5. [Certification & Exam Essentials (Cheat Sheet)](#5-certification--exam-essentials-cheat-sheet)

6. [Comparative Analysis Matrix: Database Scaling Models](#6-comparative-analysis-matrix-database-scaling-models)

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

Scaling relational database systems to sustain hundreds of thousands of transactions per second with 99.999% availability requires a distributed infrastructure topology: **Physical Streaming Replication** (Write-Ahead Log streaming from Primary to Read Replicas), **Logical Replication** (table-level Pub/Sub for cross-version zero-downtime upgrades), **Connection Multiplexing** (PgBouncer transaction-mode pooling), and **Consensus-Driven Failover Orchestration** (Patroni + etcd).

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│           ENTERPRISE HIGH-AVAILABILITY & CONNECTION POOLING ARCHITECTURE       │
├────────────────────────────────────────────────────────────────────────────────┤
│ [10,000 Application Client Connections]                                        │
│         │                                                                      │
│         ▼                                                                      │
│ ┌────────────────────────────────────────────────────────────────────────────┐ │
│ │ PGBOUNCER CONNECTION POOLER (epoll single-threaded transaction multiplexer)│ │
│ └──────────────────────────────┬─────────────────────────────────────────────┘ │
│                                │ (50 Pooled Server Connections)                │
│                                ▼                                               │
│ ┌────────────────────────────────────────────────────────────────────────────┐ │
│ │ PRIMARY DB NODE (Leader)                                                   │ │
│ │ - Handles 100% of Writes (INSERT, UPDATE, DELETE)                          │ │
│ │ - Generates Write-Ahead Log (WAL) ──► `walsender` process                  │ │
│ └──────────────────────────────┬─────────────────────────────────────────────┘ │
│                                │ (Physical WAL TCP Streaming)                  │
│                                ▼                                               │
│ ┌────────────────────────────────────────────────────────────────────────────┐ │
│ │ STANDBY REPLICA NODES (Followers)                                          │ │
│ │ - `walreceiver` receives WAL blocks ──► Startup process applies redo replay│ │
│ │ - Serves 100% of Analytical and Read-Only Traffic                          │ │
│ └────────────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 👔 Executive Summary (For Managers & Non-Technical Stakeholders)

* **Business Purpose**: Unplanned database outages halt business operations, resulting in lost revenue, brand reputation damage, and SLA penalty fees.
* **How It Works**: High Availability architectures deploy live replica copies of the database in separate data centers. If the primary database hardware catches fire or suffers a network failure, automated monitoring systems (Patroni) promote a standby replica to leader within 10 to 15 seconds without losing data.
* **Key Business Value & ROI**: Delivers 99.999% uptime ("five nines"), eliminates database connection memory exhaustion, and allows the platform to scale to millions of concurrent active users.

---

## 2. Physical vs Logical Streaming Replication Internals

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│               PHYSICAL VS LOGICAL REPLICATION COMPARISON                       │
├──────────────────────────┬──────────────────────────┬──────────────────────────┤
│ Dimension                │ Physical Replication     │ Logical Replication      │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Replication Payload**  │ Exact binary byte WAL    │ Decoded logical tuple DML│
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Granularity**          │ Whole cluster/instance   │ Specific tables/schemas  │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Standby Mutability**   │ Read-Only (`hot_standby`)| **Read-Write enabled**   │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Cross-Version Support**│ Same major version only  │ **Different PG versions**│
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **DDL Replication**      │ Full automatic DDL       │ DML only (DDL manual)    │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Best For**             │ Disaster recovery & HA   │ Zero-downtime upgrades   │
└──────────────────────────┴──────────────────────────┴──────────────────────────┘
```

### 2.1 The `synchronous_commit` Levels & RPO Guarantees

* **`off`**: Writes WAL to memory only; commits instantly. (Risk: Loses up to 3 seconds of data on power outage).
* **`local` / `on`**: Flushes WAL to local primary disk before acknowledging commit to client. (Zero data loss on primary failure; replica may lag slightly).
* **`remote_write`**: Waits until Standby OS acknowledges receiving WAL bytes into memory.
* **`remote_apply`**: Primary waits until Standby has physically replayed and applied the transaction in memory. (**Zero RPO guarantee**; maximum latency).

---

## 3. Connection Pooling Architecture: PgBouncer Deep Dive

In PostgreSQL, each incoming client connection spawns a dedicated **OS backend process** consuming 5MB to 10MB of baseline RAM plus per-query `work_mem`. Connecting 5,000 application pods directly to PostgreSQL requires **~50GB of RAM just for connection memory**, causing severe kernel context-switching degradation.

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                    PGBOUNCER POOLING MODES BREAKDOWN                           │
├───────────────────┬──────────────────────────────────┬─────────────────────────┤
│ Pool Mode         │ Connection Binding Duration      │ Compatibility Notes     │
├───────────────────┼──────────────────────────────────┼─────────────────────────┤
│ **`session`**     │ Entire client socket lifetime    │ Supports all features   │
├───────────────────┼──────────────────────────────────┼─────────────────────────┤
│ **`transaction`** │ **Duration of 1 Transaction**    │ **Recommended default** │
│ (High-Throughput) │ Released on `COMMIT`/`ROLLBACK`  │ (No `SET` session vars) │
├───────────────────┼──────────────────────────────────┼─────────────────────────┤
│ **`statement`**   │ Duration of a single SQL query   │ Multi-statement trans   │
│                   │                                  │ not allowed!            │
└───────────────────┴──────────────────────────────────┴─────────────────────────┘
```

---

## 4. Automated Failover & High Availability Clustering (Patroni + Raft)

To eliminate single points of failure without risking split-brain data corruption, enterprise architectures deploy **Patroni**:

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                     PATRONI CONSENSUS HA CLUSTER                               │
├────────────────────────────────────────────────────────────────────────────────┤
│                     [ETCD DISTRIBUTED CONSENSUS CLUSTER]                       │
│                     (Maintains Leader Lock via Raft Key-Value)                 │
│                               ▲             ▲                                  │
│                        Heartbeat          Heartbeat                            │
│                               │             │                                  │
│                   ┌───────────┴─┐         ┌─┴───────────┐                      │
│                   │ PATRONI AGT │         │ PATRONI AGT │                      │
│                   │ (Primary)   │         │ (Standby)   │                      │
│                   ├─────────────┤         ├─────────────┤                      │
│                   │ Postgres DB │────WAL─►│ Postgres DB │                      │
│                   └─────────────┘         └─────────────┘                      │
└────────────────────────────────────────────────────────────────────────────────┘
```

1. **Leader Key Lease**: The Primary Patroni agent holds an ephemeral leader key in `etcd` with a TTL (e.g. 10 seconds), renewing it continuously.
2. **Automated Promotion**: If the Primary node fails to renew its lease, `etcd` expires the key. The Standby Patroni agent detecting the lowest WAL lag wins the leader election and runs `pg_ctl promote` within 10 seconds.
3. **Fencing (Shoot The Other Node In The Head - STONITH)**: Hardware watchdogs or cloud API fencing terminate the failed primary to guarantee it cannot write data if it reboots.

---

## 5. Certification & Exam Essentials (Cheat Sheet)

* ⚠️ **Replication Slots & Disk Exhaustion**: A **Physical Replication Slot** (`pg_create_physical_replication_slot()`) guarantees the Primary node will **never** delete WAL files until the Standby has acknowledged receiving them. **Critical Warning**: If a Standby goes offline, the Primary will accumulate gigabytes of WAL files on disk until the primary disk fills up and crashes the entire database! Always configure `max_slot_wal_keep_size = '20GB'`.
* 🔒 **Standby Query Cancellation (`max_standby_streaming_delay`)**: When an incoming WAL replay on a Standby needs to clean up a dead tuple currently being read by a long-running reporting query, PostgreSQL will pause WAL replay. After `max_standby_streaming_delay` (default: 30s), it **cancels the read query** with `ERROR: canceling statement due to conflict with recovery`.
* ⚙️ **Read/Write Splitting with HAProxy / PgBouncer**: Configure dual listening ports:
  * Port 5000: Routes to Primary Node (Read-Write).
  * Port 5001: Round-robins across Standby Nodes (Read-Only).
* ⚠️ **Logical Replication Sequences**: Logical replication synchronizes table DML, but does **not** replicate `SEQUENCE` states (`last_value`). Sequences must be manually synchronized before performing a failover or cutover.

---

## 6. Comparative Analysis Matrix: Database Scaling Models

| Architecture Model | Write Scalability | Read Scalability | High Availability (RTO) | Data Consistency (RPO) |
| :--- | :--- | :--- | :--- | :--- |
| **Single Master + Replicas** | Single node limit | Unlimited (Add replicas) | 10–30 seconds (Patroni) | Zero or < 1 second |
| **Multi-Master (BDR/Galera)** | Moderate (Write conflicts) | High | Near Instant | Strict / Synchronous |
| **Citus Distributed Sharding** | **Near Infinite (Scale-out)** | Near Infinite | Managed per worker node | Strict |
| **Cloud Managed (Aurora/AlloyDB)** | Single master / Fast write | High (Shared Storage) | < 15 seconds | Storage-Level Sync |

---

## 7. Performance & Resource Optimization

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                        HA & POOLING TUNING PLAYBOOK                            │
├────────────────────────────────────────────────────────────────────────────────┤
│ 1. Deploy PgBouncer in `pool_mode = transaction` in front of all OLTP apps.   │
│ 2. Set `max_connections = 100` on Postgres; size PgBouncer `max_client_conn = 5000`.│
│ 3. Set `max_slot_wal_keep_size = '30GB'` to prevent disconnected replica disk crash.│
│ 4. Route analytical reporting workloads exclusively to Read Replicas.         │
│ 5. Enable WAL compression (`wal_compression = lz4`) to reduce network transit.│
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. In-Depth Engineering Perspectives

### Security Perspective

* **Replication User Permissions**: The replication connection must use a dedicated role with minimal privileges (`CREATE ROLE repl_user WITH REPLICATION LOGIN PASSWORD '...'`), restricted in `pg_hba.conf` strictly to the Standby replica's private IP subnet.

### High Availability Perspective

* **Cascading Replication for Multi-Region DR**: To avoid saturating Primary server bandwidth when replicating across cross-region data centers (e.g. US-East to EU-West), configure **Cascading Replication**: Primary streams to a local Standby in US-East, which acts as the upstream sender to the EU-West Standby.

### Resilience & Fault Tolerance Perspective

* **Read-Replica Lag Mitigation**: Applications requiring immediate "read-your-own-writes" consistency (e.g. viewing user profile immediately after editing) should direct reads to the Primary node for 2 seconds post-write before falling back to read replicas.

### Cost & Efficiency Perspective

* **WAL Compression Bandwidth Savings**: Enabling `wal_compression = lz4` compresses raw WAL byte records by 50%–70% before network transmission, slashing cross-region and cross-AZ cloud network egress bills.

---

## 9. Step-by-Step Hands-On Production Walkthrough

### Step 1: Configure Primary Streaming Replication Settings

```sql
-- Execute on Primary Node:
-- 1. Create Dedicated Replication User
CREATE ROLE repl_user WITH REPLICATION LOGIN PASSWORD 'SuperSecretReplication2026!';

-- 2. Create Physical Replication Slot for Standby
SELECT pg_create_physical_replication_slot('standby_slot_node1');

-- 3. Verify Slot Creation
SELECT slot_name, plugin, active, wal_status FROM pg_replication_slots;
```

---

### Step 2: Configure Standby Initialization via pg_basebackup

```bash

# 1. Stop Standby Server and Clear Data Directory
pg_ctl -D /var/lib/postgresql/data stop
rm -rf /var/lib/postgresql/data/*

# 2. Stream Base Backup from Primary with Standby Configuration
pg_basebackup \
    -h 10.0.1.10 \
    -p 5432 \
    -U repl_user \
    -D /var/lib/postgresql/data \
    -Fp -Xs -R \
    --slot=standby_slot_node1

# 3. Start Standby Server (Automatically Enters Hot Standby Mode!)
pg_ctl -D /var/lib/postgresql/data start
```

---

### Step 3: Configure PgBouncer Connection Multiplexer

```ini

# /etc/pgbouncer/pgbouncer.ini
[databases]
enterprise_db = host=127.0.0.1 port=5432 dbname=enterprise_db pool_mode=transaction

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 10000
default_pool_size = 50
min_pool_size = 10
reserve_pool_size = 10
reserve_pool_timeout = 5
server_idle_timeout = 60
```

---

### Step 4: Verify Replication Status and Byte Lag

```sql
-- Query Primary Node to verify streaming state and byte lag:
SELECT
    client_addr,
    application_name,
    state,
    sync_state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) AS pending_bytes,
    pg_wal_lsn_diff(sent_lsn, write_lsn) AS write_lag_bytes,
    pg_wal_lsn_diff(write_lsn, replay_lsn) AS replay_lag_bytes
FROM pg_stat_replication;
```

---

## 10. Pure CLI / Command Interface

### 1. Inspect Replication Lag and Synchronization Metrics

Verify replica status directly from shell:

```bash
psql -U postgres -d enterprise_db -c "SELECT client_addr, sync_state, state, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS total_lag_bytes FROM pg_stat_replication;"
```

### 2. Inspect Active PgBouncer Connection Pools and Queued Clients

Query PgBouncer administrative console:

```bash
psql -p 6432 -U postgres -d pgbouncer -c "SHOW POOLS;"
```

### 3. Check for Standby Node Replication Pause or Recovery State

Query Standby recovery state:

```bash
psql -U postgres -d enterprise_db -c "SELECT pg_is_in_recovery(), pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(), pg_last_xact_replay_timestamp();"
```

---

## 11. Advanced Architecture & Edge-Case Failure Modes

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                    REPLICATION FAILURE RECOVERY MATRIX                         │
├──────────────────────┬────────────────────────┬────────────────────────────────┤
│ Failure Scenario     │ Underlying Root Cause  │ Production Mitigation Runbook  │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **WAL Disk Runaway** │ Inactive replication   │ Set `max_slot_wal_keep_size`   │
│                      │ slot accumulating WAL. │ or drop stale slot.            │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Split-Brain State**│ Two nodes believe they │ Deploy Patroni with etcd Raft  │
│                      │ are both Primary.      │ consensus & watchdog fencing.  │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Recovery Conflict**│ Dead tuple cleanup on  │ Increase `max_standby_streaming│
│ **Cancellations**    │ Standby cancels query. │ _delay` or route to Primary.   │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Connection Pool**  │ Long-running tx holding│ Terminate idle transactions;   │
│ **Exhaustion**       │ PgBouncer pooled slot. │ tune `default_pool_size`.      │
└──────────────────────┴────────────────────────┴────────────────────────────────┘
```

---

## 12. Detailed Sub-Components & Subsystems

### 1. WAL Sender Subsystem (`walsender`)

* **Key Concepts**: Backend process on Primary responsible for streaming Write-Ahead Log page frames across TCP sockets to registered standbys.
* **CLI / Tool Snippet**:

```bash
psql -U postgres -d enterprise_db -c "SELECT count(*) FROM pg_stat_replication;"
```

### 2. WAL Receiver Subsystem (`walreceiver`)

* **Key Concepts**: Background process on Standby node responsible for consuming incoming WAL network frames and writing them to Standby storage.
* **CLI / Tool Snippet**:

```bash
psql -U postgres -d enterprise_db -c "SELECT * FROM pg_stat_wal_receiver;"
```

### 3. Replication Slot Controller

* **Key Concepts**: Prevents the database checkpoint engine from recycling or deleting WAL segments that downstream standbys have not yet replayed.
* **CLI / Tool Snippet**:

```bash
psql -U postgres -d enterprise_db -c "SELECT * FROM pg_replication_slots;"
```

### 4. PgBouncer Epoll Loop Multiplexer

* **Key Concepts**: Single-threaded C event loop multiplexing asynchronous I/O sockets via `epoll`, dispatching client transactions to pre-authenticated backend sockets.
* **CLI / Tool Snippet**:

```bash
psql -p 6432 -U postgres -d pgbouncer -c "SHOW STATS;"
```

---

## 13. References (The 5+5 Rule)

### Official Documentation & Academic Foundations

1. [PostgreSQL Official Documentation: Chapter 27. High Availability, Load Balancing, and Replication](https://www.postgresql.org/docs/current/high-availability.html)
2. [PostgreSQL Official Documentation: Streaming Replication Protocol](https://www.postgresql.org/docs/current/protocol-replication.html)
3. [PostgreSQL Official Documentation: Logical Replication](https://www.postgresql.org/docs/current/logical-replication.html)
4. [PgBouncer Official Documentation: Architectural Overview & Configuration](https://www.pgbouncer.org/config.html)
5. [Patroni HA Documentation: Architectural Overview & DCS Consensus](https://patroni.readthedocs.io/en/latest/)

### Authoritative Engineering Blogs & Architecture Deep Dives

1. [Brandur Leach: Scaling Postgres with PgBouncer Connection Pooling and Prepared Statements](https://brandur.org/postgres-connections)
2. [Craig Kerstiens: PostgreSQL Streaming Replication and High Availability](https://www.craigkerstiens.com/)
3. [High-Performance PostgreSQL: Zero Data Loss Synchronous Replication and Failover](https://www.cybertec-postgresql.com/en/synchronous-replication-in-postgresql/)
4. [Use The Index, Luke: Distributed Database Scaling and Read-Replica Consistency](https://use-the-index-luke.com/)
5. [Database Trends & Applications: Modern Relational HA Architecture & Clustering](https://www.dbta.com/)

---

## 14. Universal FinOps & Resource Cost Governance

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                      HA FINOPS COST SAVINGS MATRIX                             │
├──────────────────────────┬──────────────────────────┬──────────────────────────┤
│ Optimization Strategy    │ Technical Mechanism      │ Measurable FinOps ROI    │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **PgBouncer Multiplexing**| 10,000 clients share 50  │ Cuts database server RAM │
│                          │ backend connections      │ requirements by 80%      │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Read/Write Splitting** │ Offloads queries to low- │ Prevents over-sizing     │
│                          │ cost read-only replicas  │ expensive Primary node   │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **`wal_compression`**    │ LZ4 compresses WAL before│ Reduces cross-AZ network │
│                          │ network streaming        │ transit fees by 60%      │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **`max_slot_wal_size`**  │ Caps maximum WAL backlog │ Prevents catastrophic    │
│                          │ on primary storage disk  │ storage volume auto-scale│
└──────────────────────────┴──────────────────────────┴──────────────────────────┘
```

### 1. PgBouncer Connection Pooling RAM Reduction

Without a connection pooler, 5,000 application microservice pods connecting directly to PostgreSQL:

* Require setting `max_connections = 5000`.
* Each connection allocates 8MB to 10MB of baseline memory, consuming **~45 Gigabytes of RAM strictly for idle connection buffers**.
* Supporting this workload requires provisioning an `db.r6g.4xlarge` (128GB RAM @ **\$1,220/month**).
* Deploying **PgBouncer in transaction pooling mode** handles the 5,000 client sockets while maintaining only **50 active connections** to PostgreSQL.
* Database memory consumption drops from 45GB to **under 500 Megabytes**, allowing the database instance to downsize to an `db.r6g.large` (16GB RAM @ **\$155/month**).
* **FinOps ROI**: **\$12,780/year in direct AWS RDS compute savings per database cluster**.

### 2. WAL Network Compression Egress Optimization

In high-write OLTP databases generating 500GB of WAL logs daily streaming across cloud availability zones (AWS Cross-AZ network billing @ \$0.01/GB):

* Uncompressed replication generates 500GB $\times 30 = 15\text{ TB}$ of cross-AZ network traffic ($~\$150/\text{month per replica}$).
* Enabling `wal_compression = lz4` reduces daily replicated WAL data from 500GB to **175GB**, saving **\$1,170/year in raw network egress fees** across a 3-replica cluster.
