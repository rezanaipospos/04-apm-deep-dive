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

type Seat struct {
	ID     string `json:"id"`
	Row    string `json:"row"`
	Number int    `json:"number"`
	Status string `json:"status"`
}

type Layout struct {
	ScheduleID string `json:"schedule_id"`
	Hall       string `json:"hall"`
	Seats      []Seat `json:"seats"`
}

func main() {
	httpserver.Run(httpserver.Config{
		ServiceName: "layout-svc",
		Addr:        httpserver.EnvOr("ADDR", ":8082"),
		ApdexT:      500 * time.Millisecond,
		Routes: func(r chi.Router) {
			r.Get("/api/layouts/{scheduleId}", getLayout)
		},
	})
}

func getLayout(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	scheduleID := chi.URLParam(r, "scheduleId")
	txn := newrelic.FromContext(ctx)
	if txn != nil {
		defer txn.StartSegment("LoadSeatLayout").End()
		txn.AddAttribute("business.operation", "load_layout")
		txn.AddAttribute("schedule.id", scheduleID)
	}

	var layout Layout
	_ = mockdb.Query(ctx, "SELECT", "SELECT seat_id,row,num,status FROM seats WHERE schedule_id=$1", 30*time.Millisecond, func() error {
		layout = Layout{
			ScheduleID: scheduleID,
			Hall:       "Studio Lab",
			Seats:      buildSeats(),
		}
		return nil
	})

	if txn != nil {
		seg := txn.StartSegment("ValidateLayoutIntegrity")
		txn.AddAttribute("seat.count", len(layout.Seats))
		seg.End()
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(layout)
}

func buildSeats() []Seat {
	rows := []string{"A", "B", "C", "D"}
	var seats []Seat
	for _, row := range rows {
		for n := 1; n <= 8; n++ {
			status := "available"
			if row == "B" && (n == 3 || n == 4) {
				status = "taken"
			}
			seats = append(seats, Seat{
				ID:     fmt.Sprintf("%s%d", row, n),
				Row:    row,
				Number: n,
				Status: status,
			})
		}
	}
	return seats
}
