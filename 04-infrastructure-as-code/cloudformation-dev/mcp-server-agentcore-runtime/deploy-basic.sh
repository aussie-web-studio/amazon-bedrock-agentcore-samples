#!/bin/bash
# Streamlined deployment script for MCP Server on AgentCore Runtime
#
# Usage:
#   ./deploy.sh [STACK_NAME] [REGION] [LLM_MODEL] [ADVANCED_MEMORY] [MEMORY_EXPIRY_DAYS]
#
# Examples:
#   ./deploy.sh                                                    # Uses defaults
#   ./deploy.sh my-stack us-east-1                                 # Custom stack and region
#   ./deploy.sh my-stack us-east-1 anthropic.claude-3-haiku-20240307-v1:0  # Custom model
#   ./deploy.sh my-stack us-east-1 amazon.nova-micro-v1:0 true    # Enable advanced memory
#   ./deploy.sh my-stack us-east-1 amazon.nova-micro-v1:0 true 7  # Advanced memory with 7-day expiry

set -e

STACK_NAME="${1:-mcp-server-demo}"
REGION="${2:-us-west-2}"
LLM_MODEL="${3:-amazon.nova-micro-v1:0}"
ADVANCED_MEMORY="${4:-false}"
MEMORY_EXPIRY_DAYS="${5:-30}"

# Validate advanced memory parameter
if [[ "$ADVANCED_MEMORY" != "true" && "$ADVANCED_MEMORY" != "false" ]]; then
    echo "❌ Error: ADVANCED_MEMORY must be 'true' or 'false'"
    exit 1
fi

# Validate memory expiry days
if ! [[ "$MEMORY_EXPIRY_DAYS" =~ ^[0-9]+$ ]] || [ "$MEMORY_EXPIRY_DAYS" -lt 1 ] || [ "$MEMORY_EXPIRY_DAYS" -gt 365 ]; then
    echo "❌ Error: MEMORY_EXPIRY_DAYS must be a number between 1 and 365"
    exit 1
fi

echo "=========================================="
echo "MCP Server Deployment Script"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "LLM Model: $LLM_MODEL"
echo "Advanced Memory: $ADVANCED_MEMORY"
echo "Memory Expiry Days: $MEMORY_EXPIRY_DAYS"
echo ""

if [ "$ADVANCED_MEMORY" = "true" ]; then
    echo "🧠 Advanced Memory Features:"
    echo "  • User preference extraction"
    echo "  • Conversation summarization"
    echo "  • Long-term memory strategies"
    echo "  • Structured namespace organization"
    echo ""
else
    echo "💾 Basic Memory Features:"
    echo "  • Simple conversation storage"
    echo "  • Basic event logging"
    echo ""
fi

# Deploy CloudFormation stack
echo "📦 Deploying CloudFormation stack..."
aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://mcp-server-template.yaml \
  --parameters \
    ParameterKey=LLMModel,ParameterValue="$LLM_MODEL" \
    ParameterKey=EnableAdvancedMemory,ParameterValue="$ADVANCED_MEMORY" \
    ParameterKey=MemoryEventExpiryDays,ParameterValue="$MEMORY_EXPIRY_DAYS" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

echo "✓ Stack creation initiated"
echo ""

# Wait for stack to complete
echo "⏳ Waiting for stack to complete (this takes ~10-15 minutes)..."
aws cloudformation wait stack-create-complete \
  --stack-name "$STACK_NAME" \
  --region "$REGION"

echo "✓ Stack deployment complete!"
echo ""

