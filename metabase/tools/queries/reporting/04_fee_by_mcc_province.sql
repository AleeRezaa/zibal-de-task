SELECT mcc, province_at_txn AS province, sum(success_fee_amount) AS fee_amount
FROM reporting.rpt_daily_merchant_sales
WHERE txn_date >= toDate(now(), 'Asia/Tehran') - 89
GROUP BY mcc, province
ORDER BY mcc, province