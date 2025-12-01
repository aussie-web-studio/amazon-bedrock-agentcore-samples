#!/bin/bash

# Test script to verify log group cleanup logic
# This script simulates the log group cleanup without actually deleting anything

set -e

# Configuration
STACK_NAME="${1:-multi-agent-demo}"
REGION="${2:-us-west-2}"

echo "=========================================="
echo "Testing CloudWatch Log Group Cleanup Logic"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "=========================================="

# Define log groups that would need manual cleanup
MANUAL_CLEANUP_LOG_GROUPS=(
    "/aws/lambda/${STACK_NAME}-codebuild-trigger"
    "/aws/lambda/${STACK_NAME}-memory-initializer"
)

echo "Base log groups to cleanup:"
for log_group in "${MANUAL_CLEANUP_LOG_GROUPS[@]}"; do
    echo "  - $log_group"
done

# Search for CodeBuild log groups
echo ""
echo "Searching for CodeBuild log groups..."
CODEBUILD_LOGS=$(aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "/aws/codebuild/${STACK_NAME}-" --query 'logGroups[].logGroupName' --output text 2>/dev/null || echo "")
if [ -n "$CODEBUILD_LOGS" ] && [ "$CODEBUILD_LOGS" != "None" ]; then
    echo "Found CodeBuild log groups:"
    for log_group in $CODEBUILD_LOGS; do
        if [ -n "$log_group" ]; then
            echo "  - $log_group"
            MANUAL_CLEANUP_LOG_GROUPS+=("$log_group")
        fi
    done
else
    echo "No CodeBuild log groups found"
fi

# Search for other stack-related log groups
echo ""
echo "Searching for other stack-related log groups..."
ALL_LOGS=$(aws logs describe-log-groups --region "$REGION" --query 'logGroups[].logGroupName' --output text 2>/dev/null || echo "")
FOUND_ADDITIONAL=false
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
                if [ "$FOUND_ADDITIONAL" = false ]; then
                    echo "Found additional stack-related log groups:"
                    FOUND_ADDITIONAL=true
                fi
                echo "  - $log_group"
                MANUAL_CLEANUP_LOG_GROUPS+=("$log_group")
            fi
        fi
    done
fi

if [ "$FOUND_ADDITIONAL" = false ]; then
    echo "No additional stack-related log groups found"
fi

echo ""
echo "=========================================="
echo "Complete list of log groups that would be cleaned up:"
echo "=========================================="
for log_group in "${MANUAL_CLEANUP_LOG_GROUPS[@]}"; do
    # Check if log group actually exists
    if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
        echo "  ✓ EXISTS: $log_group"
    else
        echo "  ✗ NOT FOUND: $log_group"
    fi
done

echo ""
echo "Test completed. No log groups were actually deleted."