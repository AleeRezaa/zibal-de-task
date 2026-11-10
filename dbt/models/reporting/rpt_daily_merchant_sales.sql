{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='txn_date',
    engine='MergeTree()',
    order_by='(txn_date, merchant_id)',
    partition_by='toYYYYMM(txn_date)'
) }}

{% set tz = var('report_tz') %}
-- depends_on: {{ ref('int_transactions') }}
-- depends_on: {{ ref('int_merchant_versions') }}

with
{% if is_incremental() %}
watermark as (
    select max(_source_loaded_at) as wm from {{ this }}
),
changed_days as (
    select distinct txn_date from (
        select toDate(created_at, '{{ tz }}') as txn_date
        from {{ ref('int_transactions') }}
        where _loaded_at > (select wm from watermark)
        union all
        select toDate(valid_from, '{{ tz }}')
        from {{ ref('int_merchant_versions') }}
        where _loaded_at > (select wm from watermark)
          and valid_from > toDateTime64('1970-01-02 00:00:00', 6, 'UTC')
    )
),
{% endif %}
successful as (
    select transaction_id, merchant_id, amount, fee_amount, created_at, _loaded_at
    from {{ ref('fct_transactions') }}
    where status = 'SUCCESS'
    {% if is_incremental() %}
      and toDate(created_at, '{{ tz }}') in (select txn_date from changed_days)
    {% endif %}
),
merchant_versions as (
    select merchant_id, merchant_name, mcc, province, risk_level, valid_from
    from {{ ref('int_merchant_versions') }} final
    where _is_deleted = 0
)
select
    toDate(t.created_at, '{{ tz }}') as txn_date,
    t.merchant_id                     as merchant_id,
    any(m.merchant_name)              as merchant_name,
    any(m.mcc)                        as mcc,
    m.province                        as province_at_txn,
    m.risk_level                      as risk_level_at_txn,
    count()                           as success_count,
    sum(t.amount)                     as success_amount,
    sum(t.fee_amount)                 as success_fee_amount,
    max(t._loaded_at)                 as _source_loaded_at
from successful as t
asof left join merchant_versions as m
    on t.merchant_id = m.merchant_id and t.created_at >= m.valid_from
group by txn_date, merchant_id, province_at_txn, risk_level_at_txn