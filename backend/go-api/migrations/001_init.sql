CREATE TABLE IF NOT EXISTS products (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  name_th TEXT,
  name_zh TEXT,
  name_en TEXT,
  category TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  order_no TEXT NOT NULL UNIQUE,
  idempotency_key TEXT,
  order_type TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT '',
  total NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'paid',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'paid';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uk_orders_idempotency_key
  ON orders(idempotency_key)
  WHERE idempotency_key IS NOT NULL AND BTRIM(idempotency_key) <> '';
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_order_type ON orders(order_type);
CREATE INDEX IF NOT EXISTS idx_orders_channel ON orders(channel);

CREATE TABLE IF NOT EXISTS refunds (
  id BIGSERIAL PRIMARY KEY,
  order_no TEXT NOT NULL REFERENCES orders(order_no) ON DELETE CASCADE,
  idempotency_key TEXT,
  amount NUMERIC(10,2) NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE refunds ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uk_refunds_idempotency_key
  ON refunds(idempotency_key)
  WHERE idempotency_key IS NOT NULL AND BTRIM(idempotency_key) <> '';

CREATE INDEX IF NOT EXISTS idx_refunds_order_no ON refunds(order_no);
CREATE INDEX IF NOT EXISTS idx_refunds_created_at ON refunds(created_at);

INSERT INTO products(name, name_th, category, price, active)
VALUES
  ('Classic Milk Tea', 'ชานมคลาสสิก', 'Milk Tea', 40, TRUE),
  ('Vanilla Ice Cream', 'ไอศกรีมวานิลลา', 'Ice Cream', 15, TRUE)
ON CONFLICT DO NOTHING;
