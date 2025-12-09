# Digital ID Lab — PL/SQL Capstone Project

**Project Overview**
- **Project:** Digital ID Lab (PL/SQL Capstone)
- **Owner:** `KALISAINEZAJovith`
- **Purpose:** Prototype a secure digital identity system with a focus on privacy, consent management, access auditing, and analytics. The repository includes schema creation scripts, sample data, PL/SQL packages, audit logging, and BI-ready queries.

**Repository Structure**
- `database/scripts/` — SQL scripts to create the schema, insert sample data, and provide stored procedures/functions.
- `queries/` — Useful SQL retrieval, audit, and analytics queries ready for SQL*Plus or SQL Developer:
  - `data_retrieval.sql` — general retrieval queries (citizens, digital IDs, consents, logs).
  - `audit_queries.sql` — audit/security-focused queries (denied attempts, IPs, violations).
  - `analytics_queries.sql` — KPI and trend queries for dashboards (monthly trends, cohorts, approval KPIs).
- `documentation/` — project documentation and data dictionary.
- `screenshots/` — saved images for demonstrations and test outputs.

**Key Database Objects**
- `citizens` — citizen personal and registration data.
- `digital_ids` — issued digital identifiers with encryption metadata and biometric hash placeholders.
- `data_categories` — types of data and sensitivity levels.
- `authorized_entities` — organizations allowed to request data.
- `consent_records` — records of consent grants and revocations.
- `access_requests` — requests by entities to access citizen data.
- `access_logs` — immutable audit trail of access attempts.
- `alerts`, `violations`, `holidays` — security and operational tables.

**Setup & Usage (Oracle / SQL Developer)**
- Prerequisites: Oracle Database (12c+ recommended) and a SQL client (SQL*Plus, SQL Developer).
- To create the schema and objects, run the scripts in order from `database/scripts/`:

```powershell
@database/scripts/00_database_creation.sql
@database/scripts/01_create_tables.sql
@database/scripts/02_insert_data.sql
@database/scripts/03_procedures.sql
@database/scripts/04_functions.sql
@database/scripts/05_packages.sql
@database/scripts/06_Cursors_Window_Functions.sql
@database/scripts/07_Complete_Testing_Script.sql
```

- After schema creation, open the files in `queries/` to run analytic or audit queries. Bind variables used in the SQL files (e.g. `:citizen_id`, `:days_back`) should be supplied by your SQL client.

**Quick Examples**
- Count total citizens:

```sql
SELECT COUNT(*) FROM citizens;
```

- Show recent denied access attempts (set :days_back in your client):

```sql
SELECT *
FROM access_logs
WHERE action_result='DENIED'
  AND action_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(:days_back,'DAY');
```

**Analytics & BI**
- `analytics_queries.sql` contains dashboard-ready queries: monthly registrations, ID issuances, consent trends, approval latency, top entities, alerts and violations summaries, cohort analyses, and a KPI snapshot.
- For heavy aggregations consider creating materialized views or scheduled ETL jobs.

**Security & Privacy Notes**
- Biometric hashes and encryption key fields are included for demonstration; in production use irreversible hashing, secure key management, and strict access controls.
- `access_logs` is modeled as an immutable audit trail. Do not truncate audit tables in production; use retention policies and archiving instead.

**Testing**
- Use `07_Complete_Testing_Script.sql` to execute end-to-end scenarios that validate procedures, triggers, and logging behavior.

**Next Steps & Suggestions**
- Add visualization layer (Power BI, Tableau, or Grafana) using `queries/analytics_queries.sql` as data source.
- Add unit tests for PL/SQL packages using `utPLSQL`.
- Implement data masking/redaction for sensitive result sets.

**Contact / Author**
- Project owner: `KALISAINEZAJovith`
- For questions or improvements, open an issue or create a pull request.
