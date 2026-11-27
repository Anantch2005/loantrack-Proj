# Issues faced

Three problems found while building and testing LoanTrack. Each one lists the symptom, how I diagnosed it, the root cause and the fix.

---

## Issue 1: Backend could not reach the database when it started first (connection error)

**Symptom**

When the backend container started before PostgreSQL, the log showed:

```text
WARNING Database unavailable: [Errno -2] Name or service not known. Retrying in 2 seconds.
```

Without retry handling the backend could not finish starting, and `/readyz` could not report a working database.

**Diagnosis** (commands run, in order)

```bash
docker compose stop frontend backend db
docker compose up -d --no-deps backend      # start ONLY the backend
docker compose logs backend                 # shows the "Name or service not known" errors
docker compose ps                           # the db container does not exist yet
docker compose up -d db
docker compose logs backend                 # shows the pool was initialized after the db came up
```

**Root cause**

With the `db` container absent, Docker's internal DNS cannot resolve the service name `db`, so every connection attempt fails with `Name or service not known`. This is a startup-ordering problem, not a wrong hostname.

**Fix**

- Backend: a background startup worker in `backend/app/database.py` retries the connection with exponential backoff (2, 4, 8, 16 seconds) and creates the connection pool as soon as the database answers. The API process stays alive, so `/healthz` keeps returning 200 while `/readyz` returns 503.
- Compose: `depends_on: condition: service_healthy` plus a `pg_isready` healthcheck on the database.
- Kubernetes: the backend `readinessProbe` uses `/readyz`, so a backend with no database is removed from the Service instead of being restarted.

The recovery log is in `evidence/01-docker.md`.

---

## Issue 2: The app URL stopped working after `minikube service ... --url` (Kubernetes access)

**Symptom**

```text
$ minikube service frontend -n loantrack --url
http://127.0.0.1:32841
!  Because you are using a Docker driver on linux, the terminal needs to be open to run it.
```

The command did not return, and the printed URL only worked while that terminal stayed open. The same URL did not work after closing it, and the port was different on every run.

**Diagnosis** (commands run, in order)

```bash
kubectl get pod -n loantrack            # all pods 1/1 Running, so the app itself was fine
kubectl get svc -n loantrack            # frontend NodePort 8080:30080/TCP
minikube service frontend -n loantrack --url
```

**Root cause**

With the Docker driver on WSL, the minikube node IP is not reachable from the host, so the NodePort (30080) cannot be opened directly. `minikube service` creates a temporary tunnel to a random local port, and the tunnel exists only while the command is running.

**Fix**

- Documented the exact command and the "keep this terminal open" rule in the README.
- `scripts/deploy.sh` prints the command at the end instead of running it, so the deploy script finishes and does not hang.
- For scripted checks, `scripts/collect-evidence-k8s.sh` uses `kubectl port-forward svc/frontend 18080:8080`, which does not depend on the minikube tunnel.

Screenshots: `screenshots/03-minikube-url.png`.

---

## Issue 3: The first deploy script was broken, and Windows line endings were in most files

**Symptom**

Reviewing `scripts/deploy-minikube.sh` from the Kubernetes branch:

- `bash -n scripts/deploy-minikube.sh` reported a syntax error (exit status 2) because the last line, an `echo` with an opening quote, was cut off and never closed.
- The file started with an empty line, so the `#!/usr/bin/env bash` shebang was on line 2, where the kernel ignores it.
- `file` reported CRLF (Windows) line endings in 22 of the repository's text files.

**Diagnosis** (commands run, in order)

```bash
bash -n scripts/deploy-minikube.sh            # syntax error, exit status 2
head -c 20 scripts/deploy-minikube.sh | xxd   # first byte is 0a (a blank line), shebang comes after it
tail -n 3 scripts/deploy-minikube.sh          # last line ends in the middle of a quoted string
find . -type f -not -name '*.pyc' | xargs file | grep -c CRLF    # 22
```

**Root cause**

The script was edited and copied on Windows. The editor and Git kept CRLF line endings, a blank line was added at the top, and the last line was cut off when the text was pasted. CRLF also breaks shell scripts (`bad interpreter`) and puts a hidden `\r` at the end of values read from `.env`.

**Fix**

- Replaced it with `scripts/deploy.sh`: shebang on line 1, complete last line, `bash -n` passes.
- Added `.gitattributes` (`* text=auto eol=lf` and `*.sh text eol=lf`) and normalised the repository with `git add --renormalize .`. The same check now finds 0 CRLF files.
- `deploy.sh` strips `\r` when it reads `.env`: `source <(tr -d '\r' < .env)`.
- Added `make deploy` as a second entry point.

Check: `bash -n scripts/deploy.sh` prints nothing and returns 0.

---

## Summary

| # | Problem | Root cause | Fix |
|---|---|---|---|
| 1 | Backend failed to connect when started before the DB | Docker DNS cannot resolve `db` while that container does not exist | Retry with exponential backoff, healthcheck with `service_healthy`, readiness probe on `/readyz` |
| 2 | App URL only worked while a terminal stayed open | Docker driver on WSL needs a temporary minikube tunnel | Documented the command, script prints it, `kubectl port-forward` for scripted checks |
| 3 | Truncated deploy script and CRLF line endings | Windows editing and copy-paste | New `deploy.sh`, `.gitattributes`, CR stripped from `.env` |