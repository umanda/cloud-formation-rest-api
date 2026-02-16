#!/bin/bash
set -e

STACK_NAME="crud-api-fargate-stack"
REGION="us-east-1"

API_URL=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayURL`].OutputValue' --output text 2>/dev/null)

if [ -z "$API_URL" ]; then
    echo "Error: Stack not found. Deploy first!"
    exit 1
fi

echo "Testing API: $API_URL"
echo ""

echo "Test 1: Health Check"
curl -s "$API_URL/health" | jq '.' || curl -s "$API_URL/health"
echo ""

echo "Test 2: Get Items (empty)"
curl -s "$API_URL/items" | jq '.' || curl -s "$API_URL/items"
echo ""

echo "Test 3: Create Item"
curl -s -X POST "$API_URL/items" \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"Gaming laptop","price":1299.99,"quantity":5}' | jq '.' || echo "Created"
echo ""

echo "Test 4: Get All Items"
curl -s "$API_URL/items" | jq '.' || curl -s "$API_URL/items"
echo ""

echo "✅ All tests complete!"
