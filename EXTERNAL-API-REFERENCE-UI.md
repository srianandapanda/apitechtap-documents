# External API reference — for UI / frontend

**Purpose:** One document for **all external (Kong-facing) APIs** with endpoint, headers, path/query params, bodies, responses, and **copy-paste samples**.  
**Base URL (local):** `http://localhost:8081` — replace with your environment (e.g. `https://api.example.com`).  
**Normative auth rules:** [API-CONTRACTS.md](./API-CONTRACTS.md) · **Internal (Basic) APIs:** [INTERNAL-API-REFERENCE.md](./INTERNAL-API-REFERENCE.md) · **OpenAPI:** `GET /v3/api-docs` when the app is running.

**Last updated:** 2026-03-19

---

## 0. Conventions

| Item | Value |
|------|--------|
| **Content-Type** | `application/json` for bodies (except webhook raw JSON string — server only). |
| **JWT** | `Authorization: Bearer <access_token>` — token from `POST /api/auth/login`. Claim **`sub`** is the **user UUID** (use for `/api/users/{userId}` path). |
| **Errors** | Most errors return JSON like `{ "message": "..." }` or `{ "error": "..." }`. **401** may have empty body on some routes. |
| **CORS** | Configure on gateway/app for your UI origin. |

---

## 1. Auth — Signup

| | |
|--|--|
| **Endpoint** | `POST /api/auth/signup` |
| **Auth** | None (public) |

**Request headers**

| Header | Required | Value |
|--------|----------|--------|
| `Content-Type` | Yes | `application/json` |

**Path parameters** | None  
**Query parameters** | None  

**Request body (JSON)**

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `email` | string | One of email/phone | |
| `phone` | string | One of email/phone | |
| `password` | string | Yes | |

**Response headers** | Standard (`Content-Type: application/json` on JSON responses).

**Response body**

| HTTP | Body |
|------|------|
| **200** | `{ "userId": "<uuid>", "message": "Signup successful" }` |
| **409** | `{ "message": "<reason e.g. duplicate>" }` |
| **500** | `{ "message": "Signup failed" }` |

**Sample request**

```http
POST /api/auth/signup HTTP/1.1
Host: localhost:8081
Content-Type: application/json

{
  "email": "user@example.com",
  "phone": null,
  "password": "StrongPass@123"
}
```

**Sample response (200)**

```json
{
  "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
  "message": "Signup successful"
}
```

---

## 2. Auth — Login

| | |
|--|--|
| **Endpoint** | `POST /api/auth/login` |
| **Auth** | None (public) |

**Request headers**

| Header | Required | Value |
|--------|----------|--------|
| `Content-Type` | Yes | `application/json` |

**Request body (JSON)**

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `email` | string | One of email / `mobile_number` | |
| `mobile_number` | string | One of email / `mobile_number` | Login JSON uses **`mobile_number`** (not `phone`). |
| `password` | string | Yes | |

**Response body**

| HTTP | Body |
|------|------|
| **200** | `{ "token": "<jwt>", "expiresIn": <seconds> }` |
| **401** | `{ "message": "Invalid credentials" }` |

**Sample request**

```json
{
  "email": "user@example.com",
  "mobile_number": null,
  "password": "StrongPass@123"
}
```

**Sample response (200)**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600
}
```

---

## 3. Auth — Logout

| | |
|--|--|
| **Endpoint** | `POST /api/auth/logout` |
| **Auth** | Optional Bearer (if sent, token is revoked) |

**Request headers**

| Header | Required | Value |
|--------|----------|--------|
| `Content-Type` | Optional | `application/json` |
| `Authorization` | Recommended | `Bearer <token>` |

**Request body** | None  

**Response body (200)**

```json
{ "message": "User logged out successfully" }
```

**Sample request**

```http
POST /api/auth/logout HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

---

## 4. Auth — Forgot password *(contract; implement when backend ready)*

| | |
|--|--|
| **Endpoint** | `POST /api/auth/forgot-password` |
| **Auth** | None |

**Request headers** | `Content-Type: application/json`  

**Request body**

| Field | Type | Required |
|-------|------|----------|
| `email` | string | At least one of `email` / `phone` |
| `phone` | string | At least one of `email` / `phone` |

**Response** | **200** always with generic message (no user enumeration).  
**Sample**

```json
{ "email": "user@example.com" }
```

```json
{ "message": "If an account exists, reset instructions were sent." }
```

> **UI note:** Until implemented, this route may return **404**. See [API-CONTRACTS.md](./API-CONTRACTS.md).

---

## 5. Auth — Reset password *(contract; implement when backend ready)*

| | |
|--|--|
| **Endpoint** | `POST /api/auth/reset-password` |
| **Auth** | None |

**Request body**

