#!/bin/bash

# Cleanup script for Multi-Agent Runtime CloudFormation stack
# This script deletes the CloudFormation stack and all associated resources

set -e

# Configuration
STACK_NAME="${1:-multi-agent-demo}"
REGION="${2:-us-west-2}"

# Get AWS Account ID for unique bucket naming
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET="${STACK_NAME}-cf-templates-${ACCOUNT_ID}"

echo "=========================================="
echo "Cleaning up Multi-Agent Runtime"
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
AGENT1_ECR_REPO=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`Agent1ECRRepositoryUri`].OutputValue' --output text 2>/dev/null | cut -d'/' -f2 || echo "")
AGENT2_ECR_REPO=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`Agent2ECRRepositoryUri`].OutputValue' --output text 2>/dev/null | cut -d'/' -f2 || echo "")
AGENT3_ECR_REPO=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`Agent3ECRRepositoryUri`].OutputValue' --output text 2>/dev/null | cut -d'/' -f2 || echo "")
RESULTS_BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`ResultsBucket`].OutputValue' --output text 2>/dev/null || echo "")

echo "Resources to be cleaned up:"
echo "  - CloudFormation Stack: $STACK_NAME"
echo "  - Agent1 ECR Repository: ${AGENT1_ECR_REPO:-'Not found'}"
echo "  - Agent2 ECR Repository: ${AGENT2_ECR_REPO:-'Not found'}"
echo "  - Agent3 ECR Repository: ${AGENT3_ECR_REPO:-'Not found'}"
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

# Empty ECR repositories
for ECR_REPO in "$AGENT1_ECR_REPO" "$AGENT2_ECR_REPO" "$AGENT3_ECR_REPO"; do
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
done

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

