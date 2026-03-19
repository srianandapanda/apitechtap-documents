# API contracts — external (JWT / Kong) vs internal (Basic Auth)

**Purpose:** Single reference for **every intended external and internal API**, authentication rules, and how **`user_id` is derived** for user validation.  
**Companion:** [ARCHITECTURE-HLD.md](./ARCHITECTURE-HLD.md), [API-FLOWS.md](./API-FLOWS.md).  
**Last updated:** 2026-03-19 (signup + register unified; Google signup removed; forgot/reset password; see [DATA-MODEL-AND-ENTITIES.md](./DATA-MODEL-AND-ENTITIES.md)). **Doc index:** [README.md](./README.md).

---

## 1. Principles

| Traffic | Path | Authentication | Who calls |
|--------|------|----------------|-----------|
| **External** | Client → **Kong** → service (public/upstream routes) | **`Authorization: Bearer <JWT>`** (except noted public/webhook) | Browser, mobile, partner apps |
| **Internal** | Service → **service directly** (cluster DNS / mesh). **Not routed through Kong.** | **HTTP Basic Auth** (`Authorization: Basic …`) using **per-caller service credentials** | Microservices only |

**User validation (external):**

1. Kong (optional) may validate JWT signature/expiry via plugin.
2. Each service **must** parse the JWT (or trust a gateway header only if you adopt a signed internal identity header — default here: **parse JWT in service**).
3. **`user_id`** = claim **`sub`** (subject), **UUID string**, unless your auth service documents another claim — **do not trust `userId` in request body** for authorization; use token-derived id only.

**Internal:**

- Each pair **caller → callee** has credentials stored in **Kubernetes Secrets** (e.g. `AUTH_SERVICE_TO_PROFILE_BASIC_USER`, `AUTH_SERVICE_TO_PROFILE_BASIC_PASSWORD`).
- Use **TLS** inside the cluster (service mesh or cluster TLS). Basic Auth is **not** a substitute for network policy — restrict internal routes to cluster IPs / mesh.

---

## 2. JWT contract (external)

### 2.1 Header

```http
Authorization: Bearer <access_token>
```

### 2.2 Access token claims (normative for this platform)

| Claim | Required | Meaning |
|-------|----------|---------|
| `sub` | Yes | **User id** (UUID string). **This is `user_id` for all authorization checks.** |
| `exp` | Yes | Expiry (Unix seconds). |
| `iat` | Recommended | Issued at. |
| `iss` | Recommended | Issuer (e.g. auth-service URL or realm name). |
| `roles` or `scope` | Optional | e.g. `ROLE_USER`, `ROLE_PLAN_ADMIN` for admin-only external routes (if you keep admin behind JWT instead of Basic on a separate admin gateway). |

**Validation steps (each protected external handler):**

1. Verify signature (shared secret or JWKS from auth service).
2. Verify `exp` (and optionally `iss`, `aud`).
3. Read **`user_id = sub`**.
4. For endpoints with **path** `/{userId}`: **reject** if `path userId != sub` (403).

### 2.3 What clients must not do

- Do not send **`userId` in body** expecting the server to act on behalf of another user.
- Do not reuse tokens across environments without matching signing keys.

---

## 3. Internal Basic Auth contract

### 3.1 Header

```http
Authorization: Basic base64("<clientId>:<clientSecret>")
```

- **`clientId`**: logical caller service name (e.g. `auth-service`, `plan-payment-service`).
- **`clientSecret`**: long random secret, rotated with deployments.

### 3.2 Rules

- Internal base paths: recommended prefix **`/internal/v1/`** (never exposed on Kong public listeners).
- **Network:** bind internal controllers to a separate port or use NetworkPolicy so only cluster workloads reach them (defense in depth).
- **Idempotency:** `POST` internal creates (e.g. provision user) must support **idempotency key** header:  
  `Idempotency-Key: <uuid>` or reuse deterministic key from `userId`.

### 3.3 Standard error responses (internal)

| HTTP | Meaning |
|------|---------|
| 401 | Missing/invalid Basic credentials |
| 403 | Valid auth but caller not allowed to call this resource |
| 404 | Resource not found |
| 409 | Conflict (e.g. duplicate provision) |

---

## 4. External API catalog (via Kong)

**Base URL (example):** `https://api.<env>.example.com`  
**Kong** strips or prefixes paths per route; below are **logical external paths** aligned with current monolith-style routes (`/api/...`). Versioning (`/api/v1/...`) can be added at Kong without changing handler logic if upstream keeps `/api/...`.

### 4.1 Authentication service (public + JWT)

**Signup = register user in one step:** `POST /api/auth/signup` must (atomically or with compensating logic):

1. Create **credentials** (hashed password) — **auth service** / `credentials` table.  
2. **Register user** — **user profile service** responsibility: `user_core` (SQL) + `user_profiles` (Mongo) with same `userId` as `credentials.user_id`.

