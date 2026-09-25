package nhttp

import (
	"net/http"
	"time"

	"github.com/newrelic/go-agent/v3/newrelic"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/applog"
)

// Client returns an HTTP client that creates External segments and propagates distributed tracing headers.
func Client(timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout:   timeout,
		Transport: &propagatingTripper{base: newrelic.NewRoundTripper(http.DefaultTransport)},
	}
}

// propagatingTripper adds X-Request-Id for log correlation across services.
type propagatingTripper struct {
	base http.RoundTripper
}

func (t *propagatingTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	if rid := applog.RequestID(req.Context()); rid != "" && req.Header.Get("X-Request-Id") == "" {
		req.Header.Set("X-Request-Id", rid)
	}
	return t.base.RoundTrip(req)
}
