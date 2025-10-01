#!/usr/bin/env bash
set -euo pipefail

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

if ! command -v k3d >/dev/null 2>&1 && ! command -v kind >/dev/null 2>&1; then
  echo "Install k3d or kind to provision a local Kubernetes cluster" >&2
  exit 1
fi

echo "Provisioning local cluster with k3d"
if command -v k3d >/dev/null 2>&1; then
  k3d cluster create helios --servers 1 --agents 2 --wait
elif command -v kind >/dev/null 2>&1; then
  kind create cluster --name helios
fi

echo "Cluster ready. Use kubectl to apply manifests."
