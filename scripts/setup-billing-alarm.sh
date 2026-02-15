#!/bin/bash

# Setup billing alarm (run this first!)

set -e

THRESHOLD=${1:-10}
EMAIL=${2:-your-email@example.com}

echo "Setting up billing alarm..."
echo "Threshold: \$$THRESHOLD"
echo "Email: $EMAIL"
echo ""

# Create SNS topic
TOPIC_ARN=$(aws sns create-topic --name billing-alarm-topic --query 'TopicArn' --output text)
echo "Created SNS topic: $TOPIC_ARN"

# Subscribe email
aws sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol email \
  --notification-endpoint $EMAIL

echo "Subscription request sent to $EMAIL - CHECK YOUR EMAIL AND CONFIRM!"
echo ""

# Create CloudWatch alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "billing-threshold-${THRESHOLD}" \
  --alarm-description "Alert when estimated charges exceed \$${THRESHOLD}" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold $THRESHOLD \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions $TOPIC_ARN \
  --dimensions Name=Currency,Value=USD

echo "Billing alarm created successfully!"
echo ""
echo "You will receive an email when charges exceed \$$THRESHOLD"
echo ""
echo "Monitor your spending at: https://console.aws.amazon.com/cost-management/home"