| Field | Type | Required |
|-------|------|----------|
| `token` | string | Yes — opaque token from email/SMS |
| `newPassword` | string | Yes |

**Response**

| HTTP | Body |
|------|------|
| **200** | `{ "message": "Password updated" }` (example) |
| **400 / 401** | Invalid/expired token |

**Sample**

```json
{
  "token": "opaque-token-from-email",
  "newPassword": "NewStrongPass@1"
}
```

---

## 6. User — Get profile

| | |
|--|--|
| **Endpoint** | `GET /api/users/{userId}` |
| **Auth** | **Bearer JWT** required |

**Request headers**

| Header | Required | Value |
|--------|----------|--------|
| `Authorization` | Yes | `Bearer <token>` |

**Path parameters**

| Param | Type | Required | Notes |
|-------|------|----------|--------|
| `userId` | UUID string | Yes | **Must equal JWT `sub`.** |

**Query parameters** | None  

**Response body**

| HTTP | Body |
|------|------|
| **200** | JSON object — merged **SQL core + Mongo profile** (keys vary by user). |
| **401** | Often empty body |
| **403** | Path `userId` ≠ token user |
| **404** | User not found |

**Sample request**

```http
GET /api/users/4b40e5fd-4194-4f11-ac58-ea0ea24f640c HTTP/1.1
Authorization: Bearer <token>
```

**Sample response (200)** — shape varies; example:

```json
{
  "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
  "email": "user@example.com",
  "phone": "9876543210",
  "displayName": "Priya Sharma",
  "firstName": "Priya",
  "lastName": "Sharma",
  "address": "Pune"
}
```

---

## 7. User — Update profile (JWT) or legacy register (no JWT)

| | |
|--|--|
| **Endpoint** | `POST /api/users` |
| **Auth** | **Bearer JWT** (recommended) — updates **only** the logged-in user. Without JWT: legacy full registration (email/phone + password). |

**Request headers**

| Header | Required | Value |
|--------|----------|--------|
| `Content-Type` | Yes | `application/json` |
| `Authorization` | For update flow | `Bearer <token>` |

**Request body (JSON)** — **dynamic**; extra keys allowed.

**Typical fields (update / extended profile):** `firstName`, `lastName`, `email`, `mobile` or `phone`, `address`, `dob`, `yearOfPassing`, `experienceYears`, `currentRole`, `skills` (array), etc.

**When using JWT:** Server injects `userId` from token — **do not rely on a client-supplied `userId` for authorization.**

**Response body**

| HTTP | Body |
|------|------|
| **200** | Map including at least `userId`; other keys echo/merge profile fields. |
| **400** | e.g. `{ "error": "email or phone required" }` (no-JWT path) |
| **409** | e.g. `{ "message": "User already registered with this email or phone" }` |

**Sample request (update with JWT)**

```http
POST /api/users HTTP/1.1
Authorization: Bearer <token>
Content-Type: application/json

{
  "firstName": "Priya",
  "lastName": "Sharma",
  "mobile": "9876543210",
  "address": "Pune"
}
```

**Sample response (200)**

```json
{
  "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
  "firstName": "Priya",
  "lastName": "Sharma",
  "address": "Pune"
}
```

---

## 8. Plans (admin list — used for storefront if exposed)

| | |
|--|--|
| **Endpoint** | `GET /api/admin/plans` |
| **Auth** | **Bearer JWT** *or* **HTTP Basic** (plan admin credentials — server config) |

**Request headers**

| Header | Required | Value |
|--------|----------|--------|
| `Authorization` | Yes | `Bearer <token>` **or** `Basic <base64>` |

**Query parameters**

| Param | Type | Required | Notes |
|-------|------|----------|--------|
| `planType` | string | No | `FREE`, `PRO`, `ELITE` |
| `activeOnly` | boolean | No | default `false` |

**Response body (200)** | JSON **array** of plan objects.

**Plan object fields**

| Field | Type | Notes |
|-------|------|--------|
| `id` | UUID | |
| `planType` | string | `FREE` / `PRO` / `ELITE` |
| `price` | number | |
| `currency` | string | e.g. `INR` |
| `isActive` | boolean | |
| `metadata` | object | nullable |
| `actionCodes` | string[] | nullable |
| `featureCodes` | string[] | nullable |
| `createdAt` | string (ISO-8601) | |
| `updatedAt` | string (ISO-8601) | |

**Sample request**

```http
GET /api/admin/plans?activeOnly=true HTTP/1.1
Authorization: Bearer <token>
```

**Sample response (200)**

```json
[
  {
    "id": "5c84a2be-4b0d-4a74-a34d-cf955ec1c2a3",
    "planType": "PRO",
    "price": 999.00,
    "currency": "INR",
    "isActive": true,
    "metadata": {},
    "actionCodes": [],
    "featureCodes": [],
    "createdAt": "2025-01-15T10:00:00Z",
    "updatedAt": "2025-01-15T10:00:00Z"
  }
]
```

