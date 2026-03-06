# AWS API Gateway + ECS Fargate CRUD API

Complete automated deployment of FastAPI CRUD application on AWS using ECS Fargate.

## 🚀 Quick Start (3 Steps)

### Step 1: Prerequisites
1. AWS Account (free tier eligible)
2. AWS CLI installed and configured
3. Docker installed and running

### Step 2: Deploy
```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

### Step 3: Test
```bash
./scripts/test-api.sh
```

That's it! ✅

## 📋 What You Need Before Starting

### 1. AWS Account Setup
If new to AWS, read: `docs/AWS-SETUP.md`

**Quick check:**
```bash
aws sts get-caller-identity
```
Should show your account ID.

### 2. Install Docker
- Mac/Windows: Docker Desktop from docker.com
- Linux: `sudo apt-get install docker.io`

**Verify:**
```bash
docker ps
```

### 3. Install AWS CLI
```bash
# Mac
brew install awscli

# Windows
# Download from aws.amazon.com/cli

# Linux
sudo apt-get install awscli
```

**Configure:**
```bash
aws configure
```

## 📁 Project Files

```
final-project/
├── README.md                    ← You are here
├── docs/
│   ├── AWS-SETUP.md            ← Complete AWS beginner guide
│   ├── ARCHITECTURE.md         ← How everything works
│   ├── LOCALSTACK-RUNBOOK.md   ← LocalStack Free vs Pro commands
│   └── AWS-SDK-RUNBOOK.md      ← Python boto3 alternative to CF
├── cloudformation/
│   ├── template.yaml           ← Root CloudFormation stack
│   └── stacks/                 ← Service-specific nested stacks
│       ├── network.yaml        ← VPC, subnets, routing
│       ├── ecr.yaml            ← ECR repository
│       ├── ecs.yaml            ← ECS, IAM, NLB, service
│       └── apigateway.yaml     ← API Gateway + VPC Link
├── fastapi/
│   ├── app.py                  ← Your API code
│   └── requirements.txt        ← Python dependencies  
├── docker/
│   └── Dockerfile              ← Container definition
├── sdk_python/
│   ├── deploy.py               ← Deploy with boto3
│   ├── cleanup.py              ← Cleanup with boto3
│   ├── test_api.py             ← Basic API tests
│   └── requirements.txt
└── scripts/
    ├── deploy.sh               ← AWS deploy (legacy path, still works)
    ├── test-api.sh             ← AWS test (legacy path, still works)
    ├── cleanup.sh              ← AWS cleanup (legacy path, still works)
    ├── aws/                    ← Organized AWS prod scripts
    │   ├── prod-deploy.sh
    │   ├── prod-test.sh
    │   ├── prod-remove.sh
    │   ├── sdk-deploy.sh
    │   ├── sdk-test.sh
    │   └── sdk-remove.sh
    └── localstack/
        ├── free/
        │   ├── deploy.sh
        │   ├── test.sh
        │   └── remove.sh
        └── pro/
            ├── deploy.sh
            ├── test.sh
            └── remove.sh
```

## 🏗️ What Gets Created

**Automatically created by deploy.sh:**
- ✅ VPC with networking (10.0.0.0/16)
- ✅ ECR repository for Docker images
- ✅ ECS Fargate cluster
- ✅ Network Load Balancer
- ✅ API Gateway
- ✅ S3 bucket for Swagger UI
- ✅ All IAM roles and security groups

**You don't configure VPC manually - it's all automated!**

## 💰 Cost

**Free Tier (first 12 months):**
- Everything covered by free tier for testing

**After free tier:**
- ~$30/month if running 24/7
- **$0 when stopped** - run `./scripts/cleanup.sh`

## 🎯 Common Commands

```bash
# Deploy everything (first time or updates)
./scripts/deploy.sh
# Or organized AWS prod path
./scripts/aws/prod-deploy.sh

# Test the API
./scripts/test-api.sh
# Or organized AWS prod path
./scripts/aws/prod-test.sh

# View container logs
aws logs tail /ecs/crud-api-fargate --follow

# Check what's running
aws ecs list-tasks --cluster crud-api-cluster

# Scale to 2 containers
aws ecs update-service \
  --cluster crud-api-cluster \
  --service crud-api-service \
  --desired-count 2

