# Final Mastery Report: AWS vs LocalStack Deployment Comparison

**Author:** Meihao Cheng  
**Date:** November 30, 2025  
**Repository:** https://github.com/MeihaoC/aws-vs-localstack-deployment-comparison.git 

---

## Executive Summary

This report compares the deployment of an asynchronous order processing system on AWS and LocalStack. The system uses SNS (Simple Notification Service) and SQS (Simple Queue Service) to process orders asynchronously. We tested both environments under identical load conditions and found that while LocalStack offers lower latency for development, AWS provides production-grade reliability with similar processing performance.

**Key Finding:** LocalStack is 2x faster in response time (21ms vs 42ms) but AWS and LocalStack have nearly identical processing throughput and queue drain times, making LocalStack ideal for development/testing and AWS ideal for production.

---

## 1. Architecture Overview

### System Architecture

The order processing system consists of three main components:

1. **Order API**: HTTP server that accepts orders and publishes them to SNS
2. **SNS Topic**: Receives order events and forwards them to SQS
3. **Order Processor**: Worker service that polls SQS and processes orders (simulates 3-second payment processing)

### AWS Architecture

```
Internet
   ↓
Application Load Balancer (ALB)
   ↓
ECS Fargate Cluster
   ├── Order API (container)
   └── Order Processor (container, 100 workers)
   ↓
SNS Topic → SQS Queue
   ↓
CloudWatch Logs
```

**Components:**
- VPC with public/private subnets
- Application Load Balancer
- ECS Fargate (container orchestration)
- ECR (Docker image registry)
- SNS Topic + SQS Queue
- CloudWatch Logs

### LocalStack Architecture

```
Local Machine
   ↓
Docker Containers
   ├── Order API (container)
   └── Order Processor (container, 100 workers)
   ↓
LocalStack (SNS/SQS emulation)
   ├── SNS Topic
   └── SQS Queue
```

**Components:**
- Docker Compose (container management)
- LocalStack (SNS/SQS emulation)
- Local logs

**Note:** LocalStack doesn't support ECS/ALB, but the core SNS/SQS message processing comparison is valid and meaningful.

---

## 2. Test Methodology

### Test Configuration

**Load Testing Tool:** Locust  
**Test Scenarios:**
1. **Baseline Load**: 20 concurrent users, 2 spawn rate, 60 seconds
2. **High Load**: 50 concurrent users, 5 spawn rate, 60 seconds

**Worker Configuration:** 100 workers in both environments

### Metrics Collected

1. **Response Time**: Average, min, max, percentiles (50th, 95th, 99th)
2. **Throughput**: Requests per second (RPS)
3. **Queue Metrics**: Peak queue depth, drain time
4. **Error Rate**: Failed requests

---

## 3. Test Results

### Baseline Load Test (20 users, 60 seconds)

| Metric | LocalStack | AWS | Difference |
|--------|-----------|-----|------------|
| **Average Response Time** | 21.42 ms | 41.97 ms | LocalStack 2x faster |
| **Throughput (RPS)** | 114.42 | 107.68 | LocalStack 6% higher |
| **Peak Queue Depth** | 1,401 messages | 1,193 messages | LocalStack 17% higher |
| **Drain Time** | 49 seconds | 51 seconds | Similar (4% difference) |
| **Total Requests** | 6,834 | 6,438 | LocalStack 6% more |
| **Failures** | 0 | 0 | Both 100% success |

**Response Time Percentiles:**

| Percentile | LocalStack | AWS |
|------------|-----------|-----|
| 50th (Median) | 7 ms | 39 ms |
| 95th | 110 ms | 58 ms |
| 99th | 300 ms | 90 ms |
| Max | 700 ms | 264 ms |

### High Load Test (50 users, 60 seconds)

| Metric | LocalStack | AWS | Difference |
|--------|-----------|-----|------------|
| **Average Response Time** | 38.91 ms | 46.86 ms | LocalStack 20% faster |
| **Throughput (RPS)** | 270.6 | 265.62 | LocalStack 2% higher |
| **Peak Queue Depth** | 5,917 messages | 5,826 messages | Similar (2% difference) |
| **Drain Time** | 180 seconds | 189 seconds | Similar (5% difference) |
| **Total Requests** | 16,172 | 15,882 | LocalStack 2% more |
| **Failures** | 0 | 0 | Both 100% success |

**Response Time Percentiles:**

| Percentile | LocalStack | AWS |
|------------|-----------|-----|
| 50th (Median) | 9 ms | 40 ms |
| 95th | 300 ms | 70 ms |
| 99th | 530 ms | 230 ms |
| Max | 710 ms | 521 ms |

---

## 4. Key Findings

### 4.1 Response Time Analysis

**LocalStack Advantage:**
- **2x faster average response time** (21ms vs 42ms baseline, 39ms vs 47ms high load)
- Lower latency due to local network (no internet round-trip)
- Better for rapid development iteration

**AWS Characteristics:**
- Higher latency due to network overhead (ALB → ECS → SNS)
- More consistent response times (lower variance)
- Production-grade infrastructure adds ~20ms overhead

