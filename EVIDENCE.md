# LoanTrack – Evidence

This document records the actual testing and verification performed for the LoanTrack application using Docker Compose and Kubernetes (Minikube).

The evidence includes application health, database connectivity, persistence, retry handling, Kubernetes deployment, scaling, rolling updates, rollback, and pod recovery.

---

# 1. Docker Compose

## Test A: Build and start all services

**Objective:** Verify that the frontend, backend, and PostgreSQL database can be built and started using Docker Compose.

**Command:**

```bash
docker compose up -d --build
```

**Output (summary):**

```text
[+] up 7/7
✔ Image loantrack-frontend:v1 Built
✔ Image loantrack-db:v1       Built
✔ Image loantrack-backend:v1  Built
✔ Network loantrack-proj_loantrack-net Created
✔ Container loantrack-db      Healthy
✔ Container loantrack-backend Healthy
✔ Container loantrack-frontend Started
```

**Verification:**

```bash
docker compose ps
```

**Output:**

```text
NAME                 IMAGE                   SERVICE    STATUS
loantrack-backend    loantrack-backend:v1    backend    Up (healthy)
loantrack-db         loantrack-db:v1         db         Up (healthy)
loantrack-frontend   loantrack-frontend:v1   frontend   Up (healthy)
```

**Result:** All three services started successfully. The backend and database passed their health checks, and the frontend started successfully.

## Test B: Verify application health and readiness

**Objective:** Verify that the application is alive and that the backend can communicate with PostgreSQL.

**Commands:**

```bash
curl -i http://localhost:8080/api/healthz
```

**Output:**

```http
HTTP/1.1 200 OK
Content-Type: application/json

{"status":"alive"}
```

Check database readiness:

```bash
curl -i http://localhost:8080/api/readyz
```

**Output:**

```http
HTTP/1.1 200 OK
Content-Type: application/json

{"status":"ready","database":"connected"}
```

**Result:** Both endpoints returned HTTP 200. The application was running and the database connection was established.

## Test C: Verify loan API and database records

**Objective:** Verify that the backend can retrieve loan records from PostgreSQL.

**Command:**

```bash
curl http://localhost:8080/api/loans
```

**Output (representative records):**

```json
{
  "loans": [
    {
      "id": 1,
      "borrower_name": "Rahul Sharma",
      "loan_amount": 2500000.0,
      "property_city": "Delhi",
      "status": "APPROVED"
    },
    {
      "id": 2,
      "borrower_name": "Priya Verma",
      "loan_amount": 1800000.0,
      "property_city": "Noida",
      "status": "PENDING"
    }
  ],
  "served_by": "e348f3cc8acc"
}
```

**Result:** The API successfully returned loan records from the database.

## Test D: Verify non-root container execution

**Objective:** Verify that the application containers do not run as root.

**Commands:**

```bash
docker compose exec backend whoami
docker compose exec frontend whoami
```

**Output:**

```text
app
nginx
```

**Result:** The backend runs as the `app` user and the frontend runs as the `nginx` user.

## Test E: Verify database persistence

**Objective:** Verify that loan records are stored in PostgreSQL and remain available after recreating the containers.

First, inspect the database:

```bash
docker compose exec db psql -P pager=off \
  -U loantrack_user \
  -d loantrack \
  -c "SELECT * FROM loans ORDER BY id;"
```

**Output:**

```text
 id | borrower_name | loan_amount | property_city | status
----+---------------+-------------+---------------+-----------
  1 | Rahul Sharma  | 2500000.00  | Delhi         | APPROVED
  2 | Priya Verma   | 1800000.00  | Noida         | PENDING
  3 | Amit Kumar    | 3200000.00  | Gurugram      | DISBURSED
  4 | Neha Singh    | 1500000.00  | Lucknow       | REJECTED
  5 | Vikash Gupta  | 2750000.00  | Jaipur        | PENDING
```

Add a new loan through the browser interface.

Then verify the database again:

```bash
docker compose exec db psql -P pager=off \
  -U loantrack_user \
  -d loantrack \
  -c "SELECT * FROM loans ORDER BY id;"
```

**Output (new record):**

```text
 6 | Anant Chaudhary | 50000000.00 | Ghaziabad | APPROVED
```

Stop and remove the containers:

```bash
docker compose down
```

Start the application again:

```bash
docker compose up -d
```

Verify the database:

