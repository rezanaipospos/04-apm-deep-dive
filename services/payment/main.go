package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/newrelic/go-agent/v3/newrelic"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/applog"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/httpserver"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/mockdb"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/nhttp"
)

type PaymentRequest struct {
	TransactionID string `json:"transaction_id"`
	Amount        int    `json:"amount"`
	Method        string `json:"method"`
	Customer      string `json:"customer"`
}

type PaymentResponse struct {
	PaymentRef string `json:"payment_ref"`
	Status     string `json:"status"`
	BankRef    string `json:"bank_ref"`
	Method     string `json:"method"`
}

type WalletMethod struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Balance     *int   `json:"balance,omitempty"`
}

type WalletResponse struct {
	Customer string         `json:"customer"`
	Methods  []WalletMethod `json:"methods"`
}

var (
	walletMu      sync.Mutex
	gopayBalances = map[string]int{
		"lab-student": 500_000,
	}
)

func main() {
	httpserver.Run(httpserver.Config{
		ServiceName: "payment-svc",
		Addr:        httpserver.EnvOr("ADDR", ":8084"),
		ApdexT:      500 * time.Millisecond,
		Routes: func(r chi.Router) {
			r.Get("/api/wallet", getWallet)
			r.Post("/api/payments", createPayment)
		},
	})
}

func getWallet(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	txn := newrelic.FromContext(ctx)
	if txn != nil {
		defer txn.StartSegment("LoadWalletMethods").End()
		txn.AddAttribute("business.operation", "load_wallet")
	}

	customer := strings.TrimSpace(r.URL.Query().Get("customer"))
	if customer == "" {
		customer = "lab-student"
	}
	if txn != nil {
		txn.AddAttribute("customer.id", customer)
	}

	var balance int
	err := mockdb.Query(ctx, "SELECT", "SELECT balance FROM wallets WHERE customer_id=$1", 25*time.Millisecond, func() error {
		walletMu.Lock()
		defer walletMu.Unlock()
		b, ok := gopayBalances[customer]
		if !ok {
			b = 500_000
			gopayBalances[customer] = b
		}
		balance = b
		return nil
	})
	if err != nil {
		if txn != nil {
			txn.NoticeError(err)
		}
		applog.Error(ctx, "wallet_load_failed", "customer.id", customer, "error", err.Error())
		http.Error(w, `{"error":"failed to load wallet balance"}`, http.StatusInternalServerError)
		return
	}

	if txn != nil {
		defer txn.StartSegment("BuildPaymentMethodCatalog").End()
	}
	resp := WalletResponse{
		Customer: customer,
		Methods: []WalletMethod{
			{
				ID:          "gopay",
				Name:        "GoPay",
				Description: "Bayar dengan saldo e-wallet",
				Balance:     &balance,
			},
			{
				ID:          "qris",
				Name:        "QRIS",
				Description: "Scan QR lalu tunggu konfirmasi pembayaran",
			},
		},
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func createPayment(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	txn := newrelic.FromContext(ctx)
	if txn != nil {
		defer txn.StartSegment("AuthorizePayment").End()
		txn.AddAttribute("business.operation", "authorize_payment")
	}

	var req PaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}
	method := strings.ToLower(strings.TrimSpace(req.Method))
	if method == "" {
		method = "gopay"
	}
	if method != "gopay" && method != "qris" {
		http.Error(w, `{"error":"unsupported payment method"}`, http.StatusBadRequest)
		return
	}
	if req.Customer == "" {
		req.Customer = "lab-student"
	}
	if txn != nil {
		txn.AddAttribute("transaction.id", req.TransactionID)
		txn.AddAttribute("amount", req.Amount)
		txn.AddAttribute("payment.method", method)
		txn.AddAttribute("customer.id", req.Customer)
	}
	applog.Info(ctx, "payment_authorize_started",
		"transaction.id", req.TransactionID,
		"customer.id", req.Customer,
		"payment.method", method,
		"amount", req.Amount,
	)

	if method == "gopay" {
		walletMu.Lock()
		balance := gopayBalances[req.Customer]
		if balance == 0 {
			balance = 500_000
			gopayBalances[req.Customer] = balance
		}
		walletMu.Unlock()
		if txn != nil {
			seg := txn.StartSegment("CheckGoPayBalance")
			txn.AddAttribute("gopay.balance", balance)
			seg.End()
		}
		if req.Amount > balance {
			if txn != nil {
				txn.NoticeError(fmt.Errorf("insufficient gopay balance"))
			}
			applog.Warn(ctx, "payment_insufficient_balance",
				"transaction.id", req.TransactionID,
				"customer.id", req.Customer,
				"amount", req.Amount,
				"gopay.balance", balance,
			)
			http.Error(w, `{"error":"saldo GoPay tidak mencukupi"}`, http.StatusPaymentRequired)
			return
		}
	}

	if txn != nil {
		txn.StartSegment("PrepareGatewayPayload").End()
	}
	payload := map[string]any{
		"merchant_tx": req.TransactionID,
		"amount":      req.Amount,
		"channel":     method,
		"customer":    req.Customer,
	}

	_ = mockdb.Query(ctx, "INSERT", "INSERT INTO payment_attempts(tx_id,amount,method) VALUES($1,$2,$3)", 20*time.Millisecond, func() error {
		return nil
	})

	if txn != nil {
		seg := txn.StartSegment("SimulatePaymentProcessing")
		time.Sleep(1800 * time.Millisecond)
		seg.End()
	} else {
		time.Sleep(1800 * time.Millisecond)
	}

	bankRef, err := callBank(ctx, payload)
	if err != nil {
		if txn != nil {
			txn.NoticeError(err)
		}
		applog.Error(ctx, "payment_bank_failed",
			"transaction.id", req.TransactionID,
			"customer.id", req.Customer,
			"error", err.Error(),
		)
		http.Error(w, fmt.Sprintf(`{"error":%q}`, err.Error()), http.StatusBadGateway)
		return
	}

	if method == "gopay" {
		if txn != nil {
			defer txn.StartSegment("DebitGoPayBalance").End()
		}
		walletMu.Lock()
		gopayBalances[req.Customer] -= req.Amount
		walletMu.Unlock()
	}

	resp := PaymentResponse{
		PaymentRef: fmt.Sprintf("PAY-%s", req.TransactionID),
		Status:     "SUCCESS",
		BankRef:    bankRef,
		Method:     method,
	}
	applog.Info(ctx, "payment_authorize_completed",
		"transaction.id", req.TransactionID,
		"customer.id", req.Customer,
		"payment.method", method,
		"payment.ref", resp.PaymentRef,
		"bank.ref", bankRef,
		"status", "SUCCESS",
	)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func callBank(ctx context.Context, payload map[string]any) (string, error) {
	base := httpserver.EnvOr("BANK_URL", "http://bank-svc:8085")
	body, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, base+"/api/bank/charge", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := nhttp.Client(15 * time.Second).Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(res.Body)
	if res.StatusCode >= 400 {
		return "", fmt.Errorf("bank gateway error: %s", string(raw))
	}
	var parsed struct {
		BankRef string `json:"bank_ref"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return "", err
	}
	return parsed.BankRef, nil
}
