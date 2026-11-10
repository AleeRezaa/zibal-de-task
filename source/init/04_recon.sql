-- Owned by the data team; read-only summary used by the reconciliation test
CREATE SCHEMA IF NOT EXISTS recon;

CREATE VIEW recon.daily_success AS
SELECT (created_at AT TIME ZONE 'Asia/Tehran')::date AS txn_date,
       count(*)::bigint                               AS success_count,
       sum(amount)::bigint                            AS success_amount
FROM core.transactions
WHERE status = 'SUCCESS'
GROUP BY 1;

GRANT USAGE ON SCHEMA recon TO analytics_ro;
GRANT SELECT ON recon.daily_success TO analytics_ro;