const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  try {
    // Test DynamoDB connectivity
    const startTime = Date.now();
    await dynamodb.scan({
      TableName: process.env.TABLE_NAME,
      Limit: 1
    }).promise();
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