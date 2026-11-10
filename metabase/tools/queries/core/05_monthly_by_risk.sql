SELECT date_trunc('month', t.created_at AT TIME ZONE 'Asia/Tehran')::date AS month,
       m.risk_level,
       COUNT(*)      AS success_count,
       SUM(t.amount) AS success_amount
FROM core.transactions t
JOIN core.merchants m USING (merchant_id)
WHERE t.status = 'SUCCESS'
GROUP BY 1, 2
ORDER BY 1, 2