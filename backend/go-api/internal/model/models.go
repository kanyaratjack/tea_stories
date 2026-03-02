package model

import "time"

type Product struct {
	ID       int64   `json:"id"`
	Name     string  `json:"name"`
	NameTH   string  `json:"name_th,omitempty"`
	NameZH   string  `json:"name_zh,omitempty"`
	NameEN   string  `json:"name_en,omitempty"`
	Category string  `json:"category"`
	Price    float64 `json:"price"`
	Active   bool    `json:"active"`
}

type Order struct {
	OrderNo   string    `json:"order_no"`
	OrderType string    `json:"order_type"`
	Channel   string    `json:"channel,omitempty"`
	Total     float64   `json:"total"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

type OrderQuery struct {
	Keyword   string
	Status    string
	OrderType string
	Channel   string
	DateFrom  *time.Time
	DateTo    *time.Time
	Limit     int
	Offset    int
}

type CreateOrderInput struct {
	OrderNo        string     `json:"order_no,omitempty"`
	OrderType      string     `json:"order_type"`
	Channel        string     `json:"channel,omitempty"`
	Total          float64    `json:"total"`
	ClientTime     *time.Time `json:"created_at,omitempty"`
	IdempotencyKey string     `json:"idempotency_key,omitempty"`
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
