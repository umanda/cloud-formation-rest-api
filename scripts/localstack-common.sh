#!/bin/bash
set -euo pipefail

STACK_NAME="${STACK_NAME:-local-api-dev}"
PROJECT_NAME="${PROJECT_NAME:-crud-api}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
CONTAINER_PORT="${CONTAINER_PORT:-8000}"
TEMPLATE_BUCKET="${TEMPLATE_BUCKET:-cf-templates}"
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-stacks}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' not found"
    exit 1
  fi
}

check_prereqs() {
  require_cmd awslocal
  require_cmd docker
  require_cmd curl
}

set_local_creds_if_missing() {
  export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
  export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
}

stack_exists() {
  awslocal cloudformation describe-stacks --stack-name "$STACK_NAME" >/dev/null 2>&1
}

stack_status() {
  awslocal cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || true
}

ensure_stack_recreatable() {
  local status
  status="$(stack_status)"
  case "$status" in
    CREATE_FAILED|ROLLBACK_COMPLETE|ROLLBACK_FAILED|DELETE_FAILED|UPDATE_ROLLBACK_COMPLETE|UPDATE_ROLLBACK_FAILED|UPDATE_FAILED)
      echo "Stack '$STACK_NAME' is in terminal failed state ($status). Deleting and recreating."
      awslocal cloudformation delete-stack --stack-name "$STACK_NAME" >/dev/null || true
      local i
      for ((i=1; i<=60; i++)); do
        if ! stack_exists; then
          break
        fi
        sleep 2
      done
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

print_nested_failed_events() {
  local nested_ids
  nested_ids=$(awslocal cloudformation list-stack-resources --stack-name "$STACK_NAME" \
    --query "StackResourceSummaries[?ResourceType=='AWS::CloudFormation::Stack' && contains(ResourceStatus, 'FAILED')].PhysicalResourceId" \
    --output text 2>/dev/null || true)

  [ -z "$nested_ids" ] && return 0

  echo ""
  echo "Nested stack failures:"
  local nested_id
  for nested_id in $nested_ids; do
    echo "---- $nested_id ----"
    awslocal cloudformation describe-stack-events --stack-name "$nested_id" \
      --query "StackEvents[].[Timestamp,LogicalResourceId,ResourceType,ResourceStatus,ResourceStatusReason]" \
      --output table || true
  done
}

check_free_services() {
  set +e
  awslocal apigateway get-rest-apis >/dev/null 2>&1
  local apigw_rc=$?
  set -e

  if [ $apigw_rc -ne 0 ]; then
    echo "LocalStack API Gateway is not reachable/enabled."
    echo "Start LocalStack with at least:"
    echo "  -e SERVICES=cloudformation,ec2,apigateway,s3,iam,sts"
    exit 1
  fi
}

check_pro_services() {
  local failed=0

  set +e
  awslocal ecr describe-registry >/dev/null 2>&1 || failed=1
  awslocal ecs list-clusters >/dev/null 2>&1 || failed=1
  awslocal elbv2 describe-load-balancers >/dev/null 2>&1 || failed=1
  awslocal apigateway get-rest-apis >/dev/null 2>&1 || failed=1
  set -e

  if [ "$failed" -ne 0 ]; then
    echo "LocalStack Pro/Base services are not fully reachable."
    echo "Start LocalStack with auth token and services including:"
    echo "  cloudformation,ec2,ecr,ecs,elbv2,apigateway,s3,iam,logs,sts"
    exit 1
  fi
}

upload_template() {
  local file="$1"
  awslocal s3 cp "$REPO_ROOT/$file" "s3://$TEMPLATE_BUCKET/${file#cloudformation/}" >/dev/null
}

prepare_template_bucket() {
  awslocal s3 mb "s3://$TEMPLATE_BUCKET" >/dev/null 2>&1 || true
}

upload_free_templates() {
  prepare_template_bucket
  upload_template "cloudformation/stacks/network.yaml"
  upload_template "cloudformation/stacks/mock-api.yaml"
}

upload_pro_templates() {
  prepare_template_bucket
  upload_template "cloudformation/stacks/network.yaml"
  upload_template "cloudformation/stacks/ecr.yaml"
  upload_template "cloudformation/stacks/ecs.yaml"
  upload_template "cloudformation/stacks/apigateway.yaml"
}

