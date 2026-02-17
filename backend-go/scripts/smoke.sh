#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
DATE_ARG="${1:-$(date +%F)}"

echo "[1/6] Health check"
curl -fsS "${BASE_URL}/healthz" | tee /tmp/tea_backend_healthz.json
echo

echo "[2/6] List products"
curl -fsS "${BASE_URL}/api/products" | tee /tmp/tea_backend_products.json
echo

echo "[3/6] Create order"
CREATE_RESP="$(curl -fsS -X POST "${BASE_URL}/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"order_type":"delivery","channel":"Grab","total":89}')"
echo "${CREATE_RESP}" | tee /tmp/tea_backend_create_order.json
echo

ORDER_NO="$(echo "${CREATE_RESP}" | sed -n 's/.*"order_no":"\([^"]*\)".*/\1/p')"
if [[ -z "${ORDER_NO}" ]]; then
  echo "ERROR: cannot extract order_no from create order response" >&2
  exit 1
fi
echo "order_no=${ORDER_NO}"

echo "[4/6] Create refund"
curl -fsS -X POST "${BASE_URL}/api/orders/${ORDER_NO}/refunds" \
  -H "Content-Type: application/json" \
  -d '{"amount":10,"reason":"smoke test"}' \
  | tee /tmp/tea_backend_refund.json
echo

echo "[5/6] List orders"
curl -fsS "${BASE_URL}/api/orders" | tee /tmp/tea_backend_orders.json
echo

echo "[6/6] Daily stats (${DATE_ARG})"
curl -fsS "${BASE_URL}/api/stats/daily?date=${DATE_ARG}" | tee /tmp/tea_backend_stats.json
echo

echo "Smoke test passed."
