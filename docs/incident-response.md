# Incident runbook: latency and intermittent errors after deployment

## Scenario
Pipeline reports success, but the new Cloud Run revision has elevated latency and intermittent errors immediately after deployment. Treat as customer-impacting until telemetry proves otherwise.

## First 10–15 minutes
### 0–3 minutes: stabilize
1. Acknowledge alert, open incident channel, appoint incident commander.
2. Freeze further releases and Terraform applies. Do not delete revisions or logs.
3. Record UTC start, service, region, revision, image digest, commit SHA, deployer, traffic split.
4. Compare request volume, p50/p95/p99 latency, 4xx/5xx, timeouts, CPU, memory, concurrency, instance count to baseline.
5. Establish blast radius: routes, tenants, clients, region, all instances or subset.

### 3–7 minutes: inspect evidence
- Cloud Run request logs: status, latency, route, revision, trace ID; redact tokens/PII.
- Application logs: exceptions, stack traces, startup/readiness, dependency timeouts.
- Cloud Monitoring: request count, CPU/memory, instance count, startup latency, concurrency, pending requests where available.
- Compare new and prior revision over the same time window.
- Diff image digest, env vars, secret versions, CPU/memory, timeout, concurrency, min/max scaling, ingress, service account, IAM.
- Check Audit Logs for IAM, Secret Manager, Cloud Run, and network changes.

### 7–15 minutes: separate hypotheses

| Area | Evidence / check | Owner |
|---|---|---|
| Application | New exceptions, hot path, endpoint-specific latency, trace comparison | Application owner |
| Configuration | Env/config diff, timeout, CPU/memory, concurrency, scaling, startup command | Platform + app |
| Identity/secrets | 401/403, secret access denied, changed runtime SA, missing version | IAM/security |
| Networking | DNS, egress/NAT/firewall, TLS handshake, resets | Network/platform |
| Scaling | Cold starts, max instances reached, CPU saturation, concurrency queueing | SRE/platform |
| Dependency | Downstream latency, quota, connection pool, regional status | Dependency owner |

## Rollback / traffic-shift decision
Rollback promptly when 5xx/timeouts breach the SLO, p95/p99 latency breaches agreed thresholds across multiple windows, a security/auth/data-integrity regression appears, or the issue correlates with the new revision and a known-good revision exists. Do not delay rollback for root cause when customer impact is severe and rollback is safe.

```bash
gcloud run services update-traffic SERVICE --project PROJECT --region REGION --to-revisions PREVIOUS_HEALTHY_REVISION=100
```
Use gradual traffic shifting only when impact is contained and telemetry is reliable. If schema/data changes make rollback unsafe, involve the data owner and mitigate forward with a reviewed fix.

After rollback, verify traffic allocation, `/health`, `/ready`, synthetic user journeys, error rate, latency, and downstream recovery. Keep the failed revision for forensics.

## Owners and communications
- Incident commander: severity, timeline, decisions, stakeholder updates.
- Application owner: code diff, exceptions, dependency behavior, safe fix.
- Platform/SRE: revisions, scaling, telemetry, rollback, deployment controls.
- IAM/security: WIF, service account, secret access, audit events.
- Network: DNS, egress, load balancer, firewall, TLS.
- Dependency owner: health, quotas, connection saturation, regional status.

## Evidence preservation
Retain workflow run URL, commit SHA, image digest, Terraform plan/apply logs, approval actor/time, revision metadata, log query links, trace IDs, before/after graphs, traffic split, and operator timeline. Restrict access and redact secrets/personal data.

## Prevention
Add progressive delivery (5% → 25% → 50% → 100%) with observation windows and automatic abort/traffic restoration if 5xx, p95 latency, or critical synthetic checks breach agreed thresholds. Store metrics and decision evidence with the release.