```bash
docker compose exec db psql -P pager=off \
  -U loantrack_user \
  -d loantrack \
  -c "SELECT * FROM loans ORDER BY id;"
```

**Output:**

```text
 id | borrower_name  | loan_amount | property_city | status
----+----------------+-------------+---------------+-----------
  1 | Rahul Sharma   | 2500000.00  | Delhi         | APPROVED
  2 | Priya Verma    | 1800000.00  | Noida         | PENDING
  3 | Amit Kumar     | 3200000.00  | Gurugram      | DISBURSED
  4 | Neha Singh     | 1500000.00  | Lucknow       | REJECTED
  5 | Vikash Gupta   | 2750000.00  | Jaipur        | PENDING
  6 | Anant Chaudhary| 50000000.00  | Ghaziabad     | APPROVED
```

**Result:** The newly created loan remained in PostgreSQL after `docker compose down` and `docker compose up -d`. This verifies persistence through the configured Docker volume.

## Test F: Database retry and recovery

**Objective:** Verify that the backend retries its database connection when PostgreSQL is unavailable.

Stop all services:

```bash
docker compose stop frontend backend db
```

Start only the backend:

```bash
docker compose up -d --no-deps backend
```

Wait and inspect the logs:

```bash
sleep 8
docker compose logs backend
```

**Output (relevant log entries):**

```text
INFO Checking PostgreSQL connection...

WARNING Database unavailable:
[Errno -2] Name or service not known.
Retrying in 2 seconds.

INFO Checking PostgreSQL connection...

WARNING Database unavailable:
[Errno -2] Name or service not known.
Retrying in 4 seconds.

INFO Checking PostgreSQL connection...

WARNING Database unavailable:
[Errno -2] Name or service not known.
Retrying in 8 seconds.

INFO Checking PostgreSQL connection...

WARNING Database unavailable:
[Errno -2] Name or service not known.
Retrying in 16 seconds.
```

Start PostgreSQL again:

```bash
docker compose up -d db
```

Wait for the retry mechanism and inspect the backend logs:

```bash
sleep 10
docker compose logs backend
```

**Output:**

```text
2026-11-26 15:33:48,313 INFO
Checking PostgreSQL connection...

2026-11-26 15:33:48,326 INFO
PostgreSQL connection pool initialized.
```

**Result:** The backend continued retrying while PostgreSQL was unavailable and successfully initialized its connection pool after the database became available.

## Test G: Liveness versus readiness

**Objective:** Verify that application liveness and database readiness are handled independently.

Stop PostgreSQL:

```bash
docker compose stop db
```

Check application liveness:

```bash
curl -i http://localhost:8080/api/healthz
```

**Output:**

```http
HTTP/1.1 200 OK

{"status":"alive"}
```

Check database readiness:

```bash
curl -i http://localhost:8080/api/readyz
```

**Output:**

```http
HTTP/1.1 503 Service Unavailable

{"detail":"Database unavailable"}
```

Restart PostgreSQL:

```bash
docker compose start db
```

**Result:** The liveness endpoint continued returning HTTP 200 while the database was unavailable. The readiness endpoint correctly returned HTTP 503, indicating that the application was not ready to serve database-dependent requests.

---

# 2. Kubernetes (Minikube)

## Test A: Deploy the application

**Objective:** Deploy the complete LoanTrack application to a Kubernetes cluster.

**Command:**

```bash
make deploy
```

The deployment script performs the following operations:

1. Ensures Minikube is running.
2. Builds the application images inside Minikube.
3. Creates the `loantrack` namespace.
4. Applies ConfigMap and Secret resources.
5. Deploys PostgreSQL using a StatefulSet.
6. Deploys backend and frontend workloads.
7. Waits for the required workloads to become ready.

**Output (summary):**

```text
[1/7] Ensuring Minikube is running...
[2/7] Building images inside Minikube...
[3/7] Applying namespace...
namespace/loantrack created

[4/7] Applying ConfigMap and Secret...
configmap/loantrack-config created
secret/db-credentials created

[5/7] Deploying PostgreSQL (StatefulSet)...
statefulset.apps/db created

[6/7] Deploying backend and frontend...
deployment.apps/backend created
deployment.apps/frontend created

deployment "backend" successfully rolled out
deployment "frontend" successfully rolled out

[7/7] Deployment complete!
```

**Verify pods:**

```bash
kubectl get pods -n loantrack
```

**Output:**

