# Module 13: Database Security — RBAC, Row-Level Security (RLS) & Cryptographic Hardening

**Track:** SQL Relational Engineering & Distributed Database Architecture  
**Category:** Enterprise Security, Multi-Tenant Isolation, Cryptography & Compliance Governance  
**Standard Identifier:** `DOC-STD-UNIVERSAL-2026`  
**Status:** ✅ Completed

---

## 📑 Table of Contents
1. [High-Level Overview & Executive Summary](#1-high-level-overview--executive-summary)
2. [The Defense-in-Depth Database Security Model](#2-the-defense-in-depth-database-security-model)
3. [Row-Level Security (RLS) & Multi-Tenant Isolation](#3-row-level-security-rls--multi-tenant-isolation)
4. [Role-Based Access Control (RBAC) & Principle of Least Privilege](#4-role-based-access-control-rbac--principle-of-least-privilege)
5. [Certification & Exam Essentials (Cheat Sheet)](#5-certification--exam-essentials-cheat-sheet)
6. [Comparative Analysis Matrix: Security Enforcement Models](#6-comparative-analysis-matrix-security-enforcement-models)
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

Enterprise relational database security implements a multi-layered **Defense-in-Depth Architecture** across network isolation, mutual TLS authentication, Role-Based Access Control (**RBAC**), Column-Level Encryption (**`pgcrypto`** / TDE), and **Row-Level Security (RLS)**. In modern multi-tenant SaaS platforms, RLS establishes an un-bypassable security boundary inside the database engine kernel, guaranteeing that tenant data remains completely isolated even if application-layer code suffers from SQL injection vulnerabilities.

```
┌────────────────────────────────────────────────────────────────────────────────┐
│               DEFENSE-IN-DEPTH DATABASE SECURITY MODEL                         │
├────────────────────────────────────────────────────────────────────────────────┤
│ 1. NETWORK PERIMETER : Private VPC Subnets, Security Groups, mTLS (TLS 1.3)    │
│         │                                                                      │
│         ▼                                                                      │
│ 2. AUTHENTICATION    : SCRAM-SHA-256 Password Hashing, AWS IAM DB Auth         │
│         │                                                                      │
│         ▼                                                                      │
│ 3. AUTHORIZATION     : RBAC Roles, Least Privilege GRANTs, Default Privileges  │
│         │                                                                      │
│         ▼                                                                      │
│ 4. ROW-LEVEL SECURITY: Engine-Enforced Tenant Isolation (`ENABLE RLS`)         │
│         │                                                                      │
│         ▼                                                                      │
│ 5. CRYPTOGRAPHY      : AES-256 Column Encryption (`pgcrypto`), Storage TDE     │
│         │                                                                      │
│         ▼                                                                      │
│ 6. AUDIT & LOGGING   : Compliance Change Logging (`pgaudit`, JSONB CDC Logs)   │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 👔 Executive Summary (For Managers & Non-Technical Stakeholders)
* **Business Purpose**: Enterprise databases store sensitive customer data, payment credentials, and corporate trade secrets. A single data breach or compliance violation can cost millions in regulatory fines (GDPR, HIPAA, PCI-DSS, SOC 2).
* **How It Works**: By enabling Row-Level Security (RLS) directly in the database engine, the database automatically filters out all data belonging to other companies. Even if an engineer writes a buggy query without a `WHERE` clause, the database kernel strictly enforces customer privacy.
* **Key Business Value & ROI**: Eliminates the risk of catastrophic multi-tenant data leaks, prevents SQL Injection attacks, and satisfies stringent compliance audit requirements with zero third-party software licensing costs.

---

## 2. The Defense-in-Depth Database Security Model

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    DATABASE SECURITY CONTROLS MATRIX                           │
├───────────────────┬──────────────────────────────────┬─────────────────────────┤
│ Security Tier     │ Technical Mechanism              │ Threat Neutralized      │
├───────────────────┼──────────────────────────────────┼─────────────────────────┤
│ **Authentication**│ SCRAM-SHA-256 & Client SSL Certs │ Man-in-the-Middle (MITM)│
│                   │ (`pg_hba.conf: scram-sha-256`)   │ credential sniffing     │
├───────────────────┼──────────────────────────────────┼─────────────────────────┤
│ **Authorization** │ RBAC Least Privilege Roles       │ Unauthorized privilege  │
│                   │ (`REVOKE ALL ON SCHEMA public`)  │ escalation by app users │
├───────────────────┼──────────────────────────────────┼─────────────────────────┤
│ **Data Isolation**│ Row-Level Security (RLS)         │ Cross-tenant data leaks │
│                   │ (`CREATE POLICY ... USING (...)`)| from ORM query bugs     │
├───────────────────┼──────────────────────────────────┼─────────────────────────┤
│ **Data at Rest**  │ AES-256 Column Encryption        │ Physical disk theft and │
│                   │ (`pgp_sym_encrypt`)              │ unencrypted backup dumps│
├───────────────────┼──────────────────────────────────┼─────────────────────────┤
│ **Auditability**  │ `pgaudit` Session & Object Logs  │ Non-repudiation and     │
│                   │                                  │ compliance audit checks │
└───────────────────┴──────────────────┴─────────────────────────┴───────────────┘
```

---

## 3. Row-Level Security (RLS) & Multi-Tenant Isolation

### 3.1 The RLS Query Rewrite Engine
When Row-Level Security is enabled on a table, the PostgreSQL Query Rewriter transparently injects security filter expressions into the Abstract Syntax Tree (AST):

```sql
-- Application executes:
SELECT * FROM financial_records;

-- Database Engine Kernel Rewrites and Executes:
SELECT * FROM financial_records 
WHERE tenant_id = CURRENT_SETTING('app.current_tenant_id', true)::BIGINT;
```

### 3.2 `USING` vs `WITH CHECK` Clauses:
- **`USING`**: Filters existing rows for `SELECT`, `UPDATE`, and `DELETE` operations (Determines what rows the user can *see*).
- **`WITH CHECK`**: Validates new rows being inserted or updated via `INSERT` and `UPDATE` (Determines what rows the user can *write*).

```sql
CREATE POLICY tenant_isolation_policy ON tenant_documents
    FOR ALL
    USING (tenant_id = CURRENT_SETTING('app.current_tenant_id', true)::BIGINT)
    WITH CHECK (tenant_id = CURRENT_SETTING('app.current_tenant_id', true)::BIGINT);
```

---

## 4. Role-Based Access Control (RBAC) & Principle of Least Privilege

### Hardening the Default Public Schema:
By default in PostgreSQL, all database users can create tables in the `public` schema. In production environments, this must be locked down immediately:

```sql
-- Revoke public permissions:
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Create Dedicated Read-Only and Read-Write Application Roles:
CREATE ROLE app_readonly_role;
GRANT USAGE ON SCHEMA public TO app_readonly_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly_role;

CREATE ROLE app_readwrite_role;
GRANT USAGE ON SCHEMA public TO app_readwrite_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_readwrite_role;

-- Enforce Default Privileges for Future Tables:
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_readonly_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_readwrite_role;
```

---

## 5. Certification & Exam Essentials (Cheat Sheet)

* ⚠️ **The `FORCE ROW LEVEL SECURITY` Requirement**: By default, table owners and database superusers bypass all RLS policies. To force the database engine to enforce RLS policies even when connected as the table owner:
  ```sql
  ALTER TABLE tenant_documents FORCE ROW LEVEL SECURITY;
  ```
* 🔒 **SQL Injection Elimination via Prepared Statements**: Never concatenate dynamic strings into SQL statements (`query = "SELECT * FROM users WHERE email = '" + input + "'"`). Always use prepared statements with binary parameter placeholders (`$1`, `$2`), which treat all user inputs strictly as literal data constants.
* ⚙️ **`SCRAM-SHA-256` Password Hashing**: In PostgreSQL `pg_hba.conf`, always enforce `scram-sha-256` instead of deprecated `md5` (which is vulnerable to collision attacks and rainbow tables).
* ⚠️ **RLS Performance & Function Leakage**: RLS policy expressions containing slow subqueries execute per candidate tuple. Ensure all columns referenced in RLS policies (e.g. `tenant_id`) are indexed with B-Tree indexes!

---

## 6. Comparative Analysis Matrix: Security Enforcement Models

| Security Model | Enforcement Layer | Vulnerability to SQL Injection | Multi-Tenant Safety | Operational Complexity |
| :--- | :--- | :--- | :--- | :--- |
| **Application-Layer WHERE**| Microservice Code | **High (1 missed filter leaks data)**| Low | High maintenance |
| **Database Views** | Relational View Logic | Moderate | Moderate | Moderate |
| **Row-Level Security (RLS)**| **Database Kernel Engine**| **Zero (Engine enforces policy)** | **Extreme** | Minimal |
| **Separate DB per Tenant** | Physical Database Instances| Zero | Extreme | **Extremely Expensive** |

---

## 7. Performance & Resource Optimization

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                        SECURITY PERFORMANCE PLAYBOOK                           │
├────────────────────────────────────────────────────────────────────────────────┤
│ 1. Index all tenant discriminator columns referenced in RLS `USING` clauses.   │
│ 2. Use `SET LOCAL` for session configuration variables to prevent state leak.  │
│ 3. Declare cryptographic functions as `PARALLEL SAFE` where applicable.        │
│ 4. Configure `pgaudit` to log DDL and role changes while filtering noisy DQL.  │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. In-Depth Engineering Perspectives

### Security Perspective
* **Column-Level Field Encryption (`pgcrypto`)**: For high-risk fields (SSNs, API secret keys), encrypt data in transit to storage using AES-256:
  ```sql
  INSERT INTO users (encrypted_ssn) VALUES (pgp_sym_encrypt('123-45-6789', 'master_secret_key'));
  ```

### High Availability Perspective
* **Role Replication Across Clusters**: Database roles and global permissions reside in the global `pg_authid` catalog, replicating automatically across physical streaming replicas.

### Resilience & Fault Tolerance Perspective
* **Connection Context Cleanup**: When using connection pooling (PgBouncer in transaction mode), always execute `SET LOCAL app.current_tenant_id = '123';` so that tenant context is automatically cleared when the transaction ends, preventing cross-request tenant leakage.

### Cost & Efficiency Perspective
* **Single Database Multi-Tenancy (Massive FinOps Savings)**: Using RLS allows hosting 10,000 SaaS customers inside a single shared database instance with military-grade isolation, eliminating the prohibitive cost of provisioning 10,000 separate database instances.

---

## 9. Step-by-Step Hands-On Production Walkthrough

### Step 1: Initialize Multi-Tenant Financial Storage

```sql
-- 1. Create Tenant Financial Document Table
CREATE TABLE enterprise_vault_documents (
    doc_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id BIGINT NOT NULL,
    document_title VARCHAR(200) NOT NULL,
    encrypted_payload BYTEA NOT NULL,
    classification VARCHAR(32) NOT NULL DEFAULT 'CONFIDENTIAL',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index tenant discriminator for high-speed RLS evaluation:
CREATE INDEX idx_vault_tenant_id ON enterprise_vault_documents (tenant_id);
```

---

### Step 2: Enable and Force Row-Level Security

```sql
-- 1. Enable RLS on Table
ALTER TABLE enterprise_vault_documents ENABLE ROW LEVEL SECURITY;

-- 2. CRITICAL: Force RLS on Table Owner
ALTER TABLE enterprise_vault_documents FORCE ROW LEVEL SECURITY;

-- 3. Create Tenant Isolation Policy using Session Variable
CREATE POLICY tenant_vault_isolation_policy ON enterprise_vault_documents
    FOR ALL
    USING (
        tenant_id = NULLIF(CURRENT_SETTING('app.current_tenant_id', true), '')::BIGINT
    )
    WITH CHECK (
        tenant_id = NULLIF(CURRENT_SETTING('app.current_tenant_id', true), '')::BIGINT
    );
```

---

### Step 3: Test Cross-Tenant Security Isolation

```sql
-- Initialize pgcrypto extension for AES encryption:
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Session 1: Tenant 100 Context Inserts Encrypted Document
BEGIN;
SET LOCAL app.current_tenant_id = '100';

INSERT INTO enterprise_vault_documents (tenant_id, document_title, encrypted_payload)
VALUES (
    100, 
    'Q3 Strategic Acquisition Plan', 
    pgp_sym_encrypt('Acquiring Competitor X for $50M', 'vault_passphrase_2026')
);
COMMIT;

-- Session 2: Tenant 200 Context Attempts to Read Tenant 100 Data
BEGIN;
SET LOCAL app.current_tenant_id = '200';

-- ⚡ RLS Automatically Returns ZERO Rows (Complete Isolation!):
SELECT doc_id, document_title, pgp_sym_decrypt(encrypted_payload, 'vault_passphrase_2026') 
FROM enterprise_vault_documents;
COMMIT;

-- Session 3: Tenant 100 Context Reads Authorized Document
BEGIN;
SET LOCAL app.current_tenant_id = '100';

SELECT 
    doc_id, 
    document_title, 
    pgp_sym_decrypt(encrypted_payload, 'vault_passphrase_2026') AS decrypted_plan
FROM enterprise_vault_documents;
COMMIT;
```

---

## 10. Pure CLI / Command Interface

### 1. Inspect Active RLS Policies Across Database Catalogs
Query registered row security policies and qualifying expressions:
```bash
psql -U postgres -d enterprise_db -c "SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check FROM pg_policies;"
```

### 2. Audit Table Row-Level Security Status
Verify that RLS and FORCE RLS are active:
```bash
psql -U postgres -d enterprise_db -c "SELECT relname, rowsecurity, forcerowsecurity FROM pg_class WHERE relname = 'enterprise_vault_documents';"
```

### 3. Verify SCRAM Password Authentication Configuration in pg_hba.conf
Check active host authentication configuration:
```bash
psql -U postgres -d enterprise_db -c "SELECT type, database, user_name, auth_method FROM pg_hba_file_rules;"
```

---

## 11. Advanced Architecture & Edge-Case Failure Modes

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    SECURITY FAILURE RECOVERY MATRIX                            │
├──────────────────────┬────────────────────────┬────────────────────────────────┤
│ Failure Scenario     │ Underlying Root Cause  │ Production Mitigation Runbook  │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Tenant Context**   │ `app.current_tenant_id`│ Enforce `NULLIF` in policy;    │
│ **Missing (Null)**   │ not set in session.    │ returns 0 rows safely.         │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Table Owner RLS**  │ Table owner bypasses   │ Execute `ALTER TABLE tbl FORCE │
│ **Bypass Leak**      │ default RLS policies.  │ ROW LEVEL SECURITY;`.          │
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **Search Path**      │ `SECURITY DEFINER`     │ Explicitly declare `SET        │
│ **Vulnerability**    │ lacks fixed path.      │ search_path = public, pg_temp`.│
├──────────────────────┼────────────────────────┼────────────────────────────────┤
│ **RLS Performance**  │ Missing B-Tree index   │ Create composite index on      │
│ **Degradation**      │ on `tenant_id`.        │ `(tenant_id, created_at)`.     │
└──────────────────────┴────────────────────────┴────────────────────────────────┘
```

---

## 12. Detailed Sub-Components & Subsystems

### 1. Row-Level Security (RLS) Policy Engine
* **Key Concepts**: Rewrites query parse trees during planning, prepending boolean policy qualifications (`qual`) to relation scan nodes.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "EXPLAIN (VERBOSE) SELECT * FROM enterprise_vault_documents;"
```

### 2. SCRAM-SHA-256 Authentication Module
* **Key Concepts**: Cryptographic challenge-response authentication protocol preventing password hashes from being sniffed over networks.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SHOW password_encryption;"
```

### 3. `pgaudit` Compliance Extension
* **Key Concepts**: Intercepts executor statements, emitting structured JSON audit logs for DDL, Role, and Data mutations to syslog/CloudWatch.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SHOW pgaudit.log;"
```

### 4. `pgcrypto` Cryptographic Engine
* **Key Concepts**: OpenSSL-backed cryptographic library providing AES-256, HMAC-SHA256, and OpenPGP encryption directly in SQL statements.
* **CLI / Tool Snippet**:
```bash
psql -U postgres -d enterprise_db -c "SELECT digest('password123', 'sha256');"
```

---

## 13. References (The 5+5 Rule)

### Official Documentation & Security Standards
1. [PostgreSQL Official Documentation: Chapter 5.8. Row Security Policies (RLS)](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
2. [PostgreSQL Official Documentation: Chapter 22. Database Roles and Privileges](https://www.postgresql.org/docs/current/user-manag.html)
3. [PostgreSQL Official Documentation: pgcrypto Cryptographic Module](https://www.postgresql.org/docs/current/pgcrypto.html)
4. [IETF RFC 7677: SCRAM-SHA-256 Authentication Mechanism](https://www.rfc-editor.org/rfc/rfc7677.html)
5. [OWASP Top 10: SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)

### Authoritative Engineering Blogs & Architecture Deep Dives
6. [Brandur Leach: Multi-Tenant Data Isolation with PostgreSQL Row-Level Security](https://brandur.org/postgres-rls)
7. [Use The Index, Luke: Security and Performance in Multi-Tenant Relational Databases](https://use-the-index-luke.com/)
8. [Craig Kerstiens: Implementing Row-Level Security in PostgreSQL](https://www.craigkerstiens.com/)
9. [High-Performance PostgreSQL: Hardening PostgreSQL Security Defenses](https://www.cybertec-postgresql.com/en/postgresql-row-level-security-security-and-performance/)
10. [Database Trends & Applications: Enterprise Database Governance & Encryption](https://www.dbta.com/)

---

## 14. Universal FinOps & Resource Cost Governance

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                      SECURITY FINOPS SAVINGS MATRIX                            │
├──────────────────────────┬──────────────────────────┬──────────────────────────┤
│ Optimization Strategy    │ Technical Mechanism      │ Measurable FinOps ROI    │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **RLS Multi-Tenancy**    │ Shared database instance │ Saves \$100k+/year vs    │
│                          │ with kernel isolation    │ dedicated DB per tenant  │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Connection Context**   │ `SET LOCAL` session state│ Eliminates external IAM  │
│                          │ avoids auth roundtrips   │ token validation calls   │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **Indexed RLS Predicates**│ Keeps RLS evaluation     │ Prevents 90% CPU spikes  │
│                          │ $O(\log N)$ in memory    │ on multi-tenant queries  │
├──────────────────────────┼──────────────────────────┼──────────────────────────┤
│ **In-Database Crypto**   │ `pgcrypto` column encrypt│ Eliminates expensive KMS │
│                          │ avoids external KMS calls│ API per-request call fees│
└──────────────────────────┴──────────────────────────┴──────────────────────────┘
```

### 1. RLS Multi-Tenancy vs Dedicated Database Fleet Sizing
When building a SaaS platform serving 2,000 corporate clients:
- **Dedicated Database Architecture**: Provisioning 2,000 separate minimal cloud database instances (e.g. AWS RDS `db.t4g.micro` @ \$15/month each) costs **\$30,000 per month (\$360,000/year)** with massive operational maintenance overhead.
- **RLS Multi-Tenant Architecture**: Hosting all 2,000 tenants in a single shared, highly-available PostgreSQL cluster (`db.r6g.2xlarge` Multi-AZ @ **\$1,200/month**) enforced by Row-Level Security delivers the exact same data isolation guarantees.
- **FinOps Savings**: **\$28,800/month (\$345,600/year in direct cloud infrastructure savings)**.

### 2. In-Database Encryption vs Cloud KMS API Fee Optimization
When an application encrypts and decrypts 50 million sensitive database fields monthly using external cloud KMS APIs (e.g. AWS KMS @ \$0.03 per 10,000 requests):
- Cloud KMS API requests generate **\$1,500/month in billable KMS API fees**, plus 15ms of added network latency per transaction.
- Encrypting data directly in PostgreSQL using `pgcrypto` (`pgp_sym_encrypt`) with an in-memory secret key performs encryption in **0.02 milliseconds** with **\$0 in cloud KMS API request fees**.
