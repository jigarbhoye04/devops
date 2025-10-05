#!/bin/bash
set -e

echo "🔍 Checking environment setup..."
echo "--------------------------------"

# Function to prompt installation
install_prompt() {
  local pkg=$1
  local install_cmd=$2
  read -p "⚠️  $pkg not found. Install it now? [Y/n]: " choice
  case "$choice" in
    [nN]*) echo "❌ Skipping $pkg installation." ;;
    *) echo "⬇️ Installing $pkg..."; eval "$install_cmd"; echo "✅ $pkg installed." ;;
  esac
}

# Ensure bc is installed (for version comparisons)
if ! command -v bc &>/dev/null; then
  echo "⚙️ Installing bc (required for version checks)..."
  sudo apt update -y >/dev/null && sudo apt install -y bc >/dev/null
fi

# Ensure jq is installed (for parsing kubectl JSON output)
if ! command -v jq &>/dev/null; then
  echo "⚙️ Installing jq (required for kubectl version parsing)..."
  sudo apt update -y >/dev/null && sudo apt install -y jq >/dev/null
fi

# -------------------- Docker --------------------
if command -v docker &>/dev/null; then
  docker_ver=$(docker --version | awk '{print $3}' | sed 's/,//')
  docker_major=$(echo "$docker_ver" | cut -d. -f1)
  if (( docker_major >= 24 )); then
    echo "✅ Docker version $docker_ver"
  else
    echo "❌ Docker version $docker_ver (need 24+)"
  fi
else
  install_prompt "Docker" "sudo apt update -y && sudo apt install -y docker.io && sudo systemctl enable docker && sudo systemctl start docker"
fi

# -------------------- kubectl --------------------
if command -v kubectl &>/dev/null; then
  kubectl_ver=$(kubectl version --client --output=json | jq -r '.clientVersion.gitVersion' | sed 's/v//')
  kubectl_major=$(echo "$kubectl_ver" | cut -d. -f1)
  kubectl_minor=$(echo "$kubectl_ver" | cut -d. -f2)
  if (( kubectl_major == 1 && kubectl_minor >= 29 )) || (( kubectl_major > 1 )); then
    echo "✅ kubectl version $kubectl_ver"
  else
    echo "❌ kubectl version $kubectl_ver (need 1.29+)"
    install_prompt "kubectl" "sudo snap install kubectl --classic --channel=1.29/stable"
  fi
else
  install_prompt "kubectl" "sudo snap install kubectl --classic --channel=1.29/stable"
fi

# -------------------- Minikube / Kubernetes Cluster --------------------
if ! command -v minikube &>/dev/null; then
  install_prompt "Minikube" "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install minikube-linux-amd64 /usr/local/bin/minikube"
fi

# Re-check if minikube is now installed
if command -v minikube &>/dev/null; then
  minikube_installed=true
fi

if command -v kubectl &>/dev/null; then
  if kubectl get nodes &>/dev/null; then
    echo "✅ Kubernetes cluster reachable"
  else
    echo "⚠️  Cannot connect to a Kubernetes cluster"
    if $minikube_installed; then
      echo "⬇️ Attempting to start Minikube..."
      minikube start --driver=docker
      echo "✅ Minikube started"
      kubectl get nodes
    else
      echo "   → Minikube not installed, cannot auto-start cluster."
    fi
  fi
fi


# -------------------- Python --------------------
if command -v python3 &>/dev/null; then
  python_ver=$(python3 --version | awk '{print $2}')
  major_minor=$(echo "$python_ver" | cut -d. -f1,2)
  if [[ $(echo "$major_minor >= 3.12" | bc -l) -eq 1 ]]; then
    echo "✅ Python version $python_ver"
  else
    echo "❌ Python version $python_ver (need 3.12+)"
    install_prompt "Python 3.12" "sudo add-apt-repository ppa:deadsnakes/ppa -y && sudo apt update -y && sudo apt install -y python3.12 python3.12-venv python3.12-distutils"
  fi
else
  install_prompt "Python 3.12" "sudo add-apt-repository ppa:deadsnakes/ppa -y && sudo apt update -y && sudo apt install -y python3.12 python3.12-venv python3.12-distutils"
fi

# -------------------- Wrap up --------------------
echo "--------------------------------"
echo "✅ Environment check completed!"
echo "If you installed new tools, reopen your terminal for changes to take effect."
