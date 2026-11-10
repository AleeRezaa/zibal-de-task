# Data layers

Each layer is a separate ClickHouse database. Data flows in one direction only: `raw` → `staging` → `warehouse` → `reporting`.

| Layer | Purpose | Allowed | Not allowed | Built by | Readers |
| --- | --- | --- | --- | --- | --- |
| `raw` | Exact, replayable record of every change | Append CDC events as delivered; unpack the Debezium envelope (op, LSN, timestamps); keep row images as JSON strings | Updates, deletes, business logic, BI access | ClickHouse Kafka engine + materialized view | Data engineers |
| `staging` | Clean, typed change events | Parse JSON, cast types, rename columns, hash/mask PII; one row per change event | Joins, aggregation, filtering out events | dbt (views) | Data engineers |
| `warehouse` | Business entities and history | Deduplicate to current state, SCD2 merchant history, facts and dimensions, joins | Clear-text PII, report-specific filters or metrics | dbt (incremental tables + views) | Analysts |
| `reporting` | Fast, dashboard-ready tables | Pre-aggregated tables shaped for cards; business definitions (success, Tehran day) | Any PII, row-level transaction data | dbt (incremental tables) | Metabase only (`metabase` user) |

## Rules per layer

**raw**
- Append-only. No row is ever updated or deleted, which is what makes it the change history.
- Schema-agnostic: row images are JSON strings, so source schema changes never break ingestion.
- Contains PII in clear text, so access is limited to data engineers.

**staging**
- One row per change event, same count as raw.
- The first place where PII is transformed: `owner_national_id` → salted SHA-256, `owner_mobile` → masked (`0912****567`). No clear-text PII leaves this layer.
- New source columns are added here explicitly (for example, `installments` as `Nullable`).

**warehouse**
- Current state is derived, never updated in place: new versions are appended and `ReplacingMergeTree` keeps the latest (`_version` = WAL position). Hard deletes are applied with `_is_deleted`.
- Merchant history is kept as SCD Type 2 (`valid_from` / `valid_to`).
- Incremental: each run reads only events ingested since the last run, with a 1-minute overlap for safety.

**reporting**
- Only aggregated data, with the grain chosen for the dashboard cards.
- Incremental by day: each run recomputes only the days touched by new events (`delete+insert` on `txn_date`).
- The only layer the BI tool can read.

## Naming conventions

| Prefix | Meaning |
| --- | --- |
| `stg_<source>__<table>` | Staging model of one source table |
| `int_` | Intermediate model (versioned storage, not for direct use) |
| `fct_` | Fact table (events, measures) |
| `dim_` | Dimension table (descriptive attributes) |
| `rpt_` | Reporting table for dashboards |
| `_column` | Technical column (`_version`, `_is_deleted`, `_loaded_at`) |