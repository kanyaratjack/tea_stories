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
	GetProductByID(ctx context.Context, id int64) (model.Product, error)
	CreateProduct(ctx context.Context, input model.ProductInput) (model.Product, error)
	UpdateProduct(ctx context.Context, id int64, input model.ProductInput) (model.Product, error)
	SetProductActive(ctx context.Context, id int64, active bool) (model.Product, error)
	DeleteProduct(ctx context.Context, id int64) error

	ListCategories(ctx context.Context) ([]model.Category, error)
	CreateCategory(ctx context.Context, input model.CategoryInput) (model.Category, error)
	UpdateCategory(ctx context.Context, id int64, input model.CategoryInput) (model.Category, error)
	DeleteCategory(ctx context.Context, id int64) error

	ListSpecGroups(ctx context.Context) ([]model.SpecGroup, error)
	CreateSpecGroup(ctx context.Context, input model.SpecGroupInput) (model.SpecGroup, error)
	UpdateSpecGroup(ctx context.Context, id int64, input model.SpecGroupInput) (model.SpecGroup, error)
	DeleteSpecGroup(ctx context.Context, id int64) error

	ListSpecItems(ctx context.Context, groupID int64) ([]model.SpecItem, error)
	CreateSpecItem(ctx context.Context, input model.SpecItemInput) (model.SpecItem, error)
	UpdateSpecItem(ctx context.Context, id int64, input model.SpecItemInput) (model.SpecItem, error)
	DeleteSpecItem(ctx context.Context, id int64) error

	ListPromotions(ctx context.Context) ([]model.Promotion, error)
	CreatePromotion(ctx context.Context, input model.PromotionInput) (model.Promotion, error)
	UpdatePromotion(ctx context.Context, id int64, input model.PromotionInput) (model.Promotion, error)
	SetPromotionActive(ctx context.Context, id int64, active bool) (model.Promotion, error)
	DeletePromotion(ctx context.Context, id int64) error

	ListOrders(ctx context.Context, q model.OrderQuery) ([]model.Order, error)
	GetOrderByNo(ctx context.Context, orderNo string) (model.Order, error)
	CreateOrder(ctx context.Context, input model.CreateOrderInput) (model.Order, error)
	CreateRefund(ctx context.Context, orderNo string, input model.CreateRefundInput) (model.Refund, error)
	ListRefundsByOrderNo(ctx context.Context, orderNo string) ([]model.Refund, error)
	DeleteOrderByNo(ctx context.Context, orderNo string) error

	DailyStats(ctx context.Context, date time.Time) (model.DailyStats, error)
	StatsOverview(ctx context.Context, from *time.Time, to *time.Time) (model.StatsOverview, error)
	StatsHourlySales(ctx context.Context, date time.Time) ([]model.StatsBucket, error)
	StatsTopProducts(ctx context.Context, from *time.Time, to *time.Time, limit int) ([]model.StatsBucket, error)
	StatsPaymentBreakdown(ctx context.Context, from *time.Time, to *time.Time) ([]model.StatsBucket, error)
	StatsOrderTypeBreakdown(ctx context.Context, from *time.Time, to *time.Time) ([]model.StatsBucket, error)

	GetSetting(ctx context.Context, key string) (string, error)
	SetSetting(ctx context.Context, key string, valueJSON string) error
	ListSettings(ctx context.Context) (map[string]string, error)

	SyncStatus(ctx context.Context) (model.SyncStatus, error)
	ListSyncErrors(ctx context.Context, limit int) ([]model.SyncErrorEvent, error)
	ListAuditLogs(ctx context.Context, limit int) ([]model.AuditLog, error)
	AppendAuditLog(ctx context.Context, actor, action, target, detail string) error

	Close()
}

var ErrNotFound = errors.New("not_found")
var ErrInvalidRefundAmount = errors.New("invalid_refund_amount")

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

func (s *PostgresStore) Ping(ctx context.Context) error { return s.pool.Ping(ctx) }
func (s *PostgresStore) Close()                         { s.pool.Close() }

func (s *PostgresStore) ListProducts(ctx context.Context) ([]model.Product, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, name, COALESCE(name_th,''), COALESCE(name_zh,''), COALESCE(name_en,''),
		       category, price, COALESCE(discount_type,''), COALESCE(discount_value,0),
		       COALESCE(delivery_price_json,''), COALESCE(image_url,''), COALESCE(sort,0), active
		FROM products
		ORDER BY COALESCE(sort,0) ASC, id ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.Product, 0, 64)
	for rows.Next() {
		var p model.Product
		if err := rows.Scan(&p.ID, &p.Name, &p.NameTH, &p.NameZH, &p.NameEN, &p.Category, &p.Price, &p.DiscountType, &p.DiscountValue, &p.DeliveryPriceJSON, &p.ImageURL, &p.Sort, &p.Active); err != nil {
			return nil, err
		}
		items = append(items, p)
	}
	return items, rows.Err()
}

