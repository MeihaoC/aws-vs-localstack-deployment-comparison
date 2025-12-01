#!/bin/bash

# Queue Monitoring Script for LocalStack and AWS
# This script monitors queue depth over time

set -e

ENVIRONMENT=$1  # "localstack" or "aws"
INTERVAL=${2:-5}  # Check every N seconds (default: 5)

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./monitor-queue.sh [localstack|aws] [interval_seconds]"
    exit 1
fi

if [ "$ENVIRONMENT" == "localstack" ]; then
    ENDPOINT="--endpoint-url=http://localhost:4566"
    QUEUE_URL="http://sqs.us-west-2.localhost.localstack.cloud:4566/000000000000/order-processing-queue"
    REGION="us-west-2"
    echo "Monitoring LocalStack queue..."
elif [ "$ENVIRONMENT" == "aws" ]; then
    ENDPOINT=""
    QUEUE_URL="https://sqs.us-west-2.amazonaws.com/975050165802/order-processing-queue"
    REGION="us-west-2"
    echo "Monitoring AWS queue..."
else
    echo "Invalid environment. Use 'localstack' or 'aws'"
    exit 1
fi

echo "Queue URL: $QUEUE_URL"
echo "Checking every $INTERVAL seconds..."
echo "Press Ctrl+C to stop"
echo ""
echo "Time,Visible,NotVisible,InFlight"
echo "---------------------------------"

while true; do
    TIMESTAMP=$(date +"%H:%M:%S")
    
    # Get queue attributes
    ATTRIBUTES=$(aws $ENDPOINT sqs get-queue-attributes \
        --queue-url "$QUEUE_URL" \
        --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible ApproximateNumberOfMessagesDelayed \
        --region $REGION \
        --output json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        VISIBLE=$(echo $ATTRIBUTES | jq -r '.Attributes.ApproximateNumberOfMessages // 0')
        NOT_VISIBLE=$(echo $ATTRIBUTES | jq -r '.Attributes.ApproximateNumberOfMessagesNotVisible // 0')
        DELAYED=$(echo $ATTRIBUTES | jq -r '.Attributes.ApproximateNumberOfMessagesDelayed // 0')
        IN_FLIGHT=$((NOT_VISIBLE + DELAYED))
        
        echo "$TIMESTAMP,$VISIBLE,$NOT_VISIBLE,$IN_FLIGHT"
    else
        echo "$TIMESTAMP,ERROR,ERROR,ERROR"
    fi
    
    sleep $INTERVAL
done

