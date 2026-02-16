# Architecture & VPC Explained

## Simple Architecture Diagram

```
Internet
   ↓
API Gateway (https://xxx.execute-api.us-east-1.amazonaws.com)
   ↓
VPC Link (secure connection)
   ↓
Application Load Balancer
   ↓
ECS Fargate Container
   └─ FastAPI App (port 8000)
```

## VPC (Virtual Private Cloud)

### What is VPC?
Your private network in AWS. Think of it as your own apartment in a large building.

### Do You Need to Configure It?
**NO!** The CloudFormation template creates everything automatically.

### What Gets Created:

**VPC:**
- CIDR: 10.0.0.0/16 (65,536 IP addresses)

**Subnets:**
- Public Subnet A: 10.0.1.0/24 (in us-east-1a)
- Public Subnet B: 10.0.2.0/24 (in us-east-1b)

**Internet Gateway:**
- Allows containers to access internet
- Allows internet to access containers

**Security Group:**
- Allows inbound: Port 8000 (your API)
- Allows outbound: All traffic

**Route Tables:**
- Routes internet traffic correctly

## Components Explained

### 1. API Gateway
- Public HTTPS endpoint
- Routes requests to Load Balancer
- Can add authentication later
- Handles CORS

### 2. VPC Link
- Secure connection from API Gateway to VPC
- Private connection (not over internet)

### 3. Application Load Balancer
- Distributes traffic to containers
- Health checks (restarts if unhealthy)
- Can handle thousands of requests

### 4. ECS Fargate
- Serverless containers
- No EC2 instances to manage
- Auto-restarts if crashes
- Runs your Docker container

### 5. ECR (Elastic Container Registry)
- Your private Docker Hub
- Stores your container images
- Secure and integrated with ECS

## Request Flow

```
1. User makes request → https://api-gateway-url/items
2. API Gateway receives request
3. VPC Link forwards to Load Balancer (inside VPC)
4. Load Balancer forwards to Fargate container
5. FastAPI app processes request
6. Response flows back same way
```

## Networking Details

### IP Addresses
- VPC: 10.0.0.0/16 (private)
- Subnet A: 10.0.1.0/24 (public)
- Subnet B: 10.0.2.0/24 (public)
- Fargate containers get IPs from these subnets

### Ports
- Container: 8000 (FastAPI)
- Load Balancer: 80 (HTTP)
- API Gateway: 443 (HTTPS)

### Security
- Security Group acts as firewall
- Only allows port 8000 from Load Balancer
- Container can access internet (for downloads)

## Why Two Subnets?

**High Availability!**
- Subnet A in Availability Zone A
- Subnet B in Availability Zone B
- If one datacenter fails, other keeps running

## Fargate vs Lambda

| Feature | Lambda | Fargate |
|---------|--------|---------|
| Execution time | Max 15 min | Unlimited |
| Memory | Max 10 GB | Up to 30 GB |
| Cold start | Yes | No (always running) |
| Container | Limited | Full Docker |
| Cost (idle) | $0 | ~$10/month |

**Use Fargate when:**
- Can't use Lambda (dependencies)
- Need longer execution
- Want full container control

## Scaling

### Manual Scaling
```bash
aws ecs update-service \
  --cluster crud-api-cluster \
  --service crud-api-service \
  --desired-count 3
```

### Auto Scaling (can add)
- Scale based on CPU
- Scale based on requests
- Scale on schedule

## Monitoring

### CloudWatch Logs
```bash
aws logs tail /ecs/crud-api-fargate --follow
```

### Container Insights
- Automatically enabled
- CPU, memory, network metrics
- View in CloudWatch console

### Health Checks
- Load Balancer checks /health every 30s
- Restarts unhealthy containers

## Cost Breakdown

### Components:
- Fargate: ~$10/month (0.25 vCPU, 0.5 GB)
- Load Balancer: ~$18/month
- NAT Gateway: $0 (we don't use it)
- Data transfer: ~$2/month
- **Total: ~$30/month** (if running 24/7)

### Free Tier (12 months):
- Fargate: 400,000 GB-hours/month
- Our setup: 0.5 GB × 720 hours = 360 GB-hours
- **Covered by free tier!**

## Security

### What's Secure:
✅ VPC isolates your resources
✅ Security groups act as firewall
✅ HTTPS on API Gateway
✅ Private Docker registry
✅ IAM roles (least privilege)

### What to Add for Production:
- Authentication (Auth0/Cognito)
- WAF (Web Application Firewall)
- Secrets Manager (for passwords)
- CloudTrail (audit logging)
- Private subnets (extra security)

## Troubleshooting

### Container Won't Start
```bash
# Check logs
aws logs tail /ecs/crud-api-fargate --follow

# Check task status
aws ecs describe-tasks \
  --cluster crud-api-cluster \
  --tasks TASK_ARN
```

### Can't Access API
```bash
# Check container is running
aws ecs list-tasks --cluster crud-api-cluster

# Check security group
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*crud-api*"
```

### Health Check Failing
```bash
# Direct load balancer test
curl http://LOAD_BALANCER_DNS/health

# If this fails, container issue
# If this works, VPC Link issue
```

## Advanced Topics

### Add Database
```yaml
# In CloudFormation, add:
RDSInstance:
  Type: AWS::RDS::DBInstance
  Properties:
    Engine: postgres
    DBInstanceClass: db.t3.micro
```

### Add HTTPS
```yaml
# Add certificate
Certificate:
  Type: AWS::CertificateManager::Certificate
  
# Update ALB listener
Listener:
  Protocol: HTTPS
  Port: 443
```

### Multiple Environments
```bash
# Deploy dev
./scripts/deploy.sh dev

# Deploy prod
./scripts/deploy.sh prod
```

## Key Takeaways

1. **VPC is auto-configured** - you don't touch it
2. **Fargate is serverless** - no EC2 to manage
3. **Everything scales** - can handle any load
4. **Production-ready** - same as major companies use
5. **Delete when not using** - avoid costs

## Questions?

**Q: Must I understand VPC?**
A: No! It's automated. Read this for knowledge only.

**Q: Why Application Load Balancer?**
A: Distributes traffic, health checks, scales better.

**Q: Can I use private subnets?**
A: Yes, but need NAT Gateway (~$32/month extra).

**Q: How do I see what's running?**
A: AWS Console → ECS → Clusters → crud-api-cluster

**Q: Is this production-ready?**
A: Yes! Add database, auth, HTTPS for full production.

---

**You don't need to understand everything here to use the project!**

The main README has all you need. This is reference material.
