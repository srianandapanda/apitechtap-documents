# Getting Started

- [Spring Boot 3.x Reference](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [Gradle Build Tool](https://docs.gradle.org)

## Run all backend services locally (Docker)

Use **[local/README.md](./local/README.md)** — one Compose file and **`scripts/docker-local.sh`** / **`scripts/docker-local.ps1`** (build, up, down, logs). Default HTTP ports: **8081** auth, **8082** user-management, **8083** assist, **8084** plan-payment; Postgres **5435**, Mongo **27018**.

---

Legacy monolith note: if you still use the old `aitechtap-core` Gradle app, run `./gradlew :app:bootRun` (or open `AitechtapCoreApplication` in the `app` module). Microservices use their own Gradle projects and the Docker stack above.

## Build, Spotless, and Tests

**Command line (from project root):**

- Format and build (run Spotless, then compile and run all tests):  
  `./gradlew buildWithSpotless`  
  On Windows: `gradlew.bat buildWithSpotless`
- Format only: `./gradlew spotlessApply`
- Build only (includes tests): `./gradlew build`
- Run app: `./gradlew :app:bootRun`

**IntelliJ run configuration:**

1. **Run → Edit Configurations**
2. Click **+** → **Gradle**
3. **Name:** e.g. `Build + Spotless + Test`
4. **Tasks:** `buildWithSpotless` (or `spotlessApply build` for the same effect)
5. Leave **Project** as your aitechtap-core root. Apply and OK.

Running this configuration will apply Spotless, then build all modules and run tests.

## API docs (Swagger)

With the app running (`./gradlew :app:bootRun`):

- **Swagger UI:** [http://localhost:8081/swagger-ui.html](http://localhost:8081/swagger-ui.html) or [http://localhost:8081/swagger-ui/index.html](http://localhost:8081/swagger-ui/index.html)
- **OpenAPI JSON:** [http://localhost:8081/v3/api-docs](http://localhost:8081/v3/api-docs)

Swagger UI is public (no JWT). Use **Authorize** to set Bearer token (from POST /api/auth/login) or Basic auth for plan admin. Then try any endpoint from the UI.
