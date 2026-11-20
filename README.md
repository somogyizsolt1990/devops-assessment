# DevOps Engineer Homework

> **The solution (user guide, changes, assumptions, limitations, improvements) is documented in [Solution](#solution), after the original assignment.**

## Overview

The goal of this assignment is to evaluate how you approach a typical DevOps engineering task involving:

- Application development / scripting
- Containerization
- Kubernetes
- Helm
- Terraform
- CI/CD
- Code review

The repository contains intentionally incomplete and imperfect components.
Your task is to complete, improve and document the solution.

You are not expected to produce a perfect production-ready system. We are more interested in your engineering approach, decision-making and ability to balance quality with the time constraints.

Time limit: approximately **3 hours**

## Repository Contents

The repository contains:

- An incomplete application skeleton
- Terraform configuration requiring review and improvement
- An incomplete Helm chart
- An incomplete CI/CD pipeline

Your task is to complete and improve these components. Our goal is to understand your engineering approach, and we will build the upcoming technical interview on this project.

## Goal 1

Complete and improve the provided project.

The repository contains the following files:

- Incomplete application code
- Broken/incomplete terraform configuration
- Incomplete Helm Chart
- Incomplete Gitlab CI pipeline

### Requirements

#### Application

Implement a simple application in either:

- Go
- Python

The application must expose the following endpoints:

##### `GET /health`

**Response:**

```json
{
    "status": "ok"
}
```

##### `GET /version`

**Response:**

```json
{
    "version": "1.0.0"
}
```

##### `GET /env`

**Response:**

```json
{
    "environment": "<value from ENVIRONMENT variable>"
}
```

##### `POST /config`

**Request:**

```json
{
    "name": "database_url",
    "value": "postgres://example"
}
```

**Response:**

```json
{
    "name": "database_url",
    "value": "postgres://example"
}
```

##### `GET /config/{name}`

**Example:**

```bash
GET /config/database_url
```

**Response:**

```json
{
    "name": "database_url",
    "value": "postgres://example"
}
```

##### `DELETE /config/{name}`

**Response:**

```json
{
    "deleted": true
}
```

#### Containerization

- Create the necessary Dockerfile with minimal setup
- The image should:
  - build successfully
  - run locally
  - expose the application endpoint

#### Terraform

- Review and fix/complete the Terraform code
- The Terraform code contains several issues and areas for improvement
- In case you don't get time to implement changes describe what would you still improve and why
- Document any changes you make

#### Helm

- Review and fix/complete the Helm Chart
- The chart should deploy the application to Kubernetes
- Document any change you make

#### Gitlab CI

- Complete the pipeline so it becomes capable of building and deploying the application
- The pipeline should support the workflow required to build and deploy the application
- The pipeline should be logically complete and demonstrate how you would automate the process
- Add any other necessary jobs to the pipeline

#### Documentation

Update the project README with following information.

##### What You Changed

Describe the changes and the rationale behind it.

##### Assumptions

Describe the assumptions made while completing the assignment.

##### Known Limitations

Describe anything you intentionally omitted.

##### Production Improvements

Describe how you would evolve this solution for production use.

### Deliverables

- Source Code of the Go/Python application
- Dockerfile
- Terraform changes
- Helm changes
- CI pipeline changes
- README describing decisions, assumptions and user guide for the project.

### Notes

You are not expected to deploy to a cloud provider.
The solution should work with a local Kubernetes cluster such as:

- Kind
- Minikube
- K3d

### Timing

Timebox yourself to approximately **3 hours**. If you can't finish the work within the timebox, describe in the README.md what is left and how you would approach it.

## Goal 2

You get this half-baked project from one of your colleagues who is a Junior and asking for your guidance.

Provide a short code review in `REVIEW.md` where you address the **top 5 most important things** to fix so the colleague can move forward.

### Review Timing

Spend no more than **30 minutes** on review and feedback.

### Evaluation Criteria

We will evaluate:

- Code quality
- Terraform quality
- Kubernetes and Helm knowledge
- CI/CD design and implementation
- Documentation quality
- Code review quality
- Maintainability and operational thinking

### Use of AI

The use of AI-assisted tools is permitted. However, we encourage you to complete the assignment primarily based on your own knowledge, experience and reasoning. During the interview, we will discuss your implementation choices, trade-offs and decision-making process, so it is important that you fully understand and can explain every part of your solution.

---

# Solution

## User Guide

### Repository layout

| Path | Content |
|---|---|
| `app/` | FastAPI application, unit tests, `Dockerfile` |
| `helm/myapp/` | Helm chart |
| `terraform/` | Namespace and Helm release; `environments/dev.tfvars` for the local cluster |
| `.gitlab-ci.yml` | Pipeline: lint → test → build → plan → deploy → verify |
| `REVIEW.md` | Code review of the original skeleton for the junior colleague (Goal 2) |

### Prerequisites

Tested with: Python 3.12, Docker 28.4, k3d 5.9 (k3s 1.35), kubectl 1.37, Helm 4.3, Terraform 1.17.

### 1. Run the application locally

```bash
cd app
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q
ENVIRONMENT=local uvicorn main:app --port 8080
```

Interactive API docs: `http://localhost:8080/docs`. Example calls:

```bash
curl http://localhost:8080/health
curl -X POST http://localhost:8080/config -H 'Content-Type: application/json' \
     -d '{"name": "database_url", "value": "postgres://example"}'
curl http://localhost:8080/config/database_url
curl -X DELETE http://localhost:8080/config/database_url
```

### 2. Build and run the container

```bash
docker build -t myapp:1.0.0 --build-arg APP_VERSION=1.0.0 app/
docker run --rm -p 8080:8080 -e ENVIRONMENT=local myapp:1.0.0
```

### 3. Create the local cluster and load the image

There is no registry: the image is imported into the cluster directly.

```bash
k3d cluster create homework -p "8081:80@loadbalancer"
k3d image import myapp:1.0.0 --cluster homework
```

The Ingress host `myapp.localhost` resolves to 127.0.0.1 without an `/etc/hosts` entry, so the app is reachable at `http://myapp.localhost:8081`.

### 4a. Deploy with Terraform (the supported way)

The state lives in GitLab (`backend "http"`). Set the backend through the same `TF_HTTP_*` variables the pipeline uses, with a GitLab personal access token (`api` scope):

```bash
cd terraform
export TF_HTTP_ADDRESS="https://gitlab.com/api/v4/projects/<PROJECT_ID>/terraform/state/dev"
export TF_HTTP_LOCK_ADDRESS="$TF_HTTP_ADDRESS/lock" TF_HTTP_UNLOCK_ADDRESS="$TF_HTTP_ADDRESS/lock"
export TF_HTTP_LOCK_METHOD=POST TF_HTTP_UNLOCK_METHOD=DELETE TF_HTTP_USERNAME=<gitlab-user>
read -rs TF_HTTP_PASSWORD && export TF_HTTP_PASSWORD   # paste the token; not stored in shell history
terraform init                                         # add -migrate-state once to upload an existing local state
terraform apply -var-file=environments/dev.tfvars -var image_tag=1.0.0
terraform output
```

Without a GitLab project, use local state through a gitignored override file instead:

```bash
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
terraform init
terraform apply -var-file=environments/dev.tfvars -var image_tag=1.0.0
```

### 4b. Deploy with Helm only (quick test, no Terraform)

```bash
helm upgrade --install homework helm/myapp --namespace myapp-test --create-namespace --kube-context k3d-homework
```

Do not use the Terraform-managed namespace (`myapp-dev`) here, and uninstall afterwards: both releases would claim the same Ingress host.

### 5. Check the deployment

```bash
helm test homework --namespace myapp-dev --kube-context k3d-homework
curl http://myapp.localhost:8081/health
curl http://myapp.localhost:8081/env       # {"environment":"dev"}
```

### 6. CI/CD

The pipeline needs the repository in a GitLab project and a self-hosted GitLab Runner with the **shell** executor, tagged `k3d`, on the machine that runs the cluster (with `docker`, `k3d`, `terraform`, `helm`, `curl` and the `k3d-homework` kubeconfig context). No CI/CD variables have to be set: the Terraform state is authenticated with the job token. Before the first pipeline, migrate any local state (step 4a, `-migrate-state`).

### 7. Clean up

```bash
k3d cluster delete homework
```

## What You Changed

### Application (`app/`)

I'm not a developer, so the application code (FastAPI) was written by AI based on my request and decisions. I reviewed it and tested it with curl.

- **Python 3.12 + FastAPI, a single `main.py`** – the same Python version locally and in the image; six endpoints do not justify splitting the code into routers and services.
- **In-memory config store** (a dict) – fits the timebox and needs no external dependency. Trade-off: data is lost on restart and is not shared between processes, so the app runs with one uvicorn worker and one replica (see Known Limitations).
- **Async handlers** – every request runs on one event loop, so the dict needs no lock.
- **Port 8080** – matches the Helm Service `targetPort` and `values.yaml`.
- **`/version` comes from `APP_VERSION`** (default `1.0.0`), baked into the image at build time – the endpoint reports what is really in the running image, not what a deployment claims.
- **`/env` returns `unknown` when `ENVIRONMENT` is not set** – the spec does not define this case; this avoids a 500 error.
- **`POST /config` is an upsert** – 201 when the entry is created, 200 when it is overwritten.
- **`GET /config/{name}` returns 404** for an unknown name.
- **`DELETE /config/{name}` is idempotent** – deleting a missing entry returns 200 with `{"deleted": false}`.
- **Name validation `^[A-Za-z0-9_.-]{1,128}$`** – the name is also a URL path segment, so for example a `/` would break `GET /config/{name}`. Invalid input gets a 422 from FastAPI/Pydantic.
- **Pinned dependencies** – `requirements.txt` (runtime) and `requirements-dev.txt` (pytest, httpx) for reproducible builds.
- **Unit tests** (`app/tests/`, pytest, 15 cases) – every endpoint, the error cases and input validation.

### Containerization (`app/Dockerfile`)

- **`python:3.12-slim`, single stage** – the assignment asks for a minimal setup, and all dependencies are prebuilt wheels, so a builder stage would add little. Alpine (musl) risks wheel compatibility issues; distroless is listed as a production improvement.
- **Non-root user with numeric UID 10001** – Kubernetes `runAsNonRoot` can only verify a numeric UID.
- **Dependencies installed before the code is copied** – code changes reuse the cached pip layer.
- **`APP_VERSION` build argument declared after the pip layer** – a new version does not invalidate the dependency cache. It is also set as an OCI label.
- **Code owned by root** – the app user can read it but cannot modify it.
- **`PYTHONUNBUFFERED`, `PYTHONDONTWRITEBYTECODE`** – logs reach `kubectl logs` immediately, and no `.pyc` files are written (works with a read-only root filesystem).
- **Exec-form `CMD`, one uvicorn worker** – uvicorn is PID 1 and receives SIGTERM for a graceful shutdown; one worker because of the in-memory store.
- **No `HEALTHCHECK`** – Kubernetes ignores it and uses the Helm probes instead.
- **Allow-list `.dockerignore`** – only `main.py` and `requirements.txt` reach the build context.

### Helm (`helm/myapp/`)

- **`deployment.yaml`: port 5000 mistake** – fixed it, the app listens on 8080.
- **The chart was in the wrong path**, and `myapp` was hardcoded in many places, so it was easier to move it into a `myapp` folder (and fix the Terraform path).
- **Names and labels come from `_helpers.tpl`** – the Service selector (`myapps`) did not match the pod label (`myapp`), so the Service had no endpoints. Selector labels are now defined in one place, and names depend on the release, so two releases do not collide.
- **Ingress backend** pointed to a non-existent `homeworks` Service – it now points to the chart's own Service by port name. The Ingress is optional (`ingress.enabled`), its class comes from values (empty means the cluster default), and the host is `myapp.localhost`, which resolves to 127.0.0.1 without an `/etc/hosts` entry.
- **Service port 80 → named container port `http` (8080)** – the container port number is defined only once.
- **`replicas` reads `replicaCount`** (it was hardcoded) – kept at 1 because of the in-memory store.
- **Image tag defaults to `appVersion`, never `latest`** – reproducible deployments and real rollbacks; CI overrides it with `--set image.tag=…`. `pullPolicy: IfNotPresent`.
- **Liveness and readiness probes on `/health`** – the app has no external dependencies, so both can use the same endpoint.
- **Resources: requests 50m CPU / 64Mi memory, memory limit 128Mi, no CPU limit** – the memory limit protects against the in-memory store growing; a CPU limit would throttle the pod even when the node has idle CPU. Measured usage: about 32 MiB.
- **Security context matching the "restricted" Pod Security Standard** (non-root, read-only root filesystem, no privilege escalation, all capabilities dropped, RuntimeDefault seccomp) and `automountServiceAccountToken: false`, because the app never calls the Kubernetes API. Verified in a namespace labelled `pod-security.kubernetes.io/enforce=restricted`.
- **`helm test` pod** – calls `/health` through the Service and can serve as a post-deploy smoke test in CI. It has no selector labels, so the Service never routes traffic to it.
- **`NOTES.txt` and `.helmignore` added**, chart version bumped to `0.2.0`, `appVersion` quoted.

### Terraform (`terraform/`)

- **The namespace was hardcoded** (`production`) although there is a `var.namespace` variable – fixed it.
- **The `image.tag` value cannot be empty** (it was a syntax error) – fixed it, it now uses `var.image_tag`.
- **The `environment` value `prod` without quotes is an invalid reference** (Terraform reads a bare word as a reference) – fixed it, it now uses `var.environment`.
- **The chart path `../helm/homework` did not exist** – it now points to the chart through `${path.module}/../helm/myapp`, so it works from any working directory and inside a module.
- **Provider versions pinned** (`helm ~> 3.3`, `kubernetes ~> 3.5`) and `.terraform.lock.hcl` committed – without `required_providers` every `init` pulled the latest major version, and the code failed `terraform validate` with helm provider v3 (`kubernetes {}` and `set {}` blocks are v2 syntax). The code now uses the v3 syntax.
- **Chart values passed with `values = [yamlencode(...)]` instead of `set`** – `set` parses values the way `helm --set` does, so a tag like `1.10` would become the number `1.1`; `yamlencode` keeps the types and shows all values in one place.
- **Explicit cluster selection** – `kubeconfig_path` (default `~/.kube/config`) and a required `kube_context` variable. Before, it deployed to whatever context was current in the kubeconfig, which can easily be the wrong cluster.
- **`kubernetes_namespace` → `kubernetes_namespace_v1`** (the old resource is deprecated), labelled `pod-security.kubernetes.io/enforce=restricted`, so the cluster rejects pods that do not meet the "restricted" Pod Security Standard.
- **Variables have descriptions and validation** – `namespace` must be a valid DNS label, `environment` must be `dev`, `staging` or `prod`, and `image_tag` must not be empty or `latest`. Wrong values fail at `plan` instead of in the cluster.
- **Per-environment values in `environments/dev.tfvars`** (the local k3d cluster). `image_tag` is not in it, because it changes with every deployment and is passed by the caller (CI).
- **Failed releases roll back** – `atomic = true`, `cleanup_on_fail = true`, `timeout = 180`: if the release does not become ready, Helm rolls back to the previous revision and `terraform apply` fails, so CI sees the error. Tested with a non-existent image tag: after 180 s the apply failed, Helm rolled back to revision 1, and the old pod kept serving.
- **Outputs** – namespace, release name, status, revision and the deployed image tag, visible in the CI log and with `terraform output`. The image tag is read from the release, not from `var.image_tag`: the rollback test showed that after a failed apply the variable-based output reported the tag that was rejected, not the one running.
- **Formatted with `terraform fmt`** (2-space HCL convention).
- **Shared remote state: GitLab-managed Terraform state** (`backend "http" {}` in `backend.tf`) – CI deploys with Terraform, so every run must see the same state; GitLab gives locking, versioning and access control through project permissions, with no extra infrastructure. The backend block is empty (partial configuration): CI fills it from `TF_HTTP_*` variables with the job token, local runs pass `-backend-config` options with a personal access token. GitLab's own Terraform CI templates were removed after the Terraform licence change, so the pipeline calls the plain `terraform` CLI.

Verified on the local k3d cluster: `fmt -check` and `validate` pass, invalid variable values are rejected at `plan`, `apply` creates the namespace and the release, `helm test` passes, all endpoints answer through the Ingress, and a second `plan` reports "No changes".

### GitLab CI (`.gitlab-ci.yml`)

The original pipeline only printed text. It now has six stages: `lint` → `test` → `build` → `plan` → `deploy` → `verify`, with the cheap checks first.

- **Two kinds of runners** – `lint` and `test` run on GitLab shared runners (Docker executor) with pinned images: `hashicorp/terraform:1.17.2`, `alpine/helm:4.3.2` (a community image; there is no official Helm image) and `python:3.12-slim`. `build`, `plan`, `deploy` and `verify` run on a self-hosted shell runner tagged `k3d`, on the machine that hosts the cluster. There is no container registry, so only a cluster on the same Docker host can use the image (`k3d image import`), and the kubeconfig never leaves that host or gets stored in GitLab variables.
- **Merge requests vs. default branch** – merge requests get lint, test, build and plan; the default branch also deploys automatically to `dev` and verifies it. `workflow:rules` prevents duplicate branch and merge request pipelines.
- **Image tag = short commit SHA** – unique and traceable to the commit; a rollback means deploying an older SHA. `APP_VERSION` is read from `appVersion` in `Chart.yaml`, so the version is defined in one place and `/version` keeps returning `1.0.0`.
- **The image reaches the cluster only in the deploy job** – nothing from an unmerged branch is imported into the cluster.
- **Plan and apply are separate** – `terraform:plan` saves the plan as an artifact (plus a readable `plan.txt`), and `terraform:apply` applies exactly that plan. The artifact expires after one day because a plan file can contain sensitive values.
- **`resource_group: dev`** – only one deployment to `dev` runs at a time; the state lock prevents conflicts, the resource group also keeps the order.
- **Verify reads its inputs from Terraform outputs** (namespace, release, image tag) instead of repeating them, checks that the release runs the image built by this pipeline, then runs `helm test` and calls `/health` through the Ingress.
- **Unit test results published as a JUnit report**, pip downloads cached per `requirements-dev.txt`.

Not run on GitLab (see Assumptions). Checked locally instead: the YAML structure (stages, `extends`, scripts); the `lint` and `test` jobs ran inside their pinned images and passed, so the image tags exist; `build`, `plan`, `deploy` and `verify` ran on the k3d host with simulated CI variables and a temporary local backend instead of the GitLab state – the image `myapp:sim0001` was built and imported, the release was upgraded to revision 4, and `helm test` and `/health` passed.

## Assumptions

- **The repository is hosted on GitHub; the GitLab pipeline is meant to be logically complete and was not executed.** Running it needs the repository in (or mirrored to) a GitLab project, plus the runner below.
- **Local Kubernetes is k3d**, because it ships an ingress controller (Traefik) and can import local images: `k3d cluster create homework -p "8081:80@loadbalancer"`. The app is then available at `http://myapp.localhost:8081`.
- **No container registry is used.** Images are built and imported on the host running k3d, through a self-hosted GitLab shell runner tagged `k3d`, which has `docker`, `k3d`, `terraform`, `helm`, `curl` and a kubeconfig with the `k3d-homework` context.
- **One environment, `dev`** (`terraform/environments/dev.tfvars`, namespace `myapp-dev`). The variable validation allows `staging` and `prod`, but they are not configured.
- **An in-memory config store is acceptable** – the assignment does not require persistence.
- **Behaviour not defined by the spec was chosen as:** 404 for an unknown name, idempotent DELETE, 201/200 on create/overwrite, 422 for invalid input, `unknown` when `ENVIRONMENT` is not set.
- **The state created during local development must be migrated once** into the GitLab state (`terraform init -migrate-state` with the GitLab backend settings); otherwise the first CI run would try to create the existing namespace again.

## Known Limitations

Intentionally omitted or accepted within the timebox:

- **Config is lost on every restart and every deployment.** The store is in process memory, and a rolling update starts a new pod. It is also not shared, so the app must run as one replica with one worker: no high availability.
- **The store has no size limit.** Many or large entries grow the memory until the 128Mi limit kills the pod, and then every entry is lost.
- **No authentication, authorization or TLS.** Anyone who reaches the Ingress can read, change and delete config, and values (which may be secrets, e.g. a database URL) travel and are returned in plain text.
- **Liveness and readiness share `/health`**, which is only correct while the app has no dependencies.
- **The pipeline is tied to one self-hosted runner and one cluster host** because there is no registry; that runner is a single point of failure.
- **The pipeline and the GitLab state backend were not run on GitLab** – only simulated locally (see the GitLab CI section).
- **Only the `dev` environment exists**, with automatic deployment; there is no staging, no promotion and no manual approval.
- **No security scanning or extra linters in CI**: no image or dependency vulnerability scan, no SAST, no Dockerfile linter (hadolint), no Python linter (ruff), no Kubernetes schema validation (kubeconform).
- **No observability beyond logs**: uvicorn access logs on stdout, no metrics, no structured logging, no tracing.
- **The application version is bumped by hand** in `Chart.yaml`; there is no release automation from git tags.
- **The `helm test` pod pulls `busybox` from Docker Hub**, so the cluster needs internet access for it.
- **The tests show a Starlette deprecation warning** for `httpx` in the TestClient; replacing it was not evaluated.

## Production Improvements

How I would evolve this for production use:

- **Persistence and scaling** – move the config to a managed database (PostgreSQL) or Redis; then run several replicas with a HorizontalPodAutoscaler, a PodDisruptionBudget and topology spread, and make readiness check the database.
- **Registry and supply chain** – push images to the GitLab Container Registry, deploy by digest, scan images and dependencies (e.g. GitLab container and dependency scanning or Trivy), sign images (cosign), use a distroless base image pinned by digest, and keep versions current with Renovate.
- **Security** – authentication and authorization on the `/config` endpoints (OIDC or API keys), TLS on the Ingress with cert-manager, a default-deny NetworkPolicy, real secrets kept in a secret manager (Vault or External Secrets) instead of a plain API, and `/docs` disabled or protected.
- **Traffic** – move from Ingress to the Gateway API (ingress-nginx is retired; Traefik and others support Gateway API).
- **CI/CD** – a Kubernetes executor or the GitLab agent for Kubernetes instead of a shell runner with a local kubeconfig; staging and production as protected environments with manual approval; release versions from git tags; hadolint, ruff, kubeconform and a Terraform security scan (Trivy config or Checkov) in the pipeline; the Terraform plan summary shown in merge requests. A GitOps tool (Argo CD or Flux) is an alternative to the push-based deploy.
- **Terraform** – one state per environment (`TF_STATE_NAME` per environment, each with its own tfvars), reusable modules once there is more than one service, and a scheduled pipeline that runs `plan` to detect drift.
- **Helm** – `values.schema.json` to validate values, the chart published to an OCI registry with automated version bumps, and a separate readiness check once there are dependencies.
- **Observability** – structured JSON logs, a Prometheus `/metrics` endpoint with a ServiceMonitor and alerts, and OpenTelemetry tracing.
- **Application** – limits on request size and on the number of entries, rate limiting, and a short `preStop` delay so in-flight requests finish before the pod leaves the Service endpoints during a rollout.