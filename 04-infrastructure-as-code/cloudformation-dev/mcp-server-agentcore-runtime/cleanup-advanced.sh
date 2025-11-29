#!/bin/bash
# Advanced Memory Cleanup Script for MCP Server on AgentCore Runtime
# This script handles the complete cleanup of advanced memory deployments
#
# Usage:
#   ./cleanup-advanced.sh STACK_NAME [REGION]
#
# Examples:
#   ./cleanup-advanced.sh my-smart-agent
#   ./cleanup-advanced.sh my-smart-agent us-west-2

set -e

# Check if stack name is provided
if [ -z "$1" ]; then
    echo "❌ Error: Stack name is required"
    echo ""
    echo "Usage: ./cleanup-advanced.sh STACK_NAME [REGION]"
    echo ""
    echo "Examples:"
    echo "  ./cleanup-advanced.sh my-smart-agent"
    echo "  ./cleanup-advanced.sh my-smart-agent us-west-2"
    exit 1
fi

STACK_NAME="$1"
REGION="${2:-us-west-2}"

echo "=========================================="
echo "🧹 Advanced Memory Cleanup"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo ""
echo "⚠️  This will delete:"
echo "  • Runtime stack ($STACK_NAME-runtime)"
echo "  • Advanced memory (via Python SDK)"
echo "  • Main infrastructure stack ($STACK_NAME)"
echo "  • SSM parameters"
echo ""

# Confirmation prompt
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

echo ""
echo "🔄 Starting advanced memory cleanup process..."
echo ""

# Step 1: Check if runtime stack exists and delete it
echo "📦 Step 1: Checking runtime stack..."
if aws cloudformation describe-stacks --stack-name "$STACK_NAME-runtime" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ Runtime stack found: $STACK_NAME-runtime"
    echo "🗑️  Deleting runtime stack..."
    
    aws cloudformation delete-stack \
        --stack-name "$STACK_NAME-runtime" \
        --region "$REGION"
    
    echo "⏳ Waiting for runtime stack deletion to complete..."
    aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK_NAME-runtime" \
        --region "$REGION"
    
    echo "✅ Runtime stack deleted successfully"
else
    echo "ℹ️  Runtime stack not found (may have been deleted already)"
fi

echo ""

# Step 2: Get memory ID and delete advanced memory
echo "🧠 Step 2: Deleting advanced memory..."

# Try to get memory ID from SSM parameter
MEMORY_ID=""
if aws ssm get-parameter --name "/bedrock-agentcore/$STACK_NAME/advanced-memory-id" --region "$REGION" >/dev/null 2>&1; then
    MEMORY_ID=$(aws ssm get-parameter \
        --name "/bedrock-agentcore/$STACK_NAME/advanced-memory-id" \
        --query 'Parameter.Value' \
        --output text \
        --region "$REGION")
    echo "✅ Found memory ID in SSM: $MEMORY_ID"
else
    echo "⚠️  Memory ID not found in SSM parameter store"
    echo "   Attempting to find memory by name pattern..."
    
    # Try to find memory by name pattern
    MEMORY_NAME="${STACK_NAME//-/_}_MCPServerMemory"
    python3 -c "
import boto3
from bedrock_agentcore.memory import MemoryClient

try:
    client = MemoryClient(region_name='$REGION')
    memories = client.list_memories()
    
    for memory in memories:
        if '$MEMORY_NAME' in memory.get('memoryId', ''):
            print(memory['memoryId'])
            break
    else:
        print('NOT_FOUND')
except Exception as e:
    print('ERROR')
" > /tmp/memory_search_result

    SEARCH_RESULT=$(cat /tmp/memory_search_result)
    rm -f /tmp/memory_search_result
    
    if [ "$SEARCH_RESULT" = "NOT_FOUND" ] || [ "$SEARCH_RESULT" = "ERROR" ]; then
        echo "⚠️  Could not find advanced memory automatically"
        echo "   You may need to delete it manually from AWS Console"
    else
        MEMORY_ID="$SEARCH_RESULT"
        echo "✅ Found memory by pattern: $MEMORY_ID"
    fi
fi

# Delete memory if found
if [ -n "$MEMORY_ID" ] && [ "$MEMORY_ID" != "NOT_FOUND" ] && [ "$MEMORY_ID" != "ERROR" ]; then
    echo "🗑️  Deleting advanced memory: $MEMORY_ID"
    
    python3 -c "
from bedrock_agentcore.memory import MemoryClient
import sys