func (s *PostgresStore) GetProductByID(ctx context.Context, id int64) (model.Product, error) {
	var p model.Product
	err := s.pool.QueryRow(ctx, `
		SELECT id, name, COALESCE(name_th,''), COALESCE(name_zh,''), COALESCE(name_en,''),
		       category, price, COALESCE(discount_type,''), COALESCE(discount_value,0),
		       COALESCE(delivery_price_json,''), COALESCE(image_url,''), COALESCE(sort,0), active
		FROM products WHERE id=$1 LIMIT 1
	`, id).Scan(&p.ID, &p.Name, &p.NameTH, &p.NameZH, &p.NameEN, &p.Category, &p.Price, &p.DiscountType, &p.DiscountValue, &p.DeliveryPriceJSON, &p.ImageURL, &p.Sort, &p.Active)
	if err != nil {
		if strings.Contains(err.Error(), "no rows") {
			return model.Product{}, ErrNotFound
		}
		return model.Product{}, err
	}
	return p, nil
}

func (s *PostgresStore) CreateProduct(ctx context.Context, input model.ProductInput) (model.Product, error) {
	var p model.Product
	err := s.pool.QueryRow(ctx, `
		INSERT INTO products(name,name_th,name_zh,name_en,category,price,discount_type,discount_value,delivery_price_json,image_url,sort,active)
		VALUES($1,$2,$3,$4,$5,$6,NULLIF($7,''),$8,NULLIF($9,''),NULLIF($10,''),$11,$12)
		RETURNING id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),category,price,
		          COALESCE(discount_type,''),COALESCE(discount_value,0),COALESCE(delivery_price_json,''),
		          COALESCE(image_url,''),COALESCE(sort,0),active
	`, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), strings.TrimSpace(input.Category), input.Price, strings.TrimSpace(input.DiscountType), input.DiscountValue, strings.TrimSpace(input.DeliveryPriceJSON), strings.TrimSpace(input.ImageURL), input.Sort, input.Active).
		Scan(&p.ID, &p.Name, &p.NameTH, &p.NameZH, &p.NameEN, &p.Category, &p.Price, &p.DiscountType, &p.DiscountValue, &p.DeliveryPriceJSON, &p.ImageURL, &p.Sort, &p.Active)
	return p, err
}

func (s *PostgresStore) UpdateProduct(ctx context.Context, id int64, input model.ProductInput) (model.Product, error) {
	var p model.Product
	err := s.pool.QueryRow(ctx, `
		UPDATE products
		SET name=$2,name_th=$3,name_zh=$4,name_en=$5,category=$6,price=$7,
		    discount_type=NULLIF($8,''),discount_value=$9,delivery_price_json=NULLIF($10,''),
		    image_url=NULLIF($11,''),sort=$12,active=$13
		WHERE id=$1
		RETURNING id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),category,price,
		          COALESCE(discount_type,''),COALESCE(discount_value,0),COALESCE(delivery_price_json,''),
		          COALESCE(image_url,''),COALESCE(sort,0),active
	`, id, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), strings.TrimSpace(input.Category), input.Price, strings.TrimSpace(input.DiscountType), input.DiscountValue, strings.TrimSpace(input.DeliveryPriceJSON), strings.TrimSpace(input.ImageURL), input.Sort, input.Active).
		Scan(&p.ID, &p.Name, &p.NameTH, &p.NameZH, &p.NameEN, &p.Category, &p.Price, &p.DiscountType, &p.DiscountValue, &p.DeliveryPriceJSON, &p.ImageURL, &p.Sort, &p.Active)
	if err != nil && strings.Contains(err.Error(), "no rows") {
		return model.Product{}, ErrNotFound
	}
	return p, err
}

func (s *PostgresStore) SetProductActive(ctx context.Context, id int64, active bool) (model.Product, error) {
	p, err := s.GetProductByID(ctx, id)
	if err != nil {
		return model.Product{}, err
	}
	p.Active = active
	return s.UpdateProduct(ctx, id, model.ProductInput{
		Name:              p.Name,
		NameTH:            p.NameTH,
		NameZH:            p.NameZH,
		NameEN:            p.NameEN,
		Category:          p.Category,
		Price:             p.Price,
		DiscountType:      p.DiscountType,
		DiscountValue:     p.DiscountValue,
		DeliveryPriceJSON: p.DeliveryPriceJSON,
		ImageURL:          p.ImageURL,
		Sort:              p.Sort,
		Active:            p.Active,
	})
}

