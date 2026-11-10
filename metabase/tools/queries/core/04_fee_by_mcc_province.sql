SELECT m.mcc, m.province, SUM(t.fee_amount) AS fee_amount
FROM core.transactions t
JOIN core.merchants m USING (merchant_id)
WHERE t.status = 'SUCCESS'
  AND created_at >= ((now() AT TIME ZONE 'Asia/Tehran')::date - 89)::timestamp AT TIME ZONE 'Asia/Tehran'
GROUP BY 1, 2
ORDER BY 1, 2