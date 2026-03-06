#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_NAME="${PROJECT_NAME:-crud-api}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
STATE_FILE="${STATE_FILE:-$REPO_ROOT/sdk_python/.state/${PROJECT_NAME}-${ENVIRONMENT}.json}"

python3 "$REPO_ROOT/sdk_python/test_api.py" --state-file "$STATE_FILE" --timeout "${TIMEOUT:-15}"
