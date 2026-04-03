# Documentation — AiTechTap Core

**All project documentation lives in this folder** (`docs/`). There is no separate `docs/architecture/` tree.

---

## Start here

| Document | Use it for |
|----------|------------|
| **[ARCHITECTURE-HLD.md](./ARCHITECTURE-HLD.md)** | **Master HLD** — diagrams (PNG), system scope, links to every other doc |
| **[GETTING-STARTED.md](./GETTING-STARTED.md)** | Build, Spotless, tests, run app, Swagger URLs |
| **[local/README.md](./local/README.md)** | **Local Docker:** all microservices + Postgres + Mongo (ports 8081–8084), scripts |

---

## API & contracts

| Document | Audience |
|----------|----------|
| **[API-CONTRACTS.md](./API-CONTRACTS.md)** | **Normative:** external JWT (`sub` = user id), internal Basic, Kong vs `/internal/*` |
| **[EXTERNAL-API-REFERENCE-UI.md](./EXTERNAL-API-REFERENCE-UI.md)** | **UI:** every public endpoint — headers, bodies, samples |
| **[INTERNAL-API-REFERENCE.md](./INTERNAL-API-REFERENCE.md)** | **Backend:** `/internal/v1/*`, Basic Auth, samples |
| **[API-FLOWS.md](./API-FLOWS.md)** | Sequence diagram PNGs, Kong routing table |
| **[api-contract-static.html](./api-contract-static.html)** | Static HTML API overview (open in browser) |
| **[postman/](./postman/)** | Postman collection + [CURL_EXAMPLES.md](./postman/CURL_EXAMPLES.md) |

---

## Data & deployment

| Document | Content |
|----------|---------|
| **[DATA-MODEL-AND-ENTITIES.md](./DATA-MODEL-AND-ENTITIES.md)** | Service → table/collection, entity fields |
| **[DOCKER-K8S-PLAN.md](./DOCKER-K8S-PLAN.md)** | Docker / Kubernetes rollout plan |

---

## Diagrams

| Path | Content |
|------|---------|
| **[diagrams/png/](./diagrams/png/)** | Rendered PNGs (embedded in HLD) |
| **[diagrams/source/](./diagrams/source/)** | Mermaid sources (`.mmd`) |
| **[diagrams/README.md](./diagrams/README.md)** | Regenerate PNGs (Kroki / Mermaid CLI) |

---

## Product context (brief)

AI TechTap Core backend supports:

- Authentication and sessions (JWT)
- Dynamic user profile (by user group)
- Plans and subscription purchase
- AI career chat and suggestions
- Resume/PDF pipeline (evolving; see HLD)

**Base URLs (local):**

- API: `http://localhost:8081`
- Swagger UI: `http://localhost:8081/swagger-ui/index.html`
- OpenAPI JSON: `http://localhost:8081/v3/api-docs`

Treat **`/v3/api-docs`** as the live schema source. For strict payloads (e.g. `POST /api/payments/orders`), validate in the UI before submit; for dynamic endpoints (`/api/users`, `/api/ai/chat`), handle flexible JSON.

---

## Sharing API docs with partners (no repo access)

1. **Fast:** share deployed Swagger — `https://<host>/swagger-ui/index.html` and `https://<host>/v3/api-docs`.
2. **Org-wide:** export OpenAPI JSON, host Swagger/Redoc on S3, GitHub Pages, or internal portal.
3. **Releases:** CI publishes `openapi.json` per version in release artifacts.

---

## Reading order

1. [ARCHITECTURE-HLD.md](./ARCHITECTURE-HLD.md)  
2. [API-CONTRACTS.md](./API-CONTRACTS.md)  
3. [EXTERNAL-API-REFERENCE-UI.md](./EXTERNAL-API-REFERENCE-UI.md) or [INTERNAL-API-REFERENCE.md](./INTERNAL-API-REFERENCE.md)  
4. [DATA-MODEL-AND-ENTITIES.md](./DATA-MODEL-AND-ENTITIES.md) when touching persistence  
