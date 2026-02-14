const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));
  
  try {
    const shortCode = event.pathParameters?.code || event.pathParameters?.proxy;
    
    if (!shortCode) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'Short code required' })
      };
    }
    
    const params = {
      TableName: process.env.TABLE_NAME,
      Key: { shortCode: shortCode }
    };
    
    const result = await dynamodb.get(params).promise();
    
    if (!result.Item) {
      return {
        statusCode: 404,
        headers: { 'Content-Type': 'text/html' },
        body: '<h1>404 - URL Not Found</h1><p>This short URL does not exist.</p>'
      };
    }
    
    // Increment hit counter (fire and forget, don't wait)
    dynamodb.update({
      TableName: process.env.TABLE_NAME,
      Key: { shortCode: shortCode },
      UpdateExpression: 'SET hits = if_not_exists(hits, :zero) + :inc',
      ExpressionAttributeValues: {
        ':inc': 1,
        ':zero': 0
      }
    }).promise().catch(err => console.error('Failed to increment counter:', err));
    
    console.log('Redirecting', shortCode, 'to', result.Item.longUrl);
    
    return {
      statusCode: 301,
      headers: {
        'Location': result.Item.longUrl,
        'Cache-Control': 'no-cache'
      },
      body: ''
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Internal server error' })
    };
  }
};