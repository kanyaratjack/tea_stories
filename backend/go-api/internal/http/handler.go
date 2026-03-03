package http

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"tea-store/backend-go/internal/model"
	"tea-store/backend-go/internal/repo"
	"tea-store/backend-go/internal/service"
)

type Handler struct {
	svc *service.POSService
}

func NewHandler(svc *service.POSService) *Handler { return &Handler{svc: svc} }

func (h *Handler) Router() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/", h.handleRoot)
	mux.HandleFunc("/healthz", h.handleHealth)

	mux.HandleFunc("/api/v1/products", h.handleProducts)
	mux.HandleFunc("/api/v1/products/", h.handleProductActions)
	mux.HandleFunc("/api/v1/categories", h.handleCategories)
	mux.HandleFunc("/api/v1/categories/", h.handleCategoryActions)
	mux.HandleFunc("/api/v1/spec-groups", h.handleSpecGroups)
	mux.HandleFunc("/api/v1/spec-groups/", h.handleSpecGroupActions)
	mux.HandleFunc("/api/v1/spec-items", h.handleSpecItems)
	mux.HandleFunc("/api/v1/spec-items/", h.handleSpecItemActions)
	mux.HandleFunc("/api/v1/promotions", h.handlePromotions)
	mux.HandleFunc("/api/v1/promotions/", h.handlePromotionActions)

	mux.HandleFunc("/api/v1/orders", h.handleOrders)
	mux.HandleFunc("/api/v1/orders/", h.handleOrderActions)

	mux.HandleFunc("/api/v1/stats/daily", h.handleDailyStats)
	mux.HandleFunc("/api/v1/stats/overview", h.handleStatsOverview)
	mux.HandleFunc("/api/v1/stats/hourly-sales", h.handleStatsHourlySales)
	mux.HandleFunc("/api/v1/stats/top-products", h.handleStatsTopProducts)
	mux.HandleFunc("/api/v1/stats/payment-breakdown", h.handleStatsPaymentBreakdown)
	mux.HandleFunc("/api/v1/stats/order-type-breakdown", h.handleStatsOrderTypeBreakdown)

	mux.HandleFunc("/api/v1/settings", h.handleSettings)
	mux.HandleFunc("/api/v1/settings/", h.handleSettingByKey)
	mux.HandleFunc("/api/v1/sync/status", h.handleSyncStatus)
	mux.HandleFunc("/api/v1/sync/errors", h.handleSyncErrors)
	mux.HandleFunc("/api/v1/sync/retry", h.handleSyncRetry)
	mux.HandleFunc("/api/v1/audit-logs", h.handleAuditLogs)

	// legacy
	mux.HandleFunc("/api/products", h.handleProducts)
	mux.HandleFunc("/api/orders", h.handleOrders)
	mux.HandleFunc("/api/orders/", h.handleOrderActions)
	mux.HandleFunc("/api/stats/daily", h.handleDailyStats)
	return withJSON(mux)
}

func (h *Handler) handleRoot(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"name":    "tea-store backend-go",
		"version": "v1",
	})
}

func (h *Handler) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, h.svc.Health(context.Background()))
}

