# syntax=docker/dockerfile:1

FROM golang:1.22-alpine AS build
WORKDIR /app
COPY services/bid-request-handler/go.mod services/bid-request-handler/go.sum ./
RUN go mod download
COPY services/bid-request-handler/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -o bid-request-handler

FROM alpine:3.20 AS runtime
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /app/bid-request-handler ./bid-request-handler
USER app
ENTRYPOINT ["/app/bid-request-handler"]
