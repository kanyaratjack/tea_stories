# go-api (PostgreSQL)

Go backend for Tea Store POS/Admin.

## 1) Prepare PostgreSQL

```sql
CREATE DATABASE tea_store;
```

Run migration:

```bash
psql "postgres://postgres:postgres@localhost:5432/tea_store?sslmode=disable" -f /Users/jack/teaStore/backend/go-api/migrations/001_init.sql
```

## 2) Run backend

```bash
cd /Users/jack/teaStore/backend/go-api
export DATABASE_URL="postgres://postgres:postgres@localhost:5432/tea_store?sslmode=disable"
go run ./cmd/server
```

Server: `http://localhost:8080`

## Core endpoints

- Health: `GET /healthz`
- Products: `GET/POST /api/v1/products`, `GET/PUT/DELETE /api/v1/products/{id}`, `PATCH /api/v1/products/{id}/status`
- Categories: `GET/POST /api/v1/categories`, `PUT/DELETE /api/v1/categories/{id}`
- Spec groups: `GET/POST /api/v1/spec-groups`, `PUT/DELETE /api/v1/spec-groups/{id}`
- Spec items: `GET/POST /api/v1/spec-items`, `PUT/DELETE /api/v1/spec-items/{id}`
- Promotions: `GET/POST /api/v1/promotions`, `PUT/DELETE /api/v1/promotions/{id}`, `PATCH /api/v1/promotions/{id}/status`
- Orders: `GET/POST /api/v1/orders`, `GET/DELETE /api/v1/orders/{orderNo}`
- Refunds: `GET/POST /api/v1/orders/{orderNo}/refunds`
- Reprint ops: `POST /api/v1/orders/{orderNo}/reprint-receipt`, `POST /api/v1/orders/{orderNo}/reprint-label`
- Stats:
  - `GET /api/v1/stats/daily?date=YYYY-MM-DD`
  - `GET /api/v1/stats/overview?from=<RFC3339>&to=<RFC3339>`
  - `GET /api/v1/stats/hourly-sales?date=YYYY-MM-DD`
  - `GET /api/v1/stats/top-products?from=<RFC3339>&to=<RFC3339>&limit=10`
  - `GET /api/v1/stats/payment-breakdown?from=<RFC3339>&to=<RFC3339>`
  - `GET /api/v1/stats/order-type-breakdown?from=<RFC3339>&to=<RFC3339>`
- Settings: `GET /api/v1/settings`, `GET/PUT /api/v1/settings/{key}`
- Sync/Audit: `GET /api/v1/sync/status`, `GET /api/v1/sync/errors?limit=100`, `POST /api/v1/sync/retry`, `GET /api/v1/audit-logs?limit=100`

## Notes

- Order/refund create supports idempotency via `idempotency_key`.
- Refund over remaining amount returns `409 refund_amount_exceeds_remaining`.
- Use `X-Actor` header for audit actor.
