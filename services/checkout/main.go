package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/newrelic/go-agent/v3/newrelic"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/applog"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/httpserver"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/mockdb"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/nhttp"
)

type CheckoutRequest struct {
	FilmID        string   `json:"film_id"`
	ScheduleID    string   `json:"schedule_id"`
	Seats         []string `json:"seats"`
	Amount        int      `json:"amount"`
	Customer      string   `json:"customer"`
	PaymentMethod string   `json:"payment_method"`
}

type CheckoutResponse struct {
	TransactionID string `json:"transaction_id"`
	Status        string `json:"status"`
	PaymentRef    string `json:"payment_ref"`
	PaymentMethod string `json:"payment_method"`
	Amount        int    `json:"amount"`
	TraceID       string `json:"trace_id,omitempty"`
}

func main() {
	httpserver.Run(httpserver.Config{
		ServiceName: "checkout-svc",
		Addr:        httpserver.EnvOr("ADDR", ":8083"),
		ApdexT:      500 * time.Millisecond,
		Routes: func(r chi.Router) {
			r.Post("/api/checkout", createCheckout)
			r.Get("/api/checkout/{id}", getCheckout)
		},
	})
}

var store = map[string]CheckoutResponse{}

func createCheckout(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	txn := newrelic.FromContext(ctx)
	if txn != nil {
		defer txn.StartSegment("CreateCheckout").End()
		txn.AddAttribute("business.operation", "checkout")
	}

	var req CheckoutRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		applog.Warn(ctx, "checkout_invalid_json", "error", err.Error())
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}

	if len(req.Seats) == 0 || req.Amount <= 0 {
		applog.Warn(ctx, "checkout_validation_failed", "customer.id", req.Customer, "seat.count", len(req.Seats))
		http.Error(w, `{"error":"seats and amount required"}`, http.StatusBadRequest)
		return
	}
	if txn != nil {
		seg := txn.StartSegment("ValidateSeatsAndAmount")
		txn.AddAttribute("seat.count", len(req.Seats))
		txn.AddAttribute("amount", req.Amount)
		seg.End()
	}

	txID := fmt.Sprintf("TX-%d", time.Now().UnixNano())
	method := req.PaymentMethod
	if method == "" {
		method = "gopay"
	}
	customer := req.Customer
	if customer == "" {
		customer = "lab-student"
	}

	if txn != nil {
		txn.AddAttribute("transaction.id", txID)
		txn.AddAttribute("customer.id", customer)
		txn.AddAttribute("payment.method", method)
		txn.AddAttribute("film.id", req.FilmID)
		txn.AddAttribute("schedule.id", req.ScheduleID)
	}
	applog.Info(ctx, "checkout_started",
		"transaction.id", txID,
		"customer.id", customer,
		"payment.method", method,
		"amount", req.Amount,
		"film.id", req.FilmID,
		"seat.count", len(req.Seats),
	)

	_ = mockdb.Query(ctx, "INSERT", "INSERT INTO transactions(id,film_id,schedule_id,amount) VALUES($1,$2,$3,$4)", 35*time.Millisecond, func() error {
		return nil
	})

	payRef, err := callPayment(ctx, txID, req.Amount, method, customer)
	if err != nil {
		if txn != nil {
			txn.NoticeError(err)
		}
		applog.Error(ctx, "checkout_payment_failed",
			"transaction.id", txID,
			"customer.id", customer,
			"error", err.Error(),
		)
		http.Error(w, fmt.Sprintf(`{"error":%q}`, err.Error()), http.StatusBadGateway)
		return
	}

	traceID := ""
	if txn != nil {
		traceID = txn.GetTraceMetadata().TraceID
	}
	resp := CheckoutResponse{
		TransactionID: txID,
		Status:        "PAID",
		PaymentRef:    payRef,
		PaymentMethod: method,
		Amount:        req.Amount,
		TraceID:       traceID,
	}
	_ = mockdb.Query(ctx, "UPDATE", "UPDATE transactions SET status='PAID', payment_ref=$1 WHERE id=$2", 20*time.Millisecond, func() error {
		store[txID] = resp
		return nil
	})

	applog.Info(ctx, "checkout_completed",
		"transaction.id", txID,
		"customer.id", customer,
		"payment.ref", payRef,
		"payment.method", method,
		"amount", req.Amount,
		"status", "PAID",
	)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

func getCheckout(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	resp, ok := store[id]
	if !ok {
		applog.Warn(r.Context(), "checkout_not_found", "transaction.id", id)
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func callPayment(ctx context.Context, txID string, amount int, method, customer string) (string, error) {
	base := httpserver.EnvOr("PAYMENT_URL", "http://payment-svc:8084")
	body, _ := json.Marshal(map[string]any{
		"transaction_id": txID,
		"amount":         amount,
		"method":         method,
		"customer":       customer,
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, base+"/api/payments", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := nhttp.Client(20 * time.Second).Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(res.Body)
	if res.StatusCode >= 400 {
		return "", fmt.Errorf("payment failed: %s", string(raw))
	}
	var parsed struct {
		PaymentRef string `json:"payment_ref"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return "", err
	}
	return parsed.PaymentRef, nil
}
