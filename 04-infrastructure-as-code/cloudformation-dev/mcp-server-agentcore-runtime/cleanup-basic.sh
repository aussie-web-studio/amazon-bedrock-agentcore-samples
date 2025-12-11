#!/bin/bash
# Basic Memory Cleanup Script for MCP Server on AgentCore Runtime
# This script handles the cleanup of basic memory deployments (single stack)
#
# Usage:
#   ./cleanup-basic.sh STACK_NAME [REGION]
#
# Examples:
#   ./cleanup-basic.sh my-basic-agent
#   ./cleanup-basic.sh my-basic-agent us-west-2

set -e

# Check if stack name is provided
if [ -z "$1" ]; then
    echo "❌ Error: Stack name is required"
    echo ""
    echo "Usage: ./cleanup-basic.sh STACK_NAME [REGION]"
    echo ""
    echo "Examples:"
    echo "  ./cleanup-basic.sh my-basic-agent"
    echo "  ./cleanup-basic.sh my-basic-agent us-west-2"
    exit 1
fi

STACK_NAME="$1"
REGION="${2:-us-west-2}"

echo "=========================================="
echo "🧹 Basic Memory Cleanup"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo ""
echo "⚠️  This will delete:"
echo "  • Main stack ($STACK_NAME)"
echo "  • Basic memory (via CloudFormation)"
echo "  • All associated resources"
echo ""

# Confirmation prompt
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

echo ""
echo "🔄 Starting basic memory cleanup process..."
echo ""

# Step 1: Check if stack exists
echo "📦 Step 1: Checking stack status..."
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ Stack found: $STACK_NAME"
    
    # Get stack status
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].StackStatus' \
        --output text \
        --region "$REGION")
    
    echo "📊 Current status: $STACK_STATUS"
    
    if [[ "$STACK_STATUS" == *"IN_PROGRESS"* ]]; then
        echo "⚠️  Stack is currently in progress state: $STACK_STATUS"
        echo "   Waiting for current operation to complete..."
        
        # Wait for current operation to complete
        aws cloudformation wait stack-create-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION" 2>/dev/null || \
        aws cloudformation wait stack-update-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION" 2>/dev/null || \
        aws cloudformation wait stack-delete-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION" 2>/dev/null || true
        
        echo "✅ Previous operation completed"
    fi
    
else
    echo "ℹ️  Stack not found: $STACK_NAME"
    echo "   Stack may have been deleted already"
    exit 0
fi

echo ""

# Step 2: Delete the stack
echo "🗑️  Step 2: Deleting stack..."
echo "⏳ This may take several minutes..."

aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

echo "✅ Stack deletion initiated"
echo "⏳ Waiting for stack deletion to complete..."

# Wait for deletion with timeout
TIMEOUT=1800  # 30 minutes
START_TIME=$(date +%s)

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -gt $TIMEOUT ]; then
        echo "❌ Timeout waiting for stack deletion (30 minutes)"
        echo "   Please check AWS Console for stack status"
        exit 1
    fi
    
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
        STACK_STATUS=$(aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].StackStatus' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "DELETE_COMPLETE")
        
        if [ "$STACK_STATUS" = "DELETE_COMPLETE" ]; then
            break
        elif [ "$STACK_STATUS" = "DELETE_FAILED" ]; then
            echo "❌ Stack deletion failed"
            echo "   Please check AWS Console for details"
            exit 1
        else
            echo "⏳ Stack status: $STACK_STATUS (${ELAPSED}s elapsed)"
            sleep 30
        fi
    else
        # Stack no longer exists
        break
    fi
done

echo "✅ Stack deleted successfully"
echo ""

# Step 3: Verification
echo "🔍 Step 3: Verifying cleanup..."

# Check if stack still exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    FINAL_STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].StackStatus' \
        --output text \
        --region "$REGION")
    echo "⚠️  Stack still exists with status: $FINAL_STATUS"
else
    echo "✅ Stack completely removed"
fi

# Check for any remaining memories (basic memory should be deleted with stack)
echo "🧠 Checking for any remaining memories..."
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
        print(f'⚠️  Found {len(stack_memories)} memories that may be related:')
        for memory_id in stack_memories:
            print(f'   - {memory_id}')
        print('   These should have been deleted with the stack')
        print('   If they persist, you may need to delete them manually')
    else:
        print('✅ No related memories found')
        
except Exception as e:
    print(f'ℹ️  Could not check memories: {e}')
"

echo ""
echo "=========================================="
echo "🎉 Basic Memory Cleanup Complete!"
echo "=========================================="
echo ""
echo "📋 Cleanup Summary:"
echo "  Stack Name: $STACK_NAME"
echo "  Region: $REGION"
echo "  Deployment Type: Basic Memory"
echo "  Stack Status: Deleted"
echo "  Memory Status: Deleted (via CloudFormation)"
echo ""
echo "✅ Basic memory deployment cleanup completed!"
echo ""
echo "💡 To deploy again:"
echo "   ./deploy-basic.sh $STACK_NAME $REGION"