#!/bin/bash

# Test multi-region failover

set -e

PRIMARY_ENDPOINT=$1
SECONDARY_ENDPOINT=$2

if [ -z "$PRIMARY_ENDPOINT" ] || [ -z "$SECONDARY_ENDPOINT" ]; then
  echo "Usage: $0 <primary_endpoint> <secondary_endpoint>"
  echo "Example: $0 https://abc123.execute-api.us-east-1.amazonaws.com https://def456.execute-api.us-west-2.amazonaws.com"
  exit 1
fi

echo "======================================"
echo "Multi-Region Failover Test"
echo "======================================"
echo ""

# Test 1: Health checks
echo "Test 1: Checking health of both regions..."
echo ""
echo "Primary Region Health:"
curl -s "${PRIMARY_ENDPOINT}/health" | jq .
echo ""
echo "Secondary Region Health:"
curl -s "${SECONDARY_ENDPOINT}/health" | jq .
echo ""

# Test 2: Create URL in primary
echo "Test 2: Creating short URL in primary region..."
RESPONSE=$(curl -s -X POST "${PRIMARY_ENDPOINT}/create" \
  -H "Content-Type: application/json" \
  -d '{"longUrl":"https://github.com/yawopokuasare"}')

SHORT_CODE=$(echo $RESPONSE | jq -r '.shortCode')
echo "Created short code: $SHORT_CODE"
echo "Full response: $RESPONSE" | jq .
echo ""

# Wait for replication
echo "Waiting 5 seconds for DynamoDB Global Table replication..."
sleep 5
echo ""

# Test 3: Read from secondary region
echo "Test 3: Reading from secondary region (testing replication)..."
curl -I "${SECONDARY_ENDPOINT}/${SHORT_CODE}"
echo ""

# Test 4: Create in secondary, read from primary
echo "Test 4: Creating in secondary, reading from primary..."
RESPONSE2=$(curl -s -X POST "${SECONDARY_ENDPOINT}/create" \
  -H "Content-Type: application/json" \
  -d '{"longUrl":"https://aws.amazon.com"}')

SHORT_CODE2=$(echo $RESPONSE2 | jq -r '.shortCode')
echo "Created short code: $SHORT_CODE2"
echo ""

sleep 5

echo "Reading from primary region..."
curl -I "${PRIMARY_ENDPOINT}/${SHORT_CODE2}"
echo ""

# Test 5: Performance comparison
echo "Test 5: Latency comparison..."
echo ""
echo "Primary region latency:"
time curl -s "${PRIMARY_ENDPOINT}/health" > /dev/null
echo ""
echo "Secondary region latency:"
time curl -s "${SECONDARY_ENDPOINT}/health" > /dev/null
echo ""

echo "======================================"
echo "Failover test complete!"
echo "======================================"
echo ""
echo "To simulate regional failure:"
echo "1. Go to Route 53 console"
echo "2. Find health check for primary region"
echo "3. Temporarily invert the health check logic"
echo "4. Watch DNS failover to secondary"
echo ""
echo "Monitor with:"
echo "  watch -n 5 'curl -s ${PRIMARY_ENDPOINT}/health | jq .'"