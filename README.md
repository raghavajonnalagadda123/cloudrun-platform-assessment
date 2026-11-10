# Cloud Run Platform Engineering Assessment

This repository contains my implementation of the Senior DevOps / Platform Engineer practical assessment.

The objective was to build and containerize a sample application, create reusable Terraform infrastructure for Google Cloud Run, and demonstrate how CI/CD, security, operational readiness, rollback, and high availability can be addressed.

## Project Contents

- FastAPI application with `/health`, `/ready`, and `/version` endpoints.
- Python unit tests.
- Multi-stage Dockerfile with a non-root runtime user.
- Reusable Terraform module for Cloud Run v2.
- Separate Terraform configurations for dev and prod.
- Terraform tests for service configuration and image validation.
- GitHub Actions workflows for PR validation and release.
- Workload Identity Federation configuration placeholders.
- Incident response runbook and rollback script.
- Two-region high availability architecture design.
- Ownership and AI-assisted tooling disclosure.

## 1. Project Scope

The implementation focuses on a locally validated application, a reusable Cloud Run Terraform module, and CI/CD workflow definitions.

The primary deployment configuration describes a single-region Cloud Run service. A two-region architecture using an external Application Load Balancer, serverless Network Endpoint Groups, and Cloud Armor is documented as a design.

The two-region architecture has not been deployed or tested in a live GCP environment.

The following resources need to be configured in the target GCP environment before deployment:

- GCP projects and required APIs.
- Artifact Registry repository.
- Workload Identity Federation pool and provider.
- Terraform GCS state bucket.
- GitHub repository environments and permissions.
- Required IAM roles and service account bindings.

No live GCP deployment is claimed as part of this implementation.

## 2. Local Application Setup

### Prerequisites

- Python 3.12 or later.
- Docker.
- Terraform >= 1.9.8 and < 2.0.0.

Create a virtual environment and install dependencies:

```bash
python -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt -r requirements-dev.txt
```

Run application tests:

```bash
python -m pytest -v
```

Run linting:

```bash
ruff check .
```

Start the application:

```bash
uvicorn app.main:app --host 127.0.0.1 --port 8080
```

Open another terminal and test the endpoints:

```bash
curl -i http://127.0.0.1:8080/health
curl -i http://127.0.0.1:8080/ready
curl -i http://127.0.0.1:8080/version
```

`/health` is used for liveness and `/ready` is used for readiness.

Since this is a stateless sample application, the readiness check is intentionally simple. A production application should also check critical dependencies using appropriate timeouts and failure-handling logic.

## 3. Docker Build and Validation

Build the image:

```bash
docker build -t cloudrun-platform-assessment:local .
```

Run the container:

```bash
docker run -d \
  --name cloudrun-assessment \
  -p 8080:8080 \
  cloudrun-platform-assessment:local
```

Verify the application:

```bash
curl -i http://127.0.0.1:8080/health
curl -i http://127.0.0.1:8080/ready
curl -i http://127.0.0.1:8080/version
```

Check container health and runtime identity:

```bash
docker inspect \
  --format='Health: {{.State.Health.Status}}' \
  cloudrun-assessment

docker exec cloudrun-assessment whoami
docker exec cloudrun-assessment id
```

Stop and remove the container:

```bash
docker rm -f cloudrun-assessment
```

### Docker validation evidence

The final locally validated image was:

`cloudrun-platform-assessment:v4`

The image was built successfully using:

```bash
docker build --pull --no-cache \
  -t cloudrun-platform-assessment:v4 .
```

The container was started on host port 8081 because port 8080 was already in use:

```bash
docker run -d \
  --name cloudrun-v4-test \
  -p 8081:8080 \
  cloudrun-platform-assessment:v4
```

The following checks passed:

- `/health` returned HTTP 200.
- `/ready` returned HTTP 200.
- `/version` returned HTTP 200.
- Docker HEALTHCHECK reported `healthy`.
- The application ran as user `app`, not root.
- Runtime UID/GID was `999:999`.

## 4. Docker Image Security Scanning

The container image was scanned locally using Trivy v0.76.2.

Scan command:

```bash
trivy image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  cloudrun-platform-assessment:v4
```

### Scan results

| Component | Result |
|---|---|
| Debian 13.7 operating system packages | 0 HIGH/CRITICAL |
| FastAPI 0.162.2 | No findings |
| Starlette 1.10.0 | No findings |
| pip 26.3 | No findings |
| setuptools | 1 HIGH finding reported |

The remaining finding is:

- Vulnerability: `CVE-2025-47273`
- Reported package: `setuptools`
- Reported installed version: `70.3.0`
- Fixed version: `78.1.1`

### Investigation of the setuptools finding

