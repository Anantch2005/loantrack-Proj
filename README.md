# LoanTrack — Three-Tier Application | DevOps & SRE Assignment

A containerized loan management application deployed using Docker Compose and Kubernetes (Minikube). This project demonstrates containerization, service communication, database persistence, health checks, deployment automation, Kubernetes operations, and Git-based development workflow.

## Project Overview

LoanTrack is a three-tier application consisting of:

- **Frontend:** Static HTML application served through Nginx.
- **Backend:** Python FastAPI application providing REST APIs.
- **Database:** PostgreSQL for persistent loan records.

The frontend communicates with the backend over HTTP. The backend communicates with PostgreSQL using environment-based configuration and connection pooling.

The same application is packaged and executed in two environments:

1. Docker Compose for local container orchestration.
2. Kubernetes using Minikube for deployment and operational testing.

The focus of this assignment is infrastructure, containerization, networking, reliability, deployment, and operational practices rather than application complexity.

## Architecture

### Application Architecture

```text
                    User / Browser
                          |
                          | HTTP :8080
                          v
                 +-------------------+
                 |     Frontend      |
                 |   Nginx / HTML    |
                 +-------------------+
                          |
                          | HTTP API
                          v
                 +-------------------+
                 |      Backend      |
                 |   Python FastAPI  |
                 |      :8000        |
                 +-------------------+
                          |
                          | PostgreSQL :5432
                          v
                 +-------------------+
                 |    PostgreSQL     |
                 |     Database      |
                 +-------------------+
                          |
                          v
                 +-------------------+
                 | Persistent Storage|
                 |  Docker Volume /  |
                 |   Kubernetes PVC  |
                 +-------------------+
```

### Docker Compose Architecture

```text
Browser
   |
   | localhost:8080
   v
Frontend Container (Nginx)
   |
   | Docker user-defined network
   | backend:8000
   v
Backend Container (FastAPI)
   |
   | Docker user-defined network
   | db:5432
   v
PostgreSQL Container
   |
   v
Named Docker Volume
```

Docker Compose services communicate using service names instead of hardcoded container IP addresses or localhost.

### Kubernetes Architecture

```text
                    Browser
                       |
                       | NodePort :30080
                       v
              +--------------------+
              | Frontend Service   |
              | NodePort           |
              +--------------------+
                       |
                       v
              +--------------------+
              | Frontend Deployment|
              +--------------------+

                       |
                       | HTTP API
                       v

              +--------------------+
              | Backend Service    |
              | ClusterIP :8000    |
              +--------------------+
                       |
                       v
              +--------------------+
              | Backend Deployment |
              | 3 Replicas         |
              +--------------------+
                       |
                       | db.loantrack.svc.cluster.local
                       v
              +--------------------+
              | Database Service   |
              | ClusterIP :5432    |
              +--------------------+
                       |
                       v
              +--------------------+
              | PostgreSQL         |
              | StatefulSet        |
              +--------------------+
                       |
                       v
              +--------------------+
              | PersistentVolume   |
              | Claim (PVC)        |
              +--------------------+
```

All application resources are deployed inside the `loantrack` namespace. The backend and database are exposed internally using ClusterIP services. Only the frontend is exposed outside the cluster through NodePort.

## Technology Stack

| Component | Technology |
|---|---|
| Frontend | HTML, JavaScript, Nginx |
| Backend | Python, FastAPI |
| Database | PostgreSQL |
| Containerization | Docker |
| Local orchestration | Docker Compose |
| Container registry | Local Docker images |
| Container orchestration | Kubernetes |
| Local Kubernetes cluster | Minikube |
| Kubernetes CLI | kubectl |
| Infrastructure configuration | Kubernetes YAML |
| Deployment automation | Bash, Makefile |
| Version control | Git, GitHub |

### Development Environment

The project was developed and tested on Windows using WSL Ubuntu.

| Tool | Version |
|---|---|
| Operating system | Windows with WSL Ubuntu 22.04.5 |
| Kubernetes version | v1.35.1 |
| kubectl version | v1.35.5 |
| Minikube | v1.38.1 |
| Docker | 29.1.3 |
| Docker Compose | v5.4.0 |
| Python | 3.10.12 |

Get the exact installed versions using:

```bash
docker --version
docker compose version
minikube version
kubectl version --client
python3 --version
```

## Repository Structure

