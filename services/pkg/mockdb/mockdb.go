package mockdb

import (
	"context"
	"time"

	"github.com/newrelic/go-agent/v3/newrelic"
)

// Query simulates a DB round-trip and records a New Relic Datastore segment (no real DB).
func Query(ctx context.Context, operation, statement string, delay time.Duration, fn func() error) error {
	txn := newrelic.FromContext(ctx)
	seg := newrelic.DatastoreSegment{
		Product:            newrelic.DatastoreProduct("Mock"),
		Collection:         "ticketing_mock",
		Operation:          operation,
		ParameterizedQuery: statement,
		Host:               "mock-db",
		DatabaseName:       "ticketing_mock",
	}
	if txn != nil {
		seg.StartTime = txn.StartSegmentNow()
	}
	defer seg.End()

	if delay > 0 {
		time.Sleep(delay)
	}
	if err := fn(); err != nil {
		if txn != nil {
			txn.NoticeError(err)
		}
		return err
	}
	return nil
}