try:
    client = MemoryClient(region_name='$REGION')
    client.delete_memory_and_wait('$MEMORY_ID', max_wait=300)
    print('✅ Memory deleted successfully')
except Exception as e:
    print(f'❌ Error deleting memory: {e}')
    sys.exit(1)
"
    
    if [ $? -eq 0 ]; then
        echo "✅ Advanced memory deleted successfully"
    else
        echo "❌ Failed to delete advanced memory"
        echo "   Please delete manually from AWS Console"
    fi
else
    echo "ℹ️  No advanced memory found to delete"
fi

echo ""

# Step 3: Delete main infrastructure stack
echo "🏗️  Step 3: Deleting main infrastructure stack..."
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ Main stack found: $STACK_NAME"
    echo "🗑️  Deleting main stack..."
    
    aws cloudformation delete-stack \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    echo "⏳ Waiting for main stack deletion to complete..."
    aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    echo "✅ Main stack deleted successfully"
else
    echo "ℹ️  Main stack not found (may have been deleted already)"
fi

echo ""

# Step 4: Clean up SSM parameters
echo "🔧 Step 4: Cleaning up SSM parameters..."
if aws ssm get-parameter --name "/bedrock-agentcore/$STACK_NAME/advanced-memory-id" --region "$REGION" >/dev/null 2>&1; then
    echo "🗑️  Deleting SSM parameter..."
    aws ssm delete-parameter \
        --name "/bedrock-agentcore/$STACK_NAME/advanced-memory-id" \
        --region "$REGION"
    echo "✅ SSM parameter deleted"
else
    echo "ℹ️  SSM parameter not found (may have been deleted already)"
fi

echo ""

# Step 5: Verification
echo "🔍 Step 5: Verifying cleanup..."

# Check stacks
echo "📦 Checking remaining stacks..."
REMAINING_STACKS=$(aws cloudformation list-stacks \
    --region "$REGION" \
    --query "StackSummaries[?StackStatus!='DELETE_COMPLETE' && (StackName=='$STACK_NAME' || StackName=='$STACK_NAME-runtime')].StackName" \
    --output text)

if [ -z "$REMAINING_STACKS" ]; then
    echo "✅ No remaining stacks found"
else
    echo "⚠️  Remaining stacks: $REMAINING_STACKS"
fi

# Check memories
echo "🧠 Checking remaining memories..."
python3 -c "
from bedrock_agentcore.memory import MemoryClient

try:
    client = MemoryClient(region_name='$REGION')
    memories = client.list_memories()
    
    stack_memories = []
    for memory in memories:
        memory_id = memory.get('memoryId', '')
        if '$STACK_NAME' in memory_id or '${STACK_NAME//-/_}' in memory_id:
            stack_memories.append(memory_id)
    
    if stack_memories:
        print(f'⚠️  Remaining memories: {len(stack_memories)}')
        for memory_id in stack_memories:
            print(f'   - {memory_id}')
    else:
        print('✅ No remaining memories found')
        
except Exception as e:
    print(f'⚠️  Could not check memories: {e}')
"

# Check SSM parameters
echo "🔧 Checking remaining SSM parameters..."
REMAINING_PARAMS=$(aws ssm describe-parameters \
    --region "$REGION" \
    --query "Parameters[?contains(Name, '/bedrock-agentcore/$STACK_NAME/')].Name" \
    --output text)

if [ -z "$REMAINING_PARAMS" ]; then
    echo "✅ No remaining SSM parameters found"
else
    echo "⚠️  Remaining SSM parameters: $REMAINING_PARAMS"
fi

echo ""
echo "=========================================="
echo "🎉 Advanced Memory Cleanup Complete!"
echo "=========================================="
echo ""
echo "📋 Cleanup Summary:"
echo "  Stack Name: $STACK_NAME"
echo "  Region: $REGION"
echo "  Runtime Stack: Deleted"
echo "  Advanced Memory: Deleted"
echo "  Main Stack: Deleted"
echo "  SSM Parameters: Cleaned up"
echo ""

if [ -n "$REMAINING_STACKS" ] || [ -n "$REMAINING_PARAMS" ]; then
    echo "⚠️  Some resources may still exist:"
    echo "   Please check AWS Console for any remaining resources"
    echo "   You may need to delete them manually"
    echo ""
fi

echo "✅ Advanced memory deployment cleanup completed!"
echo ""
echo "💡 To deploy again:"
echo "   ./deploy-advanced.sh $STACK_NAME $REGION"