```text
loantrack/
│
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   ├── database.py
│   │   └── main.py
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
│
├── db/
│   ├── migrations/
│   │   └── 001_create_loans.sql
│   ├── seeds/
│   │   └── 002_seed_loans.sql
│   └── Dockerfile
│
├── frontend/
│   ├── index.html
│   ├── nginx.conf
│   └── Dockerfile
│
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.example.yaml
│   ├── backend.yaml
│   ├── database.yaml
│   └── frontend.yaml
│
├── scripts/
│   └── deploy.sh
│
├── screenshots/
├── docker-compose.yml
├── Makefile
├── .dockerignore
├── .gitattributes
├── .gitignore
├── .env.example
├── AI_USAGE.md
├── BRANCHING.md
├── EVIDENCE.md
├── ISSUES.md
└── README.md
```

The actual repository also contains the local Kubernetes Secret file when created for deployment. It must remain excluded from Git.

## Application Features

### Frontend

- Displays loan records.
- Provides a form to add new loans.
- Communicates with the backend through HTTP API requests.
- Does not connect directly to PostgreSQL.
- Does not contain database credentials or connection strings.

### Backend

The FastAPI backend provides loan management APIs and health-check endpoints.

| Endpoint | Purpose |
|---|---|
| `GET /loans` | Retrieve loan records |
| `POST /loans` | Add a loan |
| `GET /healthz` | Check whether the application process is alive |
| `GET /readyz` | Check whether the database is reachable |

The frontend uses the configured Nginx API proxy. The exact externally accessed API path can differ from the backend route.

The backend also includes database connection pooling and retry handling with backoff during startup.

### Database

PostgreSQL stores loan information in a `loans` table.

The schema is maintained in:

```text
db/migrations/001_create_loans.sql
```

Seed data is maintained in:

```text
db/seeds/002_seed_loans.sql
```

The database initialization process applies the SQL initialization files automatically.

The application starts with at least five sample loan records.

## Docker Compose Deployment

### Prerequisites

Install:

- Docker Engine
- Docker Compose plugin
- Git

### 1. Clone the repository

```bash
git clone https://github.com/Anantch2005/loantrack-Proj.git

cd loantrack-Proj
```

### 2. Configure environment variables

Copy the example environment file:

```bash
cp .env.example .env
```

Update the local `.env` file with appropriate development values.

The `.env` file is excluded from Git and must never be committed.

### 3. Build and start all services

```bash
docker compose up -d --build
```

### 4. Verify running containers

```bash
docker compose ps
```

All three application services should become healthy.

### 5. Open the application

```text
http://localhost:8080
```

### 6. Test the backend

```bash
curl http://localhost:8080/api/healthz
```

```bash
curl -i http://localhost:8080/api/readyz
```

```bash
curl http://localhost:8080/api/loans
```

These frontend-proxied API paths should be checked against the configured Nginx routes.

### 7. Verify non-root execution

```bash
docker compose exec backend whoami
docker compose exec frontend whoami
```

The expected configured users are:

- Backend: `app`
- Frontend: `nginx`

### 8. Inspect container images

```bash
docker images
```

The backend image is designed to remain below the assignment's 300 MB limit.

### 9. Stop the application

```bash
docker compose down
```

Start it again:

```bash
docker compose up -d
```

PostgreSQL data is retained because the database uses a named Docker volume.

**Volume removal:** Running `docker compose down -v` removes the Compose-managed named volume as well as the containers and networks. Database data stored in that volume is deleted.

## Kubernetes Deployment — Minikube

### Prerequisites

Install:

- Docker
- Minikube
- kubectl
- Git
- Make

### 1. Start Minikube

```bash
minikube start --driver=docker
```

Verify the cluster:

```bash
kubectl get nodes
```

### 2. Configure Kubernetes Secret

The project provides:

```text
k8s/secret.example.yaml
```

Create a local Secret manifest using the example and replace the dummy values with local development credentials.

```bash
cp k8s/secret.example.yaml k8s/secret.yaml
```

Apply the Secret only after configuring the correct values:

```bash
kubectl apply -f k8s/secret.yaml
```

The real Secret manifest must remain Git-ignored. Never commit real database credentials.

An alternative is to create the Secret using `kubectl create secret generic` with the exact key names expected by the Kubernetes manifests.

### 3. Deploy the application

The project includes a deployment script and Makefile.

Run:

```bash
make deploy
```

Alternatively:

```bash
./scripts/deploy.sh
```

The deployment automation is designed to:

1. Build the application images inside the Minikube environment.
2. Apply the Kubernetes namespace.
3. Apply configuration and Secret resources.
4. Deploy the PostgreSQL StatefulSet and storage.
5. Deploy the backend and frontend.
6. Create the required services.
7. Wait for the deployments to become ready.
8. Print the frontend access URL.

The deployment script should be safe to run again to reconcile the declared resources with the cluster.

### 4. Verify Kubernetes resources

```bash
kubectl get all -n loantrack
```

Check persistent storage:

```bash
kubectl get pvc -n loantrack
```

