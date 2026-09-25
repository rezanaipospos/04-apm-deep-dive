package main

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/newrelic/go-agent/v3/newrelic"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/httpserver"
	"github.com/rezanaipospos/04-apm-deep-dive/services/pkg/mockdb"
)

type Film struct {
	ID       string   `json:"id"`
	Title    string   `json:"title"`
	Genre    string   `json:"genre"`
	Duration int      `json:"duration_min"`
	Cinemas  []Cinema `json:"cinemas"`
}

type Cinema struct {
	Code      string     `json:"code"`
	Name      string     `json:"name"`
	City      string     `json:"city"`
	Schedules []Schedule `json:"schedules"`
}

type Schedule struct {
	ID    string `json:"id"`
	Time  string `json:"time"`
	Hall  string `json:"hall"`
	Price int    `json:"price"`
}

func main() {
	httpserver.Run(httpserver.Config{
		ServiceName: "cinema-svc",
		Addr:        httpserver.EnvOr("ADDR", ":8081"),
		ApdexT:      500 * time.Millisecond,
		Routes: func(r chi.Router) {
			r.Get("/api/films", listFilms)
			r.Get("/api/films/{id}", getFilm)
		},
	})
}

func listFilms(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	txn := newrelic.FromContext(ctx)
	if txn != nil {
		defer txn.StartSegment("ListFilms").End()
		txn.AddAttribute("business.operation", "list_films")
	}

	var films []Film
	_ = mockdb.Query(ctx, "SELECT", "SELECT id,title,genre FROM films WHERE active=true", 25*time.Millisecond, func() error {
		films = catalog()
		return nil
	})

	writeJSON(w, films)
}

func getFilm(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := chi.URLParam(r, "id")
	txn := newrelic.FromContext(ctx)
	if txn != nil {
		defer txn.StartSegment("GetFilmDetail").End()
		txn.AddAttribute("business.operation", "get_film")
		txn.AddAttribute("film.id", id)
	}

	var found *Film
	_ = mockdb.Query(ctx, "SELECT", "SELECT * FROM films f JOIN schedules s ON s.film_id=f.id WHERE f.id=$1", 40*time.Millisecond, func() error {
		for _, f := range catalog() {
			if f.ID == id {
				cp := f
				found = &cp
				return nil
			}
		}
		return nil
	})
	if found == nil {
		http.Error(w, `{"error":"film not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, found)
}

func catalog() []Film {
	return []Film{
		{
			ID: "f-dune2", Title: "Dune: Part Two", Genre: "Sci-Fi", Duration: 166,
			Cinemas: []Cinema{{
				Code: "JKT-CGV", Name: "CGV Grand Indonesia", City: "Jakarta",
				Schedules: []Schedule{
					{ID: "sch-1", Time: "13:30", Hall: "Studio 1", Price: 55000},
					{ID: "sch-2", Time: "19:00", Hall: "Studio 3 IMAX", Price: 80000},
				},
			}},
		},
		{
			ID: "f-insideout2", Title: "Inside Out 2", Genre: "Animation", Duration: 96,
			Cinemas: []Cinema{{
				Code: "BDG-XXI", Name: "Cinema XXI Paris Van Java", City: "Bandung",
				Schedules: []Schedule{
					{ID: "sch-3", Time: "11:00", Hall: "Studio 2", Price: 45000},
					{ID: "sch-4", Time: "16:45", Hall: "Studio 2", Price: 45000},
				},
			}},
		},
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}
