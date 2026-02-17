#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/localstack-common.sh"

check_prereqs
set_local_creds_if_missing

if ! stack_exists; then
  echo "Stack '$STACK_NAME' not found. Run localstack-pro-deploy.sh first."
  exit 1
fi

API_URL="$(get_output ApiGatewayURL || true)"

if [ -z "$API_URL" ] || [ "$API_URL" = "None" ]; then
  echo "ApiGatewayURL output not available. Verify stack/resources first."
  exit 1
fi

echo "Testing Pro API"
echo "API URL: $API_URL"
echo ""

echo "GET /"
curl -sS "$API_URL"
echo ""

echo "GET /health"
curl -sS "$API_URL/health"
echo ""