---

## 9. Plan admin — Get plan by ID

| | |
|--|--|
| **Endpoint** | `GET /api/admin/plans/{id}` |
| **Auth** | JWT or Basic (same as list) |

**Path parameters**

| Param | Type | Required |
|-------|------|----------|
| `id` | UUID | Yes |

**Response** | **200** single plan object · **404** empty  

**Sample:** `GET /api/admin/plans/5c84a2be-4b0d-4a74-a34d-cf955ec1c2a3`

---

## 10. Plan admin — Create plan *(usually not from end-user UI)*

| | |
|--|--|
| **Endpoint** | `POST /api/admin/plans` |
| **Auth** | **HTTP Basic** (per current backend) |

**Request body**

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `planType` | string | Yes | `FREE`, `PRO`, `ELITE` |
| `price` | number | No | |
| `currency` | string | No | default `INR` |
| `isActive` | boolean | No | default `true` |
| `metadata` | object | No | |
| `actionCodes` | string[] | No | |
| `featureCodes` | string[] | No | |

**Sample request**

```http
POST /api/admin/plans HTTP/1.1
Authorization: Basic cGxhbmFkbWluOnlvdXItc2VjcmV0
Content-Type: application/json

{
  "planType": "PRO",
  "price": 999.00,
  "currency": "INR",
  "isActive": true,
  "metadata": { "label": "Pro annual" },
  "actionCodes": [],
  "featureCodes": ["AI_CHAT"]
}
```

**Sample response (200)** | Same shape as one element from list endpoint.

---

## 11. Plan admin — Update plan

| | |
|--|--|
| **Endpoint** | `PUT /api/admin/plans/{id}` |
| **Auth** | **HTTP Basic** |

**Path parameters** | `id` (UUID)  

**Request body** | All fields optional (partial update per `UpdatePlanRequest`): `planType`, `price`, `currency`, `isActive`, `metadata`, `actionCodes`, `featureCodes`.

**Sample**

```json
{
  "price": 799.00,
  "isActive": true
}
```

---

## 12. Payments — Create order

| | |
|--|--|
| **Endpoint** | `POST /api/payments/orders` |
| **Auth** | **Bearer JWT** required |

**Request headers**

| Header | Required | Value |
|--------|----------|--------|
| `Content-Type` | Yes | `application/json` |
| `Authorization` | Yes | `Bearer <token>` |

**Request body**

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `planId` | UUID | Yes | **Do not send `userId`** — from token only. |

**Response body (200)**

| Field | Type | Notes |
|-------|------|--------|
| `orderId` | UUID | Internal order id |
| `gatewayOrderId` | string | Razorpay order id |
| `amount` | number | |
| `currency` | string | |
| `status` | string | e.g. `PENDING_PAYMENT` |

**Errors:** **400** `{ "error": "..." }` · **401** `{ "error": "Unauthorized" }` · **500** `{ "error": "Unable to create order" }`

**Sample request**

```json
{ "planId": "5c84a2be-4b0d-4a74-a34d-cf955ec1c2a3" }
```

**Sample response (200)**

```json
{
  "orderId": "5a3cd087-9d38-4665-b22f-bf868ce4d08b",
  "gatewayOrderId": "order_Q2tfFq7piVnE2A",
  "amount": 999.0,
  "currency": "INR",
  "status": "PENDING_PAYMENT"
}
```

---

## 13. Payments — List my orders

| | |
|--|--|
| **Endpoint** | `GET /api/payments/orders` |
| **Auth** | **Bearer JWT** |

**Response (200)** | JSON array of **order** objects.

**Order object (typical)**

| Field | Type |
|-------|------|
| `id` | UUID |
| `userId` | string |
| `planId` | UUID |
| `status` | string — `CREATED`, `PENDING_PAYMENT`, `PAYMENT_INITIATED`, `PAYMENT_SUCCESS`, `COMPLETED`, `FAILED`, `CANCELLED` |
| `amount` | number |
| `currency` | string |
| `gatewayOrderId` | string |
| `createdAt` | string |
| `updatedAt` | string |

**Sample response**

```json
[
  {
    "id": "5a3cd087-9d38-4665-b22f-bf868ce4d08b",
    "userId": "4b40e5fd-4194-4f11-ac58-ea0ea24f640c",
    "planId": "5c84a2be-4b0d-4a74-a34d-cf955ec1c2a3",
    "status": "PENDING_PAYMENT",
    "amount": 999.0,
    "currency": "INR",
    "gatewayOrderId": "order_Q2tfFq7piVnE2A",
    "createdAt": "2025-03-01T12:00:00Z",
    "updatedAt": "2025-03-01T12:00:00Z"
  }
]
```