```text
NAME                        READY   STATUS    RESTARTS
backend-586b86cbb4-l4trc    1/1     Running   0
db-0                        1/1     Running   0
frontend-76698dcdb6-v2sl5   1/1     Running   0
```

**Result:** All three application components were successfully deployed and reached the Running state.

## Test B: Verify Kubernetes services and persistent storage

**Objective:** Verify that the application services and database storage are correctly configured.

**Command:**

```bash
kubectl get services -n loantrack
```

**Output:**

```text
NAME       TYPE        CLUSTER-IP       PORT(S)
backend    ClusterIP   10.110.71.173    8000/TCP
db         ClusterIP   10.110.87.229    5432/TCP
frontend   NodePort    10.104.183.106   8080:30080/TCP
```

Check persistent volume claims:

```bash
kubectl get pvc -n loantrack
```

**Output:**

```text
NAME                       STATUS   CAPACITY   ACCESS MODES
postgres-storage-db-0      Bound    2Gi        RWO
```

Check application configuration:

```bash
kubectl get configmap,secret -n loantrack
```

**Output (relevant resources):**

```text
configmap/loantrack-config   6
secret/db-credentials       Opaque   2
```

**Result:** Backend and database use internal ClusterIP services, while the frontend is exposed through a NodePort service. PostgreSQL has a bound persistent volume claim.

## Test C: Verify Kubernetes DNS connectivity

**Objective:** Verify that the database service can be resolved using Kubernetes internal DNS.

**Command:**

```bash
kubectl exec -n loantrack db-0 -- \
  getent hosts db.loantrack.svc.cluster.local
```

**Output:**

```text
10.108.189.176 db.loantrack.svc.cluster.local
```

**Result:** Kubernetes DNS successfully resolved the database service name.

## Test D: Scale backend to three replicas

**Objective:** Verify that Kubernetes can scale the backend deployment horizontally.

**Command:**

```bash
kubectl scale deployment/backend --replicas=3 -n loantrack
```

**Output:**

```text
deployment.apps/backend scaled
```

Wait for the deployment:

```bash
kubectl rollout status deployment/backend -n loantrack
```

**Output:**

```text
deployment "backend" successfully rolled out
```

Verify backend pods:

```bash
kubectl get pods -n loantrack -l app=backend
```

**Output:**

```text
NAME                       READY   STATUS
backend-586b86cbb4-slws6   1/1     Running
backend-586b86cbb4-vtflp   1/1     Running
backend-586b86cbb4-zrcrg   1/1     Running
```

Verify API requests through the frontend service:

```bash
for i in {1..10}; do
  curl -s "http://127.0.0.1:43253/api/loans"
  echo
done
```

**Output (served_by values observed across the requests):**

```json
{"served_by":"backend-586b86cbb4-slws6"}
{"served_by":"backend-586b86cbb4-slws6"}
{"served_by":"backend-586b86cbb4-zrcrg"}
{"served_by":"backend-586b86cbb4-vtflp"}
```

The complete test produced responses from all three backend pod identities.

**Result:** The backend successfully scaled to three replicas. API requests were served by different backend pods, demonstrating service-level traffic distribution.

## Test E: Rolling update and rollback

**Objective:** Verify Kubernetes Deployment rollout and rollback functionality.

Build the second backend image:

```bash
minikube image build -t loantrack-backend:v2 ./backend
```

Update the backend deployment:

```bash
kubectl set image deployment/backend \
  backend=loantrack-backend:v2 \
  -n loantrack
```

**Output:**

```text
deployment.apps/backend image updated
```

Monitor the rollout:

```bash
kubectl rollout status deployment/backend -n loantrack
```

**Output:**

```text
deployment "backend" successfully rolled out
```

Rollback the deployment:

```bash
kubectl rollout undo deployment/backend -n loantrack
```

**Output:**

```text
deployment.apps/backend rolled back
```

Verify rollback:

```bash
kubectl rollout status deployment/backend -n loantrack
```

**Output:**

```text
deployment "backend" successfully rolled out
```

**Result:** Kubernetes successfully completed the deployment update and rollback operations.

Note: The recorded v1 and v2 image builds produced the same image digest. Therefore, this evidence demonstrates the Kubernetes rollout and rollback mechanism, but does not establish that a different application binary was deployed.

## Test F: Backend pod recovery

**Objective:** Verify that Kubernetes automatically replaces deleted backend pods.

