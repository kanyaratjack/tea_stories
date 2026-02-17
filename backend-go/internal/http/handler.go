package http

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"tea-store/backend-go/internal/model"
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
			"GET /api/products",
			"GET /api/orders",
			"POST /api/orders",
			"POST /api/orders/{orderNo}/refunds",
			"GET /api/stats/daily?date=YYYY-MM-DD",
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
	items, err := h.svc.Orders(r.Context())
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
	// Expecting: /api/orders/{orderNo}/refunds
	path := strings.TrimPrefix(r.URL.Path, "/api/orders/")
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] != "refunds" {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": "not_found"})
		return
	}
	orderNo := parts[0]
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]any{
			"error": "method_not_allowed",
		})
		return
	}

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
		if strings.Contains(err.Error(), "order_not_found") {
			writeJSON(w, http.StatusNotFound, map[string]any{
				"error": "order_not_found",
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
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
