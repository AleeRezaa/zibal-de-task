# Data quality and governance

## Ownership

| Table | Layer | Owner | Steward | Sensitive columns | Who can read |
| --- | --- | --- | --- | --- | --- |
| `core.merchants` | source | Core Payments engineering | Risk team | `owner_national_id`, `owner_mobile` (PII, clear text) | Application, CDC user |
| `core.transactions` | source | Core Payments engineering | Finance | `card_bin` (internal) | Application, CDC user |
| `raw.cdc_events` | raw | Data Platform | Data Platform | All PII inside JSON row images | Data engineers only |
| `staging.stg_core__merchants` | staging | Data Platform | Data Platform | `owner_national_id_hash`, `owner_mobile_masked` | Data engineers |
| `staging.stg_core__transactions` | staging | Data Platform | Data Platform | `card_bin` | Data engineers |
| `warehouse.dim_merchant`, `dim_merchant_scd2` | warehouse | Analytics Engineering | Risk team | `owner_national_id_hash`, `owner_mobile_masked` | Analysts |
| `warehouse.fct_transactions` | warehouse | Analytics Engineering | Finance | `card_bin` | Analysts |
| `reporting.rpt_daily_channel_status` | reporting | Finance Analytics | Finance | None | Metabase (`metabase` user) |
| `reporting.rpt_daily_merchant_sales` | reporting | Finance Analytics | Finance | None | Metabase (`metabase` user) |

The same ownership is stored as dbt `meta` (`owner`, `data_steward`, `contains_pii`, column-level `pii` and `treatment`), so it appears in `dbt docs` and can be read by tools.

## Sensitive data rules

1. **Hash or mask at the first transformation.** `owner_national_id` becomes a salted SHA-256 hash, which stays usable as a join key but cannot be reversed. `owner_mobile` is masked as `0912****567`, which keeps the operator prefix for analysis. No layer after `raw` holds these values in clear text.
2. **Raw is never exposed to BI.** The ClickHouse `metabase` user has `SELECT` on `reporting.*` only.
3. **Limited retention for clear text.** Kafka topics carry clear-text PII, so their retention is set to 7 days.
4. The hash salt comes from the `PII_HASH_SALT` environment variable. In production it belongs in a secret manager.

## Automated tests

Run with `docker compose exec dbt dbt test` (or `make test`).

| Test | Type | What it checks |
| --- | --- | --- |
| `unique`, `not_null` on `fct_transactions.transaction_id` | generic | Primary key of the fact |
| `unique`, `not_null` on `dim_merchant.merchant_id` | generic | Primary key of the dimension |
| `relationships` `fct_transactions.merchant_id` → `dim_merchant` | generic | Foreign key integrity |
| `accepted_values` on `channel`, `status`, `risk_level`, `risk_level_at_txn` | generic | Allowed values |
| `not_null` on reporting keys | generic | Reporting grain columns are filled |
| `assert_daily_success_matches_core` | singular | Daily successful **count and amount** in `reporting` equal `core` for every closed day (today is skipped because of normal CDC lag). Core is read through ClickHouse's `postgresql()` function from a small summary view (`recon.daily_success`) |
| `assert_no_pii_in_reporting` | singular | No column in `reporting` looks like a national ID, mobile or phone number |
| `assert_pii_is_masked` | singular | Every national ID hash is 64 characters and every mobile number matches the mask pattern |
| `assert_merchant_sales_grain_unique` | singular | `rpt_daily_merchant_sales` has exactly one row per declared grain |
| `assert_cdc_is_fresh` | singular | A change arrived in the last 5 minutes (CDC is alive) |

`dbt test --store-failures` keeps failing rows in ClickHouse for inspection.