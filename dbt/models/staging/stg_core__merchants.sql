with events as (
    select *, if(op = 'd', before, after) as row_json
    from {{ source('raw', 'cdc_events') }}
    where source_table = 'merchants'
)
select
    JSONExtractUInt(row_json, 'merchant_id')                                   as merchant_id,
    JSONExtractString(row_json, 'name')                                        as merchant_name,
    JSONExtractString(row_json, 'mcc')                                         as mcc,
    JSONExtractString(row_json, 'province')                                    as province,
    JSONExtractString(row_json, 'risk_level')                                  as risk_level,
    {{ hash_pii("JSONExtractString(row_json, 'owner_national_id')") }}         as owner_national_id_hash,
    {{ mask_mobile("JSONExtractString(row_json, 'owner_mobile')") }}           as owner_mobile_masked,
    parseDateTime64BestEffort(JSONExtractString(row_json, 'updated_at'), 6, 'UTC') as updated_at,
    op,
    toUInt8(op = 'd')                                                          as is_deleted,
    source_lsn,
    source_ts,
    ingested_at
from events