func (h *Handler) handleProducts(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		items, err := h.svc.Products(r.Context())
		if err != nil {
			serverErr(w, "failed_to_list_products", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"items": items})
	case http.MethodPost:
		var input model.ProductInput
		if !decodeJSON(w, r, &input) {
			return
		}
		if strings.TrimSpace(input.Name) == "" || input.Price < 0 {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_product_input"})
			return
		}
		item, err := h.svc.CreateProduct(r.Context(), input)
		if err != nil {
			serverErr(w, "failed_to_create_product", err)
			return
		}
		writeJSON(w, http.StatusCreated, item)
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handleProductActions(w http.ResponseWriter, r *http.Request) {
	path := strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/products/"), "/")
	parts := strings.Split(path, "/")
	if len(parts) == 0 || parts[0] == "" {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "not_found"})
		return
	}
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_id"})
		return
	}
	if len(parts) == 1 {
		switch r.Method {
		case http.MethodGet:
			item, err := h.svc.ProductByID(r.Context(), id)
			h.writeSingleWithNotFound(w, item, err, "product_not_found", "failed_to_get_product")
		case http.MethodPut:
			var input model.ProductInput
			if !decodeJSON(w, r, &input) {
				return
			}
			item, err := h.svc.UpdateProduct(r.Context(), id, input)
			h.writeSingleWithNotFound(w, item, err, "product_not_found", "failed_to_update_product")
		case http.MethodDelete:
			err := h.svc.DeleteProduct(r.Context(), id)
			if errors.Is(err, repo.ErrNotFound) {
				writeJSON(w, http.StatusNotFound, map[string]any{"error": "product_not_found"})
				return
			}
			if err != nil {
				serverErr(w, "failed_to_delete_product", err)
				return
			}
			_ = h.svc.AppendAuditLog(r.Context(), actorFromReq(r), "delete_product", strconv.FormatInt(id, 10), "")
			writeJSON(w, http.StatusOK, map[string]any{"ok": true})
		default:
			methodNotAllowed(w)
		}
		return
	}
	if len(parts) == 2 && parts[1] == "status" && r.Method == http.MethodPatch {
		var body struct {
			Active bool `json:"active"`
		}
		if !decodeJSON(w, r, &body) {
			return
		}
		item, err := h.svc.SetProductActive(r.Context(), id, body.Active)
		h.writeSingleWithNotFound(w, item, err, "product_not_found", "failed_to_update_product_status")
		return
	}
	writeJSON(w, http.StatusNotFound, map[string]any{"error": "not_found"})
}

