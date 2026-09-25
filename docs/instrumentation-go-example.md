# Contoh instrumentasi New Relic Go Agent (untuk ditiru di kode Anda)

Dokumen ini adalah **satu contoh end-to-end** yang merangkum pola lab:

| Lab file | Peran |
|----------|--------|
| `services/pkg/nragent` | Bootstrap `NewApplication` |
| `services/pkg/httpserver` | Middleware → **Transaction** (= metrics) |
| `services/pkg/mockdb` | **DatastoreSegment** |
| `services/pkg/nhttp` | **External** via `NewRoundTripper` |
| `services/payment/main.go` | **Code segments** + `NoticeError` + attributes |

Di learning platform: **Modul 2.4**.

---

## Metrics vs tracing — jangan tertukar

```text
HTTP Request
 └── Transaction (middleware)     → Metrics: throughput, latency, error %, Apdex
      ├── StartSegment("Validate") → Trace waterfall (code)
      ├── DatastoreSegment         → Trace waterfall (DB) + Databases UI
      ├── NewRoundTripper HTTP     → Trace waterfall (external) + Distributed Trace
      └── NoticeError(err)         → Errors inbox + transaction marked error
```

Anda **tidak** perlu menghitung latency manual untuk golden signals — cukup transaction yang benar.  
Segment ditambahkan agar **waterfall** menjawab: *waktu habis di mana?*

---

## Mini contoh `order-svc`

### Bootstrap

```go
app, err := newrelic.NewApplication(
  newrelic.ConfigAppName("order-svc"),
  newrelic.ConfigLicense(os.Getenv("NEW_RELIC_LICENSE_KEY")),
  newrelic.ConfigDistributedTracerEnabled(true),
)
```

### Middleware (metrics)

```go
txn := app.StartTransaction(r.Method + " " + r.URL.Path)
defer txn.End()
txn.SetWebRequestHTTP(r)
w = txn.SetWebResponse(w)
r = newrelic.RequestWithTransactionContext(r, txn)
next.ServeHTTP(w, r)
// set nama pakai route pattern Chi agar tidak meledak cardinality
```

### Handler (segments + DB + external)

```go
txn := newrelic.FromContext(r.Context())
txn.AddAttribute("business.operation", "create_order")

seg := txn.StartSegment("ValidateOrderPayload")
// validasi...
seg.End()

// DB
ds := newrelic.DatastoreSegment{
  Product: newrelic.DatastoreMySQL, Collection: "orders", Operation: "SELECT",
  ParameterizedQuery: "SELECT ...", Host: "db", DatabaseName: "orders",
}
ds.StartTime = txn.StartSegmentNow()
defer ds.End()

// External
client := &http.Client{Transport: newrelic.NewRoundTripper(http.DefaultTransport)}
req, _ := http.NewRequestWithContext(ctx, http.MethodPost, paymentURL, body)
resp, err := client.Do(req)
```

### Error

```go
if err != nil {
  txn.NoticeError(err)
}
```

---

## Checklist porting ke service Anda

1. `go get github.com/newrelic/go-agent/v3/newrelic`
2. Env `NEW_RELIC_LICENSE_KEY`
3. Satu `Application` per microservice (nama unik)
4. Middleware di semua route bisnis
5. `StartSegment` pada langkah mahal/kritis
6. Datastore segment (atau integrasi driver resmi)
7. HTTP client keluar = `NewRoundTripper` + context transaction
8. `NoticeError` untuk kegagalan yang ingin di-alert/debug
9. Distributed tracing ON di semua service saling panggil
10. Verifikasi: Summary (metrics) → Transaction waterfall → Distributed tracing → Errors

---

## Mapping ke lab ticketing

Setelah contoh di atas dipahami, buka lagi:

- `payment-svc` — banyak `StartSegment` bisnis (Authorize, CheckGoPayBalance, …)
- `checkout-svc` → `payment-svc` — External + distributed trace
- Chaos `payment-500` — Errors + alert Phase 5
