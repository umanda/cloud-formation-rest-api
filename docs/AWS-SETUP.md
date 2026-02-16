# AWS Account Setup Guide

Complete guide for AWS beginners.

## Step 1: Create AWS Account (10 min)

1. Go to https://aws.amazon.com/free/
2. Click "Create a Free Account"
3. Enter email and password
4. Add payment method (required but free tier covers testing)
5. Verify phone number
6. Select "Basic Support - Free"

**You now have:** AWS Account ID (12 digits)

## Step 2: Create IAM User (10 min)

**Why?** Never use root account for daily work.

1. Login to AWS Console: https://console.aws.amazon.com/
2. Search "IAM" → Click IAM
3. Users → Create user
4. Username: `admin-user`
5. Check "Provide user access to AWS Management Console"
6. Set password
7. Next → Attach policies directly
8. Search and select: `AdministratorAccess`
9. Create user

**Save these:**
- Console URL: `https://ACCOUNT_ID.signin.aws.amazon.com/console`
- Username: admin-user
- Password: (what you set)

## Step 3: Create Access Keys (5 min)

1. Login with IAM user
2. IAM → Users → admin-user
3. Security credentials tab
4. Create access key
5. Use case: "Command Line Interface (CLI)"
6. Create

**⚠️ SAVE THESE - You can't see them again!**
- Access Key ID: `AKIAIOSFODNN7EXAMPLE`
- Secret Access Key: `wJalrXUtnFEMI/K7MDENG/...`

## Step 4: Install AWS CLI

**Mac:**
```bash
brew install awscli
```

**Windows:**
Download: https://awscli.amazonaws.com/AWSCLIV2.msi

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Verify:**
```bash
aws --version
```

## Step 5: Configure AWS CLI

```bash
aws configure
```

Enter:
```
AWS Access Key ID: (paste your access key)
AWS Secret Access Key: (paste your secret key)
Default region name: us-east-1
Default output format: json
```

## Step 6: Verify Setup

```bash
aws sts get-caller-identity
```

Should show:
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",  ← Your account ID
    "Arn": "arn:aws:iam::123456789012:user/admin-user"
}
```

**✅ If you see this, you're ready!**

## Step 7: Set Billing Alert (5 min)

1. AWS Console → Billing
2. Billing preferences → Check "Receive Billing Alerts"
3. Save preferences
4. CloudWatch → Create Alarm
5. Metric: Billing → Total Estimated Charge
6. Threshold: $1 (or any amount)
7. Email notification
8. Confirm email

## Understanding Your Account

### Account ID
```bash
aws sts get-caller-identity --query Account --output text
```

### Current Region
```bash
aws configure get region
```

### List Resources
```bash
# S3 buckets
aws s3 ls

# ECS clusters
aws ecs list-clusters

# CloudFormation stacks
aws cloudformation list-stacks
```

## Security Best Practices

✅ DO:
- Use IAM user for daily work
- Enable MFA on root account
- Set billing alerts
- Keep access keys secret
- Delete resources when done

❌ DON'T:
- Use root account daily
- Share access keys
- Commit keys to Git
- Leave resources running unused

## Common Issues

**Issue: "Unable to locate credentials"**
```bash
aws configure
```

**Issue: "Access Denied"**
- Ensure IAM user has AdministratorAccess policy

**Issue: "Invalid security token"**
```bash
# Reconfigure
aws configure
```

**Issue: "Don't know my Account ID"**
```bash
aws sts get-caller-identity
```

## Quick Reference

```bash
# Check account
aws sts get-caller-identity

# Check region
aws configure get region

# Change region
aws configure set region us-east-1

# View current configuration
aws configure list
```

## Cost Management

### Free Tier Includes:
- ECS Fargate: 400,000 GB-hours/month
- ECR: 500 MB storage
- API Gateway: 1M requests/month
- S3: 5 GB storage

### Check Costs:
1. AWS Console → Billing Dashboard
2. View current month charges

### Set Alarm:
Already done in Step 7!

## Next Steps

✅ Account created
✅ IAM user configured
✅ AWS CLI installed
✅ Credentials configured
✅ Billing alert set

**You're ready to deploy!**

Go back to main README.md and run:
```bash
./scripts/deploy.sh
```
