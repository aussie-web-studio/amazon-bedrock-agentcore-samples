#!/bin/bash
# Smart Cleanup Script for MCP Server Deployments
# Automatically detects deployment type and calls appropriate cleanup script
#
# Usage:
#   ./cleanup.sh STACK_NAME [REGION]
#
# Examples:
#   ./cleanup.sh my-agent
#   ./cleanup.sh my-agent us-west-2

set -e

# Check if stack name is provided
if [ -z "$1" ]; then
    echo "❌ Error: Stack name is required"
    echo ""
    echo "Usage: ./cleanup.sh STACK_NAME [REGION]"
    echo ""
    echo "Examples:"
    echo "  ./cleanup.sh my-agent"
    echo "  ./cleanup.sh my-agent us-west-2"
    echo ""
    echo "💡 This script automatically detects your deployment type:"
    echo "   • Advanced Memory: Uses cleanup-advanced.sh"
    echo "   • Basic Memory: Uses cleanup-basic.sh"
    exit 1
fi

STACK_NAME="$1"
REGION="${2:-us-west-2}"

echo "=========================================="
echo "🔍 Smart MCP Server Cleanup"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo ""
echo "🔄 Detecting deployment type..."

# Check for advanced memory deployment indicators
ADVANCED_DEPLOYMENT=false

# Check 1: Runtime stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME-runtime" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ Found runtime stack: $STACK_NAME-runtime"
    ADVANCED_DEPLOYMENT=true
fi

# Check 2: SSM parameter exists
if aws ssm get-parameter --name "/bedrock-agentcore/$STACK_NAME/advanced-memory-id" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ Found SSM parameter for advanced memory"
    ADVANCED_DEPLOYMENT=true
fi

# Check 3: Advanced memory exists
if [ "$ADVANCED_DEPLOYMENT" = false ]; then
    MEMORY_NAME="${STACK_NAME//-/_}_MCPServerMemory"
    MEMORY_CHECK=$(python3 -c "
from bedrock_agentcore.memory import MemoryClient
try:
    client = MemoryClient(region_name='$REGION')
    memories = client.list_memories()
    for memory in memories:
        if '$MEMORY_NAME' in memory.get('memoryId', ''):
            print('FOUND')
            break
    else:
        print('NOT_FOUND')
except:
    print('ERROR')
" 2>/dev/null || echo "ERROR")
    
    if [ "$MEMORY_CHECK" = "FOUND" ]; then
        echo "✅ Found advanced memory by pattern"
        ADVANCED_DEPLOYMENT=true
    fi
fi

echo ""

# Route to appropriate cleanup script
if [ "$ADVANCED_DEPLOYMENT" = true ]; then
    echo "🧠 Detected: Advanced Memory Deployment"
    echo "   Routing to specialized advanced cleanup..."
    echo ""
    
    if [ -f "./cleanup-advanced.sh" ]; then
        ./cleanup-advanced.sh "$STACK_NAME" "$REGION"
    else
        echo "❌ Error: cleanup-advanced.sh not found"
        echo "   Please ensure all cleanup scripts are in the same directory"
        exit 1
    fi
else
    echo "💾 Detected: Basic Memory Deployment"
    echo "   Routing to specialized basic cleanup..."
    echo ""
    
    if [ -f "./cleanup-basic.sh" ]; then
        ./cleanup-basic.sh "$STACK_NAME" "$REGION"
    else
        echo "❌ Error: cleanup-basic.sh not found"
        echo "   Please ensure all cleanup scripts are in the same directory"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "🎉 Smart Cleanup Complete!"
echo "=========================================="
echo ""
echo "📋 Summary:"
echo "  Stack Name: $STACK_NAME"
echo "  Region: $REGION"
echo "  Deployment Type: $([ "$ADVANCED_DEPLOYMENT" = true ] && echo "Advanced Memory" || echo "Basic Memory")"
echo "  Status: Successfully cleaned up"
echo ""
echo "💡 To deploy again:"
if [ "$ADVANCED_DEPLOYMENT" = true ]; then
    echo "   ./deploy-advanced.sh $STACK_NAME $REGION"
else
    echo "   ./deploy-basic.sh $STACK_NAME $REGION"
fi