#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/localstack-common.sh"

check_prereqs
set_local_creds_if_missing
check_free_services

upload_free_templates
create_or_update_stack_free "cloudformation/template.localstack.free.yaml"

echo "Free stack deployed: $STACK_NAME"
echo "Mock API health URL: $(get_output MockHealthUrl)"
