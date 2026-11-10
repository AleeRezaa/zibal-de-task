SELECT (created_at AT TIME ZONE 'Asia/Tehran')::date AS day,
       channel,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'SUCCESS')
             / NULLIF(COUNT(*) FILTER (WHERE status <> 'PENDING'), 0), 2) AS success_rate_pct
FROM core.transactions
WHERE created_at >= ((now() AT TIME ZONE 'Asia/Tehran')::date - 29) AT TIME ZONE 'Asia/Tehran'
GROUP BY 1, 2
ORDER BY 1, 2