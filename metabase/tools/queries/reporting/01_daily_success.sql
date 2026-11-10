SELECT txn_date AS day, sum(txn_count) AS success_count, sum(total_amount) AS success_amount
FROM reporting.rpt_daily_channel_status
WHERE status = 'SUCCESS'
  AND txn_date >= toDate(now(), 'Asia/Tehran') - 89
GROUP BY day
ORDER BY day