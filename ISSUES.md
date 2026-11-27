# Issues

This document records development and deployment issues encountered during the LoanTrack project, their impact, and the fixes or verification performed.

## 1. Line Ending Mismatch (CRLF vs LF)

**Problem:**

Windows uses CRLF (`\r\n`) line endings, while Linux and macOS use LF (`\n`). When files created on Windows are used inside Linux containers, carriage-return characters can cause compatibility problems.

Potential symptoms include:

- Shell scripts failing with `/bin/bash\r: bad interpreter: No such file or directory`.
- Environment values containing unexpected trailing `\r` characters.
- `grep`, `diff`, and `sed` commands failing to match expected patterns.
- Configuration and deployment scripts behaving differently across environments.

**Fix:**

Add a `.gitattributes` file at the repository root:

```gitattributes
* text=auto eol=lf
*.sh text eol=lf
```

This configures Git to normalize text files and enforce LF endings for shell scripts.

After adding the file, normalize tracked files if required:

```bash
git add --renormalize .
git status
```

Commit the updated files after reviewing the changes.

**Status:** Fix configured through Git attributes.

---

## 2. Backend Starts Before PostgreSQL Is Ready

**Problem:**

The backend depends on PostgreSQL, but Docker containers can start before the database is ready to accept connections.

During testing, the backend attempted to connect while the database service was unavailable. This initially caused DNS/connection errors such as:

```text
Name or service not known
```

Without retry handling, a temporary database startup delay could prevent the backend from becoming operational.

**Fix:**

Implement connection retry logic with exponential backoff in the backend startup process.

The retry sequence observed in the logs included:

```text
Retrying database connection in 2 seconds
Retrying database connection in 4 seconds
Retrying database connection in 8 seconds
Retrying database connection in 16 seconds
```

After PostgreSQL became available, the backend successfully initialized its connection pool:

```text
PostgreSQL connection pool initialized
```

**Verification:**

- Started the backend while PostgreSQL was unavailable.
- Observed retry attempts and increasing delays.
- Started the database service.
- Confirmed successful connection-pool initialization.

**Status:** Retry and recovery behavior tested successfully.

---

## 3. Database Data Must Survive Container and Pod Restarts

**Problem:**

Containerized databases can lose data if their storage is tied only to a temporary container filesystem. Similarly, a Kubernetes database pod can be recreated with a fresh filesystem if persistent storage is not configured correctly.

This is especially important for LoanTrack because loan records must remain available after service restarts and pod recovery.

**Fix:**

- Docker Compose: use a named volume for PostgreSQL data.
- Kubernetes: use a PersistentVolumeClaim attached to the PostgreSQL StatefulSet.
- Avoid deleting persistent volumes when restarting application services.

**Verification:**

Docker Compose:
- Added a loan record through the application.
- Restarted the Compose services.
- Queried PostgreSQL again.
- Confirmed that the record remained present.

Kubernetes:
- Confirmed the PostgreSQL PVC was `Bound`.
- Deleted the PostgreSQL pod.
- Waited for the StatefulSet to recreate it.
- Queried the database again.
- Confirmed that the existing records remained present.

**Status:** Persistence tested in Docker Compose and Kubernetes.

**Note:** Verify the loan amount in the Kubernetes test data before using the screenshot as final submission evidence.

---

## 4. Liveness and Readiness Must Be Checked Separately

**Problem:**

A running backend process does not necessarily mean the application is ready to serve requests. The backend may still be running even when its database dependency is unavailable.

Using only one health endpoint can incorrectly report an application as fully ready.

**Fix:**

Use separate endpoints:

- `/api/healthz` checks whether the application process is alive.
- `/api/readyz` checks whether the application can serve requests, including database connectivity.

**Verification:**

With PostgreSQL stopped, the observed responses were:

```text
/api/healthz
HTTP 200
{"status":"alive"}
```

```text
/api/readyz
HTTP 503
{"detail":"Database unavailable"}
```

After restarting PostgreSQL, readiness could be checked again.

**Status:** Liveness and readiness behavior tested.

---

## Summary

| Issue | Resolution |
|---|---|
| CRLF vs LF line endings | Configured Git attributes |
| Backend starts before database | Retry with exponential backoff |
| Database data loss risk | Named volume and Kubernetes PVC |
| Incorrect health reporting | Separate liveness and readiness endpoints |
