# Chapter 5: Serverless Made Easy - Ballroom Application

A full-stack serverless Twitter-like application deployed on AWS,
adapted from the book's Azure Functions example.

## Demo

[ballroom.webm](./images/ballroom.webm)

**Live application:** API Gateway → Lambda (Web + API) → DynamoDB

## Architecture

```
API Gateway (Single URL)
├── GET /              → Web Lambda → index.html
├── GET /{proxy+}      → Web Lambda → CSS/JS/images
└── ANY /api/tweet/*   → API Lambda → DynamoDB (tweets table)
```

**Resources Deployed:** 20 AWS resources (S3, Lambda, DynamoDB, IAM, API Gateway)

## Key Differences from Book

| Book (Azure)                          | This Implementation (AWS)            | Reason                                    |
| ------------------------------------- | ------------------------------------ | ----------------------------------------- |
| Azure Functions App                   | AWS Lambda + API Gateway v2          | AWS serverless equivalent                 |
| Azure Table Storage                   | DynamoDB (PAY_PER_REQUEST)           | NoSQL key-value store, free tier friendly |
| `terraform-in-action/ballroom` module | Custom function code in `functions/` | Remove external dependencies              |
| Azure Function context                | Lambda event/response                | Different handler interface               |
| Callback-based code                   | async/await with AWS SDK v3          | Modern JavaScript patterns                |
| Single output (website URL)           | Two outputs (website + api_endpoint) | Better UX for API consumers               |

## Project Structure

```
chapter_05/
├── functions/
│   ├── api/              # Tweet CRUD API (DynamoDB)
│   │   ├── index.js      # Lambda handler
│   │   └── package.json  # AWS SDK dependencies
│   └── web/              # Static file server
│       ├── index.js      # Lambda handler
│       ├── package.json
│       └── public/       # HTML, CSS, JS, images
├── main.tf               # Infrastructure
├── variables.tf
├── outputs.tf
└── versions.tf           # Terraform 1.12+, AWS 5.82+
```

## Commands Used

### Setup

```bash
# Install dependencies
cd functions/api && npm install
cd ../web && npm install
cd ../..

# Initialize Terraform
terraform init
```

### Deploy

```bash
# Plan changes
terraform plan -out=chapter05.tfplan

# Apply infrastructure
terraform apply

# Or apply plan file
terraform apply chapter05.tfplan
```

### Destroy

```bash
terraform destroy
```

## Key Learnings

### 1. Service Mapping (Azure ↔ AWS)

- **Azure Functions** = AWS Lambda (serverless compute)
- **Table Storage** = DynamoDB (NoSQL database)
- **Functions App** = API Gateway + Lambda (HTTP routing)

### 2. Lambda Handler Patterns

**Azure:**

```javascript
module.exports = function (context, req) {
  context.res = { status: 200, body: "..." };
  context.done();
};
```

**AWS:**

```javascript
exports.handler = async (event) => {
  return { statusCode: 200, body: "..." };
};
```

### 3. DynamoDB vs Table Storage

```javascript
// Azure Table Storage
tableService.insertEntity(tableName, entity, callback);

// AWS DynamoDB
await docClient.send(
  new PutCommand({
    TableName: tableName,
    Item: item,
  }),
);
```

### 4. API Gateway Routing

- **Route precedence:** More specific routes take priority
- **Catch-all route:** `GET /{proxy+}` for static assets
- **Root route:** `GET /` separate from `/{proxy+}`

### 5. IAM Least Privilege

- **API Lambda:** DynamoDB + CloudWatch Logs
- **Web Lambda:** CloudWatch Logs only
- Separate roles prevent unnecessary access

**Example successful API request:**

```
INFO Request: { method: 'GET', path: '/api/tweet', query: undefined }
INFO Scanning all tweets from table: ballroominaction-d8bachf-tweets
INFO Scan result: found 3 tweets
REPORT Duration: 60.81 ms  Memory: 88 MB  Billed: 61 ms
```

_Performance: ~60ms response time, ~88MB memory usage_

## Cost Analysis

**Total cost:** $0 (within free tier)

| Service         | Free Tier                     | Usage                 |
| --------------- | ----------------------------- | --------------------- |
| Lambda          | 1M requests/month             | ~100 requests         |
| DynamoDB        | 25GB storage, 25 RCU/WCU      | <1GB, minimal traffic |
| API Gateway     | 1M requests/month             | ~100 requests         |
| S3              | 5GB storage, 20K GET requests | <10MB                 |
| CloudWatch Logs | 5GB ingestion                 | <100MB                |

**Recommendation:** Always run `terraform destroy` after testing to avoid surprise charges!

## Testing the Application

### Web Interface

```bash
# Get URL from output
terraform output website_url

# Open in browser
# Try posting tweets!
```

### API Endpoints

```bash
# List all tweets
curl $(terraform output -raw api_endpoint)/tweet

# Create tweet
curl -X POST $(terraform output -raw api_endpoint)/tweet \
  -H "Content-Type: application/json" \
  -d '{"name":"YourName","message":"Hello from AWS!"}'

# Get specific tweet (requires name and uuid from create response)
curl "$(terraform output -raw api_endpoint)/tweet/{uuid}?name={name}"
```

## Production Considerations

**What we did (learning):**

- Single region deployment
- No custom domain
- Public API endpoints (no authentication)
- Lambda serves static files

**What production would do:**

- Multi-region deployment for HA
- CloudFront + custom domain
- API authentication (Cognito, IAM, API keys)
- S3 + CloudFront for static assets (not Lambda)
- WAF for security
- Monitoring and alerting

## Clean Up

```bash
# Destroy all resources
terraform destroy

# Verify in AWS Console:
# - Lambda functions deleted
# - DynamoDB table deleted
# - API Gateway deleted
# - S3 bucket deleted
```
