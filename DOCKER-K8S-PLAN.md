# Docker & Kubernetes Deployment Plan — AI TechTap Core

This plan gets the service running with **Docker** and **Kubernetes** locally first, then prepares for cloud (EKS or EC2 + managed Kubernetes).

---

## 1. Current Stack Summary

| Component        | Technology        | Port / Notes                          |
|-----------------|-------------------|--------------------------------------|
| Application     | Spring Boot 3 (app module) | 8081, single JAR              |
| Relational DB   | PostgreSQL        | 5432, database `aitechtap`            |
| Document store  | MongoDB           | 27017, database `aitechtap`           |
| Build           | Gradle            | `:app:bootJar` produces runnable JAR  |

No Docker or Kubernetes config exists yet; this plan adds it step by step.

---

## 2. Phase 1 — Local Docker (Single Machine)

**Goal:** Run app + PostgreSQL + MongoDB on your machine using Docker (and optionally Docker Compose).

### 2.1 Add to the repo

- **Dockerfile** (multi-stage): build with Gradle, run with JRE 21; expose 8081.
- **docker-compose.yml** (or `compose.yaml`):
  - Service `postgres`: image `postgres:16`, port 5432, env for user/password/db name, volume for data.
  - Service `mongo`: image `mongo:7`, port 27017, volume for data.
  - Service `app`: build from Dockerfile, depends on `postgres` and `mongo`, env pointing to `postgres:5432` and `mongo:27017`, port 8081.

### 2.2 Configuration

- Use env vars or a **profile** (e.g. `application-docker.properties`) so the app gets:
  - `spring.datasource.url=jdbc:postgresql://postgres:5432/aitechtap`
  - `spring.data.mongodb.uri=mongodb://mongo:27017/aitechtap`
- No code change required if you keep the same property names and override via env/profile.

### 2.3 Local workflow

1. From repo root: `docker compose up -d postgres mongo` then `docker compose up --build app` (or `docker compose up --build` for all).
2. App: `http://localhost:8081`, Swagger: `http://localhost:8081/swagger-ui/index.html`.
3. Optional: `.env` file for secrets (DB passwords, JWT secret); add `.env` to `.gitignore` if it contains secrets.

**Exit criteria:** App starts, health check passes, can login and hit one DB-backed and one Mongo-backed API.

---

## 3. Phase 2 — Local Kubernetes (Minikube / Kind / K3d)

**Goal:** Run the same stack on a local Kubernetes cluster so manifests are validated before cloud.

### 3.1 Choose local cluster (pick one)

- **Minikube** — good default, works on Windows/Mac/Linux.
- **Kind** — cluster-in-Docker, fast, CI-friendly.
- **K3d** — lightweight K3s in Docker.

### 3.2 Kubernetes manifests (suggested layout)

Create a directory, e.g. `k8s/` or `deploy/`, with:

| Manifest / directory | Purpose |
|----------------------|--------|
| **Namespace**        | e.g. `aitechtap` (optional but recommended). |
| **Secrets**          | DB passwords, JWT secret, any API keys (base64 or external secret store). |
| **ConfigMap**        | Non-secret config (e.g. DB host names, feature flags) if not only in image/env. |
| **PostgreSQL**       | Deployment (1 replica for dev) + Service (clusterIP); optional PVC for data. |
| **MongoDB**          | Deployment (1 replica) + Service (clusterIP); optional PVC. |
| **App**              | Deployment (replicas: 1, then 2+ for cloud), env from ConfigMap/Secret, liveness/readiness probes on 8081, resource requests/limits. |
| **App Service**      | ClusterIP (or NodePort for local access). |
| **Ingress** (optional) | For local, e.g. `minikube addons enable ingress` and Ingress pointing to app Service (host e.g. `aitechtap.local`). |

### 3.3 App configuration in K8s

- Same as Docker: datasource URL and MongoDB URI must point to **K8s Service names** (e.g. `postgres`, `mongo`) and internal ports (5432, 27017).
- Use env from ConfigMap/Secret; or one ConfigMap with `application.yaml` snippet and `SPRING_CONFIG_ADDITIONAL_LOCATION` or `SPRING_CONFIG_IMPORT` if you prefer file-based config.

### 3.4 Local workflow

1. Start cluster: e.g. `minikube start` (or kind/k3d equivalent).
2. Build image so cluster can pull it:
   - **Minikube:** `eval $(minikube docker-env)` then `docker build -t aitechtap-core:local .` from repo root (Dockerfile context = root).
   - **Kind:** build image and load into kind: `kind load docker-image aitechtap-core:local`.
3. Apply manifests: `kubectl apply -f k8s/` (or apply in order: namespace → secrets → configmap → postgres → mongo → app → service → ingress).
4. Access app:
   - NodePort: `kubectl get svc`, then `http://<node-ip>:<nodeport>`.
   - Ingress: `http://aitechtap.local` (add host to hosts file if needed).
   - Port-forward (quick test): `kubectl port-forward svc/aitechtap-app 8081:8081 -n aitechtap`.

