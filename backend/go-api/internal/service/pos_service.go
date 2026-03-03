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

func NewPOSService(store repo.Store) *POSService { return &POSService{store: store} }

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
func (s *POSService) ProductByID(ctx context.Context, id int64) (model.Product, error) {
	return s.store.GetProductByID(ctx, id)
}
func (s *POSService) CreateProduct(ctx context.Context, input model.ProductInput) (model.Product, error) {
	return s.store.CreateProduct(ctx, input)
}
func (s *POSService) UpdateProduct(ctx context.Context, id int64, input model.ProductInput) (model.Product, error) {
	return s.store.UpdateProduct(ctx, id, input)
}
func (s *POSService) SetProductActive(ctx context.Context, id int64, active bool) (model.Product, error) {
	return s.store.SetProductActive(ctx, id, active)
}
func (s *POSService) DeleteProduct(ctx context.Context, id int64) error {
	return s.store.DeleteProduct(ctx, id)
}

func (s *POSService) Categories(ctx context.Context) ([]model.Category, error) {
	return s.store.ListCategories(ctx)
}
func (s *POSService) CreateCategory(ctx context.Context, input model.CategoryInput) (model.Category, error) {
	return s.store.CreateCategory(ctx, input)
}
func (s *POSService) UpdateCategory(ctx context.Context, id int64, input model.CategoryInput) (model.Category, error) {
	return s.store.UpdateCategory(ctx, id, input)
}
func (s *POSService) DeleteCategory(ctx context.Context, id int64) error {
	return s.store.DeleteCategory(ctx, id)
}

func (s *POSService) SpecGroups(ctx context.Context) ([]model.SpecGroup, error) {
	return s.store.ListSpecGroups(ctx)
}
func (s *POSService) CreateSpecGroup(ctx context.Context, input model.SpecGroupInput) (model.SpecGroup, error) {
	return s.store.CreateSpecGroup(ctx, input)
}
func (s *POSService) UpdateSpecGroup(ctx context.Context, id int64, input model.SpecGroupInput) (model.SpecGroup, error) {
	return s.store.UpdateSpecGroup(ctx, id, input)
}
func (s *POSService) DeleteSpecGroup(ctx context.Context, id int64) error {
	return s.store.DeleteSpecGroup(ctx, id)
}

func (s *POSService) SpecItems(ctx context.Context, groupID int64) ([]model.SpecItem, error) {
	return s.store.ListSpecItems(ctx, groupID)
}
func (s *POSService) CreateSpecItem(ctx context.Context, input model.SpecItemInput) (model.SpecItem, error) {
	return s.store.CreateSpecItem(ctx, input)
}
func (s *POSService) UpdateSpecItem(ctx context.Context, id int64, input model.SpecItemInput) (model.SpecItem, error) {
	return s.store.UpdateSpecItem(ctx, id, input)
}
func (s *POSService) DeleteSpecItem(ctx context.Context, id int64) error {
	return s.store.DeleteSpecItem(ctx, id)
}

func (s *POSService) Promotions(ctx context.Context) ([]model.Promotion, error) {
	return s.store.ListPromotions(ctx)
}
func (s *POSService) CreatePromotion(ctx context.Context, input model.PromotionInput) (model.Promotion, error) {
	return s.store.CreatePromotion(ctx, input)
}
func (s *POSService) UpdatePromotion(ctx context.Context, id int64, input model.PromotionInput) (model.Promotion, error) {
	return s.store.UpdatePromotion(ctx, id, input)
}
func (s *POSService) SetPromotionActive(ctx context.Context, id int64, active bool) (model.Promotion, error) {
	return s.store.SetPromotionActive(ctx, id, active)
}
func (s *POSService) DeletePromotion(ctx context.Context, id int64) error {
	return s.store.DeletePromotion(ctx, id)
}

func (s *POSService) Orders(ctx context.Context, q model.OrderQuery) ([]model.Order, error) {
	return s.store.ListOrders(ctx, q)
}
func (s *POSService) OrderByNo(ctx context.Context, orderNo string) (model.Order, error) {
	return s.store.GetOrderByNo(ctx, orderNo)
}
func (s *POSService) CreateOrder(ctx context.Context, input model.CreateOrderInput) (model.Order, error) {
	return s.store.CreateOrder(ctx, input)
}
func (s *POSService) CreateRefund(ctx context.Context, orderNo string, input model.CreateRefundInput) (model.Refund, error) {
	return s.store.CreateRefund(ctx, orderNo, input)
}
func (s *POSService) RefundsByOrderNo(ctx context.Context, orderNo string) ([]model.Refund, error) {
	return s.store.ListRefundsByOrderNo(ctx, orderNo)
}
func (s *POSService) DeleteOrderByNo(ctx context.Context, orderNo string) error {
	return s.store.DeleteOrderByNo(ctx, orderNo)
}

func (s *POSService) DailyStats(ctx context.Context, date time.Time) (model.DailyStats, error) {
	return s.store.DailyStats(ctx, date)
}
func (s *POSService) StatsOverview(ctx context.Context, from *time.Time, to *time.Time) (model.StatsOverview, error) {
	return s.store.StatsOverview(ctx, from, to)
}
func (s *POSService) StatsHourlySales(ctx context.Context, date time.Time) ([]model.StatsBucket, error) {
	return s.store.StatsHourlySales(ctx, date)
}
func (s *POSService) StatsTopProducts(ctx context.Context, from *time.Time, to *time.Time, limit int) ([]model.StatsBucket, error) {
	return s.store.StatsTopProducts(ctx, from, to, limit)
}
func (s *POSService) StatsPaymentBreakdown(ctx context.Context, from *time.Time, to *time.Time) ([]model.StatsBucket, error) {
	return s.store.StatsPaymentBreakdown(ctx, from, to)
}
func (s *POSService) StatsOrderTypeBreakdown(ctx context.Context, from *time.Time, to *time.Time) ([]model.StatsBucket, error) {
	return s.store.StatsOrderTypeBreakdown(ctx, from, to)
}

func (s *POSService) GetSetting(ctx context.Context, key string) (string, error) {
	return s.store.GetSetting(ctx, key)
}
func (s *POSService) SetSetting(ctx context.Context, key string, valueJSON string) error {
	return s.store.SetSetting(ctx, key, valueJSON)
}
func (s *POSService) Settings(ctx context.Context) (map[string]string, error) {
	return s.store.ListSettings(ctx)
}

func (s *POSService) SyncStatus(ctx context.Context) (model.SyncStatus, error) {
	return s.store.SyncStatus(ctx)
}
func (s *POSService) SyncErrors(ctx context.Context, limit int) ([]model.SyncErrorEvent, error) {
	return s.store.ListSyncErrors(ctx, limit)
}
func (s *POSService) AuditLogs(ctx context.Context, limit int) ([]model.AuditLog, error) {
	return s.store.ListAuditLogs(ctx, limit)
}
func (s *POSService) AppendAuditLog(ctx context.Context, actor, action, target, detail string) error {
	return s.store.AppendAuditLog(ctx, actor, action, target, detail)
}
