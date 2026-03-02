package service

import (
	"context"
	"time"

	"tea-store/backend-go/internal/model"
	"tea-store/backend-go/internal/repo"
)

type POSService struct {
	store repo.Store
}

func NewPOSService(store repo.Store) *POSService {
	return &POSService{store: store}
}

func (s *POSService) Health(ctx context.Context) map[string]string {
	status := "ok"
	if err := s.store.Ping(ctx); err != nil {
		status = "db_error"
	}
	return map[string]string{"status": status}
}

func (s *POSService) Products(ctx context.Context) ([]model.Product, error) {
	return s.store.ListProducts(ctx)
}

func (s *POSService) Orders(ctx context.Context, q model.OrderQuery) ([]model.Order, error) {
	return s.store.ListOrders(ctx, q)
}

func (s *POSService) OrderByNo(ctx context.Context, orderNo string) (model.Order, error) {
	return s.store.GetOrderByNo(ctx, orderNo)
}

func (s *POSService) CreateOrder(
	ctx context.Context,
	input model.CreateOrderInput,
) (model.Order, error) {
	return s.store.CreateOrder(ctx, input)
}

func (s *POSService) CreateRefund(
	ctx context.Context,
	orderNo string,
	input model.CreateRefundInput,
) (model.Refund, error) {
	return s.store.CreateRefund(ctx, orderNo, input)
}

func (s *POSService) RefundsByOrderNo(ctx context.Context, orderNo string) ([]model.Refund, error) {
	return s.store.ListRefundsByOrderNo(ctx, orderNo)
}

func (s *POSService) DeleteOrderByNo(ctx context.Context, orderNo string) error {
	return s.store.DeleteOrderByNo(ctx, orderNo)
}

func (s *POSService) DailyStats(
	ctx context.Context,
	date time.Time,
) (model.DailyStats, error) {
	return s.store.DailyStats(ctx, date)
}
