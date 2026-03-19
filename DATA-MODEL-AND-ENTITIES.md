# Data model: service ownership, tables, and entity structures

**Purpose:** Map **which service owns which persistence**, list **tables/collections**, and document **entity fields** (aligned with current Java modules where applicable).  
**Companion:** [API-CONTRACTS.md](./API-CONTRACTS.md), [ARCHITECTURE-HLD.md](./ARCHITECTURE-HLD.md).  
**Last updated:** 2026-03-19

---

## 1. Physical deployment vs logical ownership

You may run **one PostgreSQL cluster** and **one MongoDB cluster** for all services. **Logical ownership** means only the named service should read/write those tables/collections (enforced by code + conventions; optional separate DB users per service).

| Store | Typical physical deployment | Logical owners |
|-------|---------------------------|----------------|
| **PostgreSQL** | Single cluster, database `aitechtap` (example) | Auth (credentials, password_reset_tokens), User (user_core), Plan (plan), Payment (orders, payments), future document_meta |
| **MongoDB** | Single cluster | User (user_profiles), AI (static_questions, ai_session, …) |
| **S3** | One or more buckets | AI / document pipeline (resume PDFs) |

---

## 2. Service → table / collection matrix

| Service | PostgreSQL tables / objects | MongoDB collections |
|---------|----------------------------|---------------------|
| **Authentication** | `credentials`, `password_reset_tokens` *(planned — implement forgot/reset)* | — |
| **User profile** | `user_core` | `user_profiles` |
| **Plan** | `plan` | — |
| **Plan & payment** | `orders`, `payments` | — |
| **AI assistance** | `document_meta` *(planned for resume pipeline)* | `static_questions`, `ai_session` *(names per implementation)* |

**Cross-service rules**

- **`user_id`:** UUID string, shared across `credentials.user_id`, `user_core.user_id`, `orders.user_id`, etc.
- **Signup (one step):** Auth creates **`credentials`**; User profile creates **`user_core`** + **`user_profiles`** with the same `userId` (in-process today, or internal API when split).
- **Update profile:** User profile service only; **does not** replace signup.

---

## 3. Entity structures (PostgreSQL)

### 3.1 `credentials` — **Authentication service**

| Column | Type | Notes |
|--------|------|--------|
| `id` | UUID | PK, generated |
| `user_id` | UUID | Unique, FK logical to `user_core.user_id` |
| `password_hash` | VARCHAR(255) | BCrypt/Argon2; **not** plaintext |
| `status` | VARCHAR(50) | e.g. `ACTIVE`, `LOCKED` |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |
| `updated_by` | VARCHAR(255) | Optional audit |

**Java:** `com.aitechtap.core.authentication.model.CredentialEntity` → table `credentials`.

---

### 3.2 `password_reset_tokens` — **Authentication service** *(planned)*

| Column | Type | Notes |
|--------|------|--------|
| `id` | UUID | PK |
| `user_id` | UUID | Who may reset |
| `token_hash` | VARCHAR(255) | Hash of opaque token sent by email/SMS |
| `expires_at` | TIMESTAMP | Short TTL (e.g. 15–60 min) |
| `used_at` | TIMESTAMP | Nullable; set when password updated |
| `created_at` | TIMESTAMP | |

**Rules:** One-time use; invalidate other active tokens for same user on successful reset; rate-limit `forgot-password` by IP/email.

---

### 3.3 `user_core` — **User profile service**

| Column | Type | Notes |
|--------|------|--------|
| `id` | BIGSERIAL | Surrogate PK |
| `user_id` | VARCHAR(36) | Unique, UUID string |
| `email` | VARCHAR(255) | Unique, nullable |
| `phone` | VARCHAR(20) | Unique, nullable |
| `display_name` | VARCHAR(255) | Optional |
| `current_plan_id` | UUID | Nullable; FK logical to `plan.id` |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

**Java:** `com.aitechtap.core.user.core.UserEntity` → table `user_core`.

---

### 3.4 `plan` — **Plan service** (catalog)

| Column | Type | Notes |
|--------|------|--------|
| `id` | UUID | PK |
| `plan_type` | VARCHAR(50) | e.g. FREE, PRO, ELITE |
| `price` | NUMERIC(10,2) | |
| `currency` | VARCHAR(10) | Default INR |
| `is_active` | BOOLEAN | |
| `metadata` | JSONB | Flexible plan display/config |
| `action_codes` | JSONB | Array of strings |
| `feature_codes` | JSONB | Array of strings |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

