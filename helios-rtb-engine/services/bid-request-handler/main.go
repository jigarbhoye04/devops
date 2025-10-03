package main

import (
	"encoding/json"
	"net/http"
	"os"
	"time"
)

type logEntry struct {
	Timestamp string `json:"timestamp"`
	Level     string `json:"level"`
	Message   string `json:"message"`
}

func logJSON(level, message string) {
	entry := logEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339Nano),
		Level:     level,
		Message:   message,
	}
	enc := json.NewEncoder(os.Stdout)
	_ = enc.Encode(entry)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func main() {
	kafkaBrokers := os.Getenv("KAFKA_BROKERS")
	kafkaTopic := os.Getenv("KAFKA_TOPIC_BID_REQUESTS")
	if kafkaBrokers == "" || kafkaTopic == "" {
		logJSON("fatal", "Missing required environment variables", map[string]interface{}{"KAFKA_BROKERS": kafkaBrokers, "KAFKA_TOPIC_BID_REQUESTS": kafkaTopic})
		os.Exit(1)
	}

	writer := kafka.NewWriter(kafka.WriterConfig{
		Brokers:  strings.Split(kafkaBrokers, ","),
		Topic:    kafkaTopic,
		Balancer: &kafka.LeastBytes{},
	})
	defer writer.Close()

	http.HandleFunc("/bid", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		body, err := io.ReadAll(r.Body)
		if err != nil {
			logJSON("error", "Failed to read request body", map[string]interface{}{"error": err.Error()})
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		defer r.Body.Close()

		msg := kafka.Message{
			Value: body,
		}
		ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
		defer cancel()
		if err := writer.WriteMessages(ctx, msg); err != nil {
			logJSON("error", "Failed to publish to Kafka", map[string]interface{}{"error": err.Error()})
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		logJSON("info", "Published bid request to Kafka", map[string]interface{}{"topic": kafkaTopic})
		w.WriteHeader(http.StatusAccepted)
	})

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	logJSON("info", "Starting bid-request-handler on :8080", nil)
	if err := http.ListenAndServe(":8080", nil); err != nil {
		logJSON("fatal", "Server failed", map[string]interface{}{"error": err.Error()})
		os.Exit(1)
	}
}
