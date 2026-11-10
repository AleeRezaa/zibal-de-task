SELECT toStartOfMonth(txn_date) AS month, risk_level_at_txn AS risk_level,
       sum(success_count) AS success_count, sum(success_amount) AS success_amount
FROM reporting.rpt_daily_merchant_sales
GROUP BY month, risk_level
ORDER BY month, risk_level