Check configuration resources:

```bash
kubectl get configmap,secret -n loantrack
```

### 5. Access the frontend

The frontend is exposed through NodePort `30080`.

Run:

```bash
minikube service frontend -n loantrack
```

This opens the frontend service using the URL provided by Minikube.

The NodePort is configured as `30080`; the local URL or tunnel port may vary depending on the Minikube environment.

### 6. Kubernetes resource configuration

The Kubernetes manifests are stored under:

```text
k8s/
```

They define:

- `loantrack` namespace.
- Backend Deployment.
- Frontend Deployment.
- PostgreSQL StatefulSet.
- Backend ClusterIP Service.
- Database ClusterIP Service.
- Frontend NodePort Service.
- ConfigMap.
- Secret configuration.
- PersistentVolumeClaim.
- Resource requests and limits.
- Health probes.

### 7. Database DNS resolution

The backend connects to PostgreSQL using the Kubernetes Service DNS name.

Fully qualified DNS name:

```text
db.loantrack.svc.cluster.local
```

Test DNS resolution from a database pod:

```bash
kubectl exec -n loantrack db-0 -- \
  getent hosts db.loantrack.svc.cluster.local
```

The backend uses the database Service name rather than a hardcoded pod IP.

### 8. Scale the backend

Scale the backend to three replicas:

```bash
kubectl scale deployment/backend --replicas=3 -n loantrack
```

Wait for the rollout:

```bash
kubectl rollout status deployment/backend -n loantrack
```

Check the pods:

```bash
kubectl get pods -n loantrack
```

Multiple backend pods allow the service to distribute requests between available replicas.

The API response includes the serving pod identifier through `served_by`, which can be used to verify that multiple replicas handle requests.

### 9. Rolling update and rollback

Build the updated backend image:

```bash
minikube image build -t loantrack-backend:v2 ./backend
```

Update the Deployment image:

```bash
kubectl set image deployment/backend \
  backend=loantrack-backend:v2 -n loantrack
```

Check the rollout:

```bash
kubectl rollout status deployment/backend -n loantrack
```

Rollback:

```bash
kubectl rollout undo deployment/backend -n loantrack
```

Verify the rollback:

```bash
kubectl rollout status deployment/backend -n loantrack
```

During a rolling update, Kubernetes replaces old pods with new pods according to the Deployment strategy. The rolling update configuration, readiness probes, and `maxUnavailable`/`maxSurge` settings control how available replicas are maintained during the update.

### 10. Backend pod recovery

Delete a backend pod:

```bash
kubectl get pods -n loantrack
```

```bash
kubectl delete pod <backend-pod-name> -n loantrack
```

Check the replacement:

```bash
kubectl get pods -n loantrack -w
```

The Deployment controller creates replacement pods to maintain the desired replica count.

### 11. Database pod recovery and persistence

Check database records before deleting the pod.

Delete the PostgreSQL pod:

```bash
kubectl delete pod db-0 -n loantrack
```

Wait for it to become ready:

```bash
kubectl get pods -n loantrack -w
```

Check the database records again.

The StatefulSet recreates the database pod and reattaches its persistent volume claim, allowing stored records to survive pod replacement.

### 12. Final Kubernetes inventory

```bash
kubectl get all -n loantrack
```

```bash
kubectl get pvc,configmap,secret -n loantrack
```

These commands provide the final resource and configuration inventory for the application namespace.

## Design Decisions

### 1. Backend Base Image

The backend uses a pinned Python slim image rather than a generic full-sized Python image. The slim image reduces the runtime footprint while retaining the Python environment required by FastAPI.

### 2. Docker Layer Caching

Dependency files are copied and installed before application source code.

This separates dependency installation from frequently changing source code, allowing Docker to reuse the dependency layer when only application code changes.

### 3. PostgreSQL StatefulSet

PostgreSQL is deployed as a StatefulSet with persistent storage.

A StatefulSet provides stable pod identity and works naturally with persistent volume claims. It is appropriate for a stateful database workload where storage must remain associated with the database instance after pod recreation.

### 4. Liveness vs Readiness

Liveness checks whether the application process is alive.

Readiness checks whether the application is able to serve requests, including whether its database dependency is reachable.

This separation prevents a temporary database outage from being treated as an application process failure.

### 5. CPU Limits vs Memory Limits

CPU limits throttle a container when it tries to consume more CPU than its configured limit.

Memory limits are enforced differently: a container exceeding its memory limit can be terminated by the operating system with an OOM kill.

Resource requests are used by Kubernetes for scheduling, while limits constrain resource consumption.

### 6. Kubernetes Secrets and Base64

Kubernetes Secret values are commonly represented using Base64 encoding. Base64 is an encoding mechanism, not encryption.

