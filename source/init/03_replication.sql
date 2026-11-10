-- Full before-images: deletes and updates carry the whole old row (needed for
-- correct delete handling downstream and for change history). Costs extra WAL; fine at this scale.
ALTER TABLE core.merchants    REPLICA IDENTITY FULL;
ALTER TABLE core.transactions REPLICA IDENTITY FULL;

-- CDC user: replication + read only
CREATE ROLE debezium WITH LOGIN REPLICATION PASSWORD 'debezium';
GRANT USAGE ON SCHEMA core TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO debezium;

-- Read-only user for the "before" Metabase connection and the reconciliation test
CREATE ROLE analytics_ro WITH LOGIN PASSWORD 'analytics_ro';
GRANT USAGE ON SCHEMA core TO analytics_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO analytics_ro;

-- Created by us (not by Debezium) so the CDC user does not need table ownership
CREATE PUBLICATION dbz_publication FOR TABLE core.merchants, core.transactions;