#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/localstack-common.sh"

check_prereqs
set_local_creds_if_missing

if ! stack_exists; then
  echo "Stack '$STACK_NAME' does not exist."
  exit 0
fi

if ! confirm_delete; then
  echo "Cancelled"
  exit 0
fi

awslocal cloudformation delete-stack --stack-name "$STACK_NAME"
echo "Delete requested for stack '$STACK_NAME'"
