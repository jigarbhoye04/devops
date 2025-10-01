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
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthHandler)

	logJSON("info", "starting bid-request-handler on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		logJSON("error", "server failed: "+err.Error())
		os.Exit(1)
	}
}
