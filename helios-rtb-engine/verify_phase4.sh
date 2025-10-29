#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║       HELIOS RTB ENGINE - PHASE 4 VERIFICATION             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

GATEWAY_URL="http://$(minikube ip):30080"

echo "=== [1] Pod Status ==="
kubectl get pods -n helios | head -1
kubectl get pods -n helios | grep "dashboard"
kubectl get pods -n helios | grep "gateway"
kubectl get pods -n helios | grep "prometheus"
kubectl get pods -n helios | grep "grafana"
kubectl get pods -n helios | grep "bid-request"
kubectl get pods -n helios | grep "bidding-logic"
kubectl get pods -n helios | grep "analytics"
echo ""

echo "=== [2] Gateway URL ==="
echo "Gateway: $GATEWAY_URL"
echo ""

echo "=== [3] Testing Gateway Ping ==="
curl -s $GATEWAY_URL/ping && echo "✅ Gateway is responding" || echo "❌ Gateway ping failed"
echo ""

echo "=== [4] Testing Analytics API ==="
curl -s $GATEWAY_URL/api/outcomes/ | head -c 100 && echo "... ✅ Analytics API responding" || echo "❌ Analytics API failed"
echo ""

echo "=== [5] Testing Prometheus Metrics - Bid Handler ==="
kubectl port-forward -n helios deployment/bid-request-handler-deployment 2112:2112 &
PF_PID=$!
sleep 2
curl -s http://localhost:2112/metrics | grep "bid_requests_total" && echo "✅ Bid Handler metrics working" || echo "❌ Bid Handler metrics failed"
kill $PF_PID 2>/dev/null || true
echo ""

echo "=== [6] Testing Prometheus Metrics - Bidding Logic ==="
kubectl port-forward -n helios deployment/bidding-logic-service-deployment 8001:8001 &
PF_PID=$!
sleep 2
curl -s http://localhost:8001/metrics | grep "bid_requests_processed_total" && echo "✅ Bidding Logic metrics working" || echo "❌ Bidding Logic metrics failed"
kill $PF_PID 2>/dev/null || true
echo ""

echo "=== [7] Service Endpoints ==="
echo "Advertiser Dashboard:  $GATEWAY_URL/"
echo "Analytics API:         $GATEWAY_URL/api/outcomes/"
echo "Grafana:              $GATEWAY_URL/grafana"
echo "Prometheus:           $GATEWAY_URL/prometheus"
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║             VERIFICATION COMPLETE                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
