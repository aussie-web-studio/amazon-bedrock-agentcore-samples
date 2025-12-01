#!/bin/bash

# Standalone CloudWatch Log Group cleanup script
# Use this script to clean up log groups after stack deletion if they weren't automatically removed

set -e

# Configuration
STACK_NAME="${1:-multi-agent-demo}"
REGION="${2:-us-west-2}"

echo "=========================================="
echo "CloudWatch Log Groups Cleanup"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "=========================================="

# Confirm deletion
read -p "Are you sure you want to delete log groups for stack '$STACK_NAME'? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Define log groups that need manual cleanup
MANUAL_CLEANUP_LOG_GROUPS=(
    "/aws/lambda/${STACK_NAME}-codebuild-trigger"
    "/aws/lambda/${STACK_NAME}-memory-initializer"
    "/aws/lambda/${STACK_NAME}-lowercase-converter"
)

# Add CodeBuild log groups
echo "Searching for CodeBuild log groups..."
CODEBUILD_LOGS=$(aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "/aws/codebuild/${STACK_NAME}-" --query 'logGroups[].logGroupName' --output text 2>/dev/null || echo "")
if [ -n "$CODEBUILD_LOGS" ] && [ "$CODEBUILD_LOGS" != "None" ]; then
    for log_group in $CODEBUILD_LOGS; do
        if [ -n "$log_group" ]; then
            echo "  Found CodeBuild log group: $log_group"
            MANUAL_CLEANUP_LOG_GROUPS+=("$log_group")
        fi
    done
fi

# Add any other log groups that match the stack name pattern
echo "Searching for other stack-related log groups..."
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
                echo "  Found additional stack-related log group: $log_group"
                MANUAL_CLEANUP_LOG_GROUPS+=("$log_group")
            fi
        fi
    done
fi

echo ""
echo "Log groups to be deleted:"
for log_group in "${MANUAL_CLEANUP_LOG_GROUPS[@]}"; do
    echo "  - $log_group"
done

echo ""
read -p "Proceed with deletion? (yes/no): " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Delete each log group with retry logic
SUCCESSFULLY_DELETED=()
FAILED_TO_DELETE=()

for log_group in "${MANUAL_CLEANUP_LOG_GROUPS[@]}"; do
    echo "Attempting to delete: $log_group"
    
    # Check if log group exists
    if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
        # Try to delete with retries
        RETRY_COUNT=0
        MAX_RETRIES=3
        DELETED=false
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DELETED" = false ]; do
            if [ $RETRY_COUNT -gt 0 ]; then
                echo "  Retry $RETRY_COUNT/$MAX_RETRIES..."
                sleep 5
            fi
            
            if aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null; then
                echo "  ✓ Successfully deleted: $log_group"
                SUCCESSFULLY_DELETED+=("$log_group")
                DELETED=true
            else
                RETRY_COUNT=$((RETRY_COUNT + 1))
                if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                    echo "  Failed to delete, retrying..."
                fi
            fi
        done
        
        if [ "$DELETED" = false ]; then
            echo "  ✗ Failed to delete after $MAX_RETRIES attempts: $log_group"
            FAILED_TO_DELETE+=("$log_group")
        fi
    else
        echo "  Log group does not exist (already deleted or never created)"
    fi
done

echo ""
echo "=========================================="
echo "Cleanup Summary"
echo "=========================================="

if [ ${#SUCCESSFULLY_DELETED[@]} -gt 0 ]; then
    echo "✓ Successfully deleted (${#SUCCESSFULLY_DELETED[@]} log groups):"
    for log_group in "${SUCCESSFULLY_DELETED[@]}"; do
        echo "  - $log_group"
    done
fi

if [ ${#FAILED_TO_DELETE[@]} -gt 0 ]; then
    echo ""
    echo "✗ Failed to delete (${#FAILED_TO_DELETE[@]} log groups):"
    for log_group in "${FAILED_TO_DELETE[@]}"; do
        echo "  - $log_group"
    done
    echo ""
    echo "To manually delete remaining log groups, run:"
    for log_group in "${FAILED_TO_DELETE[@]}"; do
        echo "  aws logs delete-log-group --log-group-name '$log_group' --region $REGION"
    done
    exit 1
else
    echo ""
    echo "✓ All log groups successfully deleted!"
fi