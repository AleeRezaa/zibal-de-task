SELECT merchant_id, argMax(merchant_name, txn_date) AS merchant_name,
       sum(success_amount) AS success_amount, sum(success_count) AS success_count
FROM reporting.rpt_daily_merchant_sales
WHERE txn_date >= toStartOfMonth(toDate(now(), 'Asia/Tehran'))
GROUP BY merchant_id
ORDER BY success_amount DESC
LIMIT 10