wait_stack_terminal() {
  local max_attempts="${1:-90}"
  local sleep_seconds="${2:-2}"
  local i

  for ((i=1; i<=max_attempts; i++)); do
    local status
    status=$(awslocal cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || true)

    case "$status" in
      CREATE_COMPLETE|UPDATE_COMPLETE)
        echo "Stack status: $status"
        return 0
        ;;
      CREATE_FAILED|ROLLBACK_COMPLETE|ROLLBACK_FAILED|UPDATE_ROLLBACK_COMPLETE|UPDATE_ROLLBACK_FAILED|UPDATE_FAILED)
        echo "Stack failed with status: $status"
        awslocal cloudformation describe-stack-events --stack-name "$STACK_NAME" \
          --query "StackEvents[].[Timestamp,LogicalResourceId,ResourceType,ResourceStatus,ResourceStatusReason]" \
          --output table || true
        print_nested_failed_events
        return 1
        ;;
      *)
        sleep "$sleep_seconds"
        ;;
    esac
  done

  echo "Timeout waiting for stack terminal status"
  return 1
}

create_or_update_stack_free() {
  local template_file="$1"

  if stack_exists && ! ensure_stack_recreatable; then
    sleep 1
  fi

  if ! stack_exists; then
    awslocal cloudformation create-stack \
      --stack-name "$STACK_NAME" \
      --template-body "file://$REPO_ROOT/$template_file" \
      --parameters \
        ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
        ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
        ParameterKey=TemplateBucket,ParameterValue="$TEMPLATE_BUCKET" \
        ParameterKey=TemplatePrefix,ParameterValue="$TEMPLATE_PREFIX"
  else
    local out
    set +e
    out=$(awslocal cloudformation update-stack \
      --stack-name "$STACK_NAME" \
      --template-body "file://$REPO_ROOT/$template_file" \
      --parameters \
        ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
        ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
        ParameterKey=TemplateBucket,ParameterValue="$TEMPLATE_BUCKET" \
        ParameterKey=TemplatePrefix,ParameterValue="$TEMPLATE_PREFIX" 2>&1)
    local rc=$?
    set -e

    if [ $rc -ne 0 ]; then
      if echo "$out" | grep -q "No updates are to be performed"; then
        echo "No updates to apply"
        return 0
      fi
      echo "$out"
      return 1
    fi
  fi

  wait_stack_terminal
}

create_or_update_stack_pro() {
  local template_file="$1"
  shift
  local capabilities=("$@")

  if stack_exists && ! ensure_stack_recreatable; then
    sleep 1
  fi

  if ! stack_exists; then
    awslocal cloudformation create-stack \
      --stack-name "$STACK_NAME" \
      --template-body "file://$REPO_ROOT/$template_file" \
      --parameters \
        ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
        ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
        ParameterKey=ContainerPort,ParameterValue="$CONTAINER_PORT" \
        ParameterKey=TemplateBucket,ParameterValue="$TEMPLATE_BUCKET" \
        ParameterKey=TemplatePrefix,ParameterValue="$TEMPLATE_PREFIX" \
      ${capabilities:+--capabilities "${capabilities[@]}"}
  else
    local out
    set +e
    out=$(awslocal cloudformation update-stack \
      --stack-name "$STACK_NAME" \
      --template-body "file://$REPO_ROOT/$template_file" \
      --parameters \
        ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
        ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
        ParameterKey=ContainerPort,ParameterValue="$CONTAINER_PORT" \
        ParameterKey=TemplateBucket,ParameterValue="$TEMPLATE_BUCKET" \
        ParameterKey=TemplatePrefix,ParameterValue="$TEMPLATE_PREFIX" \
      ${capabilities:+--capabilities "${capabilities[@]}"} 2>&1)
    local rc=$?
    set -e

    if [ $rc -ne 0 ]; then
      if echo "$out" | grep -q "No updates are to be performed"; then
        echo "No updates to apply"
        return 0
      fi
      echo "$out"
      return 1
    fi
  fi

  wait_stack_terminal
}

get_output() {
  local key="$1"
  awslocal cloudformation describe-stacks --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='$key'].OutputValue" --output text
}

confirm_delete() {
  if [ "${FORCE:-false}" = "true" ]; then
    return 0
  fi

  echo "This will delete stack '$STACK_NAME'."
  read -r -p "Type 'yes' to continue: " ans
  [ "$ans" = "yes" ]
}
