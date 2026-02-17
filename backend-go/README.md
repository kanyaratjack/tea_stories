# backend-go (PostgreSQL)

Go backend scaffold for Tea Store POS using PostgreSQL.

## 1) Prepare PostgreSQL

Create database:

```sql
CREATE DATABASE tea_store;
```

Run migration:

```bash
psql "postgres://postgres:postgres@localhost:5432/tea_store?sslmode=disable" -f /Users/jack/teaStore/backend-go/migrations/001_init.sql
```

## 2) Run backend

```bash
cd /Users/jack/teaStore/backend-go
export DATABASE_URL="postgres://postgres:postgres@localhost:5432/tea_store?sslmode=disable"
go run ./cmd/server
```

Server: `http://localhost:8080`

## Endpoints

- `GET /`
- `GET /healthz`
- `GET /api/products`
- `GET /api/orders`
- `POST /api/orders`
- `POST /api/orders/{orderNo}/refunds`
- `GET /api/stats/daily?date=YYYY-MM-DD`

## Request examples

Create order:

```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"order_type":"delivery","channel":"Grab","total":89}'
```

Create refund:

```bash
curl -X POST http://localhost:8080/api/orders/G20260215-120000123/refunds \
  -H "Content-Type: application/json" \
  -d '{"amount":10,"reason":"customer request"}'
```

## One-command smoke test

After server is running:

```bash
/Users/jack/teaStore/backend-go/scripts/smoke.sh
```

Or specify date for stats:

```bash
/Users/jack/teaStore/backend-go/scripts/smoke.sh 2026-02-15
```

## Notes

- This is a minimal backend skeleton.
- Next step: add auth, create order, refund APIs, and role permissions.
