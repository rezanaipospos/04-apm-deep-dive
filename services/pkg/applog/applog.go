package applog

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"github.com/newrelic/go-agent/v3/newrelic"
)

type ctxKey struct{}

// Init sets the process-wide JSON logger (stdout). Call once at process start.
func Init(serviceName string) {
	level := slog.LevelInfo
	switch strings.ToLower(os.Getenv("LOG_LEVEL")) {
	case "debug":
		level = slog.LevelDebug
	case "warn", "warning":
		level = slog.LevelWarn
	case "error":
		level = slog.LevelError
	}
	h := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: level,
		ReplaceAttr: func(_ []string, a slog.Attr) slog.Attr {
			if a.Key == slog.TimeKey {
				return slog.String("timestamp", a.Value.Time().UTC().Format(time.RFC3339Nano))
			}
			if a.Key == slog.MessageKey {
				return slog.Attr{Key: "message", Value: a.Value}
			}
			if a.Key == slog.LevelKey {
				return slog.String("level", strings.ToLower(a.Value.String()))
			}
			return a
		},
	})
	slog.SetDefault(slog.New(h).With(
		"service.name", serviceName,
		"service.environment", envOr("DEPLOY_ENV", "lab"),
	))
}

// WithContext stores a logger enriched for this request in context.
func WithContext(ctx context.Context, l *slog.Logger) context.Context {
	return context.WithValue(ctx, ctxKey{}, l)
}

// From returns the request logger, or a NR-enriched default from context.
func From(ctx context.Context) *slog.Logger {
	if v := ctx.Value(ctxKey{}); v != nil {
		if l, ok := v.(*slog.Logger); ok && l != nil {
			return l
		}
	}
	return Enrich(ctx, slog.Default())
}

// Enrich adds New Relic trace/span IDs and optional request id for log↔trace correlation.
func Enrich(ctx context.Context, base *slog.Logger) *slog.Logger {
	if base == nil {
		base = slog.Default()
	}
	attrs := make([]any, 0, 8)
	if txn := newrelic.FromContext(ctx); txn != nil {
		md := txn.GetTraceMetadata()
		if md.TraceID != "" {
			attrs = append(attrs, "trace.id", md.TraceID)
		}
		if md.SpanID != "" {
			attrs = append(attrs, "span.id", md.SpanID)
		}
	}
	if rid := RequestID(ctx); rid != "" {
		attrs = append(attrs, "request.id", rid)
	}
	if len(attrs) == 0 {
		return base
	}
	return base.With(attrs...)
}

// Info / Warn / Error / Debug
// event = short event name; kv = structured fields.
// The JSON "message" field is expanded to a full line (event + key=value) so
// New Relic / grep "message contains TX-…" keeps working.
func Info(ctx context.Context, event string, kv ...any) {
	log(ctx, slog.LevelInfo, event, kv...)
}

func Warn(ctx context.Context, event string, kv ...any) {
	log(ctx, slog.LevelWarn, event, kv...)
}

func Error(ctx context.Context, event string, kv ...any) {
	log(ctx, slog.LevelError, event, kv...)
}

func Debug(ctx context.Context, event string, kv ...any) {
	log(ctx, slog.LevelDebug, event, kv...)
}

func log(ctx context.Context, level slog.Level, event string, kv ...any) {
	msg := fullMessage(ctx, event, kv...)
	fields := append([]any{"event", event}, kv...)

	l := From(ctx)
	l.Log(ctx, level, msg, fields...)

	if txn := newrelic.FromContext(ctx); txn != nil {
		attrs := kvToMap(fields...)
		if rid := RequestID(ctx); rid != "" {
			attrs["request.id"] = rid
		}
		txn.RecordLog(newrelic.LogData{
			Severity:   strings.ToUpper(level.String()),
			Message:    msg,
			Attributes: attrs,
		})
	}
}

// fullMessage builds a searchable line, e.g.
// checkout_completed request.id=… trace.id=… transaction.id=TX-1 customer.id=lab-student …
func fullMessage(ctx context.Context, event string, kv ...any) string {
	var b strings.Builder
	b.WriteString(event)

	if rid := RequestID(ctx); rid != "" {
		fmt.Fprintf(&b, " request.id=%s", rid)
	}
	if txn := newrelic.FromContext(ctx); txn != nil {
		md := txn.GetTraceMetadata()
		if md.TraceID != "" {
			fmt.Fprintf(&b, " trace.id=%s", md.TraceID)
		}
		if md.SpanID != "" {
			fmt.Fprintf(&b, " span.id=%s", md.SpanID)
		}
	}
	for i := 0; i+1 < len(kv); i += 2 {
		key, ok := kv[i].(string)
		if !ok {
			continue
		}
		fmt.Fprintf(&b, " %s=%v", key, kv[i+1])
	}
	return b.String()
}

func kvToMap(kv ...any) map[string]any {
	out := map[string]any{}
	for i := 0; i+1 < len(kv); i += 2 {
		key, ok := kv[i].(string)
		if !ok {
			continue
		}
		out[key] = kv[i+1]
	}
	return out
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

type reqIDKey struct{}

// WithRequestID attaches a request/correlation id.
func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, reqIDKey{}, id)
}

func RequestID(ctx context.Context) string {
	if v := ctx.Value(reqIDKey{}); v != nil {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
