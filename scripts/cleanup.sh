#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

STACK_NAME="crud-api-fargate-stack"
REGION="us-east-1"

echo -e "${RED}⚠️  WARNING: This deletes EVERYTHING!${NC}"
read -p "Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled"
    exit 0
fi

echo "Deleting stack..."
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
echo "Waiting for deletion (10-15 minutes)..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

echo -e "${GREEN}✅ All resources deleted!${NC}"
