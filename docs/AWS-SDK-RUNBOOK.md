# AWS SDK (Python) Runbook

This runbook provides a Python AWS SDK (boto3) alternative to CloudFormation for the same stack.

## Scope

Translated resources from CloudFormation to boto3 calls:
- VPC, internet gateway, public subnets, route table, route associations
- ECR repository
- ECS cluster, IAM task roles, CloudWatch log group
- NLB, target group, listener, ECS service, task definition
- API Gateway REST API + VPC Link + proxy methods + stage

Main scripts:
- `sdk_python/deploy.py`
- `sdk_python/cleanup.py`
- `sdk_python/test_api.py`

Wrapper commands:
- `scripts/aws/sdk-deploy.sh`
- `scripts/aws/sdk-test.sh`
- `scripts/aws/sdk-remove.sh`

## Install

```bash
cd /mnt/harddisk/aws/cloud-formation-rest-api
python3 -m venv .venv
source .venv/bin/activate
pip install -r sdk_python/requirements.txt
```

## Deploy (AWS)

```bash
export AWS_REGION=us-east-1
# optional: export AWS_PROFILE=default

./scripts/aws/sdk-deploy.sh
```

## Test

```bash
./scripts/aws/sdk-test.sh
```

## Remove

```bash
./scripts/aws/sdk-remove.sh
```

## Optional controls

```bash
PROJECT_NAME=crud-api ENVIRONMENT=dev CONTAINER_PORT=8000 ./scripts/aws/sdk-deploy.sh
```

Custom state file:

```bash
STATE_FILE=/tmp/my-stack-state.json ./scripts/aws/sdk-deploy.sh
```

## LocalStack use (optional)

You can target LocalStack by setting endpoint URL:

```bash
export ENDPOINT_URL=http://localhost:4566
./scripts/aws/sdk-deploy.sh
```

Note: full stack behavior still depends on LocalStack service-tier support (ECR/ECS/ELBv2/APIGW).

## Notes

- This SDK path is separate and does not modify `cloudformation/template.yaml`.
- State is stored in `sdk_python/.state/<project>-<environment>.json` and used for cleanup.
