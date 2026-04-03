# Local setup on Windows

This guide is **Windows-only**. Follow it in order to run every backend service locally with Docker.

**What you run:** auth-service, user-management, aitechtap-assist, plan-payment-service, plus **Postgres** and **MongoDB**. The old monolith **`aitechtap-core`** is **not** in this stack.

---

## 1. What to install (checklist)

Install these before you clone code or run Docker.

| # | Software | Why you need it | Get it |
|---|-----------|-----------------|--------|
| 1 | **Git for Windows** | Clone repositories | [https://git-scm.com/download/win](https://git-scm.com/download/win) |
| 2 | **Docker Desktop for Windows** | Runs containers; includes Docker Compose | [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/) |
| 3 | **Windows Terminal** (optional but recommended) | Better tabs and copy/paste | Microsoft Store: “Windows Terminal” |

**During Docker Desktop setup**

- Turn on **WSL 2** if the installer asks (default on recent Windows).
- After install, open Docker Desktop once and wait until it says **Docker is running**.

**Only if you use the prebuilt image path** (Gradle on your PC instead of inside Docker — see [Troubleshooting](#7-troubleshooting-build--network)):

| # | Software | Why you need it |
|---|-----------|-----------------|
| 4 | **JDK 21** (Temurin or Oracle) | Host `gradlew bootJar` for each microservice repo |

**Optional**

| Software | Use |
|----------|-----|
| **Postman** or **curl** in PowerShell | Call APIs |
| **DBeaver** or **pgAdmin** | Inspect Postgres on port **5435** |
| **MongoDB Compass** | Inspect Mongo on port **27018** |

---

## 2. Folder layout on your PC

Docker Compose in **`aitechtap-docs`** expects the **microservice repos next to** `aitechtap-docs` (same parent folder). Example:

```text
C:\dev\aitechtap-core\          ← parent (name can be anything)
  aitechtap-docs\               ← this documentation repo (compose + scripts)
  auth-service\
  user-management\
  aitechtap-assist\
  plan-payment-service\
```

If `auth-service` (and the others) are missing or in a different place, **`build`** and **`up`** will fail when Compose looks for `..\..\auth-service` from `aitechtap-docs\local`.

---

## 3. Local URLs (from your browser or Postman)

Defaults use **`local/.env`** (copy from **`local/.env.example`**). If you change ports in `.env`, replace the port numbers below.

### Applications (HTTP)

| Service | Base URL | Notes |
|---------|----------|--------|
| **auth-service** | `http://localhost:8081` | Auth APIs |
| **user-management** | `http://localhost:8082` | User profile / internal APIs |
| **aitechtap-assist** | `http://localhost:8083` | Assist / AI-related APIs |
| **plan-payment-service** | `http://localhost:8084` | Plans / payments |

Inside Docker, services talk to each other with **service names** (e.g. `http://auth-service:8080`), **not** `localhost`.

### Swagger / OpenAPI (typical SpringDoc paths)

| Service | Swagger UI | OpenAPI JSON |
|---------|--------------|--------------|
| auth | `http://localhost:8081/swagger-ui/index.html` | `http://localhost:8081/v3/api-docs` |
| user-management | `http://localhost:8082/swagger-ui/index.html` | `http://localhost:8082/v3/api-docs` |
| assist | `http://localhost:8083/swagger-ui/index.html` | `http://localhost:8083/v3/api-docs` |
| plan-payment | `http://localhost:8084/swagger-ui/index.html` | `http://localhost:8084/v3/api-docs` |

If a path returns **401/403**, security may block anonymous access; use the app’s docs or a valid token.

### Health (Spring Boot Actuator)

| Check | URL |
|-------|-----|
| auth | `http://localhost:8081/actuator/health` |
| user-management | `http://localhost:8082/actuator/health` |
| assist | `http://localhost:8083/actuator/health` |
| plan-payment | `http://localhost:8084/actuator/health` |

### Databases (from host tools)

| Database | Host connection |
|----------|-----------------|
| **Postgres** | Host `localhost`, port **5435**, user/password per DB (see `local/postgres/init-databases.sql` and compose env) |
| **MongoDB** | `mongodb://localhost:27018` (no auth in this local stack) |

---

## 4. First-time setup (commands)

Open **Command Prompt** or **PowerShell**. Use the **`aitechtap-docs`** folder as your current directory.

### 4.1 Create `local\.env`

```bat
cd C:\path\to\your\aitechtap-docs
copy local\.env.example local\.env
```

Edit **`local\.env`** in Notepad if you need to change **JWT_SECRET** or internal passwords. For solo dev, defaults are enough to start.

### 4.2 Build images (first time or after code changes)

**Recommended on Windows (works even if `.ps1` opens in Notepad):**

```bat
scripts\docker-local.cmd build
```

First build can take **many minutes** (Gradle downloads dependencies inside Docker).

### 4.3 Start everything

```bat
scripts\docker-local.cmd up
```

### 4.4 Check containers

```bat
scripts\docker-local.cmd ps
```

You want **postgres**, **mongo**, and all four Java services **Up** (postgres/mongo often show **healthy**).

### 4.5 Logs

See **[section 9](#9-view-application-logs-for-each-service)** for tailing **all** logs or **one** service (Java apps, Postgres, Mongo).

### 4.6 Stop

```bat
scripts\docker-local.cmd down
```

To also delete database volumes (fresh DB next time):

```bat
scripts\docker-local.cmd down --volumes
```

---

## 5. PowerShell (if you prefer)

From **`aitechtap-docs`**:

```powershell
Copy-Item local\.env.example local\.env
.\scripts\docker-local.ps1 build
.\scripts\docker-local.ps1 up
```

If **`.\scripts\docker-local.ps1`** opens in **Notepad**, use **`scripts\docker-local.cmd`** instead, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\docker-local.ps1 build
```

---

## 6. Prebuilt build (optional)

If **Gradle inside Docker** cannot download from Maven (firewall/DNS), build JARs on Windows and use prebuilt images:

```bat
scripts\docker-local.cmd -Prebuilt build
scripts\docker-local.cmd -Prebuilt up
```

Requires **JDK 21** and **Docker Compose 2.17+**. See **`local/README.md`** for details.

---

## 7. Troubleshooting (build / network)

1. **Docker must be running** (whale icon in the system tray, Docker Desktop says “Running”).
2. **`Could not GET repo.maven.apache.org`**: fix **Docker Desktop → Settings → Docker Engine** DNS, e.g. `"dns": ["8.8.8.8","1.1.1.1"]`, apply, restart Docker. Or set **`HTTP_PROXY` / `HTTPS_PROXY`** in **`local\.env`** (see **`.env.example`**).
3. **Port already in use**: change the matching `*_HOST_PORT` in **`local\.env`**, then **`down`** and **`up`** again.
4. **Gradle on host fails with “Unable to delete directory …\build\…”**: close the IDE for those folders, run `gradlew.bat --stop`, or pause OneDrive on the repo; then try **`-Prebuilt`** again or use normal **`build`** inside Docker.

More detail: **`local/README.md`**.

---

## 8. Quick reference — default ports

| Port | Service |
|------|---------|
| 8081 | auth-service |
| 8082 | user-management |
| 8083 | aitechtap-assist |
| 8084 | plan-payment-service |
| 5435 | Postgres (maps to 5432 in the container) |
| 27018 | MongoDB (maps to 27017 in the container) |

---

## 9. View application logs for each service

Run these from the **`aitechtap-docs`** folder (same as **`build`** / **`up`**). Logs are whatever the process prints to **stdout** in the container (Spring Boot lines, SQL errors, stack traces).

### 9.1 All services at once (follow / tail)

Stream logs from **every** container until you press **Ctrl+C**:

```bat
scripts\docker-local.cmd logs
```

This is the same as `docker compose logs -f` for the local stack.

### 9.2 One service at a time (recommended)

Pass the **Compose service name** (middle column below). Still follows live output until **Ctrl+C**:

```bat
scripts\docker-local.cmd logs auth-service
scripts\docker-local.cmd logs user-management
scripts\docker-local.cmd logs aitechtap-assist
scripts\docker-local.cmd logs plan-payment-service
scripts\docker-local.cmd logs postgres
scripts\docker-local.cmd logs mongo
```

| Compose service name | What it is |
|----------------------|------------|
| `auth-service` | Auth Spring Boot app |
| `user-management` | User management Spring Boot app |
| `aitechtap-assist` | Assist Spring Boot app |
| `plan-payment-service` | Plan / payment Spring Boot app |
| `postgres` | Postgres database server |
| `mongo` | MongoDB server |

### 9.3 Last N lines only (no follow)

Compose accepts extra flags after the service name. Examples from **`aitechtap-docs\local`**:

```bat
cd local
docker compose --env-file .env -f docker-compose.yml logs --tail 200 auth-service
docker compose --env-file .env -f docker-compose.yml logs --tail 100 postgres
```

Or stay in **`aitechtap-docs`** and use the script (forwarding works the same):

```bat
scripts\docker-local.cmd logs --tail 200 auth-service
```

### 9.4 Prebuilt stack (`-Prebuilt`)

If you started the stack with **`scripts\docker-local.cmd -Prebuilt up`**, use **`-Prebuilt`** on logs too so the same Compose file is used:

```bat
scripts\docker-local.cmd -Prebuilt logs auth-service
```

### 9.5 PowerShell equivalent

```powershell
.\scripts\docker-local.ps1 logs user-management
.\scripts\docker-local.ps1 -Prebuilt logs aitechtap-assist
```

### 9.6 Docker Desktop

**Docker Desktop → Containers** → select a container → **Logs** tab. Names look like `aitechtap-local-auth-service-1` (project prefix + service + number).

### 9.7 Raw `docker logs` (by container name)

List running containers:

```bat
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Then:

```bat
docker logs -f aitechtap-local-auth-service-1
docker logs --tail 100 aitechtap-local-user-management-1
```

Replace the name with what **`docker ps`** shows for the service you care about.

---

## 10. Related docs

| Doc | Content |
|-----|---------|
| [README.md](./README.md) | Stack overview, scripts table, deeper troubleshooting |
| [../GETTING-STARTED.md](../GETTING-STARTED.md) | Gradle, tests, legacy monolith note |
| [../README.md](../README.md) | Full documentation index |
