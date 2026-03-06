#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_NAME="${PROJECT_NAME:-crud-api}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
STATE_FILE="${STATE_FILE:-$REPO_ROOT/sdk_python/.state/${PROJECT_NAME}-${ENVIRONMENT}.json}"

python3 "$REPO_ROOT/sdk_python/cleanup.py" \
  --project-name "$PROJECT_NAME" \
  --environment "$ENVIRONMENT" \
  --region "${AWS_REGION:-us-east-1}" \
  ${AWS_PROFILE:+--profile "$AWS_PROFILE"} \
  ${ENDPOINT_URL:+--endpoint-url "$ENDPOINT_URL"} \
  --state-file "$STATE_FILE"

echo "SDK cleanup complete."
