# LocalStack Runbook (Free vs Pro)

This runbook captures the LocalStack-related changes and the exact commands to run this repository with CloudFormation.

Known working path:
- Run commands from repository root: `/mnt/harddisk/aws/cloud-formation-rest-api`
- Use script entrypoints:
  - Free: `./scripts/localstack/free/deploy.sh`, `./scripts/localstack/free/test.sh`
  - Pro: `./scripts/localstack/pro/deploy.sh`, `./scripts/localstack/pro/test.sh`

## 1. Template Matrix

- Live AWS template (unchanged):
  - `cloudformation/template.yaml`
- LocalStack Pro/Base template (full stack):
  - `cloudformation/template.localstack.yaml`
- LocalStack Free template (network + mock API):
  - `cloudformation/template.localstack.free.yaml`

Nested stacks:
- `cloudformation/stacks/network.yaml`
- `cloudformation/stacks/ecr.yaml`
- `cloudformation/stacks/ecs.yaml`
- `cloudformation/stacks/apigateway.yaml`
- `cloudformation/stacks/mock-api.yaml` (new, Free mock runtime)

## 2. Why ECR Failed in Free

If you see this error:
- `InternalFailure ... service ecr is either not included in your current license plan or has not yet been emulated`

It means your LocalStack plan/runtime cannot provide ECR in your current mode.
For Free workflow in this repo, do not deploy ECR/ECS/ELBv2 stacks.

Reference docs:
- https://docs.localstack.cloud/aws/services/ecr/
- https://docs.localstack.cloud/aws/services/ecs/
- https://docs.localstack.cloud/aws/licensing/

## 3. Runtime Controls & Config

### 3.1 Free runtime start (no auth token required)

```bash
docker rm -f localstack >/dev/null 2>&1 || true
docker run -d --name localstack -p 4566:4566 \
  -e SERVICES=cloudformation,ec2,apigateway,s3,iam,sts \
  localstack/localstack:latest
```

### 3.2 Pro/Base runtime start (auth token + ECS container execution)

```bash
docker rm -f localstack >/dev/null 2>&1 || true
docker run -d --name localstack -p 4566:4566 \
  -e LOCALSTACK_AUTH_TOKEN=${LOCALSTACK_AUTH_TOKEN} \
  -e SERVICES=cloudformation,ec2,ecr,ecs,elbv2,apigateway,s3,iam,logs,sts \
  -e MAIN_DOCKER_NETWORK=bridge \
  -v /var/run/docker.sock:/var/run/docker.sock \
  localstack/localstack:latest
```

### 3.3 Set dummy credentials

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

### 3.4 Upload nested templates to LocalStack S3

```bash
cd /mnt/harddisk/aws/cloud-formation-rest-api

awslocal s3 mb s3://cf-templates || true
awslocal s3 cp cloudformation/stacks/network.yaml s3://cf-templates/stacks/network.yaml
awslocal s3 cp cloudformation/stacks/mock-api.yaml s3://cf-templates/stacks/mock-api.yaml
awslocal s3 cp cloudformation/stacks/ecr.yaml s3://cf-templates/stacks/ecr.yaml
awslocal s3 cp cloudformation/stacks/ecs.yaml s3://cf-templates/stacks/ecs.yaml
awslocal s3 cp cloudformation/stacks/apigateway.yaml s3://cf-templates/stacks/apigateway.yaml
```

## 4. LocalStack Free (Recommended for your current setup)

### 4.1 Deploy Free stack

```bash
awslocal cloudformation delete-stack --stack-name local-api-dev || true

awslocal cloudformation create-stack \
  --stack-name local-api-dev \
  --template-body file://cloudformation/template.localstack.free.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=crud-api \
    ParameterKey=Environment,ParameterValue=dev \
    ParameterKey=TemplateBucket,ParameterValue=cf-templates \
    ParameterKey=TemplatePrefix,ParameterValue=stacks
```

### 4.2 Verify

```bash
awslocal cloudformation describe-stacks --stack-name local-api-dev
awslocal cloudformation list-stack-resources --stack-name local-api-dev
```

### 4.3 Mock runtime test (Free)

Get health URL from outputs:

```bash
awslocal cloudformation describe-stacks --stack-name local-api-dev \
  --query "Stacks[0].Outputs[?OutputKey=='MockHealthUrl'].OutputValue" --output text
```

Test API:

```bash
curl "$(awslocal cloudformation describe-stacks --stack-name local-api-dev \
  --query \"Stacks[0].Outputs[?OutputKey=='MockHealthUrl'].OutputValue\" --output text)"
```