# Handle advanced memory creation if enabled
if [ "$ADVANCED_MEMORY" = "true" ]; then
    echo "🧠 Creating advanced memory with strategies..."
    
    # Generate memory name
    MEMORY_NAME="${STACK_NAME//-/_}_MCPServerMemory"
    
    # Create advanced memory using Python SDK
    python create-advanced-memory.py "$STACK_NAME" "$REGION" "$MEMORY_NAME" "$MEMORY_EXPIRY_DAYS"
    
    if [ $? -eq 0 ]; then
        echo "✅ Advanced memory created successfully!"
        
        # Get the advanced memory ID from SSM
        ADVANCED_MEMORY_ID=$(aws ssm get-parameter \
          --name "/bedrock-agentcore/$STACK_NAME/advanced-memory-id" \
          --query 'Parameter.Value' \
          --output text \
          --region "$REGION")
        
        echo "📦 Deploying MCP Server Runtime with advanced memory..."
        
        # Get required parameters from main stack
        ECR_URI=$(aws cloudformation describe-stacks \
          --stack-name "$STACK_NAME" \
          --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryUri`].OutputValue' \
          --output text \
          --region "$REGION")
          
        ROLE_ARN=$(aws cloudformation describe-stacks \
          --stack-name "$STACK_NAME" \
          --query 'Stacks[0].Outputs[?OutputKey==`AgentExecutionRoleArn`].OutputValue' \
          --output text \
          --region "$REGION")
          
        CLIENT_ID=$(aws cloudformation describe-stacks \
          --stack-name "$STACK_NAME" \
          --query 'Stacks[0].Outputs[?OutputKey==`CognitoUserPoolClientId`].OutputValue' \
          --output text \
          --region "$REGION")
          
        USER_POOL_ID=$(aws cloudformation describe-stacks \
          --stack-name "$STACK_NAME" \
          --query 'Stacks[0].Outputs[?OutputKey==`CognitoUserPoolId`].OutputValue' \
          --output text \
          --region "$REGION")
        
        # Deploy runtime stack
        aws cloudformation create-stack \
          --stack-name "$STACK_NAME-runtime" \
          --template-body file://mcp-runtime-template.yaml \
          --parameters \
            ParameterKey=StackName,ParameterValue="$STACK_NAME" \
            ParameterKey=ECRRepositoryUri,ParameterValue="$ECR_URI" \
            ParameterKey=AgentExecutionRoleArn,ParameterValue="$ROLE_ARN" \
            ParameterKey=CognitoUserPoolClientId,ParameterValue="$CLIENT_ID" \
            ParameterKey=CognitoUserPoolId,ParameterValue="$USER_POOL_ID" \
            ParameterKey=MemoryId,ParameterValue="$ADVANCED_MEMORY_ID" \
            ParameterKey=AdvancedMemoryEnabled,ParameterValue="true" \
          --region "$REGION"
          
        echo "⏳ Waiting for runtime stack to complete..."
        aws cloudformation wait stack-create-complete \
          --stack-name "$STACK_NAME-runtime" \
          --region "$REGION"
          
        echo "✅ MCP Server Runtime deployed with advanced memory!"
        
    else
        echo "❌ Advanced memory creation failed"
        echo "   Deployment stopped - please check the error above"
        exit 1
    fi
    echo ""
fi

# Get stack outputs
echo "📋 Retrieving stack outputs..."
# Get stack outputs (from main stack or runtime stack)
if [ "$ADVANCED_MEMORY" = "true" ]; then
    # For advanced memory, get outputs from runtime stack
    CLIENT_ID=$(aws cloudformation describe-stacks \
      --stack-name "$STACK_NAME" \
      --query 'Stacks[0].Outputs[?OutputKey==`CognitoUserPoolClientId`].OutputValue' \
      --output text \
      --region "$REGION")

    AGENT_ARN=$(aws cloudformation describe-stacks \
      --stack-name "$STACK_NAME-runtime" \
      --query 'Stacks[0].Outputs[?OutputKey==`MCPServerRuntimeArn`].OutputValue' \
      --output text \
      --region "$REGION")

    MEMORY_ID=$(aws ssm get-parameter \
      --name "/bedrock-agentcore/$STACK_NAME/advanced-memory-id" \
      --query 'Parameter.Value' \
      --output text \
      --region "$REGION")
      
    MEMORY_TYPE="Advanced (with strategies)"
else
    # For basic memory, get outputs from main stack
    CLIENT_ID=$(aws cloudformation describe-stacks \
      --stack-name "$STACK_NAME" \
      --query 'Stacks[0].Outputs[?OutputKey==`CognitoUserPoolClientId`].OutputValue' \
      --output text \
      --region "$REGION")

    AGENT_ARN=$(aws cloudformation describe-stacks \
      --stack-name "$STACK_NAME" \
      --query 'Stacks[0].Outputs[?OutputKey==`MCPServerRuntimeArn`].OutputValue' \
      --output text \
      --region "$REGION")

    MEMORY_ID=$(aws cloudformation describe-stacks \
      --stack-name "$STACK_NAME" \
      --query 'Stacks[0].Outputs[?OutputKey==`MemoryId`].OutputValue' \
      --output text \
      --region "$REGION")
      
    MEMORY_TYPE=$(aws cloudformation describe-stacks \
      --stack-name "$STACK_NAME" \
      --query 'Stacks[0].Outputs[?OutputKey==`MemoryType`].OutputValue' \
      --output text \
      --region "$REGION")
fi

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Client ID: $CLIENT_ID"
echo "Agent ARN: $AGENT_ARN"
echo "Memory ID: $MEMORY_ID"
echo "Memory Type: $MEMORY_TYPE"
echo ""
echo "Test Credentials:"
echo "  Username: testuser"
echo "  Password: MyPassword123!"
echo ""

if [ "$ADVANCED_MEMORY" = "true" ]; then
    echo "🧠 Advanced Memory Configuration:"
    echo "  • User preferences will be automatically extracted"
    echo "  • Conversation summaries will be generated"
    echo "  • Memory organized in structured namespaces"
    echo "  • Long-term retention with $MEMORY_EXPIRY_DAYS day expiry"
    echo ""
fi
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "Test your MCP server:"
echo "  ./test.sh $STACK_NAME $REGION"
echo ""