Delete all backend pods:

```bash
kubectl delete pod -n loantrack \
  -l app=backend \
  --wait=false
```

**Output:**

```text
pod "backend-586b86cbb4-6w4vn" deleted
pod "backend-586b86cbb4-c79wk" deleted
pod "backend-586b86cbb4-w9vkl" deleted
```

Monitor replacement pods:

```bash
kubectl get pods -n loantrack -w
```

**Output:**

```text
backend-586b86cbb4-vd6pf   0/1   Running
backend-586b86cbb4-rrzc4   0/1   Running
backend-586b86cbb4-jr26d   0/1   Running

backend-586b86cbb4-vd6pf   1/1   Running
backend-586b86cbb4-rrzc4   1/1   Running
backend-586b86cbb4-jr26d   1/1   Running
```

**Result:** Kubernetes automatically created replacement backend pods and restored the desired three-replica state.

## Test G: PostgreSQL persistence and pod recovery

**Objective:** Verify that database records survive PostgreSQL pod deletion and recreation.

Inspect database records:

```bash
kubectl exec -n loantrack db-0 -- \
  psql -U loantrack_user -d loantrack \
  -c "SELECT * FROM loans;"
```

**Output:**

```text
id | borrower_name  | loan_amount    | property_city
---+----------------+----------------+--------------
1  | Rahul Sharma   | 2500000.00     | Delhi
2  | Priya Verma    | 1800000.00     | Noida
3  | Amit Kumar     | 3200000.00     | Gurugram
4  | Neha Singh     | 1500000.00     | Lucknow
5  | Vikash Gupta   | 2750000.00     | Jaipur
6  | Anant Chaudhary| 50000000.00 | Ghaziabad
```

Delete the PostgreSQL pod:

```bash
kubectl delete pod db-0 -n loantrack
```

**Output:**

```text
pod "db-0" deleted
```

Monitor the database pod:

```bash
kubectl get pods -n loantrack -w
```

**Output:**

```text
db-0   0/1   Running
db-0   1/1   Running
```

Verify database records again:

```bash
kubectl exec -n loantrack db-0 -- \
  psql -U loantrack_user -d loantrack \
  -c "SELECT * FROM loans;"
```

**Output:** The same six loan records were present after the database pod restarted.

**Result:** PostgreSQL was automatically recreated by its StatefulSet, and the existing database records remained available through the persistent volume.

## Test H: Final Kubernetes resource inventory

**Objective:** Verify the final state of all deployed Kubernetes resources.

**Command:**

```bash
kubectl get all -n loantrack
```

**Output:**

```text
NAME                        READY   STATUS
backend-586b86cbb4-jr26d   1/1     Running
backend-586b86cbb4-rrzc4   1/1     Running
backend-586b86cbb4-vd6pf   1/1     Running
db-0                       1/1     Running
frontend-76698dcdb6-5mb75  1/1     Running
```

Deployment status:

```text
NAME       READY   UP-TO-DATE   AVAILABLE
backend    3/3     3            3
frontend   1/1     1            1
```

StatefulSet:

```text
NAME   READY
db     1/1
```

Verify storage and configuration:

```bash
kubectl get pvc,configmap,secret -n loantrack
```

**Output (relevant resources):**

```text
persistentvolumeclaim/postgres-storage-db-0   Bound   2Gi   RWO

configmap/loantrack-config                    6

secret/db-credentials                         Opaque   2
```

**Result:** The final cluster state shows three healthy backend replicas, one frontend replica, one PostgreSQL StatefulSet pod, persistent storage, and the required configuration resources.

---

# 3. Assessment Summary

| Assessment area | Verification |
|---|---|
| Docker image builds | Verified |
| Docker Compose services | Verified |
| Container health checks | Verified |
| Non-root containers | Verified |
| Application health and readiness | Verified |
| PostgreSQL connectivity | Verified |
| Database connection retry | Verified |
| Docker volume persistence | Verified |
| Kubernetes deployment | Verified |
| ConfigMap and Secret | Verified |
| Kubernetes DNS | Verified |
| PostgreSQL StatefulSet and PVC | Verified |
| Backend horizontal scaling | Verified |
| Rolling update and rollback | Verified |
| Backend pod recovery | Verified |
| Database pod recovery | Verified |
| Kubernetes persistent data | Verified |

**Project:** LoanTrack

**Evidence date:** 26 November 2026
