# Cursor Cloud Agents API
The Cloud Agents API (Beta) allows you to programmatically create and manage AI-powered coding agents that work autonomously on your repositories. You can use the API to automatically respond to user feedback, fix bugs, update docs, and much more.

Cloud Agents API is currently in beta, we'd love your feedback on it!

MCP (Model Context Protocol) is not yet supported by the Cloud Agents API.

Key features
Autonomous code generation - Create agents that can understand your prompt and make changes to your codebase
Repository integration - Work directly with GitHub repositories
Follow-up prompts - Add additional instructions to running agents
Usage-based pricing - Pay only for the tokens you use
Scalable - Support for up to 256 active agents per API key
Quick start
1. Get your API key
Navigate to Cursor Dashboard → Integrations to create your API key.

2. Start using the API
All API endpoints are relative to:


https://api.cursor.com
See the API reference for a detailed list of endpoints.

## Authentication
All API requests require authentication using a Bearer token:


Authorization: Bearer YOUR_API_KEY
API keys are created in the Cursor Dashboard. Keys are scoped to your account and grant permission to create and manage agents (subject to your plan limits and repository access).

## Cloud Agents API Endpoints
View the full OpenAPI specification for detailed schemas and examples.

MCP (Model Context Protocol) is not yet supported by the Cloud Agents API.

Agent Information
### List Agents
GET
/v0/agents
List all cloud agents for the authenticated user.


curl --request GET \
  --url https://api.cursor.com/v0/agents \
  --header 'Authorization: Bearer <token>'


### Agent Status
GET
/v0/agents/{id}
Retrieve the current status and results of a cloud agent.


curl --request GET \
  --url https://api.cursor.com/v0/agents/{id} \
  --header 'Authorization: Bearer <token>'
Agent Conversation
GET
/v0/agents/{id}/conversation
Retrieve the conversation history of a cloud agent.

If the cloud agent has been deleted, you cannot access the conversation.


curl --request GET \
  --url https://api.cursor.com/v0/agents/{id}/conversation \
  --header 'Authorization: Bearer <token>'

## Agent Management

### Launch an Agent
POST
/v0/agents
Start a new cloud agent to work on your repository.


curl --request POST \
  --url https://api.cursor.com/v0/agents \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "prompt": {
    "text": "Add a README.md file with installation instructions",
    "images": [
      {
        "data": "iVBORw0KGgoAAAANSUhEUgAA...",
        "dimension": {
          "width": 1024,
          "height": 768
        }
      }
    ]
  },
  "source": {
    "repository": "https://github.com/your-org/your-repo",
    "ref": "main"
  }
}'

### Add Follow-up
POST
/v0/agents/{id}/followup
Add a follow-up instruction to an existing cloud agent.


curl --request POST \
  --url https://api.cursor.com/v0/agents/{id}/followup \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
  "prompt": {
    "text": "Also add a section about troubleshooting",
    "images": [
      {
        "data": "iVBORw0KGgoAAAANSUhEUgAA...",
        "dimension": {
          "width": 1024,
          "height": 768
        }
      }
    ]
  }
}'

### Delete an Agent
DELETE
/v0/agents/{id}
Delete a cloud agent. This action is permanent and cannot be undone.


curl --request DELETE \
  --url https://api.cursor.com/v0/agents/{id} \
  --header 'Authorization: Bearer <token>'

## General Endpoints

### API Key Info
GET
/v0/me
Retrieve information about the API key being used for authentication.


curl --request GET \
  --url https://api.cursor.com/v0/me \
  --header 'Authorization: Bearer <token>'

### List Models
GET
/v0/models
If you want to provide the cloud agent's model during creation, you can use this endpoint to see a list of recommended models.

In that case, we also recommend having an "Auto" option, in which you would not provide a model name to the creation endpoint, and we will pick the most appropriate model.


curl --request GET \
  --url https://api.cursor.com/v0/models \
  --header 'Authorization: Bearer <token>'

### List GitHub Repositories
GET
/v0/repositories
Retrieve a list of GitHub repositories accessible to the authenticated user.


curl --request GET \
  --url https://api.cursor.com/v0/repositories \
  --header 'Authorization: Bearer <token>'
This endpoint has very strict rate limits.

Limit requests to 1 / user / minute, and 30 / user / hour.

This request can take tens of seconds to respond for users with access to many repositories.

Make sure to handle this information not being available gracefully.

### Response Codes
All endpoints return standard HTTP status codes:

200 - Success (for GET requests)
201 - Created (for POST requests that create resources)
400 - Bad Request (invalid parameters)
401 - Unauthorized (invalid or missing API key)
403 - Forbidden (insufficient permissions, plan limits exceeded)
404 - Not Found
409 - Conflict (resource in invalid state)
429 - Rate Limit Exceeded
500 - Internal Server Error
Rate Limiting
The API implements rate limiting to ensure fair usage. When you exceed the rate limit, you'll receive a 429 status code. We recommend implementing exponential backoff in your applications.

Authentication
All endpoints require authentication via Bearer token. Include your API key in the Authorization header:


Authorization: Bearer YOUR_API_KEY
You can obtain an API key from your Cursor Dashboard.

Webhooks
When you create an agent with a webhook URL, Cursor will send HTTP POST requests to notify you about status changes. Currently, only statusChange events are supported, specifically when an agent encounters an ERROR or FINISHED state.

Webhook verification
To ensure the webhook requests are authentically from Cursor, verify the signature included with each request:

Headers
Each webhook request includes the following headers:

X-Webhook-Signature – Contains the HMAC-SHA256 signature in the format sha256=<hex_digest>
X-Webhook-ID – A unique identifier for this delivery (useful for logging)
X-Webhook-Event – The event type (currently only statusChange)
User-Agent – Always set to Cursor-Agent-Webhook/1.0
Signature verification
To verify the webhook signature, compute the expected signature and compare it with the received signature:


const crypto = require("crypto");
function verifyWebhook(secret, rawBody, signature) {
  const expectedSignature =
    "sha256=" +
    crypto.createHmac("sha256", secret).update(rawBody).digest("hex");
  return signature === expectedSignature;
}

import hmac
import hashlib
def verify_webhook(secret, raw_body, signature):
    expected_signature = 'sha256=' + hmac.new(
        secret.encode(),
        raw_body,
        hashlib.sha256
    ).hexdigest()
    return signature == expected_signature
Always use the raw request body (before any parsing) when computing the signature.

Payload format
The webhook payload is sent as JSON with the following structure:


{
  "event": "statusChange",
  "timestamp": "2024-01-15T10:30:00Z",
  "id": "bc_abc123",
  "status": "FINISHED",
  "source": {
    "repository": "https://github.com/your-org/your-repo",
    "ref": "main"
  },
  "target": {
    "url": "https://cursor.com/agents?id=bc_abc123",
    "branchName": "cursor/add-readme-1234",
    "prUrl": "https://github.com/your-org/your-repo/pull/1234"
  },
  "summary": "Added README.md with installation instructions"
}
Note that some fields are optional and will only be included when available.

Best practices
Verify signatures – Always verify the webhook signature to ensure the request is from Cursor
Handle retries – Webhooks may be retried if your endpoint returns an error status code
Return quickly – Return a 2xx status code as soon as possible
Use HTTPS – Always use HTTPS URLs for webhook endpoints in production
Store raw payloads – Store the raw webhook payload for debugging and future verification