func (s *PostgresStore) DeleteProduct(ctx context.Context, id int64) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM products WHERE id=$1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) ListCategories(ctx context.Context) ([]model.Category, error) {
	rows, err := s.pool.Query(ctx, `SELECT id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),COALESCE(sort,0),active FROM categories ORDER BY COALESCE(sort,0),id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.Category, 0, 32)
	for rows.Next() {
		var it model.Category
		if err := rows.Scan(&it.ID, &it.Name, &it.NameTH, &it.NameZH, &it.NameEN, &it.Sort, &it.Active); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

func (s *PostgresStore) CreateCategory(ctx context.Context, input model.CategoryInput) (model.Category, error) {
	var it model.Category
	err := s.pool.QueryRow(ctx, `
		INSERT INTO categories(name,name_th,name_zh,name_en,sort,active)
		VALUES($1,$2,$3,$4,$5,$6)
		RETURNING id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),COALESCE(sort,0),active
	`, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), input.Sort, input.Active).
		Scan(&it.ID, &it.Name, &it.NameTH, &it.NameZH, &it.NameEN, &it.Sort, &it.Active)
	return it, err
}

func (s *PostgresStore) UpdateCategory(ctx context.Context, id int64, input model.CategoryInput) (model.Category, error) {
	var it model.Category
	err := s.pool.QueryRow(ctx, `
		UPDATE categories SET name=$2,name_th=$3,name_zh=$4,name_en=$5,sort=$6,active=$7
		WHERE id=$1
		RETURNING id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),COALESCE(sort,0),active
	`, id, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), input.Sort, input.Active).
		Scan(&it.ID, &it.Name, &it.NameTH, &it.NameZH, &it.NameEN, &it.Sort, &it.Active)
	if err != nil && strings.Contains(err.Error(), "no rows") {
		return model.Category{}, ErrNotFound
	}
	return it, err
}

func (s *PostgresStore) DeleteCategory(ctx context.Context, id int64) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM categories WHERE id=$1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) ListSpecGroups(ctx context.Context) ([]model.SpecGroup, error) {
	rows, err := s.pool.Query(ctx, `SELECT id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),COALESCE(sort,0),active FROM spec_groups ORDER BY COALESCE(sort,0),id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.SpecGroup, 0, 32)
	for rows.Next() {
		var it model.SpecGroup
		if err := rows.Scan(&it.ID, &it.Name, &it.NameTH, &it.NameZH, &it.NameEN, &it.Sort, &it.Active); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

func (s *PostgresStore) CreateSpecGroup(ctx context.Context, input model.SpecGroupInput) (model.SpecGroup, error) {
	var it model.SpecGroup
	err := s.pool.QueryRow(ctx, `
		INSERT INTO spec_groups(name,name_th,name_zh,name_en,sort,active)
		VALUES($1,$2,$3,$4,$5,$6)
		RETURNING id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),COALESCE(sort,0),active
	`, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), input.Sort, input.Active).
		Scan(&it.ID, &it.Name, &it.NameTH, &it.NameZH, &it.NameEN, &it.Sort, &it.Active)
	return it, err
}

func (s *PostgresStore) UpdateSpecGroup(ctx context.Context, id int64, input model.SpecGroupInput) (model.SpecGroup, error) {
	var it model.SpecGroup
	err := s.pool.QueryRow(ctx, `
		UPDATE spec_groups SET name=$2,name_th=$3,name_zh=$4,name_en=$5,sort=$6,active=$7
		WHERE id=$1
		RETURNING id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),COALESCE(sort,0),active
	`, id, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), input.Sort, input.Active).
		Scan(&it.ID, &it.Name, &it.NameTH, &it.NameZH, &it.NameEN, &it.Sort, &it.Active)
	if err != nil && strings.Contains(err.Error(), "no rows") {
		return model.SpecGroup{}, ErrNotFound
	}
	return it, err
}

func (s *PostgresStore) DeleteSpecGroup(ctx context.Context, id int64) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM spec_groups WHERE id=$1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) ListSpecItems(ctx context.Context, groupID int64) ([]model.SpecItem, error) {
	args := []any{}
	sql := `SELECT id,group_id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),COALESCE(extra_price,0),COALESCE(sort,0),active FROM spec_items`
	if groupID > 0 {
		sql += ` WHERE group_id=$1`
		args = append(args, groupID)
	}
	sql += ` ORDER BY group_id,COALESCE(sort,0),id`
	rows, err := s.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.SpecItem, 0, 64)
	for rows.Next() {
		var it model.SpecItem
		if err := rows.Scan(&it.ID, &it.GroupID, &it.Name, &it.NameTH, &it.NameZH, &it.NameEN, &it.ExtraPrice, &it.Sort, &it.Active); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

func (s *PostgresStore) CreateSpecItem(ctx context.Context, input model.SpecItemInput) (model.SpecItem, error) {
	var it model.SpecItem
	err := s.pool.QueryRow(ctx, `
		INSERT INTO spec_items(group_id,name,name_th,name_zh,name_en,extra_price,sort,active)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING id,group_id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),COALESCE(extra_price,0),COALESCE(sort,0),active
	`, input.GroupID, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), input.ExtraPrice, input.Sort, input.Active).
		Scan(&it.ID, &it.GroupID, &it.Name, &it.NameTH, &it.NameZH, &it.NameEN, &it.ExtraPrice, &it.Sort, &it.Active)
	return it, err
}

func (s *PostgresStore) UpdateSpecItem(ctx context.Context, id int64, input model.SpecItemInput) (model.SpecItem, error) {
	var it model.SpecItem
	err := s.pool.QueryRow(ctx, `
		UPDATE spec_items SET group_id=$2,name=$3,name_th=$4,name_zh=$5,name_en=$6,extra_price=$7,sort=$8,active=$9
		WHERE id=$1
		RETURNING id,group_id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),COALESCE(extra_price,0),COALESCE(sort,0),active
	`, id, input.GroupID, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), input.ExtraPrice, input.Sort, input.Active).
		Scan(&it.ID, &it.GroupID, &it.Name, &it.NameTH, &it.NameZH, &it.NameEN, &it.ExtraPrice, &it.Sort, &it.Active)
	if err != nil && strings.Contains(err.Error(), "no rows") {
		return model.SpecItem{}, ErrNotFound
	}
	return it, err
}

