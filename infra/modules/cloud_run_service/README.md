# cloud_run_service module

Creates a dedicated Cloud Run runtime service account, a Cloud Run v2 service with configurable compute/timeout/concurrency/scaling/ingress/image digest, secret accessor IAM bindings for explicitly supplied Secret Manager references, and an optional allUsers invoker binding. It does not create secrets, accept secret payloads, or create a load balancer. Caller owns project APIs, registry access, remote state, and deployer IAM.