**Exit criteria:** All pods Running, app responds on 8081, DBs and Mongo are reachable from app pod; Swagger and one auth + one DB call work.

---

## 4. Phase 3 — Cloud Deployment (EKS vs EC2 + Managed K8s)

**Goal:** Same Kubernetes manifests (with env-specific tweaks) run in AWS — either **EKS only** or **EC2 + a managed Kubernetes** (e.g. EKS on EC2, or another managed K8s).

### 4.1 Option A — Amazon EKS (recommended)

- **What:** Managed control plane; you manage node group(s) (EC2 or Fargate).
- **Pros:** No control-plane ops, scales well, integrates with IAM, ALB/NLB, RDS, etc.
- **Steps (high level):**
  1. Create EKS cluster (console, Terraform, or eksctl).
  2. Add node group(s) (e.g. 2–3 t3.medium for dev).
  3. Use same K8s manifests; differences:
     - **PostgreSQL / MongoDB:** Prefer **managed services** (RDS PostgreSQL, DocumentDB or Atlas) instead of running DBs in K8s in production. Point app ConfigMap/Secret to RDS and Mongo connection strings.
     - **Secrets:** Use AWS Secrets Manager or Parameter Store + e.g. External Secrets Operator / CSI driver, or inject env at deploy time.
     - **Image:** Build and push app image to ECR; in Deployment use `image: <account>.dkr.ecr.<region>.amazonaws.com/aitechtap-core:<tag>`.
     - **Ingress/Load balancer:** Install AWS Load Balancer Controller; use Ingress (ALB) or Service type LoadBalancer (NLB) for app.
     - **HTTPS:** Terminate TLS at ALB; certificate in ACM.
  4. CI/CD: Build JAR → build image → push to ECR → update K8s Deployment (e.g. `kubectl set image` or GitOps with Argo CD/Flux).

### 4.2 Option B — EC2 + “Managed Kubernetes” (e.g. EKS on EC2, or other provider)

- **What:** You run one or more EC2 instances and either:
  - Use **EKS** with a node group backed by those EC2 instances (same as Option A), or
  - Use a different “managed K8s” (e.g. managed control plane elsewhere with nodes on your EC2).
- **Plan:** Same as Option A for EKS. If “managed K8s” is not EKS, adapt load balancer and ingress to that provider; the app and DB connection approach stay the same.

### 4.3 Database strategy in cloud

- **Dev / staging:** You can still run Postgres and Mongo inside the cluster (as in Phase 2) for cost savings.
- **Production:** Use **RDS (PostgreSQL)** and **DocumentDB or MongoDB Atlas**; store connection strings and credentials in Secrets Manager/Parameter Store and inject into app via ConfigMap/Secret or sidecar.

### 4.4 Order of implementation in cloud

1. EKS cluster + node group (or EC2 + managed K8s).
2. ECR repo; build and push app image from CI or local.
3. RDS PostgreSQL (and optionally DocumentDB/Atlas) if moving off in-cluster DBs.
4. Apply K8s manifests (namespace, secrets, configmap, app Deployment/Service); keep Postgres/Mongo manifests only if you still run them in-cluster.
5. AWS Load Balancer Controller + Ingress for app; DNS record to ALB.
6. Harden: network policies, pod security, secrets management, backups for DBs.

---

## 5. Suggested File Layout (After Implementation)

```text
<repo-root>/
  Dockerfile
  docker-compose.yml
  .env.example
  app/src/main/resources/
    application-docker.properties   # optional profile for Docker/K8s
  k8s/
    namespace.yaml
    secret.yaml.example
    configmap.yaml
    postgres/
      deployment.yaml
      service.yaml
      pvc.yaml
    mongo/
      deployment.yaml
      service.yaml
      pvc.yaml
    app/
      deployment.yaml
      service.yaml
    ingress.yaml
  docs/DOCKER-K8S-PLAN.md   # this file
```

---

## 6. Checklist Summary

| Phase   | Item |
|--------|------|
| **1. Local Docker** | Dockerfile (multi-stage, JRE 21); docker-compose with postgres, mongo, app; app config for Docker hostnames; `.env.example`; run and smoke-test. |
| **2. Local K8s**   | Local cluster (minikube/kind/k3d); k8s manifests (namespace, secrets, configmap, postgres, mongo, app, service, optional ingress); image build/load; apply and test. |
| **3. Cloud**       | EKS (or EC2 + managed K8s); ECR + push image; optional RDS + DocumentDB/Atlas; same K8s manifests with cloud-specific image and secrets; ALB/NLB + Ingress; CI/CD for image and deploy. |

Start with **Phase 1**; once `docker compose up` works end-to-end, move to **Phase 2** and then reuse the same manifests (with small cloud-specific changes) for **Phase 3**.
