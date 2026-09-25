package chaos

import (
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

// Middleware injects artificial latency / errors from env or request headers.
//
// Env:
//   CHAOS_LATENCY_MS=800
//   CHAOS_ERROR_STATUS=500
//   CHAOS_ERROR_RATE=0.3   (0.0–1.0)
//   CHAOS_MATCH_PATH=/api/wallet  (optional; only inject when path contains this)
//
// Headers (override env for one request):
//   X-Chaos-Latency-Ms
//   X-Chaos-Error-Status
//   X-Chaos-Error-Rate
func Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/healthz" {
			next.ServeHTTP(w, r)
			return
		}

		// Optional path filter: only inject chaos when URL path contains this substring.
		// Example: CHAOS_MATCH_PATH=/api/wallet → balance endpoint only.
		if match := strings.TrimSpace(os.Getenv("CHAOS_MATCH_PATH")); match != "" {
			if !strings.Contains(r.URL.Path, match) {
				next.ServeHTTP(w, r)
				return
			}
		}

		latencyMs := intFrom(r.Header.Get("X-Chaos-Latency-Ms"), envInt("CHAOS_LATENCY_MS", 0))
		if latencyMs > 0 {
			time.Sleep(time.Duration(latencyMs) * time.Millisecond)
		}

		status := intFrom(r.Header.Get("X-Chaos-Error-Status"), envInt("CHAOS_ERROR_STATUS", 0))
		rate := floatFrom(r.Header.Get("X-Chaos-Error-Rate"), envFloat("CHAOS_ERROR_RATE", 0))
		if status >= 400 {
			// rate <= 0 means always fail when status is set; otherwise probabilistic
			if rate <= 0 || rand.Float64() < rate {
				http.Error(w, chaosMessage(status), status)
				return
			}
		}

		next.ServeHTTP(w, r)
	})
}

func chaosMessage(status int) string {
	switch status {
	case 400:
		return `{"error":"chaos: bad request injected"}`
	case 500:
		return `{"error":"chaos: internal server error injected"}`
	default:
		return `{"error":"chaos: injected failure"}`
	}
}

func envInt(key string, def int) int {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}

func envFloat(key string, def float64) float64 {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return def
	}
	n, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return def
	}
	return n
}

func intFrom(raw string, def int) int {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return def
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return def
	}
	return n
}

func floatFrom(raw string, def float64) float64 {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return def
	}
	n, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return def
	}
	return n
}