In a **split deployment**, step 2 is an **internal** call (`POST /internal/v1/users/provision` with Basic Auth). In the **current monolith**, this is an in-process call to the same user module.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/signup` | **Public** | **Signup + register:** email and/or phone + password. Creates credential row + user core + profile document. Response: `userId`, `message`. **Google / social signup: not supported for now.** |
| POST | `/api/auth/login` | **Public** | Returns JWT (`token`, `expiresIn`). |
| POST | `/api/auth/logout` | **JWT** | Revoke/blacklist token (if implemented). |
| POST | `/api/auth/forgot-password` | **Public** | Body: `{ "email"?: "...", "phone"?: "..." }` (at least one). Always respond **200** with generic message (do not reveal whether account exists). If user exists, create **password reset token** (see data model), send link/code via email/SMS. |
| POST | `/api/auth/reset-password` | **Public** | Body: `{ "token": "...", "newPassword": "..." }`. Validate one-time token, update **credentials.password_hash**, invalidate token. **400/401** if invalid/expired token. |

**`user_id`:** After signup, response returns `userId` for client UX only. After login, identity is **only** from JWT `sub`.

---

### 4.2 User profile service

| Method | Path | Auth | `user_id` usage |
|--------|------|------|-----------------|
| GET | `/api/users/{userId}` | **JWT** | **Must equal `sub`.** Else 403. |
| POST | `/api/users` | **JWT** (recommended) | **Update user details only** — merge/patch `user_core`, `user_profiles.profile_data` for **`sub`**. Does **not** create a new account; use **`/api/auth/signup`** for first-time registration. |
| POST | `/api/users` | **Public** (legacy / optional) | Only if product keeps “register with password in one POST” without calling `/api/auth/signup` first; prefer deprecating in favor of signup + JWT updates. |

**Rules:** With JWT, scope all writes to **`sub`**; never promote a body `userId` over the token.

---

### 4.3 Plan & payment service

| Method | Path | Auth | `user_id` usage |
|--------|------|------|-----------------|
| POST | `/api/payments/orders` | **JWT** | **`user_id` = `sub` only.** Body: `planId` (UUID). Do **not** accept `userId` in body. |
| GET | `/api/payments/orders` | **JWT** | List orders for **`sub`**. |
| GET | `/api/payments/orders/{orderId}` | **JWT** | Order must belong to **`sub`**. |
| GET | `/api/payments/callback/razorpay` | **Public** (browser redirect) | Query params per provider; validate session server-side. |
| POST | `/api/payments/webhook/razorpay` | **Provider signature** (not JWT) | Verify HMAC/signature; **no** end-user JWT. |

**Plan catalog (user-facing):**

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| GET | `/api/plans` | **JWT** or **public** | Product decision: anonymous browse vs logged-in only. If JWT optional, no `user_id` required for list. |

*(If only admin list exists today at `/api/admin/plans`, add a dedicated public or JWT user route for storefront.)*

---

### 4.4 Plan admin (product decision: external JWT admin vs internal only)

**Option A — External admin (through Kong):** `ROLE_PLAN_ADMIN` in JWT, same Bearer token.  
**Option B — Internal only:** move create/update plan to **internal Basic** only (no public route).

Current codebase uses **Basic** on `/api/admin/plans` for some operations. Target architecture per your rule: **internal = Basic, not Kong**. So:

| Method | Path (today) | Target exposure |
|--------|----------------|-----------------|
| POST/PUT/GET | `/api/admin/plans` … | **Internal only** under e.g. `/internal/v1/plans` with **Basic Auth**; admin UI uses a **BFF** or tooling that holds technical credentials — **or** keep one Kong route with **JWT + admin role** if you explicitly want external admin via JWT (document as exception). |

This contract **recommends:** admin plan CRUD on **internal Basic**; if you expose admin to browser, use **JWT + `sub` + admin role** and still **do not** trust body `userId`.

---

### 4.5 AI assistance service

| Method | Path | Auth | `user_id` usage |
|--------|------|------|-----------------|
| POST | `/api/ai/chat` | **JWT** | Pass **`sub`** into AI/session logic. |
| GET | `/api/ai/career-suggestions` | **JWT** | Scope all data to **`sub`**. |

---

### 4.6 Planned / extended APIs (from HLD — implement when ready)

| Method | Path | Auth | `user_id` usage |
|--------|------|------|-----------------|
| GET | `/api/questions` or `/api/v1/questions` | **JWT** | Load static question set by **group** resolved from profile belonging to **`sub`**. |
| POST | `/api/documents/upload-url` | **JWT** | Create document row for **`sub`**. |
| GET | `/api/documents/{documentId}` | **JWT** | Return doc only if owned by **`sub`**. |
| POST | `/api/documents/{documentId}/parse` | **JWT** or internal worker | Trigger parse; scope by **`sub`**. |

---

## 5. Internal API catalog (Basic Auth, not via Kong)

All paths below are **examples**; keep them on **internal ports** or **internal ingress** only.

### 5.1 Auth service → User profile service

Used when **auth** and **user-profile** are separate processes. **Not used** when monolith calls user module in-process (same effect as this contract).

| Method | Path | Auth | Body / params | Description |
|--------|------|------|---------------|-------------|
| POST | `/internal/v1/users/provision` | Basic (**auth-service** credential) | `{ "userId"?: "uuid", "email"?: "...", "phone"?: "...", "profile"?: {} }` | **Internal register:** create `user_core` + `user_profiles` if missing; idempotent on `userId` or email/phone. Called as part of **signup** right after credential insert (or in same saga). |
| PATCH | `/internal/v1/users/{userId}/core` | Basic | Partial core fields | Rare: system updates from auth (e.g. email verified). |
| DELETE | `/internal/v1/users/{userId}` | Basic | — | Rare: compensating transaction if signup rolls back. |

**`userId` in body/path:** Trusted **only** because caller is authenticated as **auth-service** and network is internal — still log correlation id.

---

### 5.2 User profile service → Auth service (optional)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/internal/v1/users/{userId}/exists` | Basic (**user-profile-service**) | Check credential existence during migrations. |

