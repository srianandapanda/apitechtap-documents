# Local Docker stack (all services)

Runs **auth-service**, **user-management**, **aitechtap-assist**, and **plan-payment-service** together with **Postgres** (one server, four databases) and **MongoDB** (for user-management). **aitechtap-core** is not part of this stack.

## Layout

| Service | Host URL | Container listens |
|--------|----------|-------------------|
| auth-service | http://localhost:**8081** | 8080 |
| user-management | http://localhost:**8082** | 8080 |
| aitechtap-assist | http://localhost:**8083** | 8080 |
| plan-payment-service | http://localhost:**8084** | 8080 |
| Postgres | localhost:**5435** → 5432 | — |
| MongoDB | localhost:**27018** → 27017 | — |

Inside Docker, services call each other with **service names** (e.g. `http://auth-service:8080`), not `localhost`.

## Quick start

From repository root **`aitechtap-docs`**:

```bash
cp local/.env.example local/.env
# Edit local/.env if you change secrets or ports

./scripts/docker-local.sh build
./scripts/docker-local.sh up
```

Windows **Command Prompt** (`cmd.exe`) — use **`docker-local.cmd`** (no `ls` / `chmod`; those are Unix/Git Bash only):

```bat
cd <your-clone>\aitechtap-docs
copy local\.env.example local\.env
scripts\docker-local.cmd build
scripts\docker-local.cmd up
```

Handy **cmd** equivalents: `dir` (not `ls`), `cd` (change directory; `echo %cd%` shows current folder).

Windows **PowerShell**:

```powershell
Set-Location <your-clone>\aitechtap-docs
Copy-Item local\.env.example local\.env
.\scripts\docker-local.ps1 build
.\scripts\docker-local.ps1 up
```

Stop everything:

```bash
./scripts/docker-local.sh down
```

## Commands

| Command | Action |
|--------|--------|
| `build` | `docker compose build` |
| `up` | `docker compose up -d` |
| `down` | `docker compose down` |
| `down --volumes` | `docker compose down -v` (wipes DB volumes) |
| `logs` | `docker compose logs -f` (optional service name) |
| `ps` | `docker compose ps` |

## Running apps on the host (without Docker)

Default **HTTP** ports in each service’s `application.yml` / `application.properties` match the table above (8081–8084). Use the same **Postgres** host port **5435** and **Mongo** **27018** if you point JDBC/Mongo URIs at the compose databases, or set your own URLs via environment variables.

## Notes

- First **Postgres** start creates databases and users from `postgres/init-databases.sql`. To re-run init, use `down --volumes` and `up` again (destroys data).
- Mongo runs **without authentication** in this stack (local convenience only).
- Set strong `JWT_SECRET` and internal passwords before any shared environment.

## Troubleshooting

### Build fails: `Could not GET ... repo.maven.apache.org` / `Could not resolve ... lombok`

Gradle in the **build** container must reach **Maven Central** on the internet. That error means DNS or outbound HTTPS from Docker failed (not a bug in the Java code).

1. **Check the host can reach Maven** (PowerShell or browser):  
   `Invoke-WebRequest -Uri "https://repo.maven.apache.org/maven2/" -Method Head -UseBasicParsing`  
   If that fails, fix Wi‑Fi/VPN/firewall first.

2. **Docker Desktop DNS (common on Windows)**  
   Open **Docker Desktop → Settings → Docker Engine** and merge a `dns` entry, for example:
   ```json
   {
     "dns": ["8.8.8.8", "1.1.1.1"]
   }
   ```
   Apply & restart Docker, then run `scripts\docker-local.cmd build` again.

3. **Corporate HTTP proxy**  
   Uncomment and set `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` in **`local/.env`** (see **`local/.env.example`**). Those values are passed as **build args** into every service Dockerfile so Gradle can download dependencies. Then rebuild.

4. **WSL2 / VPN**  
   If you use WSL2 or a VPN, search for “Docker Desktop WSL2 DNS” or “Docker cannot resolve host” — often the same DNS fix as above.

5. **Retry**  
   Transient outages happen; run `build` again after a few minutes.

### Workaround: build JARs on the host, copy into images

If Gradle **inside Docker** still cannot reach Maven but your **host** can, use the **same** scripts with **`-Prebuilt`** (PowerShell) or **`--prebuilt`** (bash). That uses **`docker-compose.prebuilt.yml`**, runs **`gradlew bootJar`** on the host, then builds images that only copy **`build/libs/*.jar`**.

- Requires **Docker Compose 2.17+** (BuildKit **`additional_contexts`**).
- Examples (from **`aitechtap-docs`**):  
  `.\scripts\docker-local.ps1 -Prebuilt build` then `.\scripts\docker-local.ps1 -Prebuilt up`  
  or **`scripts\docker-local-prebuilt.cmd`** / **`./scripts/docker-local-prebuilt.sh`** (wrappers for the same thing).
- **`jars`** (prebuilt only): Gradle only; **`build`**: **`jars`** then **`docker compose build`**.

### After `build`, does `up` use the new image?

**Yes, in normal use.** `docker compose up -d` creates or **recreates** containers when the service’s image changed (e.g. after a successful **`build`**). You are not required to pass extra flags.

If you ever see an old container still running (unusual), run **`up`** with **`--force-recreate`**, for example:

`.\scripts\docker-local.ps1 up --force-recreate`  
`.\scripts\docker-local.ps1 -Prebuilt up --force-recreate`
