const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand, ScanCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');
const { v4: uuidv4 } = require('uuid');

// Initialize DynamoDB client
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const tableName = process.env.DYNAMODB_TABLE;

// Log initialization (helps debug env var issues)
console.log('DynamoDB client initialized');
console.log('Table name:', tableName || 'NOT SET - CHECK ENVIRONMENT VARIABLES!');
console.log('AWS Region:', process.env.AWS_REGION || 'default');

// Lambda handler (replaces Azure Function context)
exports.handler = async (event) => {
    // Log incoming request
    console.log('Request:', {
        method: event.requestContext?.http?.method,
        path: event.rawPath,
        query: event.queryStringParameters
    });

    try {
        // Parse path: /api/tweet or /api/tweet/{id}
        const pathParts = event.rawPath.split('/').filter(p => p);
        const action = pathParts[1]; // 'tweet'
        const id = pathParts[2];     // uuid (optional)

        if (action === 'tweet') {
            return await handleTweet(event, id);
        } else {
            return {
                statusCode: 404,
                body: JSON.stringify({ error: 'Not found' })
            };
        }
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Internal server error' })
        };
    }
};

async function handleTweet(event, id) {
    const method = event.requestContext.http.method;

    switch (method) {
        case 'POST':
            return await createTweet(event);
        case 'GET':
            return await readTweet(event, id);
        case 'PATCH':
            return await updateTweet(event, id);
        case 'DELETE':
            return await deleteTweet(event, id);
        default:
            return {
                statusCode: 405,
                body: JSON.stringify({ error: 'Method not allowed' })
            };
    }
}

async function createTweet(event) {
    try {
        const body = JSON.parse(event.body || '{}');
        const { name, message } = body;

        if (!name || !message) {
            return {
                statusCode: 400,
                body: JSON.stringify({ error: 'Name and message required' })
            };
        }

        const item = {
            name: name,           // Partition key
            uuid: uuidv4(),       // Sort key
            message: message,
            timestamp: new Date().toISOString()
        };

        console.log('Creating tweet in table:', tableName, 'Item:', item);

        await docClient.send(new PutCommand({
            TableName: tableName,
            Item: item
        }));

        console.log('Tweet created successfully:', item.uuid);

        return {
            statusCode: 201,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(item)
        };
    } catch (error) {
        console.error('Create error:', error);
        return {
            statusCode: 400,
            body: JSON.stringify({ error: error.message })
        };
    }
}

async function readTweet(event, uuid) {
    try {
        // If no uuid provided, list all tweets
        if (!uuid) {
            console.log('Scanning all tweets from table:', tableName);

            const result = await docClient.send(new ScanCommand({
                TableName: tableName
            }));

            console.log('Scan result: found', result.Items?.length || 0, 'tweets');

            return {
                statusCode: 200,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(result.Items || [])
            };
        }

        // Get specific tweet by name and uuid
        const name = event.queryStringParameters?.name;
        if (!name) {
            return {
                statusCode: 400,
                body: JSON.stringify({ error: 'Name query parameter required' })
            };
        }

        console.log('Getting tweet:', { tableName, name, uuid });

        const result = await docClient.send(new GetCommand({
            TableName: tableName,
            Key: { name, uuid }
        }));

        console.log('Get result:', result.Item ? 'found' : 'not found');

        if (!result.Item) {
            return {
                statusCode: 404,
                body: JSON.stringify({ error: 'Tweet not found' })
            };
        }

        return {
            statusCode: 200,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(result.Item)
        };
    } catch (error) {
        console.error('Read error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message })
        };
    }
}

async function updateTweet(event, uuid) {
    try {
        const body = JSON.parse(event.body || '{}');
        const { name, message } = body;

        if (!name || !uuid || !message) {
            return {
                statusCode: 400,
                body: JSON.stringify({ error: 'Name, uuid, and message required' })
            };
        }

        const item = {
            name: name,
            uuid: uuid,
            message: message,
            timestamp: new Date().toISOString()
        };

        await docClient.send(new PutCommand({
            TableName: tableName,
            Item: item
        }));

        return {
            statusCode: 202,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(item)
        };
    } catch (error) {
        console.error('Update error:', error);
        return {
            statusCode: 400,
            body: JSON.stringify({ error: error.message })
        };
    }
}

async function deleteTweet(event, uuid) {
    try {
        const name = event.queryStringParameters?.name;

        if (!name || !uuid) {
            return {
                statusCode: 400,
                body: JSON.stringify({ error: 'Name and uuid required' })
            };
        }

        await docClient.send(new DeleteCommand({
            TableName: tableName,
            Key: { name, uuid }
        }));

        return {
            statusCode: 202,
            body: JSON.stringify({ message: 'Tweet deleted' })
        };
    } catch (error) {
        console.error('Delete error:', error);
        return {
            statusCode: 404,
            body: JSON.stringify({ error: 'Tweet not found' })
        };
    }
}