*(Only if needed.)*

---

### 5.3 Plan & payment → User profile (optional)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/internal/v1/users/{userId}/summary` | Basic (**plan-payment-service**) | Email/phone for receipts, plan tier for entitlements. |

---

### 5.4 AI assistance → User profile (optional)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/internal/v1/users/{userId}/group` | Basic (**ai-service**) | Resolve **user group** for static questions. |

---

### 5.5 Plan admin CRUD (recommended internal shape)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/internal/v1/plans` | Basic (**admin-bff** or **ops** identity) | Create plan. |
| PUT | `/internal/v1/plans/{planId}` | Basic | Update plan. |
| GET | `/internal/v1/plans/{planId}` | Basic | Get plan. |
| GET | `/internal/v1/plans` | Basic | List/filter plans. |

---

### 5.6 Auth service → token issuance (internal, optional)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/internal/v1/oauth/token` | Basic (machine client) | If you add service accounts; not required for human JWT flow. |

---

## 6. Third-party & special cases (neither user JWT nor service Basic)

| Source | Path | Validation |
|--------|------|------------|
| Payment provider | `POST /api/payments/webhook/...` | **Signature / HMAC** in provider headers; IP allowlist optional. |
| Payment provider | `GET /api/payments/callback/...` | **Session/order id** + server-side state; do not trust user_id from query string alone. |
| S3 | Direct PUT to presigned URL | **Presigned policy** enforces bucket/key/expiry; metadata links in DB scoped by **`sub`** when URL was minted. |

---

## 7. Kong routing summary (external only)

| External path prefix | Upstream service | Typical plugins |
|---------------------|------------------|-----------------|
| `/api/auth` | auth-service | Rate limit; no JWT on signup/login |
| `/api/users` | user-profile-service | JWT validate (except public POST if kept) |
| `/api/payments` | plan-payment-service | JWT on orders; **no** JWT on webhook/callback (use signature rules) |
| `/api/plans` | plan-payment-service or plan-service | JWT optional/public per product |
| `/api/ai` | ai-assistance-service | JWT required |
| `/api/documents`, `/api/questions` | ai-assistance-service | JWT when implemented |

**Do not** register `/internal/*` on public Kong listeners.

---

## 8. Headers (cross-cutting)

| Header | Where | Purpose |
|--------|-------|---------|
| `Authorization: Bearer` | External protected | JWT |
| `Authorization: Basic` | Internal only | Service-to-service |
| `X-Request-Id` / `X-Correlation-Id` | All | Tracing (Kong can inject) |
| `Idempotency-Key` | Internal POST creates | Safe retries |

---

## 9. Alignment with other docs

- **Product context, base URLs, sharing OpenAPI with partners:** **[README.md](./README.md)**.
- **This file** is the **normative** split: **external = JWT + `sub` as `user_id`**, **internal = Basic, not via Kong**, plus webhooks/S3 rules.
- **Tables, columns, entity classes:** **[DATA-MODEL-AND-ENTITIES.md](./DATA-MODEL-AND-ENTITIES.md)**.
- **UI-oriented request/response samples:** **[EXTERNAL-API-REFERENCE-UI.md](./EXTERNAL-API-REFERENCE-UI.md)**.
- **Internal service-to-service samples (Basic):** **[INTERNAL-API-REFERENCE.md](./INTERNAL-API-REFERENCE.md)**.

---

## 10. Changelog (manual)

| Date | Change |
|------|--------|
| 2026-03-19 | Initial contracts: external JWT, internal Basic, internal path prefix, planned HLD endpoints. |
| 2026-03-19 | Google signup **removed**. Signup documented as credential + user register together. **POST /api/users** with JWT = **update details** only. **Forgot / reset password** external APIs added. Internal **provision** clarified. |
| 2026-03-19 | All documentation consolidated under **`docs/`**; duplicate **API_CONTRACT_PRODUCT.md** removed (content folded into **docs/README.md**). |
