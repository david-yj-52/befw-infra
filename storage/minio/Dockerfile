FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git ca-certificates

ARG MINIO_VERSION=RELEASE.2025-10-15T17-29-55Z

RUN git clone --depth 1 --branch ${MINIO_VERSION} \
      https://github.com/minio/minio.git /src/minio

WORKDIR /src/minio

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /out/minio .

# ── runtime ────────────────────────────────────────────────────────────────
FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -S minio && adduser -S minio -G minio

COPY --from=builder /out/minio /usr/local/bin/minio

EXPOSE 9000 9001

USER minio

ENTRYPOINT ["/usr/local/bin/minio"]