func (s *PostgresStore) DeleteSpecItem(ctx context.Context, id int64) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM spec_items WHERE id=$1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) ListPromotions(ctx context.Context) ([]model.Promotion, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),
		       promo_type,COALESCE(rule_json::text,'{}'),COALESCE(priority,0),
		       COALESCE(stacking_mode,''),COALESCE(exclude_order_type_json::text,'[]'),start_at,end_at,active
		FROM promotions
		ORDER BY active DESC, COALESCE(priority,0) DESC, id DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.Promotion, 0, 32)
	for rows.Next() {
		var p model.Promotion
		if err := rows.Scan(&p.ID, &p.Name, &p.NameTH, &p.NameZH, &p.NameEN, &p.PromoType, &p.RuleJSON, &p.Priority, &p.StackingMode, &p.ExcludeJSON, &p.StartAt, &p.EndAt, &p.Active); err != nil {
			return nil, err
		}
		items = append(items, p)
	}
	return items, rows.Err()
}

func (s *PostgresStore) CreatePromotion(ctx context.Context, input model.PromotionInput) (model.Promotion, error) {
	var p model.Promotion
	err := s.pool.QueryRow(ctx, `
		INSERT INTO promotions(name,name_th,name_zh,name_en,promo_type,rule_json,priority,stacking_mode,exclude_order_type_json,start_at,end_at,active)
		VALUES($1,$2,$3,$4,$5,COALESCE(NULLIF($6,''),'{}')::jsonb,$7,NULLIF($8,''),COALESCE(NULLIF($9,''),'[]')::jsonb,$10,$11,$12)
		RETURNING id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),promo_type,
		          COALESCE(rule_json::text,'{}'),COALESCE(priority,0),COALESCE(stacking_mode,''),
		          COALESCE(exclude_order_type_json::text,'[]'),start_at,end_at,active
	`, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), strings.TrimSpace(input.PromoType), strings.TrimSpace(input.RuleJSON), input.Priority, strings.TrimSpace(input.StackingMode), strings.TrimSpace(input.ExcludeJSON), input.StartAt, input.EndAt, input.Active).
		Scan(&p.ID, &p.Name, &p.NameTH, &p.NameZH, &p.NameEN, &p.PromoType, &p.RuleJSON, &p.Priority, &p.StackingMode, &p.ExcludeJSON, &p.StartAt, &p.EndAt, &p.Active)
	return p, err
}

func (s *PostgresStore) UpdatePromotion(ctx context.Context, id int64, input model.PromotionInput) (model.Promotion, error) {
	var p model.Promotion
	err := s.pool.QueryRow(ctx, `
		UPDATE promotions
		SET name=$2,name_th=$3,name_zh=$4,name_en=$5,promo_type=$6,
		    rule_json=COALESCE(NULLIF($7,''),'{}')::jsonb,priority=$8,stacking_mode=NULLIF($9,''),
		    exclude_order_type_json=COALESCE(NULLIF($10,''),'[]')::jsonb,start_at=$11,end_at=$12,active=$13
		WHERE id=$1
		RETURNING id,name,COALESCE(name_th,''),COALESCE(name_zh,''),COALESCE(name_en,''),promo_type,
		          COALESCE(rule_json::text,'{}'),COALESCE(priority,0),COALESCE(stacking_mode,''),
		          COALESCE(exclude_order_type_json::text,'[]'),start_at,end_at,active
	`, id, strings.TrimSpace(input.Name), strings.TrimSpace(input.NameTH), strings.TrimSpace(input.NameZH), strings.TrimSpace(input.NameEN), strings.TrimSpace(input.PromoType), strings.TrimSpace(input.RuleJSON), input.Priority, strings.TrimSpace(input.StackingMode), strings.TrimSpace(input.ExcludeJSON), input.StartAt, input.EndAt, input.Active).
		Scan(&p.ID, &p.Name, &p.NameTH, &p.NameZH, &p.NameEN, &p.PromoType, &p.RuleJSON, &p.Priority, &p.StackingMode, &p.ExcludeJSON, &p.StartAt, &p.EndAt, &p.Active)
	if err != nil && strings.Contains(err.Error(), "no rows") {
		return model.Promotion{}, ErrNotFound
	}
	return p, err
}

func (s *PostgresStore) SetPromotionActive(ctx context.Context, id int64, active bool) (model.Promotion, error) {
	tag, err := s.pool.Exec(ctx, `UPDATE promotions SET active=$2 WHERE id=$1`, id, active)
	if err != nil {
		return model.Promotion{}, err
	}
	if tag.RowsAffected() == 0 {
		return model.Promotion{}, ErrNotFound
	}
	rows, err := s.ListPromotions(ctx)
	if err != nil {
		return model.Promotion{}, err
	}
	for _, it := range rows {
		if it.ID == id {
			return it, nil
		}
	}
	return model.Promotion{}, ErrNotFound
}

