{% set tz = var('report_tz') %}

with core as (
    select txn_date, toInt64(success_count) as core_count, toInt64(success_amount) as core_amount
    from postgresql('source-db:5432', 'paymentyar', 'daily_success',
                    'analytics_ro', 'analytics_ro', 'recon')
),
rpt as (
    select txn_date, toInt64(sum(txn_count)) as rpt_count, toInt64(sum(total_amount)) as rpt_amount
    from {{ ref('rpt_daily_channel_status') }}
    where status = 'SUCCESS'
    group by txn_date
),
combined as (
    select txn_date, core_count, core_amount, toInt64(0) as rpt_count, toInt64(0) as rpt_amount from core
    union all
    select txn_date, toInt64(0), toInt64(0), rpt_count, rpt_amount from rpt
)
select txn_date,
       sum(core_count) as core_count, sum(rpt_count) as rpt_count,
       sum(core_amount) as core_amount, sum(rpt_amount) as rpt_amount
from combined
where txn_date < toDate(now(), '{{ tz }}')
group by txn_date
having core_count != rpt_count or core_amount != rpt_amount