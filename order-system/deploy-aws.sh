#!/bin/bash

# AWS Deployment Script
# This script builds Docker images, pushes to ECR, and deploys with Terraform

set -e

echo "=== AWS Deployment Script ==="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REGION="us-west-2"
TERRAFORM_DIR="../terraform"

# Check if AWS CLI is configured
echo -e "${BLUE}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Please run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account: ${ACCOUNT_ID}${NC}"
echo ""

# Get ECR repository URLs from Terraform
echo -e "${BLUE}Getting ECR repository URLs...${NC}"
cd "${TERRAFORM_DIR}"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

# Get ECR URLs
ECR_API_URL=$(terraform output -raw ecr_order_api_url 2>/dev/null || echo "")
ECR_PROCESSOR_URL=$(terraform output -raw ecr_order_processor_url 2>/dev/null || echo "")

# If outputs don't exist, create ECR repos first
if [ -z "$ECR_API_URL" ] || [ -z "$ECR_PROCESSOR_URL" ]; then
    echo -e "${YELLOW}ECR repositories not found. Creating them...${NC}"
    terraform apply -target=aws_ecr_repository.order_api -target=aws_ecr_repository.order_processor -auto-approve
    ECR_API_URL=$(terraform output -raw ecr_order_api_url)
    ECR_PROCESSOR_URL=$(terraform output -raw ecr_order_processor_url)
fi

echo -e "${GREEN}✓ ECR API URL: ${ECR_API_URL}${NC}"
echo -e "${GREEN}✓ ECR Processor URL: ${ECR_PROCESSOR_URL}${NC}"
echo ""

# Login to ECR
echo -e "${BLUE}Logging in to ECR...${NC}"
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
echo -e "${GREEN}✓ ECR login successful${NC}"
echo ""

# Build and push order-api
cd - > /dev/null
echo -e "${BLUE}Building order-api Docker image...${NC}"
docker build -f cmd/order-api/Dockerfile -t order-api:latest .
docker tag order-api:latest ${ECR_API_URL}:latest
echo -e "${BLUE}Pushing order-api to ECR...${NC}"
docker push ${ECR_API_URL}:latest
echo -e "${GREEN}✓ order-api pushed${NC}"
echo ""

# Build and push order-processor
echo -e "${BLUE}Building order-processor Docker image...${NC}"
docker build -f cmd/order-processor/Dockerfile -t order-processor:latest .
docker tag order-processor:latest ${ECR_PROCESSOR_URL}:latest
echo -e "${BLUE}Pushing order-processor to ECR...${NC}"
docker push ${ECR_PROCESSOR_URL}:latest
echo -e "${GREEN}✓ order-processor pushed${NC}"
echo ""

# Deploy with Terraform
echo -e "${BLUE}Deploying infrastructure with Terraform...${NC}"
cd "${TERRAFORM_DIR}"
echo ""
echo -e "${YELLOW}Review the Terraform plan:${NC}"
terraform plan

echo ""
read -p "Do you want to apply these changes? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply
    echo ""
    echo -e "${GREEN}=== Deployment Complete! ===${NC}"
    echo ""
    echo "Get the ALB URL:"
    echo "  terraform output alb_dns_name"
    echo ""
    echo "Or check CloudWatch logs:"
    echo "  aws logs tail /ecs/hw7 --follow"
else
    echo -e "${YELLOW}Deployment cancelled${NC}"
fi

