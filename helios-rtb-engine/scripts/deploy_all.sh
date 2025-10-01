#!/usr/bin/env bash
set -euo pipefail

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

kubectl apply -f "$ROOT_DIR/kubernetes/00-namespace.yaml"

for dir in "$ROOT_DIR"/kubernetes/infra/*; do
  if [ -d "$dir" ]; then
    kubectl apply -f "$dir"
  fi
done

for dir in "$ROOT_DIR"/kubernetes/services/*; do
  if [ -d "$dir" ]; then
    kubectl apply -f "$dir"
  fi
done

kubectl apply -f "$ROOT_DIR/kubernetes/gateway"