**Java:** `com.aitechtap.core.plan.entity.PlanEntity` → table `plan`.

---

### 3.5 `orders` — **Plan & payment service**

| Column | Type | Notes |
|--------|------|--------|
| `id` | UUID | PK |
| `user_id` | VARCHAR(36) | From JWT `sub` only |
| `plan_id` | UUID | |
| `status` | VARCHAR(50) | CREATED, PENDING_PAYMENT, … |
| `amount` | NUMERIC(10,2) | |
| `currency` | VARCHAR(10) | |
| `gateway_order_id` | VARCHAR(255) | Nullable |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

**Java:** `com.aitechtap.core.paymentgateway.entity.OrderEntity` → table `orders`.

---

### 3.6 `payments` — **Plan & payment service**

| Column | Type | Notes |
|--------|------|--------|
| `id` | UUID | PK |
| `order_id` | UUID | FK → `orders.id` |
| `payment_type` | VARCHAR(50) | SUBSCRIPTION, ONE_TIME |
| `payment_method` | VARCHAR(50) | Optional |
| `gateway` | VARCHAR(50) | e.g. RAZORPAY |
| `gateway_payment_id` | VARCHAR(255) | |
| `gateway_order_id` | VARCHAR(255) | |
| `status` | VARCHAR(50) | PENDING, SUCCESS, … |
| `amount` | NUMERIC(10,2) | |
| `currency` | VARCHAR(10) | |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

**Java:** `com.aitechtap.core.paymentgateway.entity.PaymentEntity` → table `payments`.

---

### 3.7 `document_meta` — **AI assistance** *(planned)*

| Column | Type | Notes |
|--------|------|--------|
| `id` | UUID | PK |
| `user_id` | VARCHAR(36) | Owner |
| `s3_bucket` | VARCHAR(255) | |
| `s3_key` | VARCHAR(1024) | |
| `status` | VARCHAR(50) | PENDING, READY, FAILED |
| `parsed_json_ref` | TEXT or JSONB | Pointer or inline summary |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

---

## 4. Entity structures (MongoDB)

### 4.1 Collection `user_profiles` — **User profile service**

| Field | Type | Notes |
|-------|------|--------|
| `_id` | ObjectId | Mongo id |
| `userId` | String | Unique index; matches `user_core.user_id` |
| `profile_data` | Object | Dynamic key/values (student/professional fields) |
| `createdAt` | Date | |
| `updatedAt` | Date | |

**Java:** `com.aitechtap.core.user.profile.UserProfileDocument` → collection `user_profiles`.

---

### 4.2 Collections for **AI assistance** *(planned / extend as needed)*

| Collection | Purpose |
|------------|---------|
| `static_questions` | Questions per `user_group`, ordering, active flag |
| `ai_session` or `user_ai_sessions` | Session id, `userId`, messages, metadata |

Shape is product-specific; keep `userId` indexed.

---

## 5. Auth flows vs data touched

| Flow | Auth service | User profile service |
|------|--------------|----------------------|
| **POST /api/auth/signup** | INSERT `credentials` | INSERT `user_core`, INSERT `user_profiles` (minimal profile from email/phone) |
| **POST /api/users** (JWT) | — | UPDATE `user_core` / merge `user_profiles.profile_data` |
| **POST /api/auth/forgot-password** | INSERT `password_reset_tokens` | Optional read `user_core` to resolve email/phone → `user_id` |
| **POST /api/auth/reset-password** | UPDATE `credentials.password_hash`, mark token used | — |
| **POST /api/auth/login** | READ `credentials`, issue JWT | READ `user_core` (via facade) to resolve login identifier → `user_id` |

---

## 6. Removed / out of scope

- **Google signup:** not supported; no OAuth-only credential row without password (unless reintroduced later).

---

## 7. Related files in repository

| Module | Entities / documents |
|--------|----------------------|
| `authentication` | `CredentialEntity` |
| `user` | `UserEntity`, `UserProfileDocument` |
| `plan` | `PlanEntity` |
| `paymentgateway` | `OrderEntity`, `PaymentEntity` |

---

## Related docs

- [README.md](./README.md) — doc index  
- [API-CONTRACTS.md](./API-CONTRACTS.md) — external vs internal APIs  
- [ARCHITECTURE-HLD.md](./ARCHITECTURE-HLD.md) — system overview  

---

## 8. Changelog

| Date | Change |
|------|--------|
| 2026-03-19 | Initial: service→table matrix, entity fields, signup vs update profile, password_reset_tokens planned, Google removed. |
