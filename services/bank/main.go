package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/newrelic/go-agent/v3/newrelic"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/httpserver"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/mockdb"
)

func main() {
	httpserver.Run(httpserver.Config{
		ServiceName: "bank-svc",
		Addr:        httpserver.EnvOr("ADDR", ":8085"),
		ApdexT:      500 * time.Millisecond,
		Routes: func(r chi.Router) {
			r.Post("/api/bank/charge", charge)
		},
	})
}

func charge(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	txn := newrelic.FromContext(ctx)
	if txn != nil {
		defer txn.StartSegment("ProcessBankCharge").End()
		txn.AddAttribute("business.operation", "bank_charge")
	}

	var payload map[string]any
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}

	if txn != nil {
		seg := txn.StartSegment("RunFraudChecks")
		time.Sleep(15 * time.Millisecond)
		seg.End()
	} else {
		time.Sleep(15 * time.Millisecond)
	}

	var bankRef string
	_ = mockdb.Query(ctx, "INSERT", "INSERT INTO bank_ledger(merchant_tx,amount,status) VALUES($1,$2,'SETTLED')", 45*time.Millisecond, func() error {
		bankRef = fmt.Sprintf("BANK-%d", time.Now().UnixNano())
		return nil
	})

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"bank_ref": bankRef,
		"status":   "SETTLED",
	})
}
