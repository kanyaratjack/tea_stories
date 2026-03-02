# go-api (PostgreSQL)

Go backend scaffold for Tea Store POS using PostgreSQL.

## 1) Prepare PostgreSQL

Create database:

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

## Endpoints

- `GET /`
- `GET /healthz`
- `GET /api/v1/products`
- `GET /api/v1/orders`
- `GET /api/v1/orders/{orderNo}`
- `POST /api/v1/orders`
- `POST /api/v1/orders/{orderNo}/refunds`
- `GET /api/v1/stats/daily?date=YYYY-MM-DD`

## Request examples

Create order:

```bash
curl -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"order_type":"delivery","channel":"Grab","total":89}'
```

Get order detail:

```bash
curl http://localhost:8080/api/v1/orders/G20260215-120000123
```

Create refund:

```bash
curl -X POST http://localhost:8080/api/v1/orders/G20260215-120000123/refunds \
  -H "Content-Type: application/json" \
  -d '{"amount":10,"reason":"customer request"}'
```

## One-command smoke test

After server is running:

```bash
/Users/jack/teaStore/backend/go-api/scripts/smoke.sh
```

Or specify date for stats:

```bash
/Users/jack/teaStore/backend/go-api/scripts/smoke.sh 2026-02-15
```

## Notes

- This is a minimal backend skeleton.
- Next step: add auth, create order, refund APIs, and role permissions.