---

## 14. Payments — Get order by ID

| | |
|--|--|
| **Endpoint** | `GET /api/payments/orders/{orderId}` |
| **Auth** | Send **Bearer JWT** if your environment’s security config requires it. |

**Path parameters**

| Param | Type | Required |
|-------|------|----------|
| `orderId` | UUID | Yes |

**Response** | **200** order object · **404** empty  

**Sample:** `GET /api/payments/orders/5a3cd087-9d38-4665-b22f-bf868ce4d08b`

---

## 15. Payments — Razorpay redirect callback *(browser / gateway, not AJAX from SPA in most cases)*

| | |
|--|--|
| **Endpoint** | `GET /api/payments/callback/razorpay` |
| **Auth** | None |

**Query parameters**

| Param | Required |
|-------|----------|
| `razorpay_payment_id` | Yes |
| `razorpay_order_id` | Yes |

**Response**

| HTTP | Notes |
|------|--------|
| **302** | `Location` header = frontend success/failure URL (configured server-side) |
| **400** | Missing params or bad redirect config |

**Sample (browser redirect)**

```http
GET /api/payments/callback/razorpay?razorpay_payment_id=pay_xxx&razorpay_order_id=order_xxx
```

**Response header example**

```http
HTTP/1.1 302 Found
Location: https://yourapp.com/payment/success
```

---

## 16. Payments — Razorpay webhook *(do not call from UI)*

| | |
|--|--|
| **Endpoint** | `POST /api/payments/webhook/razorpay` |
| **Auth** | **Razorpay signature** — header `X-Razorpay-Signature` |

> **Frontend:** Do not implement. Razorpay servers call this directly.

---

## 17. AI — Chat

| | |
|--|--|
| **Endpoint** | `POST /api/ai/chat` |
| **Auth** | **Bearer JWT** |

**Request body (JSON)** — dynamic; commonly:

| Field | Type | Required | Notes |
|-------|------|----------|--------|
| `message` | string | Yes for follow-up | Empty body may start new session (per service). |

**Response (200)**

```json
{
  "question": "I am a BTech final year student...",
  "answer": "Based on your profile...",
  "nextStep": "Share your interests..."
}
```

**Errors:** **400** `{ "error": "message is required" }` etc. · **401** `{ "error": "Unauthorized" }`

**Sample request**

```http
POST /api/ai/chat HTTP/1.1
Authorization: Bearer <token>
Content-Type: application/json

{
  "message": "I have 4 years of Java experience and want to move to AI.",
  "userType": "professional",
  "targetRole": "AI Engineer"
}
```

---

## 18. AI — Career suggestions

| | |
|--|--|
| **Endpoint** | `GET /api/ai/career-suggestions` |
| **Auth** | **Bearer JWT** |

**Request body** | None  

**Response (200)** | JSON object — structure from service (conversation + suggestions).

**Sample request**

```http
GET /api/ai/career-suggestions HTTP/1.1
Authorization: Bearer <token>
```

---

## 19. Planned external APIs *(not in backend yet — for roadmap)*

| Method | Path | Auth | Notes |
|--------|------|------|--------|
| GET | `/api/questions` | JWT | Static questions by user group |
| POST | `/api/documents/upload-url` | JWT | Presigned resume upload |
| GET | `/api/documents/{documentId}` | JWT | Parsed resume JSON |

See [API-CONTRACTS.md](./API-CONTRACTS.md) §4.6.

---

## 20. Quick checklist for UI devs

1. **Register:** `POST /api/auth/signup` → store `userId` → `POST /api/auth/login` → store `token`.  
2. **Profile:** `GET /api/users/{userId}` with `userId ===` decoded JWT `sub`.  
3. **Update details:** `POST /api/users` with Bearer token.  
4. **Plans:** `GET /api/admin/plans?activeOnly=true` with Bearer (or Basic for admin tools).  
5. **Checkout:** `POST /api/payments/orders` with `{ "planId" }` only.  
6. **Pay:** Use Razorpay Checkout with `gatewayOrderId` / `keyId` from your payment integration layer (see backend/order response fields).  
7. **AI:** `POST /api/ai/chat`, `GET /api/ai/career-suggestions` with Bearer.

---

## Related docs

- [API-CONTRACTS.md](./API-CONTRACTS.md) — JWT vs internal Basic, forgot/reset contract  
- [DATA-MODEL-AND-ENTITIES.md](./DATA-MODEL-AND-ENTITIES.md) — tables & ownership  
- [README.md](./README.md) — doc index & product brief  
- [postman/CURL_EXAMPLES.md](./postman/CURL_EXAMPLES.md) — cURL copies  