func (s *PostgresStore) DeletePromotion(ctx context.Context, id int64) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM promotions WHERE id=$1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) ListOrders(ctx context.Context, q model.OrderQuery) ([]model.Order, error) {
	limit := q.Limit
	if limit <= 0 {
		limit = 200
	}
	if limit > 500 {
		limit = 500
	}
	offset := q.Offset
	if offset < 0 {
		offset = 0
	}

	args := []any{}
	conds := []string{}
	addArg := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}
	if keyword := strings.TrimSpace(q.Keyword); keyword != "" {
		p := addArg("%" + keyword + "%")
		conds = append(conds, fmt.Sprintf("(order_no ILIKE %s OR channel ILIKE %s OR platform_order_no ILIKE %s)", p, p, p))
	}
	if status := strings.TrimSpace(q.Status); status != "" {
		conds = append(conds, fmt.Sprintf("status = %s", addArg(status)))
	}
	if orderType := strings.TrimSpace(q.OrderType); orderType != "" {
		conds = append(conds, fmt.Sprintf("order_type = %s", addArg(normalizeOrderType(orderType))))
	}
	if channel := strings.TrimSpace(q.Channel); channel != "" {
		conds = append(conds, fmt.Sprintf("channel ILIKE %s", addArg("%"+channel+"%")))
	}
	if pay := strings.TrimSpace(q.PaymentMethod); pay != "" {
		conds = append(conds, fmt.Sprintf("payment_method = %s", addArg(pay)))
	}
	if q.DateFrom != nil {
		conds = append(conds, fmt.Sprintf("created_at >= %s", addArg(*q.DateFrom)))
	}
	if q.DateTo != nil {
		conds = append(conds, fmt.Sprintf("created_at < %s", addArg(*q.DateTo)))
	}

	sql := `
		SELECT order_no, COALESCE(platform_order_no,''), order_type, COALESCE(channel,''), COALESCE(payment_method,''),
		       COALESCE(subtotal,total), COALESCE(product_discount,0), COALESCE(promo_discount,0), COALESCE(manual_platform_discount,0),
		       total, COALESCE(status, 'paid'), created_at
		FROM orders
	`
	if len(conds) > 0 {
		sql += " WHERE " + strings.Join(conds, " AND ")
	}
	sql += fmt.Sprintf(" ORDER BY created_at DESC LIMIT %s OFFSET %s", addArg(limit), addArg(offset))

	rows, err := s.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]model.Order, 0, 64)
	for rows.Next() {
		var o model.Order
		if err := rows.Scan(&o.OrderNo, &o.PlatformOrderNo, &o.OrderType, &o.Channel, &o.PaymentMethod, &o.Subtotal, &o.ProductDiscount, &o.PromoDiscount, &o.ManualPlatformDiscount, &o.Total, &o.Status, &o.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, o)
	}
	return items, rows.Err()
}

