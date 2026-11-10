{{ config(
    materialized='incremental',
    incremental_strategy='append',
    engine='ReplacingMergeTree(_version)',
    order_by='(merchant_id, valid_from)'
) }}

select
    merchant_id, merchant_name, mcc, province, risk_level,
    owner_national_id_hash, owner_mobile_masked,
    -- snapshot = state before CDC existed, assumed valid since the beginning
    if(op = 'r',
       toDateTime64('1970-01-01 00:00:00', 6, 'UTC'),
       toDateTime64(source_ts, 6, 'UTC'))      as valid_from,
    is_deleted  as _is_deleted,
    source_lsn  as _version,
    ingested_at as _ingested_at,
    now64(3)    as _loaded_at
from {{ ref('stg_core__merchants') }}
{% if is_incremental() %}
where ingested_at > (select max(_ingested_at) - interval 1 minute from {{ this }})
{% endif %}