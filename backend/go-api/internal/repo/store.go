package repo

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"tea-store/backend-go/internal/model"
)

type Store interface {
	Ping(ctx context.Context) error
	ListProducts(ctx context.Context) ([]model.Product, error)
	ListOrders(ctx context.Context) ([]model.Order, error)
	GetOrderByNo(ctx context.Context, orderNo string) (model.Order, error)
	CreateOrder(ctx context.Context, input model.CreateOrderInput) (model.Order, error)
	CreateRefund(ctx context.Context, orderNo string, input model.CreateRefundInput) (model.Refund, error)
	DailyStats(ctx context.Context, date time.Time) (model.DailyStats, error)
	Close()
}

var ErrNotFound = errors.New("not_found")

type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(ctx context.Context, databaseURL string) (*PostgresStore, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, err
	}
	return &PostgresStore{pool: pool}, nil
}

func (s *PostgresStore) Ping(ctx context.Context) error {
	return s.pool.Ping(ctx)
}

func (s *PostgresStore) Close() {
	s.pool.Close()
}

func (s *PostgresStore) ListProducts(ctx context.Context) ([]model.Product, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, name, COALESCE(name_th, ''), COALESCE(name_zh, ''), COALESCE(name_en, ''), category, price, active
		FROM products
		ORDER BY id ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.Product, 0, 32)
	for rows.Next() {
		var p model.Product
		if err := rows.Scan(
			&p.ID,
			&p.Name,
			&p.NameTH,
			&p.NameZH,
			&p.NameEN,
			&p.Category,
			&p.Price,
			&p.Active,
		); err != nil {
			return nil, err
		}
		items = append(items, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

func (s *PostgresStore) ListOrders(ctx context.Context) ([]model.Order, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT order_no, order_type, COALESCE(channel, ''), total, COALESCE(status, 'paid'), created_at
		FROM orders
		ORDER BY created_at DESC
		LIMIT 200
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.Order, 0, 64)
	for rows.Next() {
		var o model.Order
		if err := rows.Scan(
			&o.OrderNo,
			&o.OrderType,
			&o.Channel,
			&o.Total,
			&o.Status,
			&o.CreatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, o)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

func (s *PostgresStore) GetOrderByNo(ctx context.Context, orderNo string) (model.Order, error) {
	row := s.pool.QueryRow(
		ctx,
		`
		SELECT order_no, order_type, COALESCE(channel, ''), total, COALESCE(status, 'paid'), created_at
		FROM orders
		WHERE order_no = $1
		LIMIT 1
		`,
		strings.TrimSpace(orderNo),
	)
	var o model.Order
	if err := row.Scan(
		&o.OrderNo,
		&o.OrderType,
		&o.Channel,
		&o.Total,
		&o.Status,
		&o.CreatedAt,
	); err != nil {
		if strings.Contains(err.Error(), "no rows in result set") {
			return model.Order{}, ErrNotFound
		}
		return model.Order{}, err
	}
	return o, nil
}

func (s *PostgresStore) CreateOrder(
	ctx context.Context,
	input model.CreateOrderInput,
) (model.Order, error) {
	orderNo := strings.TrimSpace(input.OrderNo)
	if orderNo == "" {
		orderNo = buildOrderNo(time.Now(), input.OrderType, input.Channel)
	}
	idempotencyKey := strings.TrimSpace(input.IdempotencyKey)
	row := s.pool.QueryRow(
		ctx,
		`
		INSERT INTO orders(order_no, order_type, channel, total, status, created_at, idempotency_key)
		VALUES($1, $2, $3, $4, 'paid', COALESCE($5, NOW()), NULLIF($6, ''))
		RETURNING order_no, order_type, COALESCE(channel, ''), total, status, created_at
		`,
		orderNo,
		normalizeOrderType(input.OrderType),
		strings.TrimSpace(input.Channel),
		input.Total,
		input.ClientTime,
		idempotencyKey,
	)
	var order model.Order
	if err := row.Scan(
		&order.OrderNo,
		&order.OrderType,
		&order.Channel,
		&order.Total,
		&order.Status,
		&order.CreatedAt,
	); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			if idempotencyKey != "" {
				existing, findErr := s.getOrderByIdempotencyKey(ctx, idempotencyKey)
				if findErr == nil {
					return existing, nil
				}
			}
			existing, findErr := s.GetOrderByNo(ctx, orderNo)
			if findErr == nil {
				return existing, nil
			}
		}
		return model.Order{}, err
	}
	return order, nil
}

func (s *PostgresStore) CreateRefund(
	ctx context.Context,
	orderNo string,
	input model.CreateRefundInput,
) (model.Refund, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.Refund{}, err
	}
	defer tx.Rollback(ctx)
	idempotencyKey := strings.TrimSpace(input.IdempotencyKey)

	if idempotencyKey != "" {
		var existing model.Refund
		err := tx.QueryRow(
			ctx,
			`
			SELECT id, order_no, amount, reason, created_at
			FROM refunds
			WHERE idempotency_key = $1
			LIMIT 1
			`,
			idempotencyKey,
		).Scan(
			&existing.ID,
			&existing.OrderNo,
			&existing.Amount,
			&existing.Reason,
			&existing.CreatedAt,
		)
		if err == nil {
			return existing, nil
		}
		if !strings.Contains(err.Error(), "no rows in result set") {
			return model.Refund{}, err
		}
	}

	var exists bool
	if err := tx.QueryRow(
		ctx,
		`SELECT EXISTS(SELECT 1 FROM orders WHERE order_no = $1)`,
		orderNo,
	).Scan(&exists); err != nil {
		return model.Refund{}, err
	}
	if !exists {
		return model.Refund{}, fmt.Errorf("%w: order_no=%s", ErrNotFound, orderNo)
	}

	var refund model.Refund
	if err := tx.QueryRow(
		ctx,
		`
		INSERT INTO refunds(order_no, amount, reason, created_at, idempotency_key)
		VALUES($1, $2, $3, COALESCE($4, NOW()), NULLIF($5, ''))
		RETURNING id, order_no, amount, reason, created_at
		`,
		orderNo,
		input.Amount,
		strings.TrimSpace(input.Reason),
		input.ClientTime,
		idempotencyKey,
	).Scan(
		&refund.ID,
		&refund.OrderNo,
		&refund.Amount,
		&refund.Reason,
		&refund.CreatedAt,
	); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" && idempotencyKey != "" {
			err = tx.QueryRow(
				ctx,
				`
				SELECT id, order_no, amount, reason, created_at
				FROM refunds
				WHERE idempotency_key = $1
				LIMIT 1
				`,
				idempotencyKey,
			).Scan(
				&refund.ID,
				&refund.OrderNo,
				&refund.Amount,
				&refund.Reason,
				&refund.CreatedAt,
			)
			if err == nil {
				return refund, nil
			}
		}
		return model.Refund{}, err
	}

	_, err = tx.Exec(
		ctx,
		`
		UPDATE orders
		SET status = CASE
			WHEN COALESCE((SELECT SUM(amount) FROM refunds WHERE order_no = $1), 0) >= total THEN 'refunded'
			ELSE 'partially_refunded'
		END
		WHERE order_no = $1
		`,
		orderNo,
	)
	if err != nil {
		return model.Refund{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return model.Refund{}, err
	}
	return refund, nil
}

