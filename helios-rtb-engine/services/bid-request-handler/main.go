package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/segmentio/kafka-go"
)

// Prometheus metrics
var (
	bidRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "bid_requests_total",
			Help: "Total number of bid requests received",
		},
		[]string{"status"},
	)

	requestProcessingDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "request_processing_duration_seconds",
			Help:    "Histogram of request processing durations",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"endpoint"},
	)

	kafkaPublishErrors = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "kafka_publish_errors_total",
			Help: "Total number of Kafka publish errors",
		},
	)

	activeRequests = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "active_requests",
			Help: "Number of requests currently being processed",
		},
	)
)

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(bidRequestsTotal)
	prometheus.MustRegister(requestProcessingDuration)
	prometheus.MustRegister(kafkaPublishErrors)
	prometheus.MustRegister(activeRequests)
}

// logEntry represents the structure for log messages
type logEntry struct {
	Timestamp string                 `json:"timestamp"`
	Level     string                 `json:"level"`
	Message   string                 `json:"message"`
	Extra     map[string]interface{} `json:"extra,omitempty"`
}

// logJSON logs messages in JSON format with optional extra fields
func logJSON(level, message string, extra ...map[string]interface{}) {
	entry := logEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339Nano),
		Level:     level,
		Message:   message,
	}
	if len(extra) > 0 {
		entry.Extra = extra[0]
	}
	enc := json.NewEncoder(os.Stdout)
	_ = enc.Encode(entry)
}

func main() {
	kafkaBrokers := os.Getenv("KAFKA_BROKERS")
	kafkaTopic := os.Getenv("KAFKA_TOPIC_BID_REQUESTS")

	if kafkaBrokers == "" || kafkaTopic == "" {
		logJSON("fatal", "Missing required environment variables", map[string]interface{}{
			"KAFKA_BROKERS":            kafkaBrokers,
			"KAFKA_TOPIC_BID_REQUESTS": kafkaTopic,
		})
		os.Exit(1)
	}

	// Kafka writer
	writer := kafka.NewWriter(kafka.WriterConfig{
		Brokers:  strings.Split(kafkaBrokers, ","),
		Topic:    kafkaTopic,
		Balancer: &kafka.LeastBytes{},
	})
	defer writer.Close()

	// /bid endpoint
	http.HandleFunc("/bid", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		activeRequests.Inc()
		defer activeRequests.Dec()
		defer func() {
			duration := time.Since(start).Seconds()
			requestProcessingDuration.WithLabelValues("/bid").Observe(duration)
		}()

		if r.Method != http.MethodPost {
			bidRequestsTotal.WithLabelValues("method_not_allowed").Inc()
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		body, err := io.ReadAll(r.Body)
		if err != nil {
			bidRequestsTotal.WithLabelValues("bad_request").Inc()
			logJSON("error", "Failed to read request body", map[string]interface{}{"error": err.Error()})
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		defer r.Body.Close()

		msg := kafka.Message{Value: body}
		ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
		defer cancel()

		if err := writer.WriteMessages(ctx, msg); err != nil {
			bidRequestsTotal.WithLabelValues("kafka_error").Inc()
			kafkaPublishErrors.Inc()
			logJSON("error", "Failed to publish to Kafka", map[string]interface{}{"error": err.Error()})
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		bidRequestsTotal.WithLabelValues("success").Inc()
		logJSON("info", "Published bid request to Kafka", map[string]interface{}{"topic": kafkaTopic})
		w.WriteHeader(http.StatusAccepted)
	})

	// /healthz endpoint
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// /metrics endpoint for Prometheus
	http.Handle("/metrics", promhttp.Handler())

	logJSON("info", "Starting bid-request-handler on :8080 with /metrics endpoint on :2112")

	// Start metrics server on a separate port
	go func() {
		metricsServer := &http.Server{
			Addr:    ":2112",
			Handler: promhttp.Handler(),
		}
		logJSON("info", "Starting Prometheus metrics server on :2112")
		if err := metricsServer.ListenAndServe(); err != nil {
			logJSON("error", "Metrics server failed", map[string]interface{}{"error": err.Error()})
		}
	}()

	// Start main server
	if err := http.ListenAndServe(":8080", nil); err != nil {
		logJSON("fatal", "Server failed", map[string]interface{}{"error": err.Error()})
		os.Exit(1)
	}
}
