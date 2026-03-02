#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
API_BASE="${API_BASE:-${BASE_URL}/api/v1}"
DATE_ARG="${1:-$(date +%F)}"

echo "[1/6] Health check"
curl -fsS "${BASE_URL}/healthz" | tee /tmp/tea_backend_healthz.json
echo

echo "[2/6] List products"
curl -fsS "${API_BASE}/products" | tee /tmp/tea_backend_products.json
echo

echo "[3/6] Create order"
CREATE_RESP="$(curl -fsS -X POST "${API_BASE}/orders" \
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
curl -fsS -X POST "${API_BASE}/orders/${ORDER_NO}/refunds" \
  -H "Content-Type: application/json" \
  -d '{"amount":10,"reason":"smoke test"}' \
  | tee /tmp/tea_backend_refund.json
echo

echo "[5/7] Get order detail"
curl -fsS "${API_BASE}/orders/${ORDER_NO}" | tee /tmp/tea_backend_order_detail.json
echo

echo "[6/7] List orders"
curl -fsS "${API_BASE}/orders" | tee /tmp/tea_backend_orders.json
echo

echo "[7/7] Daily stats (${DATE_ARG})"
curl -fsS "${API_BASE}/stats/daily?date=${DATE_ARG}" | tee /tmp/tea_backend_stats.json
echo

echo "Smoke test passed."
