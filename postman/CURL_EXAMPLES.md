# cURL examples – localhost:8081

Replace `YOUR_JWT` with the token from `POST /api/auth/login`. Replace `USER_UUID` / `PLAN_UUID` / `ORDER_UUID` with real IDs. Basic auth for plan admin POST/PUT: `planadmin:change-me-in-production` (from application.properties).

Base URL: `http://localhost:8081`

---

## Auth

**Signup**
```bash
curl -s -X POST http://localhost:8081/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","phone":null,"password":"your-password"}'
```

**Login**
```bash
curl -s -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","mobile_number":null,"password":"your-password"}'
```

**Logout**
```bash
curl -s -X POST http://localhost:8081/api/auth/logout \
  -H "Authorization: Bearer YOUR_JWT"
```

**Forgot password** (contract — implement; see `docs/API-CONTRACTS.md`)
```bash
curl -s -X POST http://localhost:8081/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'
```

**Reset password** (contract — implement)
```bash
curl -s -X POST http://localhost:8081/api/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{"token":"<from-email>","newPassword":"new-secure-password"}'
```

---

## User

**Get my profile**
```bash
curl -s http://localhost:8081/api/users/USER_UUID \
  -H "Authorization: Bearer YOUR_JWT"
```

**Update my profile**
```bash
curl -s -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT" \
  -d '{"email":"updated@example.com","name":"My Name","phone":"+919876543210"}'
```

---

## Plan Admin

**List plans (JWT)**
```bash
curl -s "http://localhost:8081/api/admin/plans" \
  -H "Authorization: Bearer YOUR_JWT"
```

**List plans (Basic auth)**
```bash
curl -s -u "planadmin:change-me-in-production" "http://localhost:8081/api/admin/plans"
```

**List plans with query**
```bash
curl -s "http://localhost:8081/api/admin/plans?planType=PRO&activeOnly=true" \
  -H "Authorization: Bearer YOUR_JWT"
```

**Get plan by ID**
```bash
curl -s http://localhost:8081/api/admin/plans/PLAN_UUID \
  -H "Authorization: Bearer YOUR_JWT"
```

**Create plan (Basic only)**
```bash
curl -s -X POST http://localhost:8081/api/admin/plans \
  -u "planadmin:change-me-in-production" \
  -H "Content-Type: application/json" \
  -d '{"planType":"PRO","price":19.99,"currency":"USD","isActive":true,"metadata":{"description":"Pro plan"},"actionCodes":["RUN_TEST_SUITE","STORE_PROFILE"],"featureCodes":["CAREER_GUIDANCE"]}'
```

**Update plan (Basic only)**
```bash
curl -s -X PUT http://localhost:8081/api/admin/plans/PLAN_UUID \
  -u "planadmin:change-me-in-production" \
  -H "Content-Type: application/json" \
  -d '{"planType":"PRO","price":24.99,"currency":"USD","isActive":true,"metadata":{},"actionCodes":["RUN_TEST_SUITE","STORE_PROFILE"],"featureCodes":["CAREER_GUIDANCE"]}'
```

---

## AI

**Chat (with message)**
```bash
curl -s -X POST http://localhost:8081/api/ai/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT" \
  -d '{"message":"I want to explore tech careers"}'
```

**Chat (start – no message)**
```bash
curl -s -X POST http://localhost:8081/api/ai/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT" \
  -d '{}'
```

**Get career suggestions**
```bash
curl -s http://localhost:8081/api/ai/career-suggestions \
  -H "Authorization: Bearer YOUR_JWT"
```

---

## Payments

**Create order**
```bash
curl -s -X POST http://localhost:8081/api/payments/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT" \
  -d '{"planId":"PLAN_UUID"}'
```

**My orders**
```bash
curl -s http://localhost:8081/api/payments/orders \
  -H "Authorization: Bearer YOUR_JWT"
```

**Get order by ID**
```bash
curl -s http://localhost:8081/api/payments/orders/ORDER_UUID \
  -H "Authorization: Bearer YOUR_JWT"
```

**Callback (redirect – e.g. mock)**
```bash
curl -s -i "http://localhost:8081/api/payments/callback/razorpay?razorpay_payment_id=pay_mock&razorpay_order_id=mock_order_ORDER_UUID"
```

**Webhook**
```bash
curl -s -X POST http://localhost:8081/api/payments/webhook/razorpay \
  -H "Content-Type: application/json" \
  -H "X-Razorpay-Signature: any" \
  -d '{"event":"payment.captured","payload":{"payment":{"entity":{"id":"pay_xxx","order_id":"order_xxx"}}}}'
```
