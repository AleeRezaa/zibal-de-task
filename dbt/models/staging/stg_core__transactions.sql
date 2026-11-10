with events as (
    select *, if(op = 'd', before, after) as row_json
    from {{ source('raw', 'cdc_events') }}
    where source_table = 'transactions'
)
select
    JSONExtractUInt(row_json, 'transaction_id')                                as transaction_id,
    JSONExtractUInt(row_json, 'merchant_id')                                   as merchant_id,
    JSONExtractString(row_json, 'channel')                                     as channel,
    JSONExtractString(row_json, 'card_bin')                                    as card_bin,
    JSONExtractInt(row_json, 'amount')                                         as amount,
    JSONExtractInt(row_json, 'fee_amount')                                     as fee_amount,
    JSONExtractString(row_json, 'status')                                      as status,
    JSONExtract(row_json, 'installments', 'Nullable(Int16)')                   as installments,
    parseDateTime64BestEffort(JSONExtractString(row_json, 'created_at'), 6, 'UTC') as created_at,
    parseDateTime64BestEffort(JSONExtractString(row_json, 'updated_at'), 6, 'UTC') as updated_at,
    op,
    CAST(op = 'd' AS UInt8)                                                          as is_deleted,
    source_lsn,
    source_ts,
    ingested_at
from events