For production, I would use encryption at rest for Kubernetes Secrets, restrict access through RBAC, and integrate a dedicated secrets manager such as HashiCorp Vault or a cloud secrets management service.

### 7. Service Discovery

Docker Compose services use service names on a user-defined network.

Kubernetes workloads use Service DNS names. This avoids relying on dynamically assigned container or pod IP addresses.

### 8. Persistent Storage

Docker Compose uses a named PostgreSQL volume.

Kubernetes uses a PersistentVolumeClaim associated with the PostgreSQL StatefulSet.

Both approaches keep database data outside the disposable application container lifecycle.

## Health Checks and Reliability

The backend exposes separate health endpoints.

| Endpoint | Purpose | Expected behavior |
|---|---|---|
| `/healthz` | Process liveness | Returns success while the application process is alive |
| `/readyz` | Application readiness | Returns an error when PostgreSQL is unavailable |

When PostgreSQL is unavailable:

- The liveness endpoint should remain successful if the backend process is still alive.
- The readiness endpoint should return an unsuccessful HTTP status.
- The backend startup process retries database connection attempts with increasing delays.
- Once PostgreSQL becomes available, the backend initializes its connection pool.

Kubernetes liveness and readiness probes use these application health checks to manage pod health and traffic eligibility.

## Deployment Automation

The repository includes:

```text
Makefile
scripts/deploy.sh
```

The deployment command is:

```bash
make deploy
```

It is intended to provide a repeatable local deployment workflow without requiring the reviewer to manually build and apply each manifest individually.

The deployment script builds the images inside Minikube, applies resources in the required order, waits for workload readiness, and prints the frontend URL.

## Git Workflow

The repository follows a feature-branch workflow with two long-lived branches:

- `main`: Stable, deployable branch.
- `develop`: Integration branch.

Feature branches are used for isolated development and merged into `develop` through pull requests.

The project includes feature branches for application development, Kubernetes implementation, and Git workflow work. Documentation is maintained separately.

Meaningful commits describe the purpose of each implementation step.

See [BRANCHING.md](BRANCHING.md) for the detailed branching strategy.

Release tags:

| Tag | Milestone |
|---|---|
| `v1.0.0` | Docker Compose implementation |
| `v1.1.0` | Kubernetes implementation |

## Issues and Troubleshooting

During implementation, issues related to container startup, service connectivity, database readiness, and persistence were investigated and tested.

The detailed symptoms, diagnosis commands, root causes, and fixes are documented in:

[ISSUES.md](ISSUES.md)

## Evidence and Validation

The implementation was validated using Docker Compose and a local Minikube cluster.

Evidence includes:

- Container health and service status.
- Backend and frontend non-root execution.
- Database seed records.
- Database connection retry behavior.
- Liveness and readiness behavior.
- Persistence after Docker Compose restart.
- Kubernetes resource status and persistent volume claims.
- Kubernetes database DNS resolution.
- Backend scaling and load distribution.
- Rolling update and rollback.
- Backend pod recreation.
- PostgreSQL pod recreation with persistent data.

See [EVIDENCE.md](EVIDENCE.md) for the actual commands and observed outputs.

Application screenshots are available in:

```text
screenshots/
```

## AI Usage

AI tools were used as development assistants for planning, code generation, Docker and Kubernetes configuration, troubleshooting, shell scripting, and documentation.

Generated suggestions were reviewed and tested in the local environment. I was responsible for integrating the components, executing the deployment steps, investigating failures, and verifying the results.

See [AI_USAGE.md](AI_USAGE.md) for the detailed breakdown of AI assistance and my changes.

## Assumptions and Limitations

- This project is intended for local development and assessment, not production deployment.
- Minikube is used as the local Kubernetes environment.
- The PostgreSQL instance runs as a single StatefulSet replica; this does not provide database high availability.
- Kubernetes Secrets require additional security controls for production use.
- Local NodePort access depends on the Minikube networking environment.
- The deployment uses local images and does not require a public container registry.
- Production deployment would additionally require monitoring, centralized logging, automated CI/CD, stronger secret management, backup and recovery procedures, and database high availability.

## Demo Video

A screen recording demonstrates the running Kubernetes application, Kubernetes manifest configuration, and a live Kubernetes operational task.

**Video:** https://drive.google.com/file/d/1S8RFURh4hLOR4yFpxW5qi_8xhA6XexlL/view?usp=drivesdk

## Author

**Anant Chaudhary**

GitHub: https://github.com/Anantch2005

Repository: https://github.com/Anantch2005/loantrack-Proj

---

This project was developed as part of the Site Reliability Engineer / DevOps Intern Round 1 take-home technical assignment.