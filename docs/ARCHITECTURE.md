# Architecture Deep Dive

## Design Decisions

### Why DynamoDB Global Tables over Aurora Global Database?

**DynamoDB Global Tables:**
- ✅ Sub-second replication (typically <1s)
- ✅ True multi-master (write to any region)
- ✅ Pay-per-request pricing (better for low traffic)
- ✅ Free tier eligible
- ✅ No server management

**Aurora Global:**
- ❌ $0.10/hour minimum (~$72/month)
- ❌ 1-second replication lag
- ❌ Primary-replica model (not multi-master)
- ❌ More complex to manage

**Verdict**: For a URL shortener with unpredictable traffic, DynamoDB's pay-per-request model and faster replication make it the clear winner.

### Why Active-Passive vs Active-Active?

**Active-Passive (Chosen):**
- ✅ Lower cost (health checks only, not continuous traffic splitting)
- ✅ Simpler to reason about
- ✅ Meets 99.9% availability SLA
- ✅ Good for portfolio demonstration

**Active-Active:**
- ❌ 2x CloudFront costs
- ❌ More complex routing logic
- ❌ Harder to debug
- ✅ Better for global latency optimization

**Verdict**: Active-passive provides sufficient availability for this use case at 1/3 the cost.

### Why Lambda over ECS/EKS?

- URL shortening is sporadic traffic (perfect for Lambda)
- Cold starts are acceptable for this use case (~200ms)
- No server management overhead
- Built-in auto-scaling
- Cost: $0 vs $30+/month for always-on containers

## Failure Scenarios

### Scenario 1: Primary Region Total Failure

**Detection**: 90 seconds (3 failed health checks × 30s interval)

**Steps**:
1. T+0s: us-east-1 goes down
2. T+30s: First health check fails
3. T+60s: Second health check fails
4. T+90s: Third health check fails, Route 53 marks unhealthy
5. T+90s: DNS queries start returning us-west-2 endpoint
6. T+120s: Most clients have switched over (TTL dependent)

**Data Loss**: Zero (DynamoDB Global Tables maintain copies in both regions)

### Scenario 2: DynamoDB Throttling

**Cause**: Traffic spike exceeds on-demand capacity

**Mitigation**:
- Lambda automatically retries with exponential backoff
- DynamoDB scales automatically but takes seconds
- Consider reserved capacity if traffic becomes predictable

### Scenario 3: Lambda Cold Start Spike

**Cause**: First requests after idle period

**Impact**: 200-500ms latency (one-time)

**Mitigation**:
- Keep memory at 128MB (fastest cold start)
- Consider provisioned concurrency if SLA requires <200ms p99
- Use Lambda SnapStart (for Java) if migrating from Node.js

## Security Considerations

**Current Implementation**:
- ✅ IAM roles with least privilege
- ✅ Encryption at rest (DynamoDB, CloudWatch Logs)
- ✅ Encryption in transit (HTTPS only)
- ✅ No hardcoded credentials
- ✅ VPC not required (public serverless services)

**Production Additions**:
- Add WAF for rate limiting and bot protection
- Implement API keys or Cognito authentication
- Add CloudTrail for audit logging
- Enable GuardDuty for threat detection
- Add Secrets Manager for any API keys

## Performance Characteristics

**Latency** (measured from client in us-east-1):
- Create URL: 50-100ms (DynamoDB write + Lambda overhead)
- Redirect: 30-50ms (DynamoDB read + Lambda overhead)
- Health Check: 20-30ms (DynamoDB scan + Lambda overhead)

**Throughput**:
- DynamoDB: Unlimited (on-demand mode)
- Lambda: 1,000 concurrent executions (soft limit, can increase)
- API Gateway: 10,000 RPS (soft limit, can increase)

**Bottleneck**: None at reasonable scale (<1M requests/day)

## Cost Breakdown by Component

Monthly costs for 100K requests/month:

| Component | Free Tier | Paid Usage | Cost |
|-----------|-----------|------------|------|
| Lambda (3 functions × 2 regions) | 1M requests | 0 | $0 |
| API Gateway | 1M requests (12mo) | 0 | $0 |
| DynamoDB Reads (100K) | 25 RCU | 0 | $0 |
| DynamoDB Writes (10K) | 25 WCU | 0 | $0 |
| Route 53 Hosted Zone | N/A | 1 zone | $0.50 |
| Route 53 Health Checks | N/A | 2 checks | $1.00 |
| Data Transfer (1GB) | 1GB free | 0 | $0 |
| CloudWatch Logs (1GB) | 5GB free | 0 | $0 |
| **Total** | | | **$1.50** |

At 1M requests/month:
- Lambda: ~$5 (beyond free tier)
- API Gateway: ~$3.50 (beyond free tier)
- DynamoDB: Still free (on-demand scales)
- Total: ~$10/month

## Alternatives Considered

### 1. Single Region + RDS Automated Backups
- **Cost**: ~$15/month (db.t3.micro + backups)
- **RTO**: 15-30 minutes (manual restore)
- **RPO**: Up to 5 minutes (backup frequency)
- **Verdict**: Cheaper but unacceptable RTO for production

### 2. CloudFront + S3 Static Site
- **Cost**: ~$1/month
- **Limitation**: Can't implement create URL logic (read-only)
- **Verdict**: Great for pure redirects, doesn't fit our use case

### 3. Containers on Fargate + Aurora Global
- **Cost**: ~$120/month (Fargate + Aurora)
- **Benefit**: More control, better for complex apps
- **Verdict**: Massive overkill for URL shortening

## Lessons Learned

1. **DynamoDB Global Tables are magic** - Setup is trivial, replication is fast
2. **Health checks cost more than you think** - $0.50/check/month adds up
3. **Route 53 TTL matters** - 60s TTL means 60s before all clients switch over
4. **Lambda cold starts are real** - But acceptable for this use case
5. **Free tier is generous** - Can run meaningful demos for months at $0

## Next Steps for Production

- [ ] Add custom domain with SSL certificate
- [ ] Implement rate limiting with WAF
- [ ] Add CloudWatch dashboards for key metrics
- [ ] Set up automated testing in CI/CD
- [ ] Add distributed tracing with X-Ray
- [ ] Implement blue/green deployments
- [ ] Add chaos engineering tests (randomly kill primary)