func (s *PostgresStore) GetOrderByNo(ctx context.Context, orderNo string) (model.Order, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT order_no, COALESCE(platform_order_no,''), order_type, COALESCE(channel,''), COALESCE(payment_method,''),
		       COALESCE(subtotal,total), COALESCE(product_discount,0), COALESCE(promo_discount,0), COALESCE(manual_platform_discount,0),
		       total, COALESCE(status, 'paid'), created_at
		FROM orders
		WHERE order_no = $1
		LIMIT 1
	`, strings.TrimSpace(orderNo))
	var o model.Order
	if err := row.Scan(&o.OrderNo, &o.PlatformOrderNo, &o.OrderType, &o.Channel, &o.PaymentMethod, &o.Subtotal, &o.ProductDiscount, &o.PromoDiscount, &o.ManualPlatformDiscount, &o.Total, &o.Status, &o.CreatedAt); err != nil {
		if strings.Contains(err.Error(), "no rows") {
			return model.Order{}, ErrNotFound
		}
		return model.Order{}, err
	}
	return o, nil
}

func (s *PostgresStore) CreateOrder(ctx context.Context, input model.CreateOrderInput) (model.Order, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.Order{}, err
	}
	defer tx.Rollback(ctx)

	orderNo := strings.TrimSpace(input.OrderNo)
	if orderNo == "" {
		orderNo = buildOrderNo(time.Now(), input.OrderType, input.Channel)
	}
	idempotencyKey := strings.TrimSpace(input.IdempotencyKey)

	row := tx.QueryRow(ctx, `
		INSERT INTO orders(order_no, platform_order_no, order_type, channel, payment_method, subtotal, product_discount, promo_discount, manual_platform_discount, total, status, created_at, idempotency_key)
		VALUES($1, NULLIF($2,''), $3, $4, NULLIF($5,''), $6, $7, $8, $9, $10, 'paid', COALESCE($11, NOW()), NULLIF($12,''))
		RETURNING order_no, COALESCE(platform_order_no,''), order_type, COALESCE(channel,''), COALESCE(payment_method,''),
		          COALESCE(subtotal,total), COALESCE(product_discount,0), COALESCE(promo_discount,0), COALESCE(manual_platform_discount,0),
		          total, status, created_at
	`, orderNo, strings.TrimSpace(input.PlatformOrderNo), normalizeOrderType(input.OrderType), strings.TrimSpace(input.Channel), strings.TrimSpace(input.PaymentMethod), input.Subtotal, input.ProductDiscount, input.PromoDiscount, input.ManualPlatformDiscount, input.Total, input.ClientTime, idempotencyKey)

	var order model.Order
	if err := row.Scan(&order.OrderNo, &order.PlatformOrderNo, &order.OrderType, &order.Channel, &order.PaymentMethod, &order.Subtotal, &order.ProductDiscount, &order.PromoDiscount, &order.ManualPlatformDiscount, &order.Total, &order.Status, &order.CreatedAt); err != nil {
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

	for _, it := range input.Items {
		qty := it.Quantity
		if qty <= 0 {
			qty = 1
		}
		lineTotal := it.LineTotal
		if lineTotal <= 0 {
			lineTotal = float64(qty) * it.UnitPrice
		}
		_, err := tx.Exec(ctx, `
			INSERT INTO order_items(order_no, product_name, quantity, unit_price, line_total)
			VALUES($1,$2,$3,$4,$5)
		`, orderNo, strings.TrimSpace(it.ProductName), qty, it.UnitPrice, lineTotal)
		if err != nil {
			return model.Order{}, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return model.Order{}, err
	}
	return order, nil
}

func (s *PostgresStore) CreateRefund(ctx context.Context, orderNo string, input model.CreateRefundInput) (model.Refund, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return model.Refund{}, err
	}
	defer tx.Rollback(ctx)
	idempotencyKey := strings.TrimSpace(input.IdempotencyKey)

	if idempotencyKey != "" {
		var existing model.Refund
		err := tx.QueryRow(ctx, `SELECT id, order_no, amount, reason, created_at FROM refunds WHERE idempotency_key=$1 LIMIT 1`, idempotencyKey).
			Scan(&existing.ID, &existing.OrderNo, &existing.Amount, &existing.Reason, &existing.CreatedAt)
		if err == nil {
			return existing, nil
		}
		if !strings.Contains(err.Error(), "no rows") {
			return model.Refund{}, err
		}
	}

	var total, refunded float64
	if err := tx.QueryRow(ctx, `
		SELECT o.total::float8, COALESCE((SELECT SUM(r.amount) FROM refunds r WHERE r.order_no=o.order_no),0)::float8
		FROM orders o WHERE o.order_no=$1 LIMIT 1
	`, strings.TrimSpace(orderNo)).Scan(&total, &refunded); err != nil {
		if strings.Contains(err.Error(), "no rows") {
			return model.Refund{}, fmt.Errorf("%w: order_no=%s", ErrNotFound, orderNo)
		}
		return model.Refund{}, err
	}
	if input.Amount > (total-refunded)+0.000001 {
		return model.Refund{}, fmt.Errorf("%w: amount=%.2f remaining=%.2f", ErrInvalidRefundAmount, input.Amount, total-refunded)
	}

	var refund model.Refund
	if err := tx.QueryRow(ctx, `
		INSERT INTO refunds(order_no, amount, reason, created_at, idempotency_key)
		VALUES($1,$2,$3,COALESCE($4,NOW()),NULLIF($5,''))
		RETURNING id, order_no, amount, reason, created_at
	`, strings.TrimSpace(orderNo), input.Amount, strings.TrimSpace(input.Reason), input.ClientTime, idempotencyKey).
		Scan(&refund.ID, &refund.OrderNo, &refund.Amount, &refund.Reason, &refund.CreatedAt); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" && idempotencyKey != "" {
			err = tx.QueryRow(ctx, `SELECT id, order_no, amount, reason, created_at FROM refunds WHERE idempotency_key=$1 LIMIT 1`, idempotencyKey).
				Scan(&refund.ID, &refund.OrderNo, &refund.Amount, &refund.Reason, &refund.CreatedAt)
			if err == nil {
				return refund, nil
			}
		}
		return model.Refund{}, err
	}

	_, err = tx.Exec(ctx, `
		UPDATE orders
		SET status = CASE
			WHEN COALESCE((SELECT SUM(amount) FROM refunds WHERE order_no=$1),0) >= total THEN 'refunded'
			ELSE 'partially_refunded'
		END
		WHERE order_no=$1
	`, strings.TrimSpace(orderNo))
	if err != nil {
		return model.Refund{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return model.Refund{}, err
	}
	return refund, nil
}

func (s *PostgresStore) ListRefundsByOrderNo(ctx context.Context, orderNo string) ([]model.Refund, error) {
	rows, err := s.pool.Query(ctx, `SELECT id, order_no, amount, reason, created_at FROM refunds WHERE order_no=$1 ORDER BY created_at DESC, id DESC`, strings.TrimSpace(orderNo))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.Refund, 0, 8)
	for rows.Next() {
		var r model.Refund
		if err := rows.Scan(&r.ID, &r.OrderNo, &r.Amount, &r.Reason, &r.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, r)
	}
	return items, rows.Err()
}

func (s *PostgresStore) DeleteOrderByNo(ctx context.Context, orderNo string) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM orders WHERE order_no=$1`, strings.TrimSpace(orderNo))
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PostgresStore) getOrderByIdempotencyKey(ctx context.Context, idempotencyKey string) (model.Order, error) {
	row := s.pool.QueryRow(ctx, `
		SELECT order_no, COALESCE(platform_order_no,''), order_type, COALESCE(channel,''), COALESCE(payment_method,''),
		       COALESCE(subtotal,total), COALESCE(product_discount,0), COALESCE(promo_discount,0), COALESCE(manual_platform_discount,0),
		       total, COALESCE(status,'paid'), created_at
		FROM orders WHERE idempotency_key=$1 LIMIT 1
	`, strings.TrimSpace(idempotencyKey))
	var o model.Order
	if err := row.Scan(&o.OrderNo, &o.PlatformOrderNo, &o.OrderType, &o.Channel, &o.PaymentMethod, &o.Subtotal, &o.ProductDiscount, &o.PromoDiscount, &o.ManualPlatformDiscount, &o.Total, &o.Status, &o.CreatedAt); err != nil {
		return model.Order{}, err
	}
	return o, nil
}

