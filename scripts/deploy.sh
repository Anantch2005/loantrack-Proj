#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NAMESPACE="loantrack"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-2}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-3g}"

echo "===================================="
echo " LoanTrack -> Minikube deployment"
echo "===================================="

# 0. Required tools
for tool in docker minikube kubectl; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: '$tool' is not installed or not in PATH"
    exit 1
  }
done

# 1. .env must exist
if [[ ! -f .env ]]; then
  echo "ERROR: .env file not found."
  echo "Run:  cp .env.example .env  and fill the values"
  exit 1
fi

# Load .env. tr -d '\r' removes Windows line endings so passwords
# never end with a hidden carriage-return character.
set -a
# shellcheck disable=SC1090
source <(tr -d '\r' < .env)
set +a

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is missing in .env}"
: "${DB_PASSWORD:?DB_PASSWORD is missing in .env}"

if [[ "$POSTGRES_PASSWORD" != "$DB_PASSWORD" ]]; then
  echo "ERROR: POSTGRES_PASSWORD and DB_PASSWORD must be the same in .env"
  exit 1
fi

# 2. Start minikube if it is not running
echo "[1/7] Ensuring Minikube is running..."
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker --cpus="$MINIKUBE_CPUS" --memory="$MINIKUBE_MEMORY"
fi

# Always talk to minikube, never to some other cluster in your kubeconfig
kubectl config use-context minikube >/dev/null

# 3. Build images inside minikube (manifests use imagePullPolicy: Never)
echo "[2/7] Building images inside Minikube..."
minikube image build -t loantrack-backend:v1  ./backend
minikube image build -t loantrack-frontend:v1 ./frontend
minikube image build -t loantrack-db:v1       ./db

# 4. Namespace
echo "[3/7] Applying namespace..."
kubectl apply -f k8s/namespace.yaml

# 5. ConfigMap + Secret (secret is created from .env, never stored in git)
echo "[4/7] Applying ConfigMap and Secret..."
kubectl apply -f k8s/configmap.yaml

kubectl create secret generic db-credentials \
  --namespace "$NAMESPACE" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# 6. Database first, and wait until it is ready
echo "[5/7] Deploying PostgreSQL (StatefulSet)..."
kubectl apply -f k8s/database.yaml
kubectl rollout status statefulset/db -n "$NAMESPACE" --timeout=180s

# 7. Backend, then frontend
echo "[6/7] Deploying backend and frontend..."
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl rollout status deployment/backend  -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=180s

# 8. Summary
echo "[7/7] Deployment complete!"
echo ""
kubectl get pods,svc,pvc -n "$NAMESPACE"
echo ""
echo "Open the app:"
echo "  Linux:                    http://$(minikube ip):30080"
echo "  Windows/macOS (docker driver) - run this and keep the terminal open:"
echo "                            minikube service frontend -n $NAMESPACE --url"
echo ""
echo "Useful commands:"
echo "  kubectl get all -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE -l app=backend"