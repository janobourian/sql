# Relational Database Architecture & Enterprise SQL — Master Curriculum Index

**Repository:** `vit/sql`
**Domain:** Relational Database Engineering, ACID Internals, Query Optimization & High Availability
**Target Certifications:** PostgreSQL Certified Professional, Oracle Database SQL Certified, AWS Database Specialty
**Status:** ✅ Complete Production-Grade Reference

---

## 📚 Complete Module Index

| Module | Core Topics & Hands-On Scope | Target Certifications | Document Link |
| :--- | :--- | :--- | :--- |
| **00. Database Foundations & ACID** | RDBMS engines, Codd's relational model, ACID guarantees, Buffer pool, WAL logging | Postgres, MySQL | [`00_relational_database_foundations_rdbms_engines_and_acid.md`](00_relational_database_foundations_rdbms_engines_and_acid.md) |
| **01. DDL & Normalization (1NF-5NF)** | Schema design, 1NF to 5NF decomposition, integrity constraints (PK, FK, CHECK, UNIQUE) | All Tracks | [`01_ddl_table_design_data_types_and_constraints.md`](01_ddl_table_design_data_types_and_constraints.md) |
| **02. DML & Batch Operations** | `INSERT`, `UPDATE`, `DELETE`, atomic UPSERT (`ON CONFLICT`), `TRUNCATE` vs `DELETE` | Postgres, MySQL | [`02_dml_crud_operations_upserts_and_batch_processing.md`](02_dml_crud_operations_upserts_and_batch_processing.md) |
| **03. Query Fundamentals & NULL** | Logical execution order, SARGable predicates, ANSI Three-Valued Logic (3VL), COALESCE | SQL Specialist | [`03_query_fundamentals_filtering_sorting_and_null_semantics.md`](03_query_fundamentals_filtering_sorting_and_null_semantics.md) |
| **04. Joins Deep Dive** | INNER, LEFT/RIGHT/FULL OUTER, CROSS, SELF, ANTI-JOIN, SEMI-JOIN, Hash vs Merge Join | All Tracks | [`04_joins_deep_dive_inner_outer_cross_self_and_anti_joins.md`](04_joins_deep_dive_inner_outer_cross_self_and_anti_joins.md) |
| **05. Aggregations & Grouping** | `GROUP BY`, `HAVING`, multi-dimensional `GROUPING SETS`, `ROLLUP`, `CUBE`, string_agg | BI & Analytics | [`05_aggregations_group_by_having_and_cube_rollup.md`](05_aggregations_group_by_having_and_cube_rollup.md) |
| **06. Subqueries & CTEs** | Subqueries, correlated queries, Common Table Expressions (`WITH`), Recursive CTEs | Advanced SQL | [`06_subqueries_correlated_queries_and_common_table_expressions_ctes.md`](06_subqueries_correlated_queries_and_common_table_expressions_ctes.md) |
| **07. Advanced Window Functions** | `OVER()`, `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LEAD`, `LAG`, window frames (`ROWS BETWEEN`) | Data Eng, BI | [`07_advanced_window_functions_ranking_analytics_and_frames.md`](07_advanced_window_functions_ranking_analytics_and_frames.md) |
| **08. Transactions & MVCC** | Isolation levels (Read Committed to Serializable), MVCC (`xmin`/`xmax`), row locking | Backend, SRE | [`08_transactions_acid_guarantees_isolation_levels_and_mvcc.md`](08_transactions_acid_guarantees_isolation_levels_and_mvcc.md) |
| **09. Indexing Strategies** | B-Tree internals, Hash, GIN (JSONB), GiST, BRIN, Partial & Covering Indexes (`INCLUDE`) | DBA, Performance | [`09_indexing_strategies_btree_hash_gin_gist_and_covering_indexes.md`](09_indexing_strategies_btree_hash_gin_gist_and_covering_indexes.md) |
| **10. Query Optimization & EXPLAIN** | Cost-Based Optimizer (CBO), `EXPLAIN (ANALYZE, BUFFERS)`, sequential vs index scans | Performance, DBA | [`10_query_optimization_execution_plans_and_explain_analyze.md`](10_query_optimization_execution_plans_and_explain_analyze.md) |
| **11. Stored Procedures & Triggers** | Procedural SQL (PL/pgSQL), functions vs procedures, row triggers (`BEFORE`/`AFTER`) | Backend, DBA | [`11_stored_procedures_user_defined_functions_and_triggers.md`](11_stored_procedures_user_defined_functions_and_triggers.md) |
| **12. Views & Table Partitioning** | Materialized Views with concurrent refresh, Declarative Partitioning (Range, List, Hash) | Data Eng, DBA | [`12_views_materialized_views_and_declarative_partitioning.md`](12_views_materialized_views_and_declarative_partitioning.md) |
| **13. Database Security & RLS** | RBAC roles, Row-Level Security (RLS) multi-tenancy, pgcrypto, SQL injection defense | Security, DBA | [`13_database_security_rbac_row_level_security_and_encryption.md`](13_database_security_rbac_row_level_security_and_encryption.md) |
| **14. High Availability & Sharding** | Streaming replication, transaction connection pooling (PgBouncer), read replicas | SRE, Cloud Arch | [`14_high_availability_streaming_replication_and_sharding.md`](14_high_availability_streaming_replication_and_sharding.md) |
| **15. Enterprise Master Blueprints** | Immutable double-entry financial ledger, covering indexes, partition lifecycle | All Tracks | [`15_real_world_enterprise_sql_case_studies_and_blueprints.md`](15_real_world_enterprise_sql_case_studies_and_blueprints.md) |

---

## 📌 Original SQL Scripts & Historical Labs (Preserved)

All original project SQL scripts in this repository remain 100% functional and intact:

* [`01_sql_code.sql`](file:///Users/frgonzal/Documents/vit/sql/01_sql_code.sql): Core SQL operations and data insertion exercises.
* [`03_sql_language.sql`](file:///Users/frgonzal/Documents/vit/sql/03_sql_language.sql): SQL language syntax, types, and schema setup.
* [`04_query_basics.sql`](file:///Users/frgonzal/Documents/vit/sql/04_query_basics.sql): Query basics, aliases, and filtering.
* [`05_create.sql`](file:///Users/frgonzal/Documents/vit/sql/05_create.sql): Table creation, primary keys, and foreign keys.

---

## 🛠️ Documentation Standards Applied Across All Guides

1. **👔 Executive Summary**: Non-technical explanation of business purpose, mechanics, and value for managers and teammates.
2. **Technical Deep Dives**: Comprehensive architecture explanations, execution plan operators, and B-Tree algorithms.
3. **Hands-On Step-by-Step Walkthroughs**: Reproducible labs for designing, indexing, optimizing, and securing databases.
4. **Clean, Escaped CLI Snippets**: Formatted with trailing `\` line escapes, 4-space indentation, and zero in-code comments.
5. **Trustworthy Curated Sources**: Exactly 5 official documentation links + 5 authoritative engineering blogs per module.
6. **FinOps & Resource Governance**: 500+ word guidelines on buffer pool right-sizing, connection pooling, and storage pruning.