func (h *Handler) handleCategories(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		items, err := h.svc.Categories(r.Context())
		if err != nil {
			serverErr(w, "failed_to_list_categories", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"items": items})
	case http.MethodPost:
		var input model.CategoryInput
		if !decodeJSON(w, r, &input) {
			return
		}
		item, err := h.svc.CreateCategory(r.Context(), input)
		if err != nil {
			serverErr(w, "failed_to_create_category", err)
			return
		}
		writeJSON(w, http.StatusCreated, item)
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handleCategoryActions(w http.ResponseWriter, r *http.Request) {
	id, ok := parseTailID(w, r.URL.Path, "/api/v1/categories/")
	if !ok {
		return
	}
	switch r.Method {
	case http.MethodPut:
		var input model.CategoryInput
		if !decodeJSON(w, r, &input) {
			return
		}
		item, err := h.svc.UpdateCategory(r.Context(), id, input)
		h.writeSingleWithNotFound(w, item, err, "category_not_found", "failed_to_update_category")
	case http.MethodDelete:
		err := h.svc.DeleteCategory(r.Context(), id)
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "category_not_found"})
			return
		}
		if err != nil {
			serverErr(w, "failed_to_delete_category", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handleSpecGroups(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		items, err := h.svc.SpecGroups(r.Context())
		if err != nil {
			serverErr(w, "failed_to_list_spec_groups", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"items": items})
	case http.MethodPost:
		var input model.SpecGroupInput
		if !decodeJSON(w, r, &input) {
			return
		}
		item, err := h.svc.CreateSpecGroup(r.Context(), input)
		if err != nil {
			serverErr(w, "failed_to_create_spec_group", err)
			return
		}
		writeJSON(w, http.StatusCreated, item)
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handleSpecGroupActions(w http.ResponseWriter, r *http.Request) {
	id, ok := parseTailID(w, r.URL.Path, "/api/v1/spec-groups/")
	if !ok {
		return
	}
	switch r.Method {
	case http.MethodPut:
		var input model.SpecGroupInput
		if !decodeJSON(w, r, &input) {
			return
		}
		item, err := h.svc.UpdateSpecGroup(r.Context(), id, input)
		h.writeSingleWithNotFound(w, item, err, "spec_group_not_found", "failed_to_update_spec_group")
	case http.MethodDelete:
		err := h.svc.DeleteSpecGroup(r.Context(), id)
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "spec_group_not_found"})
			return
		}
		if err != nil {
			serverErr(w, "failed_to_delete_spec_group", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handleSpecItems(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		gid, _ := strconv.ParseInt(strings.TrimSpace(r.URL.Query().Get("group_id")), 10, 64)
		items, err := h.svc.SpecItems(r.Context(), gid)
		if err != nil {
			serverErr(w, "failed_to_list_spec_items", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"items": items})
	case http.MethodPost:
		var input model.SpecItemInput
		if !decodeJSON(w, r, &input) {
			return
		}
		item, err := h.svc.CreateSpecItem(r.Context(), input)
		if err != nil {
			serverErr(w, "failed_to_create_spec_item", err)
			return
		}
		writeJSON(w, http.StatusCreated, item)
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handleSpecItemActions(w http.ResponseWriter, r *http.Request) {
	id, ok := parseTailID(w, r.URL.Path, "/api/v1/spec-items/")
	if !ok {
		return
	}
	switch r.Method {
	case http.MethodPut:
		var input model.SpecItemInput
		if !decodeJSON(w, r, &input) {
			return
		}
		item, err := h.svc.UpdateSpecItem(r.Context(), id, input)
		h.writeSingleWithNotFound(w, item, err, "spec_item_not_found", "failed_to_update_spec_item")
	case http.MethodDelete:
		err := h.svc.DeleteSpecItem(r.Context(), id)
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "spec_item_not_found"})
			return
		}
		if err != nil {
			serverErr(w, "failed_to_delete_spec_item", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handlePromotions(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		items, err := h.svc.Promotions(r.Context())
		if err != nil {
			serverErr(w, "failed_to_list_promotions", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"items": items})
	case http.MethodPost:
		var input model.PromotionInput
		if !decodeJSON(w, r, &input) {
			return
		}
		item, err := h.svc.CreatePromotion(r.Context(), input)
		if err != nil {
			serverErr(w, "failed_to_create_promotion", err)
			return
		}
		writeJSON(w, http.StatusCreated, item)
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handlePromotionActions(w http.ResponseWriter, r *http.Request) {
	path := strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/promotions/"), "/")
	parts := strings.Split(path, "/")
	if len(parts) == 0 || parts[0] == "" {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "not_found"})
		return
	}
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_id"})
		return
	}
	if len(parts) == 1 {
		switch r.Method {
		case http.MethodPut:
			var input model.PromotionInput
			if !decodeJSON(w, r, &input) {
				return
			}
			item, err := h.svc.UpdatePromotion(r.Context(), id, input)
			h.writeSingleWithNotFound(w, item, err, "promotion_not_found", "failed_to_update_promotion")
		case http.MethodDelete:
			err := h.svc.DeletePromotion(r.Context(), id)
			if errors.Is(err, repo.ErrNotFound) {
				writeJSON(w, http.StatusNotFound, map[string]any{"error": "promotion_not_found"})
				return
			}
			if err != nil {
				serverErr(w, "failed_to_delete_promotion", err)
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{"ok": true})
		default:
			methodNotAllowed(w)
		}
		return
	}
	if len(parts) == 2 && parts[1] == "status" && r.Method == http.MethodPatch {
		var body struct {
			Active bool `json:"active"`
		}
		if !decodeJSON(w, r, &body) {
			return
		}
		item, err := h.svc.SetPromotionActive(r.Context(), id, body.Active)
		h.writeSingleWithNotFound(w, item, err, "promotion_not_found", "failed_to_update_promotion_status")
		return
	}
	writeJSON(w, http.StatusNotFound, map[string]any{"error": "not_found"})
}

func (h *Handler) handleOrders(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		h.handleListOrders(w, r)
	case http.MethodPost:
		h.handleCreateOrder(w, r)
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handleListOrders(w http.ResponseWriter, r *http.Request) {
	query, err := parseOrderQuery(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	items, err := h.svc.Orders(r.Context(), query)
	if err != nil {
		serverErr(w, "failed_to_list_orders", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleCreateOrder(w http.ResponseWriter, r *http.Request) {
	var input model.CreateOrderInput
	if !decodeJSON(w, r, &input) {
		return
	}
	if input.Total <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_total"})
		return
	}
	if strings.TrimSpace(input.OrderType) == "" {
		input.OrderType = "in_store"
	}
	order, err := h.svc.CreateOrder(r.Context(), input)
	if err != nil {
		serverErr(w, "failed_to_create_order", err)
		return
	}
	writeJSON(w, http.StatusCreated, order)
}

func (h *Handler) handleOrderActions(w http.ResponseWriter, r *http.Request) {
	path := orderActionPath(r.URL.Path)
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) == 1 && parts[0] != "" {
		switch r.Method {
		case http.MethodGet:
			h.handleGetOrderByNo(w, r, parts[0])
		case http.MethodDelete:
			h.handleDeleteOrderByNo(w, r, parts[0])
		default:
			methodNotAllowed(w)
		}
		return
	}
	if len(parts) != 2 || parts[0] == "" {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "not_found"})
		return
	}
	orderNo := parts[0]
	switch {
	case parts[1] == "refunds" && r.Method == http.MethodGet:
		h.handleListRefundsByOrderNo(w, r, orderNo)
	case parts[1] == "refunds" && r.Method == http.MethodPost:
		h.handleCreateRefund(w, r, orderNo)
	case parts[1] == "reprint-receipt" && r.Method == http.MethodPost:
		h.handleReprint(w, r, orderNo, "receipt")
	case parts[1] == "reprint-label" && r.Method == http.MethodPost:
		h.handleReprint(w, r, orderNo, "label")
	default:
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "not_found"})
	}
}

func (h *Handler) handleCreateRefund(w http.ResponseWriter, r *http.Request, orderNo string) {
	var input model.CreateRefundInput
	if !decodeJSON(w, r, &input) {
		return
	}
	if input.Amount <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_amount"})
		return
	}
	refund, err := h.svc.CreateRefund(r.Context(), orderNo, input)
	if err != nil {
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "order_not_found"})
			return
		}
		if errors.Is(err, repo.ErrInvalidRefundAmount) {
			writeJSON(w, http.StatusConflict, map[string]any{"error": "refund_amount_exceeds_remaining"})
			return
		}
		serverErr(w, "failed_to_create_refund", err)
		return
	}
	_ = h.svc.AppendAuditLog(r.Context(), actorFromReq(r), "create_refund", orderNo, "")
	writeJSON(w, http.StatusCreated, refund)
}

