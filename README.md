# Final Mastery: AWS vs LocalStack Deployment Comparison

This project compares the deployment of an asynchronous order processing system on AWS and LocalStack, analyzing performance differences and use cases for each environment.

## Project Structure

```
final_mastery/
├── FINAL_MASTERY_REPORT.md    # Main report
├── order-system/               # Application code
│   ├── cmd/
│   │   ├── order-api/         # Order API service
│   │   └── order-processor/   # Order processor service
│   ├── pkg/models/            # Shared data models
│   ├── deploy-localstack.sh   # LocalStack deployment script
│   ├── deploy-aws.sh          # AWS deployment script
│   └── docker-compose.yml    # Docker Compose for LocalStack
├── terraform/                  # Infrastructure as Code
│   ├── main.tf               # SNS, SQS, ECR
│   ├── vpc.tf                # VPC and networking
│   ├── ecs.tf                # ECS cluster and services
│   ├── alb.tf                # Application Load Balancer
│   ├── security_groups.tf    # Security groups
│   └── iam.tf                # IAM roles
└── locust/                    # Load testing
    ├── locustfile.py         # Load test script
    └── results/              # Test results
```

## Quick Start

### LocalStack Deployment

1. Start LocalStack:
```bash
docker run -d -p 4566:4566 -e SERVICES=sns,sqs --name localstack localstack/localstack
```

2. Setup infrastructure:
```bash
cd order-system
./deploy-localstack.sh
```

3. Run services:
```bash
# Terminal 1: Order API
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-west-2
export SNS_TOPIC_ARN=arn:aws:sns:us-west-2:000000000000:order-processing-events
./order-api

# Terminal 2: Order Processor
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-west-2
export SQS_QUEUE_URL=http://sqs.us-west-2.localhost.localstack.cloud:4566/000000000000/order-processing-queue
export NUM_WORKERS=100
./order-processor
```

### AWS Deployment

1. Build and push Docker images:
```bash
cd order-system
./deploy-aws.sh
```

2. Deploy infrastructure:
```bash
cd terraform
terraform init
terraform apply
```

## Load Testing

```bash
cd locust

# Test LocalStack
locust -f locustfile.py --host=http://localhost:8080 --users=20 --spawn-rate=2 --run-time=60s --headless --html=results/localstack-test.html

# Test AWS
locust -f locustfile.py --host=http://<ALB_DNS> --users=20 --spawn-rate=2 --run-time=60s --headless --html=results/aws-test.html
```

## Key Findings

- **LocalStack**: 2x faster response times (21ms vs 42ms), zero cost, ideal for development
- **AWS**: Production-grade infrastructure, ~20ms network overhead, ideal for production
- **Processing Performance**: Nearly identical (queue drain times within 5%)

See `FINAL_MASTERY_REPORT.md` for detailed analysis.

