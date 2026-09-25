package nragent

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/newrelic/go-agent/v3/newrelic"
)

// New creates a New Relic application for one microservice.
// License key: NEW_RELIC_LICENSE_KEY.
// Apdex T for Go apps is configured in New Relic UI (Settings → Application);
// apdexT is kept for lab documentation (default 500ms) and logged at startup.
func New(serviceName string, apdexT time.Duration) (*newrelic.Application, error) {
	key := os.Getenv("NEW_RELIC_LICENSE_KEY")
	if key == "" {
		log.Printf("nragent: NEW_RELIC_LICENSE_KEY kosong — agent disabled untuk %s", serviceName)
	}
	if apdexT <= 0 {
		apdexT = 500 * time.Millisecond
	}
	log.Printf("nragent: %s starting (lab Apdex T hint=%s — set threshold di NR UI Settings→Application)", serviceName, apdexT)

	forwardLogs := envBool("NEW_RELIC_APPLICATION_LOGGING_FORWARDING_ENABLED", true)

	app, err := newrelic.NewApplication(
		newrelic.ConfigAppName(serviceName),
		newrelic.ConfigLicense(key),
		newrelic.ConfigDistributedTracerEnabled(true),
		newrelic.ConfigAppLogEnabled(true),
		newrelic.ConfigAppLogForwardingEnabled(forwardLogs),
		newrelic.ConfigAppLogMetricsEnabled(true),
		newrelic.ConfigAppLogDecoratingEnabled(false), // we emit structured JSON ourselves with trace.id
		func(c *newrelic.Config) {
			if os.Getenv("NEW_RELIC_LOG") == "debug" {
				c.Logger = newrelic.NewDebugLogger(os.Stdout)
			}
			if env := os.Getenv("DEPLOY_ENV"); env != "" {
				if c.Labels == nil {
					c.Labels = map[string]string{}
				}
				c.Labels["environment"] = env
				c.Labels["lab"] = "apm-deep-dive"
			}
		},
	)
	if err != nil {
		return nil, fmt.Errorf("newrelic.NewApplication: %w", err)
	}

	go func() {
		if err := app.WaitForConnection(10 * time.Second); err != nil {
			log.Printf("nragent: %s belum connect ke New Relic: %v (traffic tetap dilayani)", serviceName, err)
		} else {
			log.Printf("nragent: %s connected to New Relic (log_forwarding=%v)", serviceName, forwardLogs)
		}
	}()

	return app, nil
}

func envBool(key string, def bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return def
	}
	return b
}
