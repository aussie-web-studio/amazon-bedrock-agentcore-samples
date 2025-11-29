#!/bin/bash

# Cleanup script for Weather Agent Runtime CloudFormation stack
# This script deletes the CloudFormation stack and all associated resources

set -e

# Configuration
STACK_NAME="${1:-weather-agent-demo}"
REGION="${2:-us-west-2}"
S3_BUCKET="${STACK_NAME}-cf-templates"

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

echo ""
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
        
        # Clean up S3 bucket
        echo "Cleaning up S3 template bucket..."
        if aws s3 ls "s3://${S3_BUCKET}" --region "$REGION" 2>&1 | grep -q 'NoSuchBucket'; then
            echo "S3 bucket does not exist (already cleaned up)"
        else
            echo "Removing S3 bucket contents..."
            aws s3 rm s3://"$S3_BUCKET" --recursive --region "$REGION" 2>/dev/null || true
            echo "Deleting S3 bucket..."
            aws s3 rb s3://"$S3_BUCKET" --region "$REGION" 2>/dev/null || true
            echo "✓ S3 bucket cleaned up"
        fi
        
        echo ""
        echo "All resources have been cleaned up."
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
