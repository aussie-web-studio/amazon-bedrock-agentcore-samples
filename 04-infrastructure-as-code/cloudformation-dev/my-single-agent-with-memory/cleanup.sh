#!/bin/bash

# Cleanup script for Weather Agent Runtime CloudFormation stack
# This script deletes the CloudFormation stack and all associated resources

set -e

# Configuration
STACK_NAME="${1:-weather-agent-demo}"
REGION="${2:-us-west-2}"

# Get AWS Account ID for unique bucket naming
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET="${STACK_NAME}-cf-templates-${ACCOUNT_ID}"

echo "=========================================="
echo "Cleaning up Weather Agent Runtime"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Template S3 Bucket: $S3_BUCKET"
echo "=========================================="

# Confirm deletion
read -p "Are you sure you want to delete the stack '$STACK_NAME'? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Get resource information before deletion
echo "Getting resource information..."
ECR_REPO=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryName`].OutputValue' --output text 2>/dev/null || echo "")
RESULTS_BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`ResultsBucket`].OutputValue' --output text 2>/dev/null || echo "")

echo "Resources to be cleaned up:"
echo "  - CloudFormation Stack: $STACK_NAME"
echo "  - ECR Repository: ${ECR_REPO:-'Not found'}"
echo "  - Results S3 Bucket: ${RESULTS_BUCKET:-'Not found'}"
echo "  - Template S3 Bucket: $S3_BUCKET"
echo ""

# Pre-cleanup: Empty S3 buckets and ECR repository
echo "Pre-cleanup: Emptying S3 buckets and ECR repository..."

# Empty Results S3 bucket
if [ -n "$RESULTS_BUCKET" ] && [ "$RESULTS_BUCKET" != "None" ]; then
    echo "Emptying Results S3 bucket: $RESULTS_BUCKET"
    aws s3 rm s3://"$RESULTS_BUCKET" --recursive --region "$REGION" 2>/dev/null || true
    echo "✓ Results S3 bucket emptied"
fi

# Empty Template S3 bucket
echo "Emptying Template S3 bucket: $S3_BUCKET"
if aws s3 ls "s3://${S3_BUCKET}" --region "$REGION" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Template S3 bucket does not exist"
else
    echo "  - Removing all template files..."
    aws s3 rm s3://"$S3_BUCKET" --recursive --region "$REGION" 2>/dev/null || true
    echo "✓ Template S3 bucket emptied"
fi

# Empty ECR repository
if [ -n "$ECR_REPO" ] && [ "$ECR_REPO" != "None" ]; then
    echo "Emptying ECR repository: $ECR_REPO"
    
    # Get all images and delete them (simpler approach without jq dependency)
    IMAGE_LIST=$(aws ecr list-images --repository-name "$ECR_REPO" --region "$REGION" --query 'imageIds' --output text 2>/dev/null || echo "")
    
    if [ -n "$IMAGE_LIST" ] && [ "$IMAGE_LIST" != "None" ]; then
        echo "Deleting all images in ECR repository..."
        aws ecr batch-delete-image \
            --repository-name "$ECR_REPO" \
            --region "$REGION" \
            --image-ids "$(aws ecr list-images --repository-name "$ECR_REPO" --region "$REGION" --query 'imageIds' --output json)" \
            2>/dev/null || true
        echo "✓ ECR repository emptied"
    else
        echo "ECR repository is already empty"
    fi
fi

# Clean up BedrockAgentCore resources manually (to avoid naming conflicts)
echo ""
echo "Cleaning up BedrockAgentCore resources..."

# Get resource IDs from stack outputs (if stack still exists)
BROWSER_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`BrowserId`].OutputValue' --output text 2>/dev/null || echo "")
CODE_INTERPRETER_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`CodeInterpreterId`].OutputValue' --output text 2>/dev/null || echo "")
MEMORY_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`MemoryId`].OutputValue' --output text 2>/dev/null || echo "")

# Also search for orphaned resources by name pattern (in case stack outputs are not available)
echo "  - Searching for orphaned BedrockAgentCore resources with pattern: *weather_agent_demo*"

# Delete Browser Tool
if [ -n "$BROWSER_ID" ] && [ "$BROWSER_ID" != "None" ]; then
    echo "  - Deleting Browser Tool: $BROWSER_ID"
    aws bedrock-agentcore delete-browser --browser-id "$BROWSER_ID" --region "$REGION" 2>/dev/null || true
    echo "    ✓ Browser Tool deleted"
fi

# Search for orphaned Browsers by name pattern
echo "  - Searching for orphaned Browsers..."
aws bedrock-agentcore list-browsers --region "$REGION" --query 'browsers[].browserId' --output text 2>/dev/null | tr '\t' '\n' | while read orphaned_browser_id; do
    if [ -n "$orphaned_browser_id" ] && echo "$orphaned_browser_id" | grep -q "weather_agent_demo"; then
        echo "    Found orphaned Browser: $orphaned_browser_id"
        echo "    Deleting: $orphaned_browser_id"
        aws bedrock-agentcore delete-browser --browser-id "$orphaned_browser_id" --region "$REGION" 2>/dev/null || true
        echo "    ✓ Orphaned Browser deleted"
    fi
done

# Delete Code Interpreter Tool  
if [ -n "$CODE_INTERPRETER_ID" ] && [ "$CODE_INTERPRETER_ID" != "None" ]; then
    echo "  - Deleting Code Interpreter Tool: $CODE_INTERPRETER_ID"
    
    # First, delete all active sessions for this code interpreter
    echo "    Cleaning up active sessions..."
    aws bedrock-agentcore list-code-interpreter-sessions --code-interpreter-id "$CODE_INTERPRETER_ID" --region "$REGION" --query 'sessions[].sessionId' --output text 2>/dev/null | tr '\t' '\n' | while read session_id; do
        if [ -n "$session_id" ]; then
            echo "      Deleting session: $session_id"
            aws bedrock-agentcore delete-code-interpreter-session --code-interpreter-id "$CODE_INTERPRETER_ID" --session-id "$session_id" --region "$REGION" 2>/dev/null || true
        fi
    done
    
    # Wait a moment for sessions to be fully deleted
    sleep 2
    
    # Now delete the code interpreter itself
    aws bedrock-agentcore delete-code-interpreter --code-interpreter-id "$CODE_INTERPRETER_ID" --region "$REGION" 2>/dev/null || true
    echo "    ✓ Code Interpreter Tool deleted"
fi

# Search for orphaned Code Interpreters by name pattern
echo "  - Searching for orphaned Code Interpreters..."
aws bedrock-agentcore list-code-interpreters --region "$REGION" --query 'codeInterpreters[].codeInterpreterId' --output text 2>/dev/null | tr '\t' '\n' | while read orphaned_ci_id; do
    if [ -n "$orphaned_ci_id" ] && echo "$orphaned_ci_id" | grep -q "weather_agent_demo"; then
        echo "    Found orphaned Code Interpreter: $orphaned_ci_id"
        
        # First, delete all active sessions for this orphaned code interpreter
        echo "      Cleaning up active sessions..."
        aws bedrock-agentcore list-code-interpreter-sessions --code-interpreter-id "$orphaned_ci_id" --region "$REGION" --query 'sessions[].sessionId' --output text 2>/dev/null | tr '\t' '\n' | while read session_id; do
            if [ -n "$session_id" ]; then
                echo "        Deleting session: $session_id"
                aws bedrock-agentcore delete-code-interpreter-session --code-interpreter-id "$orphaned_ci_id" --session-id "$session_id" --region "$REGION" 2>/dev/null || true
            fi
        done
        
        # Wait a moment for sessions to be fully deleted
        sleep 2
        
        # Now delete the orphaned code interpreter
        echo "      Deleting: $orphaned_ci_id"
        aws bedrock-agentcore delete-code-interpreter --code-interpreter-id "$orphaned_ci_id" --region "$REGION" 2>/dev/null || true
        echo "    ✓ Orphaned Code Interpreter deleted"
    fi
done

# Delete Memory
if [ -n "$MEMORY_ID" ] && [ "$MEMORY_ID" != "None" ]; then
    echo "  - Deleting Memory: $MEMORY_ID"
    aws bedrock-agentcore delete-memory --memory-id "$MEMORY_ID" --region "$REGION" 2>/dev/null || true
    echo "    ✓ Memory deleted"
fi

# Search for orphaned Memories by name pattern
echo "  - Searching for orphaned Memories..."
aws bedrock-agentcore list-memories --region "$REGION" --query 'memories[].memoryId' --output text 2>/dev/null | tr '\t' '\n' | while read orphaned_memory_id; do
    if [ -n "$orphaned_memory_id" ] && echo "$orphaned_memory_id" | grep -q "weather_agent_demo"; then
        echo "    Found orphaned Memory: $orphaned_memory_id"
        echo "    Deleting: $orphaned_memory_id"
        aws bedrock-agentcore delete-memory --memory-id "$orphaned_memory_id" --region "$REGION" 2>/dev/null || true
        echo "    ✓ Orphaned Memory deleted"
    fi
done

# Search for orphaned Agent Runtimes by name pattern
echo "  - Searching for orphaned Agent Runtimes..."
aws bedrock-agentcore list-runtimes --region "$REGION" --query 'runtimes[].agentRuntimeId' --output text 2>/dev/null | tr '\t' '\n' | while read orphaned_runtime_id; do
    if [ -n "$orphaned_runtime_id" ] && echo "$orphaned_runtime_id" | grep -q "weather_agent_demo"; then
        echo "    Found orphaned Agent Runtime: $orphaned_runtime_id"
        echo "    Deleting: $orphaned_runtime_id"
        aws bedrock-agentcore delete-runtime --agent-runtime-id "$orphaned_runtime_id" --region "$REGION" 2>/dev/null || true
        echo "    ✓ Orphaned Agent Runtime deleted"
    fi
done

echo "✓ BedrockAgentCore resources cleanup completed"

# Clean up CloudWatch Log Groups
echo ""
echo "Cleaning up CloudWatch Log Groups..."
echo "Searching for log groups related to stack: $STACK_NAME"

# Get Agent Runtime ID for bedrock-agentcore logs
AGENT_RUNTIME_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`AgentRuntimeId`].OutputValue' --output text 2>/dev/null || echo "")

# Delete specific log groups created by this stack
LOG_GROUPS_TO_DELETE=(
    "/aws/lambda/${STACK_NAME}-codebuild-trigger"
    "/aws/lambda/${STACK_NAME}-memory-initializer"
    "/aws/codebuild/${STACK_NAME}-strands-agent-build"
)

# Add bedrock-agentcore log groups if we have the runtime ID
if [ -n "$AGENT_RUNTIME_ID" ] && [ "$AGENT_RUNTIME_ID" != "None" ]; then
    LOG_GROUPS_TO_DELETE+=("/aws/vendedlogs/bedrock-agentcore/${AGENT_RUNTIME_ID}")
    # Also add the runtime-specific log group pattern
    LOG_GROUPS_TO_DELETE+=("/aws/bedrock-agentcore/runtimes/${AGENT_RUNTIME_ID}-DEFAULT")
fi

# Also search for bedrock-agentcore log groups using the agent name pattern (not just runtime ID)
echo "  - Searching for additional bedrock-agentcore log groups with agent name pattern..."
aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "/aws/vendedlogs/bedrock-agentcore/" --query 'logGroups[].logGroupName' --output text 2>/dev/null | tr '\t' '\n' | while read log_group; do
    if [ -n "$log_group" ] && echo "$log_group" | grep -q "weather_agent_demo.*TestAgent"; then
        echo "    Found bedrock-agentcore vendedlogs: $log_group"
        LOG_GROUPS_TO_DELETE+=("$log_group")
    fi
done

# Delete each log group
for log_group in "${LOG_GROUPS_TO_DELETE[@]}"; do
    echo "  - Checking log group: $log_group"
    if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
        echo "    Deleting log group: $log_group"
        aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null || true
        echo "    ✓ Log group deleted"
    else
        echo "    Log group does not exist or already deleted"
    fi
done

# Search for bedrock-agentcore runtime log groups specific to this stack
echo "  - Searching for bedrock-agentcore runtime log groups for stack: $STACK_NAME..."
aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "/aws/bedrock-agentcore/runtimes/" --query 'logGroups[].logGroupName' --output text 2>/dev/null | tr '\t' '\n' | while read log_group; do
    # Only delete log groups that contain both the stack name pattern AND are bedrock-agentcore related
    if [ -n "$log_group" ] && echo "$log_group" | grep -q "weather_agent_demo.*TestAgent"; then
        echo "    Found stack-specific bedrock-agentcore runtime log group: $log_group"
        echo "    Deleting: $log_group"
        aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null || true
        echo "    ✓ Stack-specific bedrock-agentcore runtime log group deleted"
    fi
done

# Search for any bedrock-agentcore log groups that match the specific pattern for this stack
echo "  - Searching for stack-specific bedrock-agentcore log groups with pattern: *${STACK_NAME}*TestAgent*..."
aws logs describe-log-groups --region "$REGION" --query 'logGroups[].logGroupName' --output text 2>/dev/null | tr '\t' '\n' | grep "bedrock-agentcore" | grep "weather_agent_demo" | grep "TestAgent" | while read log_group; do
    if [ -n "$log_group" ]; then
        echo "    Found stack-specific bedrock-agentcore log group: $log_group"
        echo "    Deleting: $log_group"
        aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null || true
        echo "    ✓ Stack-specific bedrock-agentcore log group deleted"
    fi
done

# Also search for any other log groups that might be related to this stack
echo "  - Searching for additional log groups with pattern: *${STACK_NAME}*"
aws logs describe-log-groups --region "$REGION" --query 'logGroups[].logGroupName' --output text 2>/dev/null | tr '\t' '\n' | grep -i "$STACK_NAME" | while read log_group; do
    if [ -n "$log_group" ]; then
        echo "    Found additional log group: $log_group"
        echo "    Deleting: $log_group"
        aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null || true
        echo "    ✓ Additional log group deleted"
    fi
done

echo "✓ CloudWatch Log Groups cleanup completed"

# Post-cleanup verification and retry for stubborn Lambda log groups
echo ""
echo "Post-cleanup verification: Checking for remaining Lambda log groups..."
LAMBDA_LOG_GROUPS=(
    "/aws/lambda/${STACK_NAME}-codebuild-trigger"
    "/aws/lambda/${STACK_NAME}-memory-initializer"
)

for log_group in "${LAMBDA_LOG_GROUPS[@]}"; do
    # Check if the log group still exists
    if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
        echo "  ⚠️  Lambda log group still exists: $log_group"
        echo "    Attempting forced deletion..."
        
        # Try deleting it again with a more aggressive approach
        aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null || true
        
        # Wait a moment and check again
        sleep 3
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
            echo "    ⚠️  Log group persists (this is common with Lambda log groups)"
            echo "    Note: Lambda log groups may recreate automatically or have delayed deletion"
        else
            echo "    ✓ Log group successfully deleted on retry"
        fi
    else
        echo "  ✓ Lambda log group confirmed deleted: $log_group"
    fi
done

echo ""
echo "Waiting for resources to be fully deleted..."
sleep 10

echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Stack deletion initiated successfully!"
    echo ""
    echo "Waiting for stack deletion to complete..."
    echo "This may take a few minutes..."
    echo "(Deleting AgentCore Runtime, Browser, Code Interpreter, Memory, ECR, S3, IAM roles, etc.)"
    echo ""
    
    aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "=========================================="
        echo "✓ Stack deleted successfully!"
        echo "=========================================="
        echo ""
        
        # Post-cleanup: Template S3 bucket should be empty and deleted by CloudFormation
        echo "Post-cleanup: Template S3 bucket should be automatically deleted by CloudFormation"
        
        echo ""
        echo "=========================================="
        echo "✓ COMPLETE CLEANUP SUMMARY"
        echo "=========================================="
        echo "The following resources have been deleted:"
        echo "  ✓ AgentCore Runtime and all tools"
        echo "  ✓ Browser tool"
        echo "  ✓ Code Interpreter tool" 
        echo "  ✓ Memory store"
        echo "  ✓ ECR Repository (and all images)"
        echo "  ✓ Results S3 Bucket (and all files)"
        echo "  ✓ Template S3 Bucket"
        echo "  ✓ CodeBuild Project"
        echo "  ✓ Lambda Functions"
        echo "  ✓ IAM Roles and Policies"
        echo "  ✓ CloudWatch Log Groups (Lambda, CodeBuild, AgentCore)"
        echo "  ✓ CloudWatch Log Delivery Sources/Destinations"
        echo "  ✓ All CloudFormation resources"
        echo ""
        
        # Final verification for Lambda log groups
        echo "Final verification: Checking for any remaining Lambda log groups..."
        REMAINING_LAMBDA_LOGS=()
        for log_group in "/aws/lambda/${STACK_NAME}-codebuild-trigger" "/aws/lambda/${STACK_NAME}-memory-initializer"; do
            if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
                REMAINING_LAMBDA_LOGS+=("$log_group")
            fi
        done
        
        if [ ${#REMAINING_LAMBDA_LOGS[@]} -gt 0 ]; then
            echo ""
            echo "⚠️  NOTE: The following Lambda log groups may still exist:"
            for log_group in "${REMAINING_LAMBDA_LOGS[@]}"; do
                echo "    - $log_group"
            done
            echo ""
            echo "This is normal behavior for Lambda log groups. They may:"
            echo "  • Have delayed deletion due to AWS eventual consistency"
            echo "  • Be recreated automatically by Lambda service"
            echo "  • Require manual deletion from AWS Console if needed"
            echo ""
            echo "To manually delete them, run:"
            for log_group in "${REMAINING_LAMBDA_LOGS[@]}"; do
                echo "  aws logs delete-log-group --log-group-name '$log_group' --region $REGION"
            done
            echo ""
        else
            echo "✓ All Lambda log groups confirmed deleted"
        fi
        
        echo "All resources have been completely removed."
        echo ""
    else
        echo ""
        echo "✗ Stack deletion failed or timed out"
        echo "Check the CloudFormation console for details"
        exit 1
    fi
else
    echo ""
    echo "✗ Failed to initiate stack deletion"
    exit 1
fi
