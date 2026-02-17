#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/localstack-common.sh"

check_prereqs
set_local_creds_if_missing

if ! stack_exists; then
  echo "Stack '$STACK_NAME' not found. Run localstack-free-deploy.sh first."
  exit 1
fi

HEALTH_URL="$(get_output MockHealthUrl)"
BASE_URL="$(get_output MockApiBaseUrl)"

if [ -z "$HEALTH_URL" ] || [ "$HEALTH_URL" = "None" ] || [ -z "$BASE_URL" ] || [ "$BASE_URL" = "None" ]; then
  echo "Mock API outputs are not available."
  echo "Check stack status and nested stack events:"
  echo "  awslocal cloudformation describe-stacks --stack-name $STACK_NAME"
  echo "  awslocal cloudformation describe-stack-events --stack-name $STACK_NAME"
  exit 1
fi

echo "Testing Free mock API"
echo "Base URL: $BASE_URL"
echo "Health URL: $HEALTH_URL"
echo ""

echo "GET /health"
curl -sS "$HEALTH_URL"
echo ""
echo "GET /"
curl -sS "$BASE_URL"
echo ""
