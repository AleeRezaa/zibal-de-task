{{ config(
    materialized='incremental',
    incremental_strategy='append',
    engine='ReplacingMergeTree(_version, _is_deleted)',
    order_by='(toDate(created_at), transaction_id)',
    partition_by='toYYYYMM(created_at)'
) }}

select
    transaction_id, merchant_id, channel, card_bin, amount, fee_amount, status, installments,
    created_at, updated_at,
    source_lsn  as _version,
    is_deleted  as _is_deleted,
    ingested_at as _ingested_at,
    now64(3)    as _loaded_at
from {{ ref('stg_core__transactions') }}
{% if is_incremental() %}
where ingested_at > (select max(_ingested_at) - interval 1 minute from {{ this }})
{% endif %}