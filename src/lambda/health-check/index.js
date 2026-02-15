const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const dynamodb = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
  try {
    const startTime = Date.now();
    await dynamodb.send(new ScanCommand({
      TableName: process.env.TABLE_NAME,
      Limit: 1
    }));
    const latency = Date.now() - startTime;
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        status: 'healthy',
        region: process.env.AWS_REGION,
        timestamp: new Date().toISOString(),
        dynamodb_latency_ms: latency,
        service: 'url-shortener'
      })
    };
  } catch (error) {
    console.error('Health check failed:', error);
    return {
      statusCode: 503,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        status: 'unhealthy',
        region: process.env.AWS_REGION,
        error: error.message,
        timestamp: new Date().toISOString()
      })
    };
  }
};