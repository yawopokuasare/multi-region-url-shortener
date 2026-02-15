const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const dynamodb = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
  console.log('Full Event:', JSON.stringify(event, null, 2));
  
  try {
    // HTTP API (v2) uses event.pathParameters.code
    // Also check rawPath as backup
    let shortCode = event.pathParameters?.code;
    
    // If not found, try parsing rawPath
    if (!shortCode && event.rawPath) {
      shortCode = event.rawPath.substring(1); // Remove leading /
    }
    
    console.log('Extracted shortCode:', shortCode);
    
    if (!shortCode) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          error: 'Short code required',
          debug: {
            pathParameters: event.pathParameters,
            rawPath: event.rawPath
          }
        })
      };
    }
    
    const result = await dynamodb.send(new GetCommand({
      TableName: process.env.TABLE_NAME,
      Key: { shortCode: shortCode }
    }));
    
    console.log('DynamoDB result:', JSON.stringify(result, null, 2));
    
    if (!result.Item) {
      return {
        statusCode: 404,
        headers: { 'Content-Type': 'text/html' },
        body: '<h1>404 - URL Not Found</h1><p>This short URL does not exist.</p>'
      };
    }
    
    // Increment hit counter (fire and forget)
    dynamodb.send(new UpdateCommand({
      TableName: process.env.TABLE_NAME,
      Key: { shortCode: shortCode },
      UpdateExpression: 'SET hits = if_not_exists(hits, :zero) + :inc',
      ExpressionAttributeValues: {
        ':inc': 1,
        ':zero': 0
      }
    })).catch(err => console.error('Failed to increment counter:', err));
    
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
      body: JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      })
    };
  }
};