func (s *PostgresStore) getOrderByIdempotencyKey(
	ctx context.Context,
	idempotencyKey string,
) (model.Order, error) {
	row := s.pool.QueryRow(
		ctx,
		`
		SELECT order_no, order_type, COALESCE(channel, ''), total, COALESCE(status, 'paid'), created_at
		FROM orders
		WHERE idempotency_key = $1
		LIMIT 1
		`,
		strings.TrimSpace(idempotencyKey),
	)
	var o model.Order
	if err := row.Scan(
		&o.OrderNo,
		&o.OrderType,
		&o.Channel,
		&o.Total,
		&o.Status,
		&o.CreatedAt,
	); err != nil {
		return model.Order{}, err
	}
	return o, nil
}

func (s *PostgresStore) DailyStats(
	ctx context.Context,
	date time.Time,
) (model.DailyStats, error) {
	start := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, time.Local)
	end := start.Add(24 * time.Hour)
	row := s.pool.QueryRow(
		ctx,
		`
		WITH order_day AS (
		  SELECT COUNT(*)::bigint AS order_count, COALESCE(SUM(total), 0)::numeric AS gross
		  FROM orders
		  WHERE created_at >= $1 AND created_at < $2
		),
		refund_day AS (
		  SELECT COALESCE(SUM(amount), 0)::numeric AS refunds
		  FROM refunds
		  WHERE created_at >= $1 AND created_at < $2
		)
		SELECT
		  order_day.order_count,
		  order_day.gross::float8,
		  refund_day.refunds::float8
		FROM order_day, refund_day
		`,
		start,
		end,
	)
	var orderCount int64
	var gross float64
	var refunds float64
	if err := row.Scan(&orderCount, &gross, &refunds); err != nil {
		return model.DailyStats{}, err
	}
	return model.DailyStats{
		Date:        start.Format("2006-01-02"),
		OrderCount:  orderCount,
		GrossAmount: gross,
		Refunds:     refunds,
		NetAmount:   gross - refunds,
	}, nil
}

func normalizeOrderType(raw string) string {
	v := strings.TrimSpace(strings.ToLower(raw))
	if v == "delivery" {
		return "delivery"
	}
	return "in_store"
}

func buildOrderNo(now time.Time, orderType string, channel string) string {
	prefix := "I"
	if normalizeOrderType(orderType) == "delivery" {
		c := strings.ToLower(strings.TrimSpace(channel))
		switch {
		case strings.Contains(c, "grab"):
			prefix = "G"
		case strings.Contains(c, "shopee"):
			prefix = "S"
		case strings.Contains(c, "foodpanda"), strings.Contains(c, "panda"):
			prefix = "F"
		case strings.Contains(c, "line"):
			prefix = "L"
		default:
			prefix = "D"
		}
	}
	return fmt.Sprintf(
		"%s%s",
		prefix,
		now.Format("20060102-150405000"),
	)
}
