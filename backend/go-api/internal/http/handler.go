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

func NewHandler(svc *service.POSService) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) Router() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/", h.handleRoot)
	mux.HandleFunc("/healthz", h.handleHealth)

	// v1 routes (recommended).
	mux.HandleFunc("/api/v1/products", h.handleProducts)
	mux.HandleFunc("/api/v1/orders", h.handleOrders)
	mux.HandleFunc("/api/v1/orders/", h.handleOrderActions)
	mux.HandleFunc("/api/v1/stats/daily", h.handleDailyStats)

	// legacy routes (backward compatible).
	mux.HandleFunc("/api/products", h.handleProducts)
	mux.HandleFunc("/api/orders", h.handleOrders)
	mux.HandleFunc("/api/orders/", h.handleOrderActions)
	mux.HandleFunc("/api/stats/daily", h.handleDailyStats)
	return withJSON(mux)
}

func (h *Handler) handleRoot(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"name": "tea-store backend-go",
		"endpoints": []string{
			"GET /healthz",
			"GET /api/v1/products",
			"GET /api/v1/orders",
			"GET /api/v1/orders/{orderNo}",
			"GET /api/v1/orders/{orderNo}/refunds",
			"POST /api/v1/orders",
			"POST /api/v1/orders/{orderNo}/refunds",
			"DELETE /api/v1/orders/{orderNo}",
			"GET /api/v1/stats/daily?date=YYYY-MM-DD",
		},
	})
}

func (h *Handler) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, h.svc.Health(context.Background()))
}

func (h *Handler) handleProducts(w http.ResponseWriter, r *http.Request) {
	items, err := h.svc.Products(r.Context())
	if err != nil {
		log.Printf("list products failed: %v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": "failed_to_list_products",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleOrders(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		h.handleListOrders(w, r)
	case http.MethodPost:
		h.handleCreateOrder(w, r)
	default:
		writeJSON(w, http.StatusMethodNotAllowed, map[string]any{
			"error": "method_not_allowed",
		})
	}
}

func (h *Handler) handleListOrders(w http.ResponseWriter, r *http.Request) {
	query, err := parseOrderQuery(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	items, err := h.svc.Orders(r.Context(), query)
	if err != nil {
		log.Printf("list orders failed: %v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": "failed_to_list_orders",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleCreateOrder(w http.ResponseWriter, r *http.Request) {
	var input model.CreateOrderInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": "invalid_json",
		})
		return
	}
	if input.Total <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": "invalid_total",
		})
		return
	}
	if strings.TrimSpace(input.OrderType) == "" {
		input.OrderType = "in_store"
	}
	order, err := h.svc.CreateOrder(r.Context(), input)
	if err != nil {
		log.Printf("create order failed: %v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": "failed_to_create_order",
		})
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
			writeJSON(w, http.StatusMethodNotAllowed, map[string]any{
				"error": "method_not_allowed",
			})
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
		return
	case parts[1] == "refunds" && r.Method == http.MethodPost:
		h.handleCreateRefund(w, r, orderNo)
		return
	default:
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "not_found"})
	}
}

func (h *Handler) handleCreateRefund(w http.ResponseWriter, r *http.Request, orderNo string) {
	var input model.CreateRefundInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": "invalid_json",
		})
		return
	}
	if input.Amount <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": "invalid_amount",
		})
		return
	}

	refund, err := h.svc.CreateRefund(r.Context(), orderNo, input)
	if err != nil {
		log.Printf("create refund failed: %v", err)
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{
				"error": "order_not_found",
			})
			return
		}
		if errors.Is(err, repo.ErrInvalidRefundAmount) {
			writeJSON(w, http.StatusConflict, map[string]any{
				"error": "refund_amount_exceeds_remaining",
			})
			return
		}
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": "failed_to_create_refund",
		})
		return
	}
	writeJSON(w, http.StatusCreated, refund)
}

func (h *Handler) handleListRefundsByOrderNo(w http.ResponseWriter, r *http.Request, orderNo string) {
	_, err := h.svc.OrderByNo(r.Context(), orderNo)
	if err != nil {
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{
				"error": "order_not_found",
			})
			return
		}
		log.Printf("get order for refunds failed: %v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": "failed_to_get_refunds",
		})
		return
	}
	items, err := h.svc.RefundsByOrderNo(r.Context(), orderNo)
	if err != nil {
		log.Printf("list refunds failed: %v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": "failed_to_get_refunds",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) handleGetOrderByNo(w http.ResponseWriter, r *http.Request, orderNo string) {
	order, err := h.svc.OrderByNo(r.Context(), orderNo)
	if err != nil {
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{
				"error": "order_not_found",
			})
			return
		}
		log.Printf("get order failed: %v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": "failed_to_get_order",
		})
		return
	}
	writeJSON(w, http.StatusOK, order)
}

func (h *Handler) handleDeleteOrderByNo(w http.ResponseWriter, r *http.Request, orderNo string) {
	if err := h.svc.DeleteOrderByNo(r.Context(), orderNo); err != nil {
		if errors.Is(err, repo.ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]any{
				"error": "order_not_found",
			})
			return
		}
		log.Printf("delete order failed: %v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": "failed_to_delete_order",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok": true,
	})
}

func orderActionPath(rawPath string) string {
	if strings.HasPrefix(rawPath, "/api/v1/orders/") {
		return strings.TrimPrefix(rawPath, "/api/v1/orders/")
	}
	return strings.TrimPrefix(rawPath, "/api/orders/")
}

func parseOrderQuery(r *http.Request) (model.OrderQuery, error) {
	q := model.OrderQuery{
		Keyword:   strings.TrimSpace(r.URL.Query().Get("keyword")),
		Status:    strings.TrimSpace(r.URL.Query().Get("status")),
		OrderType: strings.TrimSpace(r.URL.Query().Get("order_type")),
		Channel:   strings.TrimSpace(r.URL.Query().Get("channel")),
		Limit:     200,
		Offset:    0,
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

func (h *Handler) handleDailyStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]any{
			"error": "method_not_allowed",
		})
		return
	}
	rawDate := strings.TrimSpace(r.URL.Query().Get("date"))
	target := time.Now()
	if rawDate != "" {
		parsed, err := time.Parse("2006-01-02", rawDate)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{
				"error": "invalid_date",
			})
			return
		}
		target = parsed
	}
	stats, err := h.svc.DailyStats(r.Context(), target)
	if err != nil {
		log.Printf("daily stats failed: %v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": "failed_to_get_stats",
		})
		return
	}
	writeJSON(w, http.StatusOK, stats)
}

func withJSON(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type,Authorization")
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
