# Internal API reference — service-to-service (Basic Auth)

**Purpose:** Same detail level as [EXTERNAL-API-REFERENCE-UI.md](./EXTERNAL-API-REFERENCE-UI.md), for **internal** HTTP APIs only.  
**Normative rules:** [API-CONTRACTS.md](./API-CONTRACTS.md) §3 and §5.

**Important**

- **Do not** expose these paths on **public Kong** listeners.  
- Reachable only from **cluster network** (K8s Service DNS, mesh, or internal ingress).  
- **Auth:** `Authorization: Basic base64("<clientId>:<clientSecret>")` — **never** send internal secrets to browsers.

**Implementation status:** Many routes below are **contract targets** for a **split microservices** deployment. In the **current monolith**, equivalent logic runs **in-process** (no HTTP). Implement controllers when you extract services.

**Last updated:** 2026-03-19

---

## 0. Conventions

| Item | Value |
|------|--------|
| **Path prefix** | `/internal/v1/` |
| **Content-Type** | `application/json` for JSON bodies |
| **Authorization** | `Basic <base64(clientId:clientSecret)>` — see §0.1 |
| **Idempotency** | `Idempotency-Key: <uuid>` recommended on **POST** that create rows |
| **Tracing** | `X-Correlation-Id` / `X-Request-Id` — propagate from caller |
| **Base URL (example)** | `http://<service-name>.<namespace>.svc.cluster.local:8080` — port per deployment |

### 0.1 Caller credentials (examples for K8s Secrets)

| Caller service | Typical `clientId` | Stored as (example secret keys) |
|----------------|-------------------|----------------------------------|
| auth-service | `auth-service` | `INTERNAL_AUTH_TO_PROFILE_USER`, `INTERNAL_AUTH_TO_PROFILE_PASSWORD` |
| plan-payment-service | `plan-payment-service` | `INTERNAL_PAYMENT_TO_PROFILE_USER`, `…_PASSWORD` |
| ai-assistance-service | `ai-assistance-service` | `INTERNAL_AI_TO_PROFILE_USER`, `…_PASSWORD` |
| user-profile-service | `user-profile-service` | `INTERNAL_PROFILE_TO_AUTH_USER`, `…_PASSWORD` |
| admin-bff / ops job | `admin-bff` | `INTERNAL_ADMIN_PLANS_USER`, `…_PASSWORD` |

The **callee** validates Basic Auth against its allowlist of `(clientId, secretHash or plaintext compare via secure compare)`.

### 0.2 Standard error responses

| HTTP | Typical body |
|------|----------------|
| **401** | `{ "error": "Unauthorized" }` or empty |
| **403** | `{ "error": "Forbidden", "reason": "caller not allowed" }` |
| **404** | `{ "error": "Not found" }` or empty |
| **409** | `{ "error": "Conflict", "message": "..." }` |

### 0.3 Response headers (general)

| Header | When |
|--------|------|
| `Content-Type: application/json` | JSON responses |
| `X-Correlation-Id` | Echo or set if missing |

---

## 1. User profile service — Provision user (Auth → Profile)

**Caller:** `auth-service` · **Callee:** `user-profile-service`

| | |
|--|--|
| **Endpoint** | `POST /internal/v1/users/provision` |
| **Auth** | **Basic** — credential for `auth-service` |

**Request headers**

| Header | Required | Value |
|--------|----------|--------|
| `Authorization` | Yes | `Basic <base64>` |
| `Content-Type` | Yes | `application/json` |
| `Idempotency-Key` | Recommended | UUID — reuse same key to safely retry signup saga |
| `X-Correlation-Id` | Recommended | Trace id |

**Path parameters** | None  

**Query parameters** | None  

**Request body (JSON)**

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `userId` | string (UUID) | Conditional | If omitted, callee may generate (prefer auth generates and sends) |
| `email` | string | No | |
| `phone` | string | No | |
| `profile` | object | No | Initial `profile_data` merge for Mongo |
| `displayName` | string | No | Maps to `user_core` if you support it |

**Response body**

