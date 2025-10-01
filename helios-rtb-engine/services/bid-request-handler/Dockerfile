# syntax=docker/dockerfile:1

FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o bid-request-handler

FROM gcr.io/distroless/base-debian12
USER nonroot:nonroot
WORKDIR /
COPY --from=build /app/bid-request-handler ./bid-request-handler
ENTRYPOINT ["./bid-request-handler"]
