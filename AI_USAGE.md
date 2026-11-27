# AI Usage Log

AI tools were used throughout the development of LoanTrack to assist with project planning, implementation, configuration, debugging, and documentation.

I used ChatGPT and Claude as development assistants. However, AI-generated code was not blindly accepted. I reviewed suggestions, modified configurations where necessary, integrated the components, and validated the implementation by running the application and testing it locally and in Minikube.

## 1. AI Assistance and Modifications

| Task | Tool | Accepted as-is | Changed and why |
|---|---|---|---|
| Backend Dockerfile | ChatGPT | Multi-stage build structure and layer organization | Changed `python:3.12` to `python:3.12-slim` and added an explicit non-root `USER` |
| `docker-compose.yml` | ChatGPT | Service definitions and healthcheck syntax | Added `depends_on: condition: service_healthy` to control startup ordering |
| Kubernetes Deployment YAML | ChatGPT | Probe and resource configuration suggestions | Replaced `latest` with the pinned `v1` image tag and added `initialDelaySeconds` to the liveness probe |
| Retry logic (Part C) | Claude | Exponential backoff approach | Replaced fixed-delay retry behavior with exponential delays of 2, 4, 8, and 16 seconds |
| PostgreSQL StatefulSet | Claude | `volumeClaimTemplates` structure | Added the required `serviceName` configuration |

## 2. Where AI Was Wrong or Misleading

The following examples describe cases where AI-generated suggestions needed review or modification.

### 2.1 Docker Compose Startup Dependency

**AI suggestion:** Use `depends_on` without `condition: service_healthy`.

**Problem:** Container startup ordering alone does not guarantee that PostgreSQL is ready to accept connections.

**My modification:** Added the health-based dependency condition and retained application-level database retry logic.

### 2.2 Dockerfile Layer Caching

**AI suggestion:** Copy the complete application using `COPY . .` before installing Python dependencies.

**Problem:** Changes to application source files can invalidate the dependency installation layer and cause unnecessary package reinstallation.

**My modification:** Reordered the Dockerfile to copy dependency files and install packages before copying the remaining application source.

### 2.3 Kubernetes Secret Configuration

**AI suggestion:** Use the `data` field with manually Base64-encoded values.

**Problem:** Manually encoding values makes example configuration less readable and increases the chance of encoding mistakes.

**My modification:** Used `stringData` for readable secret configuration. For production environments, secret-management solutions such as SOPS or Vault should be considered.

## 3. AI-Assisted Debugging

AI was also used to investigate implementation and deployment problems, including:

- Backend startup failures when PostgreSQL was unavailable.
- Database connection retry and backoff behavior.
- Docker container networking and service communication.
- Kubernetes DNS resolution.
- Persistent storage and database data retention.
- Liveness and readiness probe behavior.
- Kubernetes pod recovery and rollout/rollback operations.

Suggested fixes were reviewed and tested against the running environment.

## 4. My Implementation and Verification

My responsibility was to integrate the application components and validate the complete deployment workflow.

I personally performed the following tasks:

- Connected the frontend, backend REST API, and PostgreSQL database.
- Built and ran Docker images and Docker Compose services.
- Configured the Kubernetes resources and deployed the application to Minikube.
- Executed API requests and database queries.
- Tested database persistence after container and pod restarts.
- Verified backend retry behavior when PostgreSQL was unavailable.
- Tested liveness and readiness endpoints.
- Scaled backend replicas and checked responses from different pods.
- Tested backend pod recovery and deployment rollback.
- Reviewed terminal output and documented the observed results.

## 5. Responsible Use of AI

AI was used as a coding and troubleshooting assistant, not as a replacement for implementation or testing.

I reviewed generated code, modified configurations where necessary, and validated functionality using actual Docker commands, API responses, SQL queries, and Kubernetes resource status.

The final implementation was integrated and tested in my development environment. AI-generated suggestions were not treated as proof that a feature worked.