# Delete everything (stop costs)
./scripts/cleanup.sh
# Or organized AWS prod path
./scripts/aws/prod-remove.sh

# Python SDK alternative (no CloudFormation)
./scripts/aws/sdk-deploy.sh
./scripts/aws/sdk-test.sh
./scripts/aws/sdk-remove.sh
```

## 🧪 Testing Your API

After deployment, you'll get URLs like:

**API Gateway:**
```bash
https://abc123.execute-api.us-east-1.amazonaws.com/dev
```

**Swagger UI:**
```bash
http://bucket-name.s3-website-us-east-1.amazonaws.com
```

**Test commands:**
```bash
API_URL="your-api-gateway-url"

# Health check
curl $API_URL/health

# Create item
curl -X POST $API_URL/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","price":1299.99,"quantity":5}'

# Get all items
curl $API_URL/items

# Get specific item
curl $API_URL/items/1

# Update item
curl -X PUT $API_URL/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Gaming Laptop","price":1499.99,"quantity":3}'

# Delete item
curl -X DELETE $API_URL/items/1
```

## 📖 Documentation

- **AWS-SETUP.md** - Complete AWS setup for beginners
- **ARCHITECTURE.md** - Understanding VPC, Fargate, networking
- **LOCALSTACK-RUNBOOK.md** - LocalStack Free/Pro deployment + mock API testing
- **AWS-SDK-RUNBOOK.md** - Deploy same stack using Python SDK (boto3)
- **README.md** (this file) - Quick reference

## 🔧 Modify Your API

1. Edit `fastapi/app.py`
2. Run `./scripts/deploy.sh`
3. Script automatically rebuilds and deploys

## ❓ FAQs

**Q: Do I need to configure VPC manually?**
A: No! CloudFormation creates everything automatically.

**Q: How do I know which AWS account I'm using?**
A: Run `aws sts get-caller-identity` - shows your account ID.

**Q: Why Fargate instead of Lambda?**
A: Fargate gives you:
- Longer execution time (no 15-min limit)
- Full Docker control
- More memory (up to 30GB)
- Better for APIs with complex dependencies

**Q: Will this cost money?**
A: Free tier covers testing. After that, ~$30/month if running 24/7. Delete when not using: `./scripts/cleanup.sh`

**Q: Can I use this in production?**
A: Yes! This is production-grade architecture. Add:
- Database (RDS/DynamoDB)
- Authentication (Auth0/Cognito)
- HTTPS certificate
- Auto-scaling policies

## 🆘 Troubleshooting

**Issue: "Docker not running"**
```bash
# Mac/Windows: Open Docker Desktop
# Linux: sudo systemctl start docker
```

**Issue: "AWS credentials not configured"**
```bash
aws configure
```

**Issue: "Container won't start"**
```bash
# Check logs
aws logs tail /ecs/crud-api-fargate --follow

# Common: dependencies issue in requirements.txt
```

**Issue: "Can't access API"**
```bash
# Wait 2-3 minutes after deployment
# Check container is running
aws ecs list-tasks --cluster crud-api-cluster
```

## 🎓 What You're Learning

- AWS ECS Fargate (serverless containers)
- ECR (Docker registry)
- VPC networking (automated)
- Network Load Balancers
- API Gateway
- CloudFormation (Infrastructure as Code)
- Docker containerization
- FastAPI development

## 📊 Deployment Time

- First time: 15-20 minutes
- Updates: 5-10 minutes
- Cleanup: 10-15 minutes

## ✅ Success Checklist

- [ ] AWS account created
- [ ] AWS CLI configured (`aws sts get-caller-identity` works)
- [ ] Docker installed and running
- [ ] Ran `./scripts/deploy.sh` successfully
- [ ] Got API Gateway URL
- [ ] Tested with `curl` or Swagger UI
- [ ] Can view logs
- [ ] Know how to clean up

## 🎉 You Did It!

You deployed production-grade serverless container infrastructure!

**Next Steps:**
1. Customize `fastapi/app.py`
2. Add a database
3. Implement authentication
4. Set up monitoring
5. Deploy to production

---

**Need Help?**
- Read `docs/AWS-SETUP.md` for account setup
- Read `docs/ARCHITECTURE.md` for technical details
- Check AWS documentation
- Search Stack Overflow with tag [amazon-ecs]
