CREATE TABLE IF NOT EXISTS products (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  name_th TEXT,
  name_zh TEXT,
  name_en TEXT,
  category TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  discount_type TEXT,
  discount_value NUMERIC(10,2) NOT NULL DEFAULT 0,
  delivery_price_json JSONB,
  image_url TEXT,
  sort INT NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE products ADD COLUMN IF NOT EXISTS discount_type TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS discount_value NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS delivery_price_json JSONB;
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS sort INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  order_no TEXT NOT NULL UNIQUE,
  platform_order_no TEXT,
  idempotency_key TEXT,
  order_type TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT '',
  payment_method TEXT NOT NULL DEFAULT '',
  subtotal NUMERIC(10,2) NOT NULL DEFAULT 0,
  product_discount NUMERIC(10,2) NOT NULL DEFAULT 0,
  promo_discount NUMERIC(10,2) NOT NULL DEFAULT 0,
  manual_platform_discount NUMERIC(10,2) NOT NULL DEFAULT 0,
  total NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'paid',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_order_no TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'paid';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS subtotal NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS product_discount NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS promo_discount NUMERIC(10,2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS manual_platform_discount NUMERIC(10,2) NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS uk_orders_idempotency_key
  ON orders(idempotency_key)
  WHERE idempotency_key IS NOT NULL AND BTRIM(idempotency_key) <> '';
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_order_type ON orders(order_type);
CREATE INDEX IF NOT EXISTS idx_orders_channel ON orders(channel);
CREATE INDEX IF NOT EXISTS idx_orders_payment_method ON orders(payment_method);

CREATE TABLE IF NOT EXISTS order_items (
  id BIGSERIAL PRIMARY KEY,
  order_no TEXT NOT NULL REFERENCES orders(order_no) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  unit_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  line_total NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_order_items_order_no ON order_items(order_no);
CREATE INDEX IF NOT EXISTS idx_order_items_created_at ON order_items(created_at);

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

CREATE TABLE IF NOT EXISTS categories (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  name_th TEXT,
  name_zh TEXT,
  name_en TEXT,
  sort INT NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS spec_groups (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  name_th TEXT,
  name_zh TEXT,
  name_en TEXT,
  sort INT NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS spec_items (
  id BIGSERIAL PRIMARY KEY,
  group_id BIGINT NOT NULL REFERENCES spec_groups(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  name_th TEXT,
  name_zh TEXT,
  name_en TEXT,
  extra_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  sort INT NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_spec_items_group_id ON spec_items(group_id);

CREATE TABLE IF NOT EXISTS promotions (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  name_th TEXT,
  name_zh TEXT,
  name_en TEXT,
  promo_type TEXT NOT NULL,
  rule_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  priority INT NOT NULL DEFAULT 0,
  stacking_mode TEXT,
  exclude_order_type_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_promotions_active ON promotions(active);

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sync_queue_events (
  id BIGSERIAL PRIMARY KEY,
  task_key TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  error_message TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sync_queue_events_status_updated_at
  ON sync_queue_events(status, updated_at DESC);

CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGSERIAL PRIMARY KEY,
  actor TEXT NOT NULL DEFAULT 'system',
  action TEXT NOT NULL,
  target TEXT NOT NULL,
  detail TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);

INSERT INTO products(name, name_th, category, price, active)
VALUES
  ('Classic Milk Tea', 'ชานมคลาสสิก', 'Milk Tea', 40, TRUE),
  ('Vanilla Ice Cream', 'ไอศกรีมวานิลลา', 'Ice Cream', 15, TRUE)
ON CONFLICT DO NOTHING;
