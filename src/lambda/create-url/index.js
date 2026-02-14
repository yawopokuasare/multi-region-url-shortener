const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const crypto = require('crypto');

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));
  
  try {
    const body = JSON.parse(event.body || '{}');
    const { longUrl } = body;
    
    if (!longUrl) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'longUrl is required' })
      };
    }
    
    // Generate 6-character short code
    const shortCode = crypto.randomBytes(3).toString('hex');
    
    const params = {
      TableName: process.env.TABLE_NAME,
      Item: {
        shortCode: shortCode,
        longUrl: longUrl,
        createdAt: Date.now(),
        createdRegion: process.env.AWS_REGION,
        hits: 0
      }
    };
    
    await dynamodb.put(params).promise();
    
    console.log('Created short URL:', shortCode);
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        shortCode: shortCode,
        longUrl: longUrl,
        shortUrl: `${process.env.BASE_URL}/${shortCode}`,
        region: process.env.AWS_REGION
      })
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ error: 'Internal server error', message: error.message })
    };
  }
};