| HTTP | Body |
|------|------|
| **201** | `{ "userId": "<uuid>", "created": true }` |
| **200** | `{ "userId": "<uuid>", "created": false }` — idempotent: user already existed |
| **409** | Conflict (e.g. email owned by different `userId`) |
| **401** | Invalid Basic |

**Sample request**

```http
POST /internal/v1/users/provision HTTP/1.1
Host: user-profile-service.aitechtap.svc.cluster.local:8080
Authorization: Basic YXV0aC1zZXJ2aWNlOnNlY3JldC1mcm9tLWt1YmVybmV0ZXM=
Content-Type: application/json
Idempotency-Key: 7b8c9d0e-1f2a-4b3c-8d9e-0a1b2c3d4e5f
X-Correlation-Id: req-abc-123

{
  "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
  "email": "user@example.com",
  "phone": null,
  "profile": {}
}
```

**Sample response (201)**

```json
{
  "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
  "created": true
}
```

---

## 2. User profile service — Patch user core (Auth → Profile)

**Caller:** `auth-service` · **Callee:** `user-profile-service`

| | |
|--|--|
| **Endpoint** | `PATCH /internal/v1/users/{userId}/core` |
| **Auth** | **Basic** (`auth-service`) |

**Path parameters**

| Param | Type | Required |
|-------|------|----------|
| `userId` | UUID string | Yes |

**Request body (JSON)** — partial; only supplied fields updated.

| Field | Type | Required |
|-------|------|----------|
| `email` | string | No |
| `phone` | string | No |
| `displayName` | string | No |
| `currentPlanId` | UUID | No |

**Response**

| HTTP | Body |
|------|------|
| **200** | Updated core representation or `{ "userId": "...", "updated": true }` |
| **404** | User not found |

**Sample request**

```http
PATCH /internal/v1/users/4b40e5fd-4194-4f11-ac58-ea0ea24f640c/core HTTP/1.1
Authorization: Basic YXV0aC1zZXJ2aWNlOnNlY3JldA==
Content-Type: application/json

{
  "email": "verified@example.com"
}
```

**Sample response (200)**

```json
{
  "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
  "updated": true
}
```

---

## 3. User profile service — Delete user (compensating transaction)

**Caller:** `auth-service` · **Callee:** `user-profile-service`

| | |
|--|--|
| **Endpoint** | `DELETE /internal/v1/users/{userId}` |
| **Auth** | **Basic** (`auth-service`) |

**Path parameters**

| Param | Type | Required |
|-------|------|----------|
| `userId` | UUID string | Yes |

**Request body** | None  

**Response**

| HTTP | Body |
|------|------|
| **204** | No content — deleted or nothing to delete |
| **401** | Invalid Basic |

**Sample request**

```http
DELETE /internal/v1/users/4b40e5fd-4194-4f11-ac58-ea0ea24f640c HTTP/1.1
Authorization: Basic YXV0aC1zZXJ2aWNlOnNlY3JldA==
```

---

## 4. Auth service — Credential exists check (Profile → Auth)

**Caller:** `user-profile-service` · **Callee:** `auth-service`

| | |
|--|--|
| **Endpoint** | `GET /internal/v1/users/{userId}/exists` |
| **Auth** | **Basic** (`user-profile-service`) |

**Path parameters**

| Param | Type | Required |
|-------|------|----------|
| `userId` | UUID string | Yes |

**Query parameters** | None  

**Response body**

| HTTP | Body |
|------|------|
| **200** | `{ "userId": "<uuid>", "credentialExists": true }` |
| **200** | `{ "userId": "<uuid>", "credentialExists": false }` |
| **401** | Invalid Basic |

**Sample response (200)**

```json
{
  "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
  "credentialExists": true
}
```

---

## 5. User profile service — User summary for billing (Payment → Profile)

**Caller:** `plan-payment-service` · **Callee:** `user-profile-service`

| | |
|--|--|
| **Endpoint** | `GET /internal/v1/users/{userId}/summary` |
| **Auth** | **Basic** (`plan-payment-service`) |

**Path parameters**

| Param | Type | Required |
|-------|------|----------|
| `userId` | UUID string | Yes |

