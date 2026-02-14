# Multi-Region URL Shortener with Automated Failover

A production-grade URL shortening service deployed across two AWS regions with automatic failover, demonstrating advanced cloud architecture patterns for high availability and disaster recovery.

## 🏗️ Architecture

This project implements:
- **Multi-region active-passive deployment** across us-east-1 (primary) and us-west-2 (secondary)
- **DynamoDB Global Tables** for sub-second cross-region replication
- **Route 53 health checks** with automatic DNS failover
- **Serverless compute** using AWS Lambda for cost efficiency
- **Infrastructure as Code** with Terraform modules

### Key Metrics
- **RTO (Recovery Time Objective)**: ~2 minutes
- **RPO (Recovery Point Objective)**: <1 second (DynamoDB Global Tables)
- **Monthly Cost**: ~$8-12 (depending on usage)
- **Availability SLA**: 99.9% (calculated across both regions)

## 📊 Architecture Diagram
```
                                    ┌─────────────────┐
                                    │   Route 53      │
                                    │  Health Checks  │
                                    │   & Failover    │
                                    └────────┬────────┘
                                             │
                        ┌────────────────────┴────────────────────┐
                        │                                          │
                  ┌─────▼──────┐                          ┌───────▼─────┐
                  │  us-east-1 │                          │  us-west-2  │
                  │  (Primary) │                          │ (Secondary) │
                  └─────┬──────┘                          └───────┬─────┘
                        │                                          │
              ┌─────────┴─────────┐                      ┌────────┴────────┐
              │                   │                      │                 │
      ┌───────▼────────┐  ┌──────▼──────┐      ┌────────▼──────┐ ┌───────▼────────┐
      │  API Gateway   │  │  DynamoDB   │      │ API Gateway   │ │   DynamoDB     │
      │                │  │             │◄────►│               │ │                │
      └───────┬────────┘  └─────────────┘      └───────┬───────┘ └────────────────┘
              │           Global Table Replication      │
      ┌───────┴────────┐                        ┌───────┴────────┐
      │                │                        │                │
      │  Lambda Funcs  │                        │  Lambda Funcs  │
      │  - Create URL  │                        │  - Create URL  │
      │  - Redirect    │                        │  - Redirect    │
      │  - Health      │                        │  - Health      │
      └────────────────┘                        └────────────────┘
```

## 🚀 Deployment

### Prerequisites
- AWS CLI configured with credentials
- Terraform >= 1.0
- Node.js 18+ (for local testing)
- jq (for test scripts)

### Cost Setup (DO THIS FIRST!)
```bash
# Set up billing alarm
./scripts/setup-billing-alarm.sh 10 your-email@example.com
```

### Deploy Single Region (Development)
```bash
cd terraform/environments/dev-single-region
terraform init
terraform plan
terraform apply

# Test it
API_URL=$(terraform output -raw api_endpoint)
curl -X POST $API_URL/create -H "Content-Type: application/json" -d '{"longUrl":"https://github.com"}'
```

**Cost: $0** (within free tier)

### Deploy Multi-Region (Production)
```bash
cd terraform/environments/prod-multi-region

# Edit terraform.tfvars if you have a domain
echo 'domain_name = ""' > terraform.tfvars  # Leave empty to skip Route 53

terraform init
terraform plan
terraform apply

# Get endpoints
terraform output
```

**Cost: ~$1-2 for 24 hours** (health checks + cross-region data transfer)

## 🧪 Testing Failover
```bash
# Get your endpoints
cd terraform/environments/prod-multi-region
PRIMARY=$(terraform output -raw primary_api_endpoint)
SECONDARY=$(terraform output -raw secondary_api_endpoint)

# Run comprehensive test
../../scripts/test-failover.sh $PRIMARY $SECONDARY

# Manual failover test
# Terminal 1: Monitor primary
watch -n 5 "curl -s $PRIMARY/health | jq ."

# Terminal 2: Monitor secondary  
watch -n 5 "curl -s $SECONDARY/health | jq ."

# Terminal 3: Create URLs and watch replication
curl -X POST $PRIMARY/create -H "Content-Type: application/json" -d '{"longUrl":"https://example.com"}'
# Note the short code, then try accessing it via secondary endpoint
```

## 💰 Cost Optimization Strategies

This project demonstrates several cost optimization techniques:

1. **Pay-per-request DynamoDB** - No provisioned capacity
2. **Lambda instead of EC2** - Pay only for actual compute time
3. **Minimal health check frequency** - 30-second intervals (not 10s)
4. **7-day log retention** - Balance debugging vs storage costs
5. **Modular Terraform** - Deploy only what you need

### Estimated Monthly Costs
| Service | Cost | Notes |
|---------|------|-------|
| Lambda | $0 | Within 1M free tier |
| API Gateway | $0 | Within 1M free tier (first 12mo) |
| DynamoDB | $0 | Within 25GB/25RCU/25WCU free tier |
| Route 53 Hosted Zone | $0.50 | Per zone |
| Route 53 Health Checks | $1.00 | $0.50 × 2 checks |
| Data Transfer | $0.50-2 | Cross-region replication |
| CloudWatch Logs | $0.50 | 7-day retention |
| **Total** | **~$2.50-4/mo** | Plus $3-5 one-time domain |

## 📈 Monitoring

Key metrics to watch:
- Route 53 health check status
- Lambda invocation errors
- DynamoDB throttling events
- Cross-region replication lag
- API Gateway 4xx/5xx errors

Access CloudWatch dashboards:
```bash
# Primary region
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1

# Secondary region
https://console.aws.amazon.com/cloudwatch/home?region=us-west-2
```

## 🎯 What This Demonstrates

**For Interviews:**
- Understanding of RPO/RTO and their business impact
- Experience with DynamoDB Global Tables and eventual consistency
- Knowledge of Route 53 failover routing policies
- Serverless architecture patterns
- Infrastructure as Code best practices
- Cost optimization thinking

**Key Talking Points:**
- "In a regional outage, our RTO is under 2 minutes with zero data loss"
- "We chose DynamoDB Global Tables over Aurora for sub-second replication and cost"
- "Health checks run every 30 seconds with 3-failure threshold for ~90-second detection"
- "The entire multi-region setup costs under $10/month, making DR accessible"

## 🔧 Teardown
```bash
# Destroy multi-region (save $$$)
cd terraform/environments/prod-multi-region
terraform destroy

# Destroy dev
cd terraform/environments/dev-single-region
terraform destroy
```

## 📚 Further Improvements

- Add CloudFront for edge caching and custom domain
- Implement AWS X-Ray for distributed tracing
- Add Cognito for authentication
- Set up CI/CD with GitHub Actions
- Add custom metrics and dashboards
- Implement canary deployments

## 📝 License

MIT License - feel free to use this in your portfolio!

---

**Built by**: Yaw Opoku Asare  
**Purpose**: Portfolio project demonstrating multi-region AWS architecture  
**Interview Ready**: Yes ✓