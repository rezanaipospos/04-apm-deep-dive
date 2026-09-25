package httpserver

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/newrelic/go-agent/v3/newrelic"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/applog"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/chaos"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/nragent"
)

type Config struct {
	ServiceName string
	Addr        string
	ApdexT      time.Duration
	Routes      func(r chi.Router)
}

func Run(cfg Config) {
	applog.Init(cfg.ServiceName)

	app, err := nragent.New(cfg.ServiceName, cfg.ApdexT)
	if err != nil {
		log.Fatalf("new relic: %v", err)
	}

	r := chi.NewRouter()
	r.Use(nrMiddleware(app))
	r.Use(requestContextMiddleware)
	r.Use(accessLogMiddleware)
	r.Use(chimw.RealIP)
	r.Use(chimw.Recoverer)
	r.Use(chaos.Middleware)
	r.Use(noticeHTTPErrors)
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})
	cfg.Routes(r)

	srv := &http.Server{Addr: cfg.Addr, Handler: r}

	go func() {
		applog.Info(context.Background(), "server listening", "addr", cfg.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	cctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(cctx)
	app.Shutdown(5 * time.Second)
}

func nrMiddleware(app *newrelic.Application) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if app == nil {
				next.ServeHTTP(w, r)
				return
			}
			txn := app.StartTransaction(r.Method + " " + r.URL.Path)
			defer txn.End()
			txn.SetWebRequestHTTP(r)
			w = txn.SetWebResponse(w)
			r = newrelic.RequestWithTransactionContext(r, txn)
			next.ServeHTTP(w, r)
			if routeCtx := chi.RouteContext(r.Context()); routeCtx != nil {
				if pattern := routeCtx.RoutePattern(); pattern != "" {
					txn.SetName(r.Method + " " + pattern)
				}
			}
		})
	}
}

func requestContextMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reqID := r.Header.Get("X-Request-Id")
		if reqID == "" {
			reqID = r.Header.Get("X-Correlation-Id")
		}
		if reqID == "" {
			reqID = newRequestID()
		}
		ctx := applog.WithRequestID(r.Context(), reqID)
		if txn := newrelic.FromContext(ctx); txn != nil {
			txn.AddAttribute("request.id", reqID)
			md := txn.GetTraceMetadata()
			if md.TraceID != "" {
				w.Header().Set("X-Trace-Id", md.TraceID)
			}
		}
		w.Header().Set("X-Request-Id", reqID)
		l := applog.Enrich(ctx, nil)
		ctx = applog.WithContext(ctx, l)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func accessLogMiddleware(next http.Handler) http.Handler {
	// Production noise control: only log failed HTTP requests here.
	// Happy-path business events are logged explicitly in checkout/payment handlers.
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/healthz" {
			next.ServeHTTP(w, r)
			return
		}
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: 200}
		next.ServeHTTP(sw, r)
		if sw.status < 400 {
			return
		}
		attrs := []any{
			"http.method", r.Method,
			"http.route", r.URL.Path,
			"http.status_code", sw.status,
			"duration_ms", time.Since(start).Milliseconds(),
		}
		if routeCtx := chi.RouteContext(r.Context()); routeCtx != nil && routeCtx.RoutePattern() != "" {
			attrs = append(attrs, "http.route_pattern", routeCtx.RoutePattern())
		}
		if sw.status >= 500 {
			applog.Error(r.Context(), "http_request_error", attrs...)
		} else {
			applog.Warn(r.Context(), "http_request_error", attrs...)
		}
	})
}

func noticeHTTPErrors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sw := &statusWriter{ResponseWriter: w, status: 200}
		next.ServeHTTP(sw, r)
		if sw.status >= 500 {
			if txn := newrelic.FromContext(r.Context()); txn != nil {
				txn.NoticeError(newrelic.Error{
					Message: http.StatusText(sw.status),
					Class:   "HTTPError",
					Attributes: map[string]interface{}{
						"http.statusCode": sw.status,
						"http.method":     r.Method,
						"http.url":        r.URL.Path,
						"request.id":      applog.RequestID(r.Context()),
					},
				})
			}
		}
	})
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func EnvOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func newRequestID() string {
	var b [8]byte
	_, _ = rand.Read(b[:])
	return fmt.Sprintf("%s-%d", hex.EncodeToString(b[:]), time.Now().UnixNano())
}