**Conclusion:** LocalStack is better for development where speed matters. AWS latency is acceptable for production.

### 4.2 Throughput Analysis

**Finding:** Both environments have **nearly identical throughput**
- Baseline: 114 RPS vs 108 RPS (6% difference)
- High Load: 271 RPS vs 266 RPS (2% difference)

**Insight:** The bottleneck is the 3-second payment processing, not the messaging infrastructure. Both SNS/SQS implementations perform similarly.

### 4.3 Queue Processing Performance

**Peak Queue Depth:**
- Both environments build similar queue depths under load
- LocalStack: 1,401 (baseline), 5,917 (high load)
- AWS: 1,193 (baseline), 5,826 (high load)

**Drain Time:**
- **Nearly identical** drain times (49s vs 51s, 180s vs 189s)
- Processing rate is determined by worker count, not infrastructure
- Both handle queue buildup and draining similarly

**Conclusion:** Queue processing performance is **equivalent** between LocalStack and AWS. The limiting factor is application logic (3-second payment processing), not the messaging service.

### 4.4 Scalability

Both environments scale proportionally:
- **2.4x increase in load** (20 → 50 users) results in:
  - **2.4x increase in throughput** (114 → 271 RPS LocalStack, 108 → 266 RPS AWS)
  - **4.2x increase in queue depth** (1,401 → 5,917 LocalStack)
  - **3.7x increase in drain time** (49s → 180s LocalStack)

**Conclusion:** Both environments scale linearly and predictably.

---

## 5. When to Use Each Environment

### Use LocalStack When:

✅ **Development & Testing**
- Rapid iteration and debugging
- No AWS costs during development
- Testing SNS/SQS patterns locally
- CI/CD pipeline testing

✅ **Learning & Experimentation**
- Understanding AWS services without cost
- Testing different configurations quickly
- Learning message queue patterns

✅ **Cost-Sensitive Development**
- Zero infrastructure costs
- Unlimited testing without billing concerns

**Limitations:**
- Not production-grade (no ALB, ECS, VPC)
- Limited to services it supports (SNS, SQS, S3, etc.)
- Local resource constraints

### Use AWS When:

✅ **Production Deployment**
- Need production-grade reliability
- Require ALB, ECS, VPC, CloudWatch
- Need auto-scaling and monitoring
- Compliance and security requirements

✅ **Real-World Performance Testing**
- Testing actual network latency
- Validating production-like conditions
- Load testing at scale

✅ **Full Infrastructure Stack**
- Need complete AWS services
- Multi-region deployment
- Enterprise-grade features

**Trade-offs:**
- Higher latency (~20ms overhead)
- Infrastructure costs (~$30-50/month for this setup)
- More complex deployment

---

## 6. Meaningful Metrics by Environment

### Metrics That Matter for Both:

1. **Queue Drain Time** ✅
   - Shows processing capacity
   - Identical in both environments
   - Key metric for system performance

2. **Throughput (RPS)** ✅
   - Shows system capacity
   - Nearly identical in both
   - Determined by worker count, not infrastructure

3. **Peak Queue Depth** ✅
   - Shows how queue builds under load
   - Similar in both environments
   - Helps determine worker scaling needs

### Metrics That Differ:

1. **Response Time** ⚠️
   - **LocalStack**: Lower (21-39ms) - local network advantage
   - **AWS**: Higher (42-47ms) - network overhead
   - **Meaningful for**: Development speed vs production realism

2. **Infrastructure Overhead** ⚠️
   - **LocalStack**: Minimal (direct container access)
   - **AWS**: ~20ms (ALB + network)
   - **Meaningful for**: Understanding production latency

3. **Cost** ⚠️
   - **LocalStack**: $0 (free for development)
   - **AWS**: ~$30-50/month (infrastructure costs)
   - **Meaningful for**: Budget planning

---

## 7. Recommendations

### For Development Phase:
**Use LocalStack**
- Faster iteration (2x faster response times)
- Zero cost
- Sufficient for testing SNS/SQS patterns
- Quick debugging and testing

### For Production Phase:
**Use AWS**
- Production-grade infrastructure
- Real-world performance testing
- Full monitoring and logging (CloudWatch)
- Auto-scaling capabilities
- Enterprise reliability

### Hybrid Approach (Recommended):
1. **Develop & Test**: Use LocalStack for rapid development
2. **Pre-Production**: Test on AWS to validate production conditions
3. **Production**: Deploy on AWS with full infrastructure

---

## 8. Conclusion

This comparison demonstrates that:

1. **LocalStack is excellent for development** - 2x faster response times, zero cost, sufficient for testing core functionality
2. **AWS is necessary for production** - Production-grade infrastructure, monitoring, and reliability
3. **Core processing performance is equivalent** - Queue drain times and throughput are nearly identical, showing that the bottleneck is application logic, not infrastructure
4. **Both environments scale similarly** - Linear scaling behavior in both cases

**Key Insight:** The choice between LocalStack and AWS should be based on **use case** (development vs production), not performance differences. Both environments handle the core SNS/SQS message processing equally well.
