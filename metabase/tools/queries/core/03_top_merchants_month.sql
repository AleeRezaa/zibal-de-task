SELECT m.merchant_id, m.name AS merchant_name,
       SUM(t.amount) AS success_amount, COUNT(*) AS success_count
FROM core.transactions t
JOIN core.merchants m USING (merchant_id)
WHERE t.status = 'SUCCESS'
  AND t.created_at >= date_trunc('month', now() AT TIME ZONE 'Asia/Tehran') AT TIME ZONE 'Asia/Tehran'
GROUP BY 1, 2
ORDER BY success_amount DESC
LIMIT 10