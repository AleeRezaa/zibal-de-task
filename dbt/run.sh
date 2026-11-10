#!/bin/sh
INTERVAL="${DBT_RUN_INTERVAL_SECONDS:-60}"

echo "waiting for ClickHouse ..."
until dbt debug --connection > /dev/null 2>&1; do sleep 5; done

while true; do
  echo "=== dbt run $(date -u +%FT%TZ) ==="
  dbt run || echo "dbt run failed, retrying next cycle"
  sleep "$INTERVAL"
done