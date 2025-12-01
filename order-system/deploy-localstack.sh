#!/bin/bash

# LocalStack Deployment Script
# This script sets up LocalStack infrastructure and runs the order system

set -e

echo "=== LocalStack Deployment Script ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LOCALSTACK_ENDPOINT="http://localhost:4566"
REGION="us-west-2"
ACCOUNT_ID="000000000000"

# Check if LocalStack is running
echo -e "${BLUE}Checking if LocalStack is running...${NC}"
if ! curl -s "${LOCALSTACK_ENDPOINT}/_localstack/health" > /dev/null 2>&1; then
    echo -e "${YELLOW}LocalStack is not running. Starting LocalStack...${NC}"
    echo "Please start LocalStack first:"
    echo "  docker run -d -p 4566:4566 -p 4571:4571 localstack/localstack"
    echo "  OR"
    echo "  localstack start"
    exit 1
fi

echo -e "${GREEN}✓ LocalStack is running${NC}"
echo ""

# Create SNS Topic
echo -e "${BLUE}Creating SNS topic...${NC}"
TOPIC_ARN=$(aws --endpoint-url=${LOCALSTACK_ENDPOINT} sns create-topic \
    --name order-processing-events \
    --region ${REGION} \
    --output text --query 'TopicArn' 2>/dev/null || echo "")

if [ -z "$TOPIC_ARN" ]; then
    # Try to get existing topic
    TOPIC_ARN=$(aws --endpoint-url=${LOCALSTACK_ENDPOINT} sns list-topics \
        --region ${REGION} \
        --output text --query "Topics[?contains(TopicArn, 'order-processing-events')].TopicArn" | head -1)
fi

if [ -z "$TOPIC_ARN" ]; then
    TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:order-processing-events"
fi

echo -e "${GREEN}✓ SNS Topic: ${TOPIC_ARN}${NC}"
echo ""

# Create SQS Queue
echo -e "${BLUE}Creating SQS queue...${NC}"
QUEUE_URL=$(aws --endpoint-url=${LOCALSTACK_ENDPOINT} sqs create-queue \
    --queue-name order-processing-queue \
    --region ${REGION} \
    --attributes VisibilityTimeout=30,MessageRetentionPeriod=345600,ReceiveMessageWaitTimeSeconds=20 \
    --output text --query 'QueueUrl' 2>/dev/null || echo "")

if [ -z "$QUEUE_URL" ]; then
    # Try to get existing queue
    QUEUE_URL=$(aws --endpoint-url=${LOCALSTACK_ENDPOINT} sqs get-queue-url \
        --queue-name order-processing-queue \
        --region ${REGION} \
        --output text --query 'QueueUrl' 2>/dev/null || echo "")
fi

if [ -z "$QUEUE_URL" ]; then
    QUEUE_URL="${LOCALSTACK_ENDPOINT}/${ACCOUNT_ID}/order-processing-queue"
fi

echo -e "${GREEN}✓ SQS Queue: ${QUEUE_URL}${NC}"
echo ""

# Get Queue ARN for subscription
QUEUE_ARN=$(aws --endpoint-url=${LOCALSTACK_ENDPOINT} sqs get-queue-attributes \
    --queue-url ${QUEUE_URL} \
    --attribute-names QueueArn \
    --region ${REGION} \
    --output text --query 'Attributes.QueueArn' 2>/dev/null || echo "")

if [ -z "$QUEUE_ARN" ]; then
    QUEUE_ARN="arn:aws:sqs:${REGION}:${ACCOUNT_ID}:order-processing-queue"
fi

echo -e "${BLUE}Queue ARN: ${QUEUE_ARN}${NC}"
echo ""

# Subscribe SQS to SNS
echo -e "${BLUE}Subscribing SQS queue to SNS topic...${NC}"
SUBSCRIPTION_ARN=$(aws --endpoint-url=${LOCALSTACK_ENDPOINT} sns subscribe \
    --topic-arn ${TOPIC_ARN} \
    --protocol sqs \
    --notification-endpoint ${QUEUE_ARN} \
    --region ${REGION} \
    --output text --query 'SubscriptionArn' 2>/dev/null || echo "")

if [ ! -z "$SUBSCRIPTION_ARN" ]; then
    echo -e "${GREEN}✓ Subscription created: ${SUBSCRIPTION_ARN}${NC}"
else
    echo -e "${YELLOW}⚠ Subscription may already exist${NC}"
fi
echo ""

# Set SQS policy to allow SNS to send messages
echo -e "${BLUE}Setting SQS queue policy...${NC}"
POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "SQS:SendMessage",
      "Resource": "${QUEUE_ARN}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${TOPIC_ARN}"
        }
      }
    }
  ]
}
EOF
)

aws --endpoint-url=${LOCALSTACK_ENDPOINT} sqs set-queue-attributes \
    --queue-url ${QUEUE_URL} \
    --attributes Policy="${POLICY}" \
    --region ${REGION} > /dev/null 2>&1 || echo "Policy may already be set"

echo -e "${GREEN}✓ Queue policy set${NC}"
echo ""

# Export environment variables
echo -e "${BLUE}Environment variables:${NC}"
echo ""
echo "export AWS_ENDPOINT_URL=${LOCALSTACK_ENDPOINT}"
echo "export AWS_REGION=${REGION}"
echo "export SNS_TOPIC_ARN=${TOPIC_ARN}"
echo "export SQS_QUEUE_URL=${QUEUE_URL}"
echo "export NUM_WORKERS=5"
echo ""

echo -e "${GREEN}=== LocalStack Setup Complete! ===${NC}"
echo ""
echo "Next steps:"
echo "1. Set the environment variables above"
echo "2. Run order-api: ./order-api"
echo "3. Run order-processor: ./order-processor"
echo ""
echo "Or use docker-compose (see docker-compose.yml)"

