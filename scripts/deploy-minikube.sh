
#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NAMESPACE="loantrack"

echo "===================================="
echo " LoanTrack Minikube Deployment"
echo "===================================="

if [[ ! -f .env ]]; then
    echo "ERROR: .env not found."
    echo "Run: cp .env.example .env"
    exit 1
fi

set -a
source .env
set +a

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is missing in .env}"
: "${DB_PASSWORD:?DB_PASSWORD is missing in .env}"

echo "[1/7] Starting Minikube..."

if ! minikube status >/dev/null 2>&1; then
    minikube start --driver=docker --cpus=4 --memory=6g
fi

echo "[2/7] Building application images inside Minikube..."

minikube image build -t loantrack-backend:v1 ./backend
minikube image build -t loantrack-frontend:v1 ./frontend
minikube image build -t loantrack-db:v1 ./db

echo "[3/7] Creating namespace..."

kubectl apply -f k8s/namespace.yaml

echo "[4/7] Applying configuration and credentials..."

kubectl apply -f k8s/configmap.yaml

kubectl create secret generic db-credentials \
    --namespace "$NAMESPACE" \
    --from-literal=DB_PASSWORD="$DB_PASSWORD" \
    --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "[5/7] Deploying PostgreSQL..."

kubectl apply -f k8s/database.yaml

kubectl rollout status statefulset/db \
    -n "$NAMESPACE" --timeout=180s

echo "[6/7] Deploying backend and frontend..."

kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml

kubectl rollout status deployment/backend \
    -n "$NAMESPACE" --timeout=180s

kubectl rollout status deployment/frontend \
    -n "$NAMESPACE" --timeout=180s

echo "[7/7] Deployment complete!"

echo ""
echo "Kubernetes resources:"
kubectl get pods,svc,pvc -n "$NAMESPACE"

echo ""
echo "Frontend URL:"
minikube service frontend -n "$NAMESPACE" --url
