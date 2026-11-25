#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NAMESPACE="loantrack"

echo "===================================="
echo " LoanTrack → Minikube Deployment"
echo "===================================="

# 1. Check .env
if [[ ! -f .env ]]; then
  echo "ERROR: .env file not found."
  echo "Run:  cp .env.example .env  and fill the values"
  exit 1
fi

set -a
source .env
set +a

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is missing in .env}"
: "${DB_PASSWORD:?DB_PASSWORD is missing in .env}"

# 2. Start Minikube if needed
echo "[1/7] Ensuring Minikube is running..."
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker --cpus=4 --memory=6g
fi

# 3. Build images inside Minikube
echo "[2/7] Building images inside Minikube..."
minikube image build -t loantrack-backend:v1  ./backend
minikube image build -t loantrack-frontend:v1 ./frontend
minikube image build -t loantrack-db:v1       ./db

# 4. Namespace
echo "[3/7] Applying namespace..."
kubectl apply -f k8s/namespace.yaml

# 5. Config + Secret
echo "[4/7] Applying ConfigMap and Secret..."
kubectl apply -f k8s/configmap.yaml

kubectl create secret generic db-credentials \
  --namespace "$NAMESPACE" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# 6. Database first
echo "[5/7] Deploying PostgreSQL (StatefulSet)..."
kubectl apply -f k8s/database.yaml
kubectl rollout status statefulset/db -n "$NAMESPACE" --timeout=180s

# 7. Backend + Frontend
echo "[6/7] Deploying Backend & Frontend..."
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml

kubectl rollout status deployment/backend  -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=180s

# 8. Summary
echo "[7/7] Deployment complete!"
echo ""
echo "Resources:"
kubectl get pods,svc,pvc -n "$NAMESPACE"
echo ""
echo "Frontend URL:"
minikube service frontend -n "$NAMESPACE" --url
echo ""
echo "Useful commands:"
echo "  kubectl get all -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE -l app=backend -