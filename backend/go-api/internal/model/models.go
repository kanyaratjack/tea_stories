package model

import "time"

type Product struct {
	ID                int64   `json:"id"`
	Name              string  `json:"name"`
	NameTH            string  `json:"name_th,omitempty"`
	NameZH            string  `json:"name_zh,omitempty"`
	NameEN            string  `json:"name_en,omitempty"`
	Category          string  `json:"category"`
	Price             float64 `json:"price"`
	DiscountType      string  `json:"discount_type,omitempty"`
	DiscountValue     float64 `json:"discount_value,omitempty"`
	DeliveryPriceJSON string  `json:"delivery_price_json,omitempty"`
	ImageURL          string  `json:"image_url,omitempty"`
	Sort              int     `json:"sort"`
	Active            bool    `json:"active"`
}

type ProductInput struct {
	Name              string  `json:"name"`
	NameTH            string  `json:"name_th,omitempty"`
	NameZH            string  `json:"name_zh,omitempty"`
	NameEN            string  `json:"name_en,omitempty"`
	Category          string  `json:"category"`
	Price             float64 `json:"price"`
	DiscountType      string  `json:"discount_type,omitempty"`
	DiscountValue     float64 `json:"discount_value,omitempty"`
	DeliveryPriceJSON string  `json:"delivery_price_json,omitempty"`
	ImageURL          string  `json:"image_url,omitempty"`
	Sort              int     `json:"sort,omitempty"`
	Active            bool    `json:"active"`
}

type Category struct {
	ID     int64  `json:"id"`
	Name   string `json:"name"`
	NameTH string `json:"name_th,omitempty"`
	NameZH string `json:"name_zh,omitempty"`
	NameEN string `json:"name_en,omitempty"`
	Sort   int    `json:"sort"`
	Active bool   `json:"active"`
}

type CategoryInput struct {
	Name   string `json:"name"`
	NameTH string `json:"name_th,omitempty"`
	NameZH string `json:"name_zh,omitempty"`
	NameEN string `json:"name_en,omitempty"`
	Sort   int    `json:"sort,omitempty"`
	Active bool   `json:"active"`
}

type SpecGroup struct {
	ID     int64  `json:"id"`
	Name   string `json:"name"`
	NameTH string `json:"name_th,omitempty"`
	NameZH string `json:"name_zh,omitempty"`
	NameEN string `json:"name_en,omitempty"`
	Sort   int    `json:"sort"`
	Active bool   `json:"active"`
}

type SpecGroupInput struct {
	Name   string `json:"name"`
	NameTH string `json:"name_th,omitempty"`
	NameZH string `json:"name_zh,omitempty"`
	NameEN string `json:"name_en,omitempty"`
	Sort   int    `json:"sort,omitempty"`
	Active bool   `json:"active"`
}

type SpecItem struct {
	ID         int64   `json:"id"`
	GroupID    int64   `json:"group_id"`
	Name       string  `json:"name"`
	NameTH     string  `json:"name_th,omitempty"`
	NameZH     string  `json:"name_zh,omitempty"`
	NameEN     string  `json:"name_en,omitempty"`
	ExtraPrice float64 `json:"extra_price"`
	Sort       int     `json:"sort"`
	Active     bool    `json:"active"`
}

type SpecItemInput struct {
	GroupID    int64   `json:"group_id"`
	Name       string  `json:"name"`
	NameTH     string  `json:"name_th,omitempty"`
	NameZH     string  `json:"name_zh,omitempty"`
	NameEN     string  `json:"name_en,omitempty"`
	ExtraPrice float64 `json:"extra_price,omitempty"`
	Sort       int     `json:"sort,omitempty"`
	Active     bool    `json:"active"`
}

type Promotion struct {
	ID           int64      `json:"id"`
	Name         string     `json:"name"`
	NameTH       string     `json:"name_th,omitempty"`
	NameZH       string     `json:"name_zh,omitempty"`
	NameEN       string     `json:"name_en,omitempty"`
	PromoType    string     `json:"promo_type"`
	RuleJSON     string     `json:"rule_json"`
	Priority     int        `json:"priority"`
	StackingMode string     `json:"stacking_mode"`
	ExcludeJSON  string     `json:"exclude_order_type_json"`
	StartAt      *time.Time `json:"start_at,omitempty"`
	EndAt        *time.Time `json:"end_at,omitempty"`
	Active       bool       `json:"active"`
}

