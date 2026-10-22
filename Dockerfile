# ---- Builder stage ----
FROM golang:1.26.10-alpine@sha256:5cb67f19c5e7994dcb80c074f7cfca8aeeada45bbdca035f73df269cefdcce61 AS builder

COPY scripts/security-ca.sh /usr/local/bin/security-ca
RUN apk add --no-cache 'ca-certificates>=20261020-r0' openssl && sh /usr/local/bin/security-ca

WORKDIR /src

# Install build deps
RUN apk add --no-cache git ca-certificates

# Cache go modules layer
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w -extldflags '-static'" \
    -o /out/cursor2api-go .

# ---- Runtime stage ----
FROM node:22.23.4-alpine@sha256:fe4f6d74e20370acb04ad889077d14d0f64a9c8ea6a42bc60cddf1e844699914

COPY scripts/security-ca.sh /usr/local/bin/security-ca
RUN apk add --no-cache 'ca-certificates>=20261020-r0' openssl && sh /usr/local/bin/security-ca

RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy binary and required assets
COPY --from=builder /out/cursor2api-go .
COPY static ./static
COPY jscode ./jscode

# Create non-root user
RUN adduser -D -g '' appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8002

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8002/health || exit 1

CMD ["./cursor2api-go"]