func (s *PostgresStore) DailyStats(ctx context.Context, date time.Time) (model.DailyStats, error) {
	start := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, time.Local)
	end := start.Add(24 * time.Hour)
	row := s.pool.QueryRow(ctx, `
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
		SELECT order_day.order_count, order_day.gross::float8, refund_day.refunds::float8 FROM order_day, refund_day
	`, start, end)
	var orderCount int64
	var gross, refunds float64
	if err := row.Scan(&orderCount, &gross, &refunds); err != nil {
		return model.DailyStats{}, err
	}
	return model.DailyStats{Date: start.Format("2006-01-02"), OrderCount: orderCount, GrossAmount: gross, Refunds: refunds, NetAmount: gross - refunds}, nil
}

func (s *PostgresStore) StatsOverview(ctx context.Context, from *time.Time, to *time.Time) (model.StatsOverview, error) {
	start, end := normalizeRange(from, to)
	row := s.pool.QueryRow(ctx, `
		WITH o AS (
		  SELECT COUNT(*)::bigint c, COALESCE(SUM(total),0)::float8 gross
		  FROM orders WHERE created_at >= $1 AND created_at < $2
		), r AS (
		  SELECT COALESCE(SUM(amount),0)::float8 refunds
		  FROM refunds WHERE created_at >= $1 AND created_at < $2
		)
		SELECT o.c, o.gross, r.refunds FROM o, r
	`, start, end)
	var out model.StatsOverview
	if err := row.Scan(&out.OrderCount, &out.Gross, &out.Refunds); err != nil {
		return model.StatsOverview{}, err
	}
	out.Net = out.Gross - out.Refunds
	return out, nil
}

func (s *PostgresStore) StatsHourlySales(ctx context.Context, date time.Time) ([]model.StatsBucket, error) {
	start := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, time.Local)
	end := start.Add(24 * time.Hour)
	rows, err := s.pool.Query(ctx, `
		SELECT TO_CHAR(date_trunc('hour', created_at), 'HH24:00') AS k, COUNT(*)::bigint c, COALESCE(SUM(total),0)::float8 a
		FROM orders
		WHERE created_at >= $1 AND created_at < $2
		GROUP BY 1
		ORDER BY 1
	`, start, end)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.StatsBucket, 0, 24)
	for rows.Next() {
		var b model.StatsBucket
		if err := rows.Scan(&b.Key, &b.Count, &b.Amount); err != nil {
			return nil, err
		}
		items = append(items, b)
	}
	return items, rows.Err()
}

func (s *PostgresStore) StatsTopProducts(ctx context.Context, from *time.Time, to *time.Time, limit int) ([]model.StatsBucket, error) {
	if limit <= 0 {
		limit = 10
	}
	if limit > 100 {
		limit = 100
	}
	start, end := normalizeRange(from, to)
	rows, err := s.pool.Query(ctx, `
		SELECT COALESCE(product_name,'(unknown)') AS k, COALESCE(SUM(quantity),0)::bigint c, COALESCE(SUM(line_total),0)::float8 a
		FROM order_items
		WHERE created_at >= $1 AND created_at < $2
		GROUP BY 1
		ORDER BY c DESC, a DESC
		LIMIT $3
	`, start, end, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.StatsBucket, 0, limit)
	for rows.Next() {
		var b model.StatsBucket
		if err := rows.Scan(&b.Key, &b.Count, &b.Amount); err != nil {
			return nil, err
		}
		items = append(items, b)
	}
	return items, rows.Err()
}

func (s *PostgresStore) StatsPaymentBreakdown(ctx context.Context, from *time.Time, to *time.Time) ([]model.StatsBucket, error) {
	start, end := normalizeRange(from, to)
	rows, err := s.pool.Query(ctx, `
		SELECT COALESCE(NULLIF(payment_method,''),'unknown') AS k, COUNT(*)::bigint c, COALESCE(SUM(total),0)::float8 a
		FROM orders
		WHERE created_at >= $1 AND created_at < $2
		GROUP BY 1
		ORDER BY a DESC, c DESC
	`, start, end)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.StatsBucket, 0, 8)
	for rows.Next() {
		var b model.StatsBucket
		if err := rows.Scan(&b.Key, &b.Count, &b.Amount); err != nil {
			return nil, err
		}
		items = append(items, b)
	}
	return items, rows.Err()
}

func (s *PostgresStore) StatsOrderTypeBreakdown(ctx context.Context, from *time.Time, to *time.Time) ([]model.StatsBucket, error) {
	start, end := normalizeRange(from, to)
	rows, err := s.pool.Query(ctx, `
		SELECT COALESCE(order_type,'in_store') AS k, COUNT(*)::bigint c, COALESCE(SUM(total),0)::float8 a
		FROM orders
		WHERE created_at >= $1 AND created_at < $2
		GROUP BY 1
		ORDER BY a DESC, c DESC
	`, start, end)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]model.StatsBucket, 0, 4)
	for rows.Next() {
		var b model.StatsBucket
		if err := rows.Scan(&b.Key, &b.Count, &b.Amount); err != nil {
			return nil, err
		}
		items = append(items, b)
	}
	return items, rows.Err()
}

