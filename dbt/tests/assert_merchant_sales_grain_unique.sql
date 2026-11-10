select txn_date, merchant_id, province_at_txn, risk_level_at_txn, count() as n
from {{ ref('rpt_daily_merchant_sales') }}
group by txn_date, merchant_id, province_at_txn, risk_level_at_txn
having n > 1