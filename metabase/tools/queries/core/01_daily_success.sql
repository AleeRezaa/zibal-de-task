SELECT (created_at AT TIME ZONE 'Asia/Tehran')::date AS day,
       COUNT(*)    AS success_count,
       SUM(amount) AS success_amount
FROM core.transactions
WHERE status = 'SUCCESS'
  AND created_at >= ((now() AT TIME ZONE 'Asia/Tehran')::date - 89) AT TIME ZONE 'Asia/Tehran'
GROUP BY 1
ORDER BY 1