**Response body (200)** — example shape (extend per product):

| Field | Type | Notes |
|-------|------|--------|
| `userId` | string | |
| `email` | string | nullable |
| `phone` | string | nullable |
| `displayName` | string | nullable |
| `currentPlanId` | UUID | nullable |

**Sample response (200)**

```json
{
  "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
  "email": "user@example.com",
  "phone": "9876543210",
  "displayName": "Priya Sharma",
  "currentPlanId": "5c84a2be-4b0d-4a74-a34d-cf955ec1c2a3"
}
```

**Sample request**

```http
GET /internal/v1/users/4b40e5fd-4194-4f11-ac58-ea0ea24f640c/summary HTTP/1.1
Authorization: Basic cGxhbi1wYXltZW50LXNlcnZpY2U6c2VjcmV0
```

---

## 6. User profile service — User group for AI (AI → Profile)

**Caller:** `ai-assistance-service` · **Callee:** `user-profile-service`

| | |
|--|--|
| **Endpoint** | `GET /internal/v1/users/{userId}/group` |
| **Auth** | **Basic** (`ai-assistance-service`) |

**Path parameters**

| Param | Type | Required |
|-------|------|----------|
| `userId` | UUID string | Yes |

**Response body (200)**

| Field | Type | Notes |
|-------|------|--------|
| `userId` | string | |
| `userGroup` | string | e.g. `STUDENT`, `PROFESSIONAL` |
| `groupId` | string | optional second key |

**Sample response (200)**

```json
{
  "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
  "userGroup": "STUDENT"
}
```

---

## 7. Plan service — List plans (internal)

**Caller:** `plan-payment-service`, `admin-bff`, or other internal consumers · **Callee:** `plan-service`

| | |
|--|--|
| **Endpoint** | `GET /internal/v1/plans` |
| **Auth** | **Basic** (allowed internal client) |

**Query parameters**

| Param | Type | Required | Notes |
|-------|------|----------|--------|
| `planType` | string | No | `FREE`, `PRO`, `ELITE` |
| `activeOnly` | boolean | No | default `false` |

**Response (200)** | JSON **array** — same shape as external `PlanResponse` (see external doc §8).

**Sample request**

```http
GET /internal/v1/plans?activeOnly=true HTTP/1.1
Authorization: Basic YWRtaW4tYmZmOnNlY3JldA==
```

---

## 8. Plan service — Get plan by ID (internal)

| | |
|--|--|
| **Endpoint** | `GET /internal/v1/plans/{planId}` |
| **Auth** | **Basic** |

**Path parameters**

| Param | Type | Required |
|-------|------|----------|
| `planId` | UUID | Yes |

**Response** | **200** plan object · **404** not found  

---

## 9. Plan service — Create plan (internal)

| | |
|--|--|
| **Endpoint** | `POST /internal/v1/plans` |
| **Auth** | **Basic** (`admin-bff` or `plan-service` ops identity) |

**Request body (JSON)** — same as external create plan:

| Field | Type | Required |
|-------|------|----------|
| `planType` | string | Yes — `FREE`, `PRO`, `ELITE` |
| `price` | number | No |
| `currency` | string | No — default `INR` |
| `isActive` | boolean | No — default `true` |
| `metadata` | object | No |
| `actionCodes` | string[] | No |
| `featureCodes` | string[] | No |

**Sample request**

```http
POST /internal/v1/plans HTTP/1.1
Authorization: Basic YWRtaW4tYmZmOnNlY3JldA==
Content-Type: application/json
Idempotency-Key: 11111111-2222-3333-4444-555555555555

{
  "planType": "PRO",
  "price": 999.00,
  "currency": "INR",
  "isActive": true,
  "metadata": { "label": "Pro" },
  "actionCodes": [],
  "featureCodes": ["AI_CHAT"]
}
```

**Sample response (200)**

```json
{
  "id": "5c84a2be-4b0d-4a74-a34d-cf955ec1c2a3",
  "planType": "PRO",
  "price": 999.0,
  "currency": "INR",
  "isActive": true,
  "metadata": { "label": "Pro" },
  "actionCodes": [],
  "featureCodes": ["AI_CHAT"],
  "createdAt": "2025-01-15T10:00:00Z",
  "updatedAt": "2025-01-15T10:00:00Z"
}
```