The reported setuptools package could not be verified inside the image:

- `pip show setuptools` returned package not found in the virtual environment.
- The same check returned package not found in system Python.
- Filesystem searches under `/usr` and `/opt` found no setuptools files.
- The Debian package database contained no setuptools package.
- Trivy reported the finding without a package path (`PkgPath: null`).

Trivy also displayed a warning that third-party SBOM data may lead to inaccurate vulnerability detection.

The finding remains unresolved and is documented rather than suppressed. No unnecessary dependency was added solely to address the scanner result.

**Security assessment:** The Debian operating system scan returned zero HIGH/CRITICAL findings, and the application dependencies listed above had no reported findings. However, the remaining setuptools attribution finding means the image should not be described as completely vulnerability-free.

The scan was completed locally. An equivalent image scan still needs to be integrated into the GitHub Actions PR workflow before claiming automated CI image scanning.

For additional investigation, Trivy can generate a JSON report:

```bash
trivy image \
  --scanners vuln \
  --format json \
  --output trivy-image-report.json \
  cloudrun-platform-assessment:v4
```

## 5. Terraform Infrastructure

The Terraform configuration is organized into a reusable module and separate environment configurations.

```text
infra/
├── modules/
│   └── cloud_run_service/
└── envs/
    ├── dev/
    └── prod/
```

Both environments use the same Cloud Run module. Environment-specific configuration is provided through variables.

The module supports configurable service name, project, region, environment, container image, CPU, memory, timeout, concurrency, scaling, ingress, runtime service account, and secret references.

The Google provider is pinned to version `6.15.0`. Terraform lock files should be retained in version control to preserve provider selections.

### Terraform validation

Run formatting validation from the repository root:

```bash
terraform fmt -check -recursive
```

Initialize and validate the module:

```bash
terraform -chdir=infra/modules/cloud_run_service init -backend=false

terraform -chdir=infra/modules/cloud_run_service validate

terraform -chdir=infra/modules/cloud_run_service test
```

Validate dev:

```bash
terraform -chdir=infra/envs/dev init -backend=false

terraform -chdir=infra/envs/dev validate
```

Validate prod:

```bash
terraform -chdir=infra/envs/prod init -backend=false

terraform -chdir=infra/envs/prod validate
```

The module tests cover:

- Expected Cloud Run service configuration and private ingress.
- Rejection of mutable image tags.

The module tests completed successfully with two passing assertions.

These commands validate Terraform configuration; they do not create or modify live GCP resources.

### Terraform remote state

For an actual deployment, configure a GCS bucket as the remote Terraform state backend.

Create the state bucket before initializing Terraform:

```bash
gcloud storage buckets create gs://YOUR_UNIQUE_TF_STATE_BUCKET \
  --location=us-central1 \
  --uniform-bucket-level-access

gcloud storage buckets update \
  gs://YOUR_UNIQUE_TF_STATE_BUCKET \
  --versioning
```

Use separate state prefixes for dev and prod:

- `cloudrun/dev`
- `cloudrun/prod`

Enable bucket versioning, use uniform bucket-level access, and restrict access through IAM. The GCS backend supports state locking.

Never commit Terraform state, plan files, credentials, real secret values, or sensitive `.tfvars` files.

### Example Terraform plan

After configuring the backend and environment variables:

```bash
cd infra/envs/dev

terraform init

terraform plan \
  -var-file=terraform.tfvars.example \
  -var="project_id=YOUR_DEV_PROJECT" \
  -var="image=us-central1-docker.pkg.dev/YOUR_DEV_PROJECT/apps/api@sha256:YOUR_64_CHAR_DIGEST"
```

Replace all placeholders with actual values before using the configuration.

The example variables file is a template. A live deployment requires a real GCP project, registry image digest, state backend, and appropriate permissions.

## 6. Security Decisions

Security considerations included in this implementation:

- A dedicated service account is used for the Cloud Run application.
- The runtime service account is separate from the GitHub deployment identity.
- Secret values are not stored in application code or workflow files.
- Terraform uses Secret Manager secret IDs and version references rather than secret payloads.
- Secret access should be granted only to the required runtime identity.
- Cloud Run defaults to authenticated invocation and internal-only ingress.
- Runtime and deployment identities should not receive project Owner or Editor permissions.
- Workload Identity Federation is preferred over service account key files.

For the external load balancer design, Cloud Run ingress and invoker IAM permissions must be configured carefully to prevent direct public access that bypasses the load balancer.

## 7. GitHub Actions and CI/CD

The repository contains two workflows:

- `.github/workflows/pr.yml` – PR validation.
- `.github/workflows/release.yml` – main-branch release workflow.

The intended CI/CD process is:

