{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='txn_date',
    engine='MergeTree()',
    order_by='(txn_date, channel, status)',
    partition_by='toYYYYMM(txn_date)'
) }}

{% set tz = var('report_tz') %}

{% if is_incremental() %}
with changed_days as (
    select distinct toDate(created_at, '{{ tz }}') as txn_date
    from {{ ref('int_transactions') }}
    where _loaded_at > (select max(_source_loaded_at) from {{ this }})
)
{% endif %}
select
    toDate(created_at, '{{ tz }}') as txn_date,
    channel,
    status,
    count()                        as txn_count,
    sum(amount)                    as total_amount,
    sum(fee_amount)                as total_fee_amount,
    max(_loaded_at)                as _source_loaded_at
from {{ ref('fct_transactions') }}
{% if is_incremental() %}
where toDate(created_at, '{{ tz }}') in (select txn_date from changed_days)
{% endif %}
group by txn_date, channel, status