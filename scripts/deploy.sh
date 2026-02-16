#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STACK_NAME="crud-api-fargate-stack"
PROJECT_NAME="crud-api"
REGION="us-east-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_TEMPLATE="$REPO_ROOT/cloudformation/template.yaml"
DOCKER_DIR="$REPO_ROOT/docker"
FASTAPI_DIR="$REPO_ROOT/fastapi"
CAPABILITIES=(CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Fargate API Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if ! command -v aws &> /dev/null; then
    echo "AWS CLI not installed!"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "Docker not installed!"
    exit 1
fi

if ! docker ps &> /dev/null; then
    echo "Docker daemon not running!"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS credentials not configured. Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ARTIFACT_BUCKET="${PROJECT_NAME}-cfn-artifacts-${ACCOUNT_ID}-${REGION}"
PACKAGED_TEMPLATE=$(mktemp "/tmp/${STACK_NAME}-packaged-XXXXXX.yaml")
trap 'rm -f "$PACKAGED_TEMPLATE"' EXIT

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo -e "${GREEN}  Account: $ACCOUNT_ID${NC}"
echo ""

ensure_artifact_bucket() {
    if aws s3api head-bucket --bucket "$ARTIFACT_BUCKET" 2>/dev/null; then
        return
    fi

    echo -e "${YELLOW}Creating CloudFormation artifact bucket: $ARTIFACT_BUCKET${NC}"
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$ARTIFACT_BUCKET" --region "$REGION" > /dev/null
    else
        aws s3api create-bucket \
            --bucket "$ARTIFACT_BUCKET" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" > /dev/null
    fi
}

package_templates() {
    ensure_artifact_bucket
    aws cloudformation package \
        --template-file "$ROOT_TEMPLATE" \
        --s3-bucket "$ARTIFACT_BUCKET" \
        --output-template-file "$PACKAGED_TEMPLATE" \
        --region "$REGION" > /dev/null
}

print_stack_failure_events() {
    echo ""
    echo -e "${YELLOW}Recent CloudFormation failure events:${NC}"
    aws cloudformation describe-stack-events \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query "StackEvents[?contains(['CREATE_FAILED','UPDATE_FAILED','DELETE_FAILED'], ResourceStatus)].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]" \
        --output table || true
    echo ""
}

create_stack() {
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$PACKAGED_TEMPLATE" \
        --capabilities "${CAPABILITIES[@]}" \
        --region "$REGION" > /dev/null

    echo -e "${YELLOW}Waiting for stack creation (10-15 minutes)...${NC}"
    if ! aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"; then
        echo -e "${YELLOW}Stack creation failed.${NC}"
        print_stack_failure_events
        exit 1
    fi

    echo -e "${GREEN}✓ Stack created${NC}"
}

echo -e "${YELLOW}Step 1: Packaging and deploying CloudFormation stacks...${NC}"
package_templates

if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" > /dev/null 2>&1; then
    create_stack
else
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text)

    if [ "$STACK_STATUS" = "ROLLBACK_COMPLETE" ] || [ "$STACK_STATUS" = "ROLLBACK_FAILED" ]; then
        echo -e "${YELLOW}Stack is in $STACK_STATUS. Deleting and recreating...${NC}"
        aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
        aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
        create_stack
    else
        echo -e "${YELLOW}Stack exists, updating if needed...${NC}"
        set +e
        UPDATE_OUTPUT=$(aws cloudformation update-stack \
            --stack-name "$STACK_NAME" \
            --template-body "file://$PACKAGED_TEMPLATE" \
            --capabilities "${CAPABILITIES[@]}" \
            --region "$REGION" 2>&1)
        UPDATE_RC=$?
        set -e

        if [ $UPDATE_RC -ne 0 ]; then
            if echo "$UPDATE_OUTPUT" | grep -q "No updates are to be performed"; then
                echo "No updates needed"
            else
                echo "$UPDATE_OUTPUT"
                print_stack_failure_events
                exit 1
            fi
        else
            echo -e "${YELLOW}Waiting for stack update (10-15 minutes)...${NC}"
            if ! aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION"; then
                echo -e "${YELLOW}Stack update failed.${NC}"
                print_stack_failure_events
                exit 1
            fi
            echo -e "${GREEN}✓ Stack updated${NC}"
        fi
    fi
fi
echo ""

ECR_REPO=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryUri`].OutputValue' --output text)
ECS_CLUSTER=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSCluster`].OutputValue' --output text)
ECS_SERVICE=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSService`].OutputValue' --output text)
API_URL=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayURL`].OutputValue' --output text)
LB_URL=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' --output text)

echo -e "${YELLOW}Step 2: Building Docker Image...${NC}"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REPO"
cd "$DOCKER_DIR"
cp "$FASTAPI_DIR/app.py" "$FASTAPI_DIR/requirements.txt" .
docker build -t "$PROJECT_NAME:latest" .
docker tag "$PROJECT_NAME:latest" "$ECR_REPO:latest"
docker push "$ECR_REPO:latest"
rm app.py requirements.txt
cd "$REPO_ROOT"
echo -e "${GREEN}✓ Image pushed to ECR${NC}"
echo ""

echo -e "${YELLOW}Step 3: Updating ECS Service...${NC}"
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" \
    --force-new-deployment --region "$REGION" > /dev/null
echo -e "${YELLOW}Waiting for service to stabilize (3-5 minutes)...${NC}"
aws ecs wait services-stable --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --region "$REGION"
echo -e "${GREEN}✓ ECS service updated${NC}"
echo ""

echo -e "${YELLOW}Step 4: Testing...${NC}"
sleep 30
curl -s "$API_URL/health" | grep -q "healthy" && echo -e "${GREEN}✓ Health check passed!${NC}" || echo -e "${YELLOW}Note: May take a few more minutes${NC}"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Deployment Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Account ID:${NC} $ACCOUNT_ID"
echo -e "${GREEN}API Gateway:${NC} $API_URL"
echo -e "${GREEN}Load Balancer:${NC} $LB_URL"
echo -e "${GREEN}ECR Repo:${NC} $ECR_REPO"
echo ""
echo -e "${GREEN}Test commands:${NC}"
echo -e "${BLUE}curl $API_URL/health${NC}"
echo -e "${BLUE}curl -X POST $API_URL/items -H 'Content-Type: application/json' -d '{\"name\":\"Laptop\",\"price\":1299.99,\"quantity\":5}'${NC}"
echo ""
