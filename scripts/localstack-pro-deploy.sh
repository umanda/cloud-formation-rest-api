#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/localstack-common.sh"

check_prereqs
set_local_creds_if_missing
check_pro_services

upload_pro_templates
create_or_update_stack_pro "cloudformation/template.localstack.yaml" CAPABILITY_IAM CAPABILITY_NAMED_IAM

if [ "${PUSH_MOCK_IMAGE:-true}" = "true" ]; then
  REPO_URI="$(get_output ECRRepositoryUri || true)"
  if [ -n "$REPO_URI" ] && [ "$REPO_URI" != "None" ]; then
    echo "Pushing mock image to ECR: $REPO_URI"
    awslocal ecr get-login-password | docker login --username AWS --password-stdin "000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566"
    docker pull ealen/echo-server:latest
    docker tag ealen/echo-server:latest "$REPO_URI:latest"
    docker push "$REPO_URI:latest"

    CLUSTER="$(get_output ECSCluster || true)"
    SERVICE="$(get_output ECSService || true)"
    if [ -n "$CLUSTER" ] && [ -n "$SERVICE" ] && [ "$CLUSTER" != "None" ] && [ "$SERVICE" != "None" ]; then
      awslocal ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment >/dev/null || true
    fi
  else
    echo "ECR output not available; skipping image push"
  fi
fi

echo "Pro stack deployed: $STACK_NAME"
echo "API URL: $(get_output ApiGatewayURL || echo 'N/A')"