---

## 10. Plan service — Update plan (internal)

| | |
|--|--|
| **Endpoint** | `PUT /internal/v1/plans/{planId}` |
| **Auth** | **Basic** |

**Path parameters** | `planId` (UUID)  

**Request body** | Partial update — fields optional: `planType`, `price`, `currency`, `isActive`, `metadata`, `actionCodes`, `featureCodes`.

**Sample**

```json
{
  "price": 799.00,
  "isActive": true
}
```

---

## 11. Auth service — Machine token (optional)

**Caller:** trusted internal job / BFF · **Callee:** `auth-service`

| | |
|--|--|
| **Endpoint** | `POST /internal/v1/oauth/token` |
| **Auth** | **Basic** (client credentials: `client_id:client_secret` for machine) |

**Request body (JSON)** — example grant (product-specific):

| Field | Type | Required |
|-------|------|----------|
| `grantType` | string | Yes | e.g. `client_credentials` |
| `scope` | string | No | |

**Response (200)** — example:

```json
{
  "accessToken": "<jwt-or-opaque>",
  "tokenType": "Bearer",
  "expiresIn": 3600
}
```

> **Note:** Not required for end-user login. Add only if you need service-to-service user-less API access.

---

## 12. AI / document pipeline — Parse complete callback *(planned)*

**Caller:** `resume-worker` / async job · **Callee:** `ai-assistance-service`

| | |
|--|--|
| **Endpoint** | `POST /internal/v1/documents/{documentId}/parse-result` |
| **Auth** | **Basic** (`resume-worker` identity) |

**Path parameters**

| Param | Type | Required |
|-------|------|----------|
| `documentId` | UUID | Yes |

**Request body (JSON)**

| Field | Type | Required |
|-------|------|----------|
| `status` | string | Yes | `READY`, `FAILED` |
| `parsedJson` | object | No | Resume structure |
| `errorMessage` | string | No | If `FAILED` |

**Response** | **204** or **200** `{ "ok": true }`  

**Sample**

```json
{
  "status": "READY",
  "parsedJson": {
    "fullName": "Jane Doe",
    "skills": ["Java", "Kubernetes"]
  }
}
```

---

## 13. Matrix: caller → callee → endpoints

| From | To | Endpoints |
|------|-----|-----------|
| **auth-service** | **user-profile-service** | `POST /internal/v1/users/provision`, `PATCH .../core`, `DELETE .../users/{userId}` |
| **user-profile-service** | **auth-service** | `GET .../users/{userId}/exists` |
| **plan-payment-service** | **user-profile-service** | `GET .../users/{userId}/summary` |
| **ai-assistance-service** | **user-profile-service** | `GET .../users/{userId}/group` |
| **internal consumers** | **plan-service** | `GET/POST /internal/v1/plans`, `GET/PUT .../plans/{planId}` |
| **resume-worker** | **ai-assistance-service** | `POST .../documents/{id}/parse-result` *(planned)* |
| **machine client** | **auth-service** | `POST /internal/v1/oauth/token` *(optional)* |

---

## 14. cURL example (local / port-forward)

Replace host, user, password, and use **TLS** in production.

```bash
curl -s -X POST "http://user-profile:8080/internal/v1/users/provision" \
  -u "auth-service:your-secret" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"userId":"4b40e5fd-4194-4f11-ac58-ea0ea24f640c","email":"u@example.com"}'
```

`-u` sends **HTTP Basic** (`Authorization: Basic …`).

---

## Related docs

- [README.md](./README.md) — full doc index  
- [API-CONTRACTS.md](./API-CONTRACTS.md) — internal catalog summary  
- [EXTERNAL-API-REFERENCE-UI.md](./EXTERNAL-API-REFERENCE-UI.md) — public/Kong APIs  
- [DATA-MODEL-AND-ENTITIES.md](./DATA-MODEL-AND-ENTITIES.md) — tables touched by each service  