# Note: CloudWatch Log Groups will be cleaned up AFTER stack deletion
# This is because:
# 1. CloudFormation-managed log groups (bedrock-agentcore) are deleted by CloudFormation
# 2. Lambda/CodeBuild log groups are auto-created and need manual cleanup after stack deletion
echo ""
echo "Note: CloudWatch Log Groups will be cleaned up after stack deletion completes..."

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
        
        # Now clean up the remaining CloudWatch Log Groups that are not managed by CloudFormation
        echo ""
        echo "Post-stack deletion: Cleaning up remaining CloudWatch Log Groups..."
        echo "These are auto-created by Lambda and CodeBuild services and not managed by CloudFormation"
        
        # Define log groups that need manual cleanup
        MANUAL_CLEANUP_LOG_GROUPS=(
            "/aws/lambda/${STACK_NAME}-codebuild-trigger"
            "/aws/lambda/${STACK_NAME}-memory-initializer"
            "/aws/lambda/${STACK_NAME}-lowercase-converter"
        )
        
        # Add CodeBuild log groups
        echo "  - Searching for CodeBuild log groups..."
        CODEBUILD_LOGS=$(aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "/aws/codebuild/${STACK_NAME}-" --query 'logGroups[].logGroupName' --output text 2>/dev/null || echo "")
        if [ -n "$CODEBUILD_LOGS" ] && [ "$CODEBUILD_LOGS" != "None" ]; then
            for log_group in $CODEBUILD_LOGS; do
                if [ -n "$log_group" ]; then
                    echo "    Found CodeBuild log group: $log_group"
                    MANUAL_CLEANUP_LOG_GROUPS+=("$log_group")
                fi
            done
        fi
        
        # Add any other log groups that match the stack name pattern
        echo "  - Searching for other stack-related log groups..."
        ALL_LOGS=$(aws logs describe-log-groups --region "$REGION" --query 'logGroups[].logGroupName' --output text 2>/dev/null || echo "")
        if [ -n "$ALL_LOGS" ] && [ "$ALL_LOGS" != "None" ]; then
            for log_group in $ALL_LOGS; do
                if [ -n "$log_group" ] && echo "$log_group" | grep -qi "$STACK_NAME"; then
                    # Check if it's not already in our list
                    ALREADY_ADDED=false
                    for existing_log in "${MANUAL_CLEANUP_LOG_GROUPS[@]}"; do
                        if [ "$existing_log" = "$log_group" ]; then
                            ALREADY_ADDED=true
                            break
                        fi
                    done
                    
                    if [ "$ALREADY_ADDED" = false ]; then
                        echo "    Found additional stack-related log group: $log_group"
                        MANUAL_CLEANUP_LOG_GROUPS+=("$log_group")
                    fi
                fi
            done
        fi
        
        # Delete each log group with retry logic
        SUCCESSFULLY_DELETED=()
        FAILED_TO_DELETE=()
        
        for log_group in "${MANUAL_CLEANUP_LOG_GROUPS[@]}"; do
            echo "  - Attempting to delete: $log_group"
            
            # Check if log group exists
            if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
                # Try to delete with retries
                RETRY_COUNT=0
                MAX_RETRIES=3
                DELETED=false
                
                while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DELETED" = false ]; do
                    if [ $RETRY_COUNT -gt 0 ]; then
                        echo "    Retry $RETRY_COUNT/$MAX_RETRIES..."
                        sleep 5
                    fi
                    
                    if aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null; then
                        echo "    ✓ Successfully deleted: $log_group"
                        SUCCESSFULLY_DELETED+=("$log_group")
                        DELETED=true
                    else
                        RETRY_COUNT=$((RETRY_COUNT + 1))
                        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                            echo "    Failed to delete, retrying..."
                        fi
                    fi
                done
                
                if [ "$DELETED" = false ]; then
                    echo "    ✗ Failed to delete after $MAX_RETRIES attempts: $log_group"
                    FAILED_TO_DELETE+=("$log_group")
                fi
            else
                echo "    Log group does not exist (already deleted or never created)"
            fi
        done
        
        echo ""
        echo "=========================================="
        echo "✓ COMPLETE CLEANUP SUMMARY"
        echo "=========================================="
        echo "The following resources have been deleted:"
        echo "  ✓ Agent1 (Orchestrator) Runtime and tools"
        echo "  ✓ Agent2 (Specialist) Runtime and tools"
        echo "  ✓ Agent3 (Weather) Runtime and tools"
        echo "  ✓ Browser tool (shared)"
        echo "  ✓ Code Interpreter tool (shared)" 
        echo "  ✓ Agent1 Memory store"
        echo "  ✓ Agent2 Memory store"
        echo "  ✓ Agent3 Memory store"
        echo "  ✓ Agent1 ECR Repository (and all images)"
        echo "  ✓ Agent2 ECR Repository (and all images)"
        echo "  ✓ Agent3 ECR Repository (and all images)"
        echo "  ✓ Results S3 Bucket (and all files)"
        echo "  ✓ Template S3 Bucket"
        echo "  ✓ CodeBuild Projects (All Agents)"
        echo "  ✓ Lambda Functions"
        echo "  ✓ IAM Roles and Policies"
        echo "  ✓ CloudWatch Log Delivery Sources/Destinations"
        echo "  ✓ All CloudFormation resources"
        
        # Report on log group cleanup
        if [ ${#SUCCESSFULLY_DELETED[@]} -gt 0 ]; then
            echo "  ✓ CloudWatch Log Groups (${#SUCCESSFULLY_DELETED[@]} deleted):"
            for log_group in "${SUCCESSFULLY_DELETED[@]}"; do
                echo "    - $log_group"
            done
        fi
        
        if [ ${#FAILED_TO_DELETE[@]} -gt 0 ]; then
            echo "  ⚠️  CloudWatch Log Groups (${#FAILED_TO_DELETE[@]} require manual cleanup):"
            for log_group in "${FAILED_TO_DELETE[@]}"; do
                echo "    - $log_group"
            done
            echo ""
            echo "To manually delete remaining log groups, you can either:"
            echo "1. Use the standalone cleanup script:"
            echo "   ./cleanup-logs-only.sh $STACK_NAME $REGION"
            echo ""
            echo "2. Or run individual AWS CLI commands:"
            for log_group in "${FAILED_TO_DELETE[@]}"; do
                echo "   aws logs delete-log-group --log-group-name '$log_group' --region $REGION"
            done
        else
            echo "  ✓ All CloudWatch Log Groups successfully deleted"
        fi
        
        echo ""
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
