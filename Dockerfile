FROM golang:1.24-alpine as builder

WORKDIR /app

COPY go.mod .
COPY go.sum .
RUN go mod download

COPY . .
RUN go build -o diruzorro ./cmd/web

# ---- Final stage ----
FROM alpine:latest

WORKDIR /root/

COPY --from=builder /app/diruzorro .
# COPY --from=builder /app/web /root/web
# COPY --from=builder /app/internal/templates /root/templates
# COPY --from=builder /app/web/static /root/static
# COPY --from=builder /app/internal/database/diruzorro.db /root/diruzorro.db

EXPOSE 8080

CMD ["./diruzorro"]
