#!/bin/sh
set -e
CONNECT_URL="${CONNECT_URL:-http://connect:8083}"

echo "waiting for Kafka Connect at $CONNECT_URL ..."
until curl -sf "$CONNECT_URL/connectors" > /dev/null; do sleep 3; done

# no -f here: we want to see Connect's error message if registration fails
code=$(curl -s -o /tmp/response.json -w "%{http_code}" -X PUT \
     -H "Content-Type: application/json" \
     --data @/cdc/debezium-postgres.json \
     "$CONNECT_URL/connectors/paymentyar-core/config")
cat /tmp/response.json; echo

if [ "$code" -ge 300 ]; then
  echo "registration failed with HTTP $code"
  exit 1
fi
echo "connector paymentyar-core registered (HTTP $code)"