1. Run application tests and linting.
2. Validate Terraform formatting, configuration, and tests.
3. Build the Docker image.
4. Run security checks.
5. After merge, build and push the image using an immutable commit-based tag.
6. Capture the resulting image digest.
7. Promote the same image digest through dev and prod.
8. Generate Terraform plans and apply them through separate jobs.
9. Require production approval and serialize production deployments.

### GitHub configuration

The following repository or environment variables need to be configured:

- `GCP_WIF_PROVIDER`
- `GCP_DEPLOYER_SERVICE_ACCOUNT`
- `DEV_PROJECT_ID`
- `PROD_PROJECT_ID`
- `GCP_REGION`
- `AR_REPOSITORY`
- `TF_STATE_BUCKET`

Create GitHub Environments named `dev` and `prod`. Configure required reviewers for production and protect the main branch.

The Workload Identity Federation conditions should restrict access to the correct repository and protected branch.

The deployment identity should receive only the permissions required for Artifact Registry, Cloud Run, service account operations, IAM changes, and Terraform state access.

Before production use:

- Pin GitHub Actions to reviewed full commit SHAs.
- Protect the production apply job with an approval gate.
- Retain the reviewed Terraform plan and apply that exact plan without regenerating it.
- Configure production deployment concurrency.
- Integrate a Trivy image scan after the Docker image build in the PR workflow.

**Current limitation:** The workflows contain the intended WIF integration points, but the actual GCP identity provider, IAM bindings, GitHub environment configuration, and live deployment have not been provisioned or tested. The local Trivy scan is complete, but automated PR image scanning remains a follow-up task.

## 8. Rollback

A rollback helper script is available:

```bash
./scripts/rollback.sh PROJECT REGION SERVICE
```

The script lists available Cloud Run revisions and prompts for a known-good revision before shifting traffic.

After rollback, verify:

- Application health.
- HTTP error rate.
- Request latency.
- Cloud Run revision status.
- Traffic allocation.

Keep the failed revision and relevant logs for further investigation.

Rollback should be performed using an approved operational process, with appropriate permissions and a known-good revision.

## 9. Incident Response

The incident response runbook is available at:

`docs/incident-response.md`

It describes the initial investigation and response steps for application errors, elevated latency, unhealthy revisions, and deployment-related incidents.

The operational approach includes checking Cloud Run revision status, request logs, application health, error rates, resource utilization, and recent deployment changes before deciding whether to roll back.

## 10. High Availability Architecture

The high availability design is documented in:

`docs/ha-architecture.md`

The proposed architecture uses:

- Two Cloud Run services in separate regions.
- External Application Load Balancer.
- Serverless Network Endpoint Groups.
- Cloud Armor for application-level protection.
- Health monitoring and regional failover.
- Centralized logging and monitoring.

The design also considers recovery, failback, dependencies, RTO, RPO, IAM, secrets, and cost.

This is an architecture proposal only; it has not been deployed in GCP.

## 11. Local Validation Results

The following checks were completed in the local development environment:

| Validation | Result |
|---|---|
| Python application tests | 3 passed in the recorded test run |
| Ruff linting | Passed |
| Docker v4 image build | Passed |
| Docker application startup | Passed |
| `/health`, `/ready`, `/version` | HTTP 200 |
| Docker health check | Healthy |
| Non-root runtime user | Verified (`app`, UID 999) |
| Terraform formatting | Passed |
| Terraform module validation | Passed |
| Terraform module tests | 2 passed, 0 failed |
| Dev Terraform validation | Passed |
| Prod Terraform validation | Passed |
| Trivy v4 image scan | Completed; one HIGH attribution finding remains |
| Live GCP deployment | Not performed |

The recorded Python test run used Python 3.14.3 and completed with three passing tests. Dependency deprecation warnings were reported in that run. The tests should be rerun after any subsequent dependency changes.

Trivy v0.76.2 was used for the local Docker image scan. Its remaining setuptools finding and the investigation evidence are documented above.

## 12. Cleanup

For local Docker testing:

```bash
docker rm -f cloudrun-v4-test
```

If infrastructure is deployed, review the resources and costs before destroying anything.

Use a reviewed Terraform destroy plan and confirm resource ownership before removing state buckets, Artifact Registry repositories, or other shared resources.

## 13. Assessment Notes and Trade-offs

The implementation prioritizes a working local application, a reusable Terraform module, environment validation, container security checks, and a documented production architecture.

Live GCP deployment was not performed, avoiding unnecessary cloud costs and long-lived credentials during the assessment.

The two-region high availability solution is documented as a design rather than presented as a deployed implementation.

Final configuration, local validation, and implementation decisions were reviewed as part of the assessment.