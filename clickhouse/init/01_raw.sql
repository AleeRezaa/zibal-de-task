CREATE DATABASE IF NOT EXISTS raw;
CREATE DATABASE IF NOT EXISTS staging;
CREATE DATABASE IF NOT EXISTS warehouse;
CREATE DATABASE IF NOT EXISTS reporting;

-- 1) Kafka consumer: reads both topics, stores nothing
CREATE TABLE raw.cdc_events_queue
(
    message String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list   = 'kafka:9092',
    kafka_topic_list    = 'paymentyar.core.merchants,paymentyar.core.transactions',
    kafka_group_name    = 'clickhouse_raw_loader',
    kafka_format        = 'JSONAsString',
    kafka_num_consumers = 1;

-- 2) Storage: append-only log of every change event (= full change history)
CREATE TABLE raw.cdc_events
(
    source_table    LowCardinality(String),   -- merchants | transactions
    op              LowCardinality(String),   -- r=snapshot c=insert u=update d=delete
    before          String,                   -- JSON row image before the change ('null' for r/c)
    after           String,                   -- JSON row image after the change ('null' for d)
    source_lsn      UInt64,                   -- WAL position: the ordering/version key
    source_tx_id    UInt64,
    source_ts       DateTime64(3, 'UTC'),     -- commit time in Postgres
    cdc_ts          DateTime64(3, 'UTC'),     -- time Debezium processed the event
    kafka_topic     LowCardinality(String),
    kafka_partition UInt32,
    kafka_offset    UInt64,
    ingested_at     DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ingested_at)
ORDER BY (source_table, ingested_at, kafka_offset);

-- 3) Glue: unpack the Debezium envelope, keep row images as raw JSON
CREATE MATERIALIZED VIEW raw.cdc_events_mv TO raw.cdc_events AS
SELECT
    JSONExtractString(message, 'source', 'table')                               AS source_table,
    JSONExtractString(message, 'op')                                            AS op,
    JSONExtractRaw(message, 'before')                                           AS before,
    JSONExtractRaw(message, 'after')                                            AS after,
    JSONExtractUInt(message, 'source', 'lsn')                                   AS source_lsn,
    JSONExtractUInt(message, 'source', 'txId')                                  AS source_tx_id,
    fromUnixTimestamp64Milli(JSONExtractInt(message, 'source', 'ts_ms'), 'UTC') AS source_ts,
    fromUnixTimestamp64Milli(JSONExtractInt(message, 'ts_ms'), 'UTC')           AS cdc_ts,
    _topic                                                                      AS kafka_topic,
    _partition                                                                  AS kafka_partition,
    _offset                                                                     AS kafka_offset,
    now64(3)                                                                    AS ingested_at
FROM raw.cdc_events_queue;

-- 4) Least-privilege BI user: can only read the reporting layer (no raw PII)
CREATE USER IF NOT EXISTS metabase IDENTIFIED WITH sha256_password BY 'metabase';
GRANT SELECT ON reporting.* TO metabase;