func (s *PostgresStore) GetSetting(ctx context.Context, key string) (string, error) {
	var value string
	err := s.pool.QueryRow(ctx, `SELECT value_json FROM app_settings WHERE key=$1`, strings.TrimSpace(key)).Scan(&value)
	if err != nil {
		if strings.Contains(err.Error(), "no rows") {
			return "", ErrNotFound
		}
		return "", err
	}
	return value, nil
}

func (s *PostgresStore) SetSetting(ctx context.Context, key string, valueJSON string) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO app_settings(key, value_json, updated_at)
		VALUES($1, COALESCE(NULLIF($2,''),'{}')::jsonb, NOW())
		ON CONFLICT(key) DO UPDATE SET value_json=EXCLUDED.value_json, updated_at=NOW()
	`, strings.TrimSpace(key), strings.TrimSpace(valueJSON))
	return err
}

func (s *PostgresStore) ListSettings(ctx context.Context) (map[string]string, error) {
	rows, err := s.pool.Query(ctx, `SELECT key, value_json::text FROM app_settings ORDER BY key`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]string{}
	for rows.Next() {
		var k, v string
		if err := rows.Scan(&k, &v); err != nil {
			return nil, err
		}
		out[k] = v
	}
	return out, rows.Err()
}

func (s *PostgresStore) SyncStatus(ctx context.Context) (model.SyncStatus, error) {
	var out model.SyncStatus
	var ts *time.Time
	err := s.pool.QueryRow(ctx, `
		SELECT
		  COALESCE((SELECT COUNT(*) FROM sync_queue_events WHERE status='pending'),0)::bigint,
		  COALESCE((SELECT error_message FROM sync_queue_events WHERE status='failed' ORDER BY updated_at DESC LIMIT 1),''),
		  (SELECT updated_at FROM sync_queue_events WHERE status='failed' ORDER BY updated_at DESC LIMIT 1)
	`).Scan(&out.PendingCount, &out.LastError, &ts)
	if err != nil {
		if strings.Contains(err.Error(), "relation \"sync_queue_events\" does not exist") {
			return model.SyncStatus{}, nil
		}
		return model.SyncStatus{}, err
	}
	out.LastErrorAt = ts
	return out, nil
}

func (s *PostgresStore) ListSyncErrors(ctx context.Context, limit int) ([]model.SyncErrorEvent, error) {
	if limit <= 0 {
		limit = 100
	}
	if limit > 1000 {
		limit = 1000
	}
	rows, err := s.pool.Query(
		ctx,
		`SELECT id, COALESCE(task_key,''), COALESCE(error_message,''), updated_at
		 FROM sync_queue_events
		 WHERE status='failed'
		 ORDER BY updated_at DESC, id DESC
		 LIMIT $1`,
		limit,
	)
	if err != nil {
		if strings.Contains(err.Error(), "relation \"sync_queue_events\" does not exist") {
			return []model.SyncErrorEvent{}, nil
		}
		return nil, err
	}
	defer rows.Close()
	items := make([]model.SyncErrorEvent, 0, limit)
	for rows.Next() {
		var it model.SyncErrorEvent
		if err := rows.Scan(&it.ID, &it.TaskKey, &it.Message, &it.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

func (s *PostgresStore) ListAuditLogs(ctx context.Context, limit int) ([]model.AuditLog, error) {
	if limit <= 0 {
		limit = 100
	}
	if limit > 1000 {
		limit = 1000
	}
	rows, err := s.pool.Query(ctx, `SELECT id, actor, action, target, detail, created_at FROM audit_logs ORDER BY id DESC LIMIT $1`, limit)
	if err != nil {
		if strings.Contains(err.Error(), "relation \"audit_logs\" does not exist") {
			return []model.AuditLog{}, nil
		}
		return nil, err
	}
	defer rows.Close()
	items := make([]model.AuditLog, 0, limit)
	for rows.Next() {
		var it model.AuditLog
		if err := rows.Scan(&it.ID, &it.Actor, &it.Action, &it.Target, &it.Detail, &it.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, rows.Err()
}

func (s *PostgresStore) AppendAuditLog(ctx context.Context, actor, action, target, detail string) error {
	_, err := s.pool.Exec(ctx, `INSERT INTO audit_logs(actor,action,target,detail,created_at) VALUES($1,$2,$3,$4,NOW())`, strings.TrimSpace(actor), strings.TrimSpace(action), strings.TrimSpace(target), strings.TrimSpace(detail))
	if err != nil && strings.Contains(err.Error(), "relation \"audit_logs\" does not exist") {
		return nil
	}
	return err
}

func normalizeRange(from *time.Time, to *time.Time) (time.Time, time.Time) {
	if from != nil && to != nil {
		return *from, *to
	}
	if from != nil {
		return *from, time.Now().Add(24 * time.Hour)
	}
	if to != nil {
		return to.Add(-24 * time.Hour), *to
	}
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	return start, start.Add(24 * time.Hour)
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
	return fmt.Sprintf("%s%s", prefix, now.Format("20060102-150405000"))
}