type PromotionInput struct {
	Name         string     `json:"name"`
	NameTH       string     `json:"name_th,omitempty"`
	NameZH       string     `json:"name_zh,omitempty"`
	NameEN       string     `json:"name_en,omitempty"`
	PromoType    string     `json:"promo_type"`
	RuleJSON     string     `json:"rule_json"`
	Priority     int        `json:"priority,omitempty"`
	StackingMode string     `json:"stacking_mode,omitempty"`
	ExcludeJSON  string     `json:"exclude_order_type_json,omitempty"`
	StartAt      *time.Time `json:"start_at,omitempty"`
	EndAt        *time.Time `json:"end_at,omitempty"`
	Active       bool       `json:"active"`
}

type Order struct {
	OrderNo                string    `json:"order_no"`
	PlatformOrderNo        string    `json:"platform_order_no,omitempty"`
	OrderType              string    `json:"order_type"`
	Channel                string    `json:"channel,omitempty"`
	PaymentMethod          string    `json:"payment_method,omitempty"`
	Subtotal               float64   `json:"subtotal"`
	ProductDiscount        float64   `json:"product_discount"`
	PromoDiscount          float64   `json:"promo_discount"`
	ManualPlatformDiscount float64   `json:"manual_platform_discount"`
	Total                  float64   `json:"total"`
	Status                 string    `json:"status"`
	CreatedAt              time.Time `json:"created_at"`
}

type OrderQuery struct {
	Keyword       string
	Status        string
	OrderType     string
	Channel       string
	PaymentMethod string
	DateFrom      *time.Time
	DateTo        *time.Time
	Limit         int
	Offset        int
}

type OrderItemInput struct {
	ProductName string  `json:"product_name"`
	Quantity    int     `json:"quantity"`
	UnitPrice   float64 `json:"unit_price"`
	LineTotal   float64 `json:"line_total"`
}

type CreateOrderInput struct {
	OrderNo                string           `json:"order_no,omitempty"`
	PlatformOrderNo        string           `json:"platform_order_no,omitempty"`
	OrderType              string           `json:"order_type"`
	Channel                string           `json:"channel,omitempty"`
	PaymentMethod          string           `json:"payment_method,omitempty"`
	Subtotal               float64          `json:"subtotal,omitempty"`
	ProductDiscount        float64          `json:"product_discount,omitempty"`
	PromoDiscount          float64          `json:"promo_discount,omitempty"`
	ManualPlatformDiscount float64          `json:"manual_platform_discount,omitempty"`
	Total                  float64          `json:"total"`
	Items                  []OrderItemInput `json:"items,omitempty"`
	ClientTime             *time.Time       `json:"created_at,omitempty"`
	IdempotencyKey         string           `json:"idempotency_key,omitempty"`
}

type Refund struct {
	ID        int64     `json:"id"`
	OrderNo   string    `json:"order_no"`
	Amount    float64   `json:"amount"`
	Reason    string    `json:"reason"`
	CreatedAt time.Time `json:"created_at"`
}

type CreateRefundInput struct {
	Amount         float64    `json:"amount"`
	Reason         string     `json:"reason"`
	ClientTime     *time.Time `json:"created_at,omitempty"`
	IdempotencyKey string     `json:"idempotency_key,omitempty"`
}

type DailyStats struct {
	Date        string  `json:"date"`
	OrderCount  int64   `json:"order_count"`
	GrossAmount float64 `json:"gross_amount"`
	Refunds     float64 `json:"refunds"`
	NetAmount   float64 `json:"net_amount"`
}

type StatsOverview struct {
	OrderCount int64   `json:"order_count"`
	Gross      float64 `json:"gross"`
	Refunds    float64 `json:"refunds"`
	Net        float64 `json:"net"`
}

type StatsBucket struct {
	Key    string  `json:"key"`
	Count  int64   `json:"count"`
	Amount float64 `json:"amount"`
}

type AuditLog struct {
	ID        int64     `json:"id"`
	Actor     string    `json:"actor"`
	Action    string    `json:"action"`
	Target    string    `json:"target"`
	Detail    string    `json:"detail"`
	CreatedAt time.Time `json:"created_at"`
}

type SyncStatus struct {
	PendingCount int64      `json:"pending_count"`
	LastError    string     `json:"last_error,omitempty"`
	LastErrorAt  *time.Time `json:"last_error_at,omitempty"`
}

type SyncErrorEvent struct {
	ID        int64     `json:"id"`
	TaskKey   string    `json:"task_key,omitempty"`
	Message   string    `json:"message"`
	UpdatedAt time.Time `json:"updated_at"`
}
