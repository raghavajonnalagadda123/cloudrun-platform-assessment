#!/usr/bin/env bash
set -euo pipefail
PROJECT="${1:?Usage: rollback.sh PROJECT REGION SERVICE}"
REGION="${2:?Usage: rollback.sh PROJECT REGION SERVICE}"
SERVICE="${3:?Usage: rollback.sh PROJECT REGION SERVICE}"
echo "Recent revisions:"
gcloud run revisions list --project "$PROJECT" --region "$REGION" --service "$SERVICE" --format="table(metadata.name,status.conditions[0].status,metadata.creationTimestamp)"
read -r -p "Previously healthy revision name: " REVISION
[[ -n "$REVISION" ]] || { echo "No revision supplied; aborting." >&2; exit 2; }
gcloud run services update-traffic "$SERVICE" --project "$PROJECT" --region "$REGION" --to-revisions "${REVISION}=100"
echo "Traffic update requested. Verify health, error rate, latency, and traffic allocation."
