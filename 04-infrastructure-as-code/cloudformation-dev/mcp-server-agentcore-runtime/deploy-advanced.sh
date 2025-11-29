#!/bin/bash
# Advanced Memory Deployment Script for MCP Server on AgentCore Runtime
# This script deploys MCP Server with AI-powered memory strategies
#
# Usage:
#   ./deploy-advanced.sh STACK_NAME [REGION] [LLM_MODEL] [MEMORY_EXPIRY_DAYS]
#
# Examples:
#   ./deploy-advanced.sh my-smart-agent
#   ./deploy-advanced.sh my-smart-agent us-east-1
#   ./deploy-advanced.sh my-smart-agent us-west-2 anthropic.claude-3-5-sonnet-20241022-v2:0 90

set -e

# Check if stack name is provided
if [ -z "$1" ]; then
    echo "❌ Error: Stack name is required"
    echo ""
    echo "Usage: ./deploy-advanced.sh STACK_NAME [REGION] [LLM_MODEL] [MEMORY_EXPIRY_DAYS]"
    echo ""
    echo "Examples:"
    echo "  ./deploy-advanced.sh my-smart-agent"
    echo "  ./deploy-advanced.sh my-smart-agent us-east-1"
    echo "  ./deploy-advanced.sh my-smart-agent us-west-2 anthropic.claude-3-5-sonnet-20241022-v2:0 90"
    exit 1
fi

STACK_NAME="$1"
REGION="${2:-us-west-2}"
LLM_MODEL="${3:-anthropic.claude-3-5-sonnet-20241022-v2:0}"
MEMORY_EXPIRY_DAYS="${4:-30}"

# Validate memory expiry days
if ! [[ "$MEMORY_EXPIRY_DAYS" =~ ^[0-9]+$ ]] || [ "$MEMORY_EXPIRY_DAYS" -lt 1 ] || [ "$MEMORY_EXPIRY_DAYS" -gt 365 ]; then
    echo "❌ Error: MEMORY_EXPIRY_DAYS must be a number between 1 and 365"
    exit 1
fi

echo "=========================================="
echo "🚀 Advanced Memory MCP Server Deployment"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "LLM Model: $LLM_MODEL"
echo "Memory Expiry Days: $MEMORY_EXPIRY_DAYS"
echo ""
echo "🧠 Advanced Memory Features:"
echo "  • AI-powered user preference extraction"
echo "  • Intelligent conversation summarization"
echo "  • Long-term memory strategies"
echo "  • Structured namespace organization"
echo ""

# Phase 1: Deploy Infrastructure
echo "📦 Phase 1: Deploying Infrastructure (~10 minutes)..."
echo "  • ECR Repository & Docker Build"
echo "  • Cognito Authentication"
echo "  • IAM Roles & Policies"
echo ""

aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://mcp-server-template.yaml \
  --parameters \
    ParameterKey=LLMModel,ParameterValue="$LLM_MODEL" \
    ParameterKey=EnableAdvancedMemory,ParameterValue="false" \
    ParameterKey=MemoryEventExpiryDays,ParameterValue="$MEMORY_EXPIRY_DAYS" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

echo "⏳ Waiting for infrastructure deployment to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name "$STACK_NAME" \
  --region "$REGION"

echo "✅ Infrastructure deployment complete!"
echo ""

# Phase 2: Create Advanced Memory
echo "🧠 Phase 2: Creating Advanced Memory with AI Strategies (~3 minutes)..."
MEMORY_NAME="${STACK_NAME//-/_}_MCPServerMemory"
python3 create-advanced-memory.py "$STACK_NAME" "$REGION" "$MEMORY_NAME" "$MEMORY_EXPIRY_DAYS"

if [ $? -ne 0 ]; then
    echo "❌ Advanced memory creation failed"
    echo "   Please check the error above and try again"
    exit 1
fi

echo "✅ Advanced memory created successfully!"
echo ""

# Phase 3: Deploy MCP Server Runtime
echo "🚀 Phase 3: Deploying MCP Server Runtime (~2 minutes)..."

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

MEMORY_ID=$(aws ssm get-parameter \
  --name "/bedrock-agentcore/$STACK_NAME/advanced-memory-id" \
  --query 'Parameter.Value' \
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
    ParameterKey=MemoryId,ParameterValue="$MEMORY_ID" \
    ParameterKey=AdvancedMemoryEnabled,ParameterValue="true" \
  --region "$REGION"

echo "⏳ Waiting for runtime deployment to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name "$STACK_NAME-runtime" \
  --region "$REGION"

echo "✅ Runtime deployment complete!"
echo ""

# Get final outputs
AGENT_ARN=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME-runtime" \
  --query 'Stacks[0].Outputs[?OutputKey==`MCPServerRuntimeArn`].OutputValue' \
  --output text \
  --region "$REGION")

echo ""
echo "=========================================="
echo "🎉 Advanced Memory Deployment Complete!"
echo "=========================================="
echo ""
echo "📋 Deployment Summary:"
echo "  Stack Name: $STACK_NAME"
echo "  Region: $REGION"
echo "  Client ID: $CLIENT_ID"
echo "  Agent ARN: $AGENT_ARN"
echo "  Memory ID: $MEMORY_ID"
echo "  Memory Type: Advanced (with AI strategies)"
echo ""
echo "🧠 Advanced Memory Features Active:"
echo "  • User preference extraction"
echo "  • Conversation summarization"
echo "  • Long-term memory strategies"
echo "  • Structured namespace organization"
echo ""
echo "🧪 Next Steps:"
echo "  1. Test everything: ./test.sh $STACK_NAME $REGION"
echo "  2. Check AWS Console for memory strategies"
echo "  3. Start using your intelligent MCP server!"
echo ""
echo "Test Credentials:"
echo "  Username: testuser"
echo "  Password: MyPassword123!"