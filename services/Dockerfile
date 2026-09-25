# syntax=docker/dockerfile:1
FROM golang:1.22-alpine AS build
ARG SERVICE
WORKDIR /src
RUN apk add --no-cache git ca-certificates
COPY go.mod go.sum ./
COPY services ./services
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/service ./services/${SERVICE}

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=build /out/service /app/service
EXPOSE 8080
ENTRYPOINT ["/app/service"]
