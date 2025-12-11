# Memory Configuration for MCP Server

This MCP Server deployment now includes AgentCore Memory support, allowing the server to maintain context and state across invocations.

## What is AgentCore Memory?

AgentCore Memory provides persistent storage for agent context, allowing:
- Conversation history retention
- User preferences storage
- Session state management
- Context sharing across invocations

## Memory Configuration

### Parameters

- **MemoryName**: Name for the memory resource (default: `MCPServerMemory`)
- **EventExpiryDuration**: How long memory events are retained (default: 30 days)

### Initial Memory Data

The deployment automatically initializes the memory with:
- Server information
- Available tools list
- Tool descriptions

This is done via the `MemoryInitializerFunction` Lambda which runs after memory creation.

## Using Memory in Your MCP Server

The Memory ID is automatically passed to your MCP server container as an environment variable:

```python
import os
from bedrock_agentcore.memory import MemoryClient

# Get memory ID from environment
memory_id = os.getenv('MEMORY_ID')

# Initialize memory client
memory_client = MemoryClient(region=os.getenv('AWS_REGION'))

# Store data in memory
memory_client.create_event(
    memory_id=memory_id,
    actor_id="user123",
    session_id="session456",
    payload=[{
        'blob': json.dumps({"key": "value"})
    }]
)

# Retrieve memory
memory_data = memory_client.get_memory(
    memory_id=memory_id,
    actor_id="user123"
)
```

## Deployment

Memory is automatically created and initialized when you deploy:

```bash
./deploy.sh my-stack us-west-2
```

## Outputs

After deployment, you can retrieve the Memory ID:

```bash
aws cloudformation describe-stacks \
  --stack-name my-stack \
  --region us-west-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`MemoryId`].OutputValue' \
  --output text
```

## Customizing Initial Memory Data

To customize the initial memory data, modify the `MemoryInitializerFunction` in the template:

```python
# Sample memory data for MCP server
mcp_context = {
    "server_info": "Your custom info",
    "custom_data": "Your data here"
}
```

## IAM Permissions

The deployment includes necessary IAM permissions for:
- Creating memory events (`bedrock-agentcore:CreateEvent`)
- Listing memory events (`bedrock-agentcore:ListEvents`)
- Getting memory data (`bedrock-agentcore:GetMemory`)

## Memory Lifecycle

- **Creation**: Memory is created during stack deployment
- **Initialization**: Custom Lambda function populates initial data
- **Usage**: MCP server can read/write during runtime
- **Expiry**: Events expire after 30 days (configurable)
- **Deletion**: Memory is deleted when stack is deleted

## Troubleshooting

### Memory not accessible

Check IAM permissions in the `AgentExecutionRole`:
```bash
aws iam get-role-policy \
  --role-name my-stack-agent-execution-role \
  --policy-name AgentCoreExecutionPolicy
```

### Memory initialization failed

Check Lambda logs:
```bash
aws logs tail /aws/lambda/my-stack-memory-initializer --follow
```

### View memory contents

Use the AWS CLI:
```bash
aws bedrock-agentcore list-events \
  --memory-id <MEMORY_ID> \
  --actor-id mcp_server \
  --region us-west-2
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    CloudFormation Stack                  │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │  MCP Server      │────────▶│  AgentCore       │     │
│  │  Runtime         │         │  Memory          │     │
│  │                  │         │                  │     │
│  │  MEMORY_ID env   │         │  Event Storage   │     │
│  └──────────────────┘         └──────────────────┘     │
│           │                            ▲                 │
│           │                            │                 │
│           ▼                            │                 │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │  Memory Client   │         │  Memory          │     │
│  │  (in container)  │────────▶│  Initializer     │     │
│  │                  │         │  Lambda          │     │
│  └──────────────────┘         └──────────────────┘     │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Example: Using Memory in MCP Server

Update your `mcp_server.py` to use memory:

```python
from mcp.server.fastmcp import FastMCP
from bedrock_agentcore.memory import MemoryClient
import os
import json

mcp = FastMCP(host="0.0.0.0", stateless_http=True)

# Initialize memory client
memory_id = os.getenv('MEMORY_ID')
region = os.getenv('AWS_REGION', 'us-west-2')
memory_client = MemoryClient(region=region)

@mcp.tool()
def remember_preference(user_id: str, preference: str, value: str) -> str:
    """Store a user preference in memory"""
    try:
        memory_client.create_event(
            memory_id=memory_id,
            actor_id=user_id,
            session_id="preferences",
            payload=[{
                'blob': json.dumps({
                    "preference": preference,
                    "value": value
                })
            }]
        )
        return f"Remembered: {preference} = {value}"
    except Exception as e:
        return f"Error: {str(e)}"

@mcp.tool()
def recall_preferences(user_id: str) -> str:
    """Retrieve user preferences from memory"""
    try:
        memory_data = memory_client.get_memory(
            memory_id=memory_id,
            actor_id=user_id
        )
        return json.dumps(memory_data, indent=2)
    except Exception as e:
        return f"Error: {str(e)}"
```

## See Also

- [AgentCore Memory Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/agentcore-memory.html)
- [Memory Client API Reference](https://github.com/awslabs/amazon-bedrock-agentcore-python)
