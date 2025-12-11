#!/bin/bash
# Standalone memory testing script for MCP Server
# This script focuses only on memory functionality testing

set -e

STACK_NAME="${1:-mcp-server-demo}"
REGION="${2:-us-west-2}"

echo "=========================================="
echo "🧠 MCP Server Memory Testing"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo ""

# Get stack outputs
echo "📋 Retrieving stack configuration..."
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

if [ -z "$CLIENT_ID" ] || [ -z "$AGENT_ARN" ] || [ -z "$MEMORY_ID" ]; then
  echo "❌ Error: Could not retrieve stack outputs"
  echo "   Make sure the stack '$STACK_NAME' exists in region '$REGION'"
  exit 1
fi

echo "✓ Configuration retrieved"
echo "  Memory ID: $MEMORY_ID"
echo "  Memory Type: $MEMORY_TYPE"
echo ""

# Get authentication token
echo "🔐 Getting authentication token..."
TOKEN_OUTPUT=$(python get_token.py "$CLIENT_ID" testuser MyPassword123! "$REGION" 2>&1)

# Extract token from output (it's the line after "Access Token:")
JWT_TOKEN=$(echo "$TOKEN_OUTPUT" | grep -A 1 "Access Token:" | tail -n 1 | tr -d '[:space:]')

if [ -z "$JWT_TOKEN" ]; then
  echo "❌ Error: Could not get authentication token"
  echo "$TOKEN_OUTPUT"
  exit 1
fi

echo "✓ Authentication successful"
echo ""

# Check if advanced memory is enabled
if [[ "$MEMORY_TYPE" == *"Advanced"* ]]; then
  echo "🧠 Advanced Memory Features Detected:"
  echo "  • User preference extraction"
  echo "  • Conversation summarization"
  echo "  • Long-term memory strategies"
  echo ""
else
  echo "💾 Basic Memory Features Detected:"
  echo "  • Simple conversation storage"
  echo "  • Basic event logging"
  echo ""
fi

# Test memory functionality
echo "🧪 Running comprehensive memory tests..."
echo ""
python test_memory.py "$AGENT_ARN" "$JWT_TOKEN" "$REGION" "$STACK_NAME"

echo ""
echo "=========================================="
echo "✅ Memory Testing Complete!"
echo "=========================================="

# Provide memory usage tips
echo ""
echo "💡 Memory Usage Tips:"
if [[ "$MEMORY_TYPE" == *"Advanced"* ]]; then
  echo "  • Your advanced memory will automatically extract user preferences"
  echo "  • Conversations are summarized for long-term retention"
  echo "  • Use structured queries to retrieve specific memories"
  echo "  • Memory is organized in namespaces for better organization"
else
  echo "  • Your basic memory stores conversation events"
  echo "  • Use actor_id and session_id to organize conversations"
  echo "  • Consider upgrading to advanced memory for AI-powered features"
fi
echo ""
echo "📚 For more information, see MEMORY_GUIDE.md"