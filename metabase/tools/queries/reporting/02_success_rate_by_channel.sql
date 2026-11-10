SELECT txn_date AS day, channel,
       round(100 * sumIf(txn_count, status = 'SUCCESS')
             / nullIf(sumIf(txn_count, status != 'PENDING'), 0), 2) AS success_rate_pct
FROM reporting.rpt_daily_channel_status
WHERE txn_date >= toDate(now(), 'Asia/Tehran') - 29
GROUP BY day, channel
ORDER BY day, channel