func (h *Handler) handleListRefundsByOrderNo(w http.ResponseWriter, r *http.Request, orderNo string) {
	_, err := h.svc.OrderByNo(r.Context(), orderNo)
	if err != nil {
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "order_not_found"})
			return
		}
		serverErr(w, "failed_to_get_refunds", err)
		return
	}
	items, err := h.svc.RefundsByOrderNo(r.Context(), orderNo)
	if err != nil {
		serverErr(w, "failed_to_get_refunds", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleGetOrderByNo(w http.ResponseWriter, r *http.Request, orderNo string) {
	order, err := h.svc.OrderByNo(r.Context(), orderNo)
	if err != nil {
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "order_not_found"})
			return
		}
		serverErr(w, "failed_to_get_order", err)
		return
	}
	writeJSON(w, http.StatusOK, order)
}

func (h *Handler) handleDeleteOrderByNo(w http.ResponseWriter, r *http.Request, orderNo string) {
	if err := h.svc.DeleteOrderByNo(r.Context(), orderNo); err != nil {
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "order_not_found"})
			return
		}
		serverErr(w, "failed_to_delete_order", err)
		return
	}
	_ = h.svc.AppendAuditLog(r.Context(), actorFromReq(r), "delete_order", orderNo, "")
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *Handler) handleReprint(w http.ResponseWriter, r *http.Request, orderNo string, t string) {
	_, err := h.svc.OrderByNo(r.Context(), orderNo)
	if err != nil {
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "order_not_found"})
			return
		}
		serverErr(w, "failed_to_get_order", err)
		return
	}
	_ = h.svc.AppendAuditLog(r.Context(), actorFromReq(r), "reprint_"+t, orderNo, "")
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *Handler) handleDailyStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}
	rawDate := strings.TrimSpace(r.URL.Query().Get("date"))
	target := time.Now()
	if rawDate != "" {
		parsed, err := time.Parse("2006-01-02", rawDate)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_date"})
			return
		}
		target = parsed
	}
	stats, err := h.svc.DailyStats(r.Context(), target)
	if err != nil {
		serverErr(w, "failed_to_get_stats", err)
		return
	}
	writeJSON(w, http.StatusOK, stats)
}

func (h *Handler) handleStatsOverview(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}
	from, to, err := parseTimeRange(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	stats, err := h.svc.StatsOverview(r.Context(), from, to)
	if err != nil {
		serverErr(w, "failed_to_get_stats", err)
		return
	}
	writeJSON(w, http.StatusOK, stats)
}

func (h *Handler) handleStatsHourlySales(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}
	rawDate := strings.TrimSpace(r.URL.Query().Get("date"))
	target := time.Now()
	if rawDate != "" {
		parsed, err := time.Parse("2006-01-02", rawDate)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_date"})
			return
		}
		target = parsed
	}
	items, err := h.svc.StatsHourlySales(r.Context(), target)
	if err != nil {
		serverErr(w, "failed_to_get_stats", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleStatsTopProducts(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}
	from, to, err := parseTimeRange(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	limit := 10
	if v := strings.TrimSpace(r.URL.Query().Get("limit")); v != "" {
		n, e := strconv.Atoi(v)
		if e != nil || n <= 0 {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_limit"})
			return
		}
		limit = n
	}
	items, err := h.svc.StatsTopProducts(r.Context(), from, to, limit)
	if err != nil {
		serverErr(w, "failed_to_get_stats", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleStatsPaymentBreakdown(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}
	from, to, err := parseTimeRange(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	items, err := h.svc.StatsPaymentBreakdown(r.Context(), from, to)
	if err != nil {
		serverErr(w, "failed_to_get_stats", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleStatsOrderTypeBreakdown(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}
	from, to, err := parseTimeRange(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	items, err := h.svc.StatsOrderTypeBreakdown(r.Context(), from, to)
	if err != nil {
		serverErr(w, "failed_to_get_stats", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleSettings(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		items, err := h.svc.Settings(r.Context())
		if err != nil {
			serverErr(w, "failed_to_get_settings", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"items": items})
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handleSettingByKey(w http.ResponseWriter, r *http.Request) {
	key := strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/settings/"), "/")
	if key == "" {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "not_found"})
		return
	}
	switch r.Method {
	case http.MethodGet:
		value, err := h.svc.GetSetting(r.Context(), key)
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{"error": "setting_not_found"})
			return
		}
		if err != nil {
			serverErr(w, "failed_to_get_setting", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"key": key, "value_json": value})
	case http.MethodPut:
		var body struct {
			ValueJSON string `json:"value_json"`
		}
		if !decodeJSON(w, r, &body) {
			return
		}
		if err := h.svc.SetSetting(r.Context(), key, body.ValueJSON); err != nil {
			serverErr(w, "failed_to_set_setting", err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		methodNotAllowed(w)
	}
}

func (h *Handler) handleSyncStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}
	status, err := h.svc.SyncStatus(r.Context())
	if err != nil {
		serverErr(w, "failed_to_get_sync_status", err)
		return
	}
	writeJSON(w, http.StatusOK, status)
}

func (h *Handler) handleSyncRetry(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	_ = h.svc.AppendAuditLog(r.Context(), actorFromReq(r), "sync_retry", "sync_queue", "manual trigger")
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *Handler) handleSyncErrors(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}
	limit := 100
	if v := strings.TrimSpace(r.URL.Query().Get("limit")); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_limit"})
			return
		}
		limit = n
	}
	items, err := h.svc.SyncErrors(r.Context(), limit)
	if err != nil {
		serverErr(w, "failed_to_get_sync_errors", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleAuditLogs(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}
	limit := 100
	if v := strings.TrimSpace(r.URL.Query().Get("limit")); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_limit"})
			return
		}
		limit = n
	}
	items, err := h.svc.AuditLogs(r.Context(), limit)
	if err != nil {
		serverErr(w, "failed_to_get_audit_logs", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func parseOrderQuery(r *http.Request) (model.OrderQuery, error) {
	q := model.OrderQuery{
		Keyword:       strings.TrimSpace(r.URL.Query().Get("keyword")),
		Status:        strings.TrimSpace(r.URL.Query().Get("status")),
		OrderType:     strings.TrimSpace(r.URL.Query().Get("order_type")),
		Channel:       strings.TrimSpace(r.URL.Query().Get("channel")),
		PaymentMethod: strings.TrimSpace(r.URL.Query().Get("payment_method")),
		Limit:         200,
		Offset:        0,
	}
	if v := strings.TrimSpace(r.URL.Query().Get("page_size")); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			return model.OrderQuery{}, errors.New("invalid_page_size")
		}
		q.Limit = n
	}
	if v := strings.TrimSpace(r.URL.Query().Get("page")); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			return model.OrderQuery{}, errors.New("invalid_page")
		}
		q.Offset = (n - 1) * q.Limit
	}
	if v := strings.TrimSpace(r.URL.Query().Get("from")); v != "" {
		ts, err := time.Parse(time.RFC3339, v)
		if err != nil {
			return model.OrderQuery{}, errors.New("invalid_from")
		}
		q.DateFrom = &ts
	}
	if v := strings.TrimSpace(r.URL.Query().Get("to")); v != "" {
		ts, err := time.Parse(time.RFC3339, v)
		if err != nil {
			return model.OrderQuery{}, errors.New("invalid_to")
		}
		q.DateTo = &ts
	}
	return q, nil
}

func parseTimeRange(r *http.Request) (*time.Time, *time.Time, error) {
	var from *time.Time
	var to *time.Time
	if v := strings.TrimSpace(r.URL.Query().Get("from")); v != "" {
		ts, err := time.Parse(time.RFC3339, v)
		if err != nil {
			return nil, nil, errors.New("invalid_from")
		}
		from = &ts
	}
	if v := strings.TrimSpace(r.URL.Query().Get("to")); v != "" {
		ts, err := time.Parse(time.RFC3339, v)
		if err != nil {
			return nil, nil, errors.New("invalid_to")
		}
		to = &ts
	}
	return from, to, nil
}

func parseTailID(w http.ResponseWriter, path string, prefix string) (int64, bool) {
	idStr := strings.Trim(strings.TrimPrefix(path, prefix), "/")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_id"})
		return 0, false
	}
	return id, true
}

func decodeJSON(w http.ResponseWriter, r *http.Request, out any) bool {
	if err := json.NewDecoder(r.Body).Decode(out); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid_json"})
		return false
	}
	return true
}

func (h *Handler) writeSingleWithNotFound(w http.ResponseWriter, item any, err error, notFoundCode string, failCode string) {
	if errors.Is(err, repo.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": notFoundCode})
		return
	}
	if err != nil {
		serverErr(w, failCode, err)
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func methodNotAllowed(w http.ResponseWriter) {
	writeJSON(w, http.StatusMethodNotAllowed, map[string]any{"error": "method_not_allowed"})
}

func serverErr(w http.ResponseWriter, code string, err error) {
	log.Printf("%s: %v", code, err)
	writeJSON(w, http.StatusInternalServerError, map[string]any{"error": code})
}

func actorFromReq(r *http.Request) string {
	if v := strings.TrimSpace(r.Header.Get("X-Actor")); v != "" {
		return v
	}
	return "system"
}

func orderActionPath(rawPath string) string {
	if strings.HasPrefix(rawPath, "/api/v1/orders/") {
		return strings.TrimPrefix(rawPath, "/api/v1/orders/")
	}
	return strings.TrimPrefix(rawPath, "/api/orders/")
}

func withJSON(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type,Authorization,X-Actor")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