Expected JSON includes:
- `{"status":"ok","mode":"localstack-free-mock"}`

## 5. LocalStack Pro/Base (Full stack)

Use this only if your LocalStack plan/runtime supports ECR + ECS + ELBv2 + API Gateway.

### 5.1 Deploy full stack

```bash
awslocal cloudformation delete-stack --stack-name local-api-dev || true

awslocal cloudformation create-stack \
  --stack-name local-api-dev \
  --template-body file://cloudformation/template.localstack.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=crud-api \
    ParameterKey=Environment,ParameterValue=dev \
    ParameterKey=ContainerPort,ParameterValue=8000 \
    ParameterKey=TemplateBucket,ParameterValue=cf-templates \
    ParameterKey=TemplatePrefix,ParameterValue=stacks \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

### 5.2 Verify

```bash
awslocal cloudformation describe-stacks --stack-name local-api-dev
awslocal cloudformation list-stack-resources --stack-name local-api-dev
```

### 5.3 Mock runtime test (Pro/Base)

Push a simple mock API image to the stack-created ECR repo:

```bash
REPO_NAME=$(awslocal cloudformation describe-stacks --stack-name local-api-dev \
  --query "Stacks[0].Outputs[?OutputKey=='ECRRepositoryUri'].OutputValue" --output text)

awslocal ecr get-login-password | docker login --username AWS --password-stdin 000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566

docker pull ealen/echo-server:latest
docker tag ealen/echo-server:latest "${REPO_NAME}:latest"
docker push "${REPO_NAME}:latest"
```

Then fetch API URL from outputs and test:

```bash
API_URL=$(awslocal cloudformation describe-stacks --stack-name local-api-dev \
  --query "Stacks[0].Outputs[?OutputKey=='ApiGatewayURL'].OutputValue" --output text)

curl "$API_URL"
```

## 6. Control/Config Summary

- Keep live AWS behavior on `cloudformation/template.yaml`.
- Use LocalStack-specific templates only for local emulation:
  - Free: `cloudformation/template.localstack.free.yaml`
  - Pro/Base: `cloudformation/template.localstack.yaml`
- Use S3-style `TemplateURL` for nested stacks in LocalStack.
- For `awslocal` + AWS CLI v2, prefer `create-stack` / `update-stack` over `cloudformation deploy`.
- Free plan behavior for this architecture:
  - `ECR`, `ECS`, and `ELBv2` are unavailable in Free tier.
  - Use `template.localstack.free.yaml` + `stacks/mock-api.yaml` to test API contract locally.
- Pro/Base behavior for this architecture:
  - Full stack can be exercised with `template.localstack.yaml` when `LOCALSTACK_AUTH_TOKEN` is set and Docker socket is mounted.

## 7. Cleanup

```bash
awslocal cloudformation delete-stack --stack-name local-api-dev
docker rm -f localstack
```

## 8. Script Shortcuts

Use these helper scripts from repository root:

### 8.1 Free

```bash
./scripts/localstack/free/deploy.sh
./scripts/localstack/free/test.sh
./scripts/localstack/free/remove.sh
```

### 8.2 Pro/Base

```bash
./scripts/localstack/pro/deploy.sh
./scripts/localstack/pro/test.sh
./scripts/localstack/pro/remove.sh
```

### 8.3 Optional environment overrides

```bash
STACK_NAME=local-api-dev PROJECT_NAME=crud-api ENVIRONMENT=dev ./scripts/localstack/free/deploy.sh
```

For Pro image push control:

```bash
PUSH_MOCK_IMAGE=false ./scripts/localstack/pro/deploy.sh
```

Legacy script paths still work:
- `./scripts/localstack-free-deploy.sh`
- `./scripts/localstack-free-test.sh`
- `./scripts/localstack-free-remove.sh`
- `./scripts/localstack-pro-deploy.sh`
- `./scripts/localstack-pro-test.sh`
- `./scripts/localstack-pro-remove.sh`

## 9. Troubleshooting

If Free deploy fails with `MockApiStack CREATE_FAILED` and reason is `None`:

1. Ensure LocalStack started with API Gateway service:
```bash
docker rm -f localstack >/dev/null 2>&1 || true
docker run -d --name localstack -p 4566:4566 \
  -e SERVICES=cloudformation,ec2,apigateway,s3,iam,sts \
  localstack/localstack:latest
```

2. Re-run deploy:
```bash
./scripts/localstack/free/deploy.sh
```

3. The deploy script now prints nested stack failure events automatically when parent stack fails.
