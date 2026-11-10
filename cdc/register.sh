#!/bin/sh
set -e
CONNECT_URL="${CONNECT_URL:-http://connect:8083}"

echo "waiting for Kafka Connect at $CONNECT_URL ..."
until curl -sf "$CONNECT_URL/connectors" > /dev/null; do sleep 3; done

curl -sf -X PUT -H "Content-Type: application/json" \
     --data @/cdc/debezium-postgres.json \
     "$CONNECT_URL/connectors/paymentyar-core/config"
echo
echo "connector paymentyar-core registered"