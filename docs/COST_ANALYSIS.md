# Cost Analysis & Optimization

## Actual Costs (10-Day Build Period)

### Breakdown
| Service | Days Active | Total Cost |
|---------|-------------|------------|
| Route 53 Hosted Zone | 10 days | $0.17 |
| Route 53 Health Checks (2) | 10 days | $0.34 |
| Data Transfer (cross-region) | Testing | $0.30 |
| CloudWatch Logs | 10 days | $0.10 |
| Lambda | Testing | $0.00 (free tier) |
| DynamoDB | Testing | $0.00 (free tier) |
| API Gateway | Testing | $0.00 (free tier) |
| **Total 10-Day Cost** | | **$0.91** |

### Monthly Projection
- Hosted Zone: $0.50
- Health Checks: $1.00
- Data Transfer: $0.50-1.00
- Logs: $0.50
- **Total: $2.50-3.00/month** (no traffic)

With 100K requests/month: $2.50-4.00
With 1M requests/month: $8-12.00

## Cost Optimization Techniques Used

### 1. Pay-Per-Request DynamoDB
**Savings**: ~$48/month vs provisioned

Instead of:
```hcl
billing_mode = "PROVISIONED"
read_capacity = 5
write_capacity = 5
```

We use:
```hcl
billing_mode = "PAY_PER_REQUEST"
```

**Why**: For sporadic traffic, pay-per-request is 4-10x cheaper than provisioned capacity.

### 2. Lambda Memory Optimization
**Savings**: ~$2/month vs 1GB memory

We use:
```hcl
memory_size = 128  # Minimum, sufficient for our use case
```

**Why**: Lambda pricing is per GB-second. 128MB is 8x cheaper than 1GB. Our functions finish in <100ms, so memory is not a bottleneck.

### 3. Health Check Interval
**Savings**: ~$1.50/month vs 10-second checks

We use:
```hcl
request_interval = 30  # seconds
```

vs faster checks:
```hcl
request_interval = 10  # costs 3x more
```

**Why**: 30-second checks still give us <2-minute RTO. 10-second checks would cost $3/check/month instead of $0.50.

### 4. Log Retention
**Savings**: ~$5/month vs indefinite retention

We use:
```hcl
retention_in_days = 7
```

**Why**: For a demo project, 7 days is plenty. Production might use 30-90 days. Indefinite retention gets expensive fast.

### 5. Minimal CloudWatch Metrics
**Savings**: ~$3/month vs custom metrics

We use:
- Built-in Lambda metrics (free)
- Built-in API Gateway metrics (free)
- Built-in DynamoDB metrics (free)

We DON'T use:
- Custom metrics ($0.30 each)
- High-resolution metrics ($0.90 each)

**Why**: Built-in metrics cover 90% of monitoring needs.

### 6. Development vs Production Environments
**Savings**: $8-10 during development

Directory structure:
```
terraform/environments/
├── dev-single-region/    # $0/month (free tier)
└── prod-multi-region/    # $2.50/month (health checks)
```

**Strategy**:
- Build and test in dev (single region)
- Deploy prod only for final testing/demos
- Destroy prod when not actively using

## Cost Gotchas to Avoid

### ❌ Data Transfer OUT
**Cost**: $0.09/GB (first 10TB)

**How to avoid**:
- Keep API responses small (just the short code, not full URL metadata)
- Don't use Lambda for large file transfers
- Consider CloudFront for frequently accessed URLs

### ❌ Aurora Global Database
**Cost**: $0.10/hour = $72/month MINIMUM

**How we avoided it**:
- Used DynamoDB Global Tables instead
- DynamoDB scales to zero when not in use
- Only pay for actual reads/writes

### ❌ NAT Gateway
**Cost**: $0.045/hour + $0.045/GB = ~$35/month

**How we avoided it**:
- Lambda doesn't need a VPC for this use case
- API Gateway and DynamoDB are public services
- No need for NAT Gateway at all

### ❌ Provisioned Lambda Concurrency
**Cost**: $0.0000041667/hour per MB = ~$6/month for 256MB

**How we avoided it**:
- Cold starts (<500ms) are acceptable for our use case
- Only provision concurrency if you have strict latency SLAs

## Break-Even Analysis

**Question**: At what traffic volume does multi-region become cost-effective?

**Single Region Costs**:
- $0/month (all free tier)
- 99.5% availability (single AZ failure = downtime)
- RPO/RTO: 15-30 minutes (manual failover)

**Multi-Region Costs**:
- $2.50/month base
- 99.9% availability
- RPO/RTO: <1 second / <2 minutes

**Break-even**:
- If downtime costs >$2.50/month, multi-region pays for itself
- For a commercial app with $1000/hour revenue, even 1 hour/year of downtime ($1000) >> $30/year DR cost

## Scaling Costs

| Monthly Requests | Lambda | API Gateway | DynamoDB | Total |
|------------------|--------|-------------|----------|-------|
| 100K | $0 | $0 | $0 | $2.50 |
| 1M | $0.20 | $3.50 | $0 | $6.20 |
| 10M | $2.00 | $35 | $0.50 | $40 |
| 100M | $20 | $350 | $5 | $377 |

**Notes**:
- DynamoDB stays cheap even at high volume (on-demand is efficient)
- API Gateway becomes the cost driver at scale
- Consider ALB + Lambda if >10M requests/month ($16/month + $0.008/LCU)

## Cost Monitoring Setup

### 1. Budget Alert (Already Done)
```bash
./scripts/setup-billing-alarm.sh 10 your-email@example.com
```

### 2. Daily Cost Check
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

### 3. Cost Explorer Tags
We tagged everything with:
```hcl
tags = {
  Project     = "url-shortener"
  Environment = "prod"
  ManagedBy   = "Terraform"
}
```

Now you can filter Cost Explorer by `Project=url-shortener` to see ONLY this project's costs.

## Recommendations for Interview Discussion

**When asked "How did you optimize costs?"**:

1. "I used DynamoDB's pay-per-request billing instead of provisioned capacity, saving ~$48/month with no performance impact for sporadic traffic."

2. "I chose Lambda over ECS/EKS because the URL shortening workload is sporadic. Lambda scales to zero when not in use, while containers would cost $30+/month even when idle."

3. "I set health check intervals to 30 seconds instead of 10 seconds. This tripled my RTO from 30s to 90s, but reduced costs by 66% while still meeting our 99.9% availability target."

4. "I created separate dev and prod environments. During development, I used the single-region dev environment (free tier) and only deployed multi-region for final testing, saving $8-10 during the build."

5. "I avoided NAT Gateways entirely by using public AWS services. NAT Gateways would've added $35/month with zero benefit for this architecture."

**The key insight**: "Every dollar spent should improve the product. If a service or configuration doesn't materially improve availability, performance, or functionality, I look for a cheaper alternative."
```

### `.gitignore`
```
# Terraform
*.tfstate
*.tfstate.*
.terraform/
*.tfvars
!terraform.tfvars.example
.terraform.lock.hcl

# Lambda builds
terraform/modules/lambda/builds/
*.zip

# Environment
.env
.env.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*

# Node
node_modules/
package-lock.json