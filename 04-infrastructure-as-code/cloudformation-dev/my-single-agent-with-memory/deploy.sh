#!/bin/bash

# Deploy script for Weather Agent Runtime CloudFormation stack
# This script deploys a complete weather agent with browser, code interpreter, and memory
#
# Usage: ./deploy.sh [STACK_NAME] [REGION] [MODEL_ID]
#
# Parameters:
#   STACK_NAME - CloudFormation stack name (default: weather-agent-demo)
#   REGION     - AWS region (default: us-west-2)
#   MODEL_ID   - Bedrock model ID (default: us.anthropic.claude-sonnet-4-5-20250929-v1:0)
#
# Examples:
#   ./deploy.sh
#   ./deploy.sh my-weather-agent us-east-1
#   ./deploy.sh my-weather-agent us-east-1 anthropic.claude-3-5-sonnet-20241022-v2:0

set -e

# Configuration
STACK_NAME="${1:-weather-agent-demo}"
REGION="${2:-us-west-2}"
MODEL_ID="${3:-amazon.nova-micro-v1:0}"
TEMPLATE_FILE="end-to-end-weather-agent.yaml"

# Get AWS Account ID for unique bucket naming
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET="${STACK_NAME}-cf-templates-${ACCOUNT_ID}"

echo "=========================================="
echo "Deploying Weather Agent Runtime"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Model ID: $MODEL_ID"
echo "Template S3 Bucket: $S3_BUCKET"
echo "=========================================="

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found!"
    exit 1
fi

# Create S3 bucket for template (if it doesn't exist)
echo ""
echo "Checking/Creating S3 bucket for CloudFormation template..."
if aws s3 ls "s3://${S3_BUCKET}" --region "$REGION" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating new S3 bucket: $S3_BUCKET"
    aws s3 mb s3://"$S3_BUCKET" --region "$REGION"
else
    echo "Using existing S3 bucket: $S3_BUCKET"
fi

# Upload template and agent code to S3
echo "Uploading template to S3..."
aws s3 cp "$TEMPLATE_FILE" s3://"$S3_BUCKET"/"$TEMPLATE_FILE" --region "$REGION"

if [ $? -ne 0 ]; then
    echo "Error: Failed to upload template to S3"
    exit 1
fi

echo "Uploading agent code to S3..."
aws s3 cp agent-code/ s3://"$S3_BUCKET"/agent-code/ --recursive --region "$REGION"

if [ $? -ne 0 ]; then
    echo "Error: Failed to upload agent code to S3"
    exit 1
fi

TEMPLATE_URL="https://${S3_BUCKET}.s3.${REGION}.amazonaws.com/${TEMPLATE_FILE}"

# Generate deployment version based on agent code hash
echo ""
echo "Generating deployment version from agent code..."
# Create hash from all agent code files
AGENT_CODE_HASH=$(find agent-code/ -type f \( -name "*.py" -o -name "*.txt" -o -name "Dockerfile" \) -exec cat {} \; | shasum -a 256 | cut -c1-8)
DEPLOYMENT_VERSION="v${AGENT_CODE_HASH}"
echo "Deployment Version: $DEPLOYMENT_VERSION (based on agent-code/ files)"

# Check if stack already exists
echo ""
echo "Checking if stack exists..."
STACK_EXISTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" 2>&1 || echo "DOES_NOT_EXIST")

if echo "$STACK_EXISTS" | grep -q "DOES_NOT_EXIST\|does not exist"; then
    # Stack doesn't exist - CREATE
    echo "Stack does not exist. Creating new stack..."
    OPERATION="create"
    
    DEPLOY_OUTPUT=$(aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-url "$TEMPLATE_URL" \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameters ParameterKey=DeploymentVersion,ParameterValue="$DEPLOYMENT_VERSION" \
                     ParameterKey=BedrockModelId,ParameterValue="$MODEL_ID" \
        --region "$REGION" 2>&1)
    
    DEPLOY_STATUS=$?
    WAIT_COMMAND="stack-create-complete"
else
    # Stack exists - UPDATE
    echo "Stack exists. Updating existing stack..."
    OPERATION="update"
    
    DEPLOY_OUTPUT=$(aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-url "$TEMPLATE_URL" \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameters ParameterKey=DeploymentVersion,ParameterValue="$DEPLOYMENT_VERSION" \
                     ParameterKey=BedrockModelId,ParameterValue="$MODEL_ID" \
        --region "$REGION" 2>&1)
    
    DEPLOY_STATUS=$?
    WAIT_COMMAND="stack-update-complete"
    
    # Check if no updates are needed
    if echo "$DEPLOY_OUTPUT" | grep -q "No updates are to be performed"; then
        echo ""
        echo "ℹ️  No updates needed - stack is already up to date"
        echo ""
        echo "Note: Template bucket '$S3_BUCKET' is retained for future updates"
        exit 0
    fi
fi

if [ $DEPLOY_STATUS -eq 0 ]; then
    echo "Stack ID/ARN: $DEPLOY_OUTPUT"
    echo ""
    echo "✓ Stack $OPERATION initiated successfully!"
    echo ""
    echo "Waiting for stack $OPERATION to complete..."
    echo "This will take approximately 15-20 minutes..."
    echo "(Building Docker image, deploying agent with browser, code interpreter, and memory)"
    echo ""
    
    aws cloudformation wait "$WAIT_COMMAND" \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "=========================================="
        if [ "$OPERATION" = "create" ]; then
            echo "✓ Stack created successfully!"
        else
            echo "✓ Stack updated successfully!"
        fi
        echo "=========================================="
        echo ""
        echo "Stack Outputs:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].Outputs' \
            --output table \
            --region "$REGION"
        echo ""
        echo "Agent Runtime ID:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].Outputs[?OutputKey==`AgentRuntimeId`].OutputValue' \
            --output text \
            --region "$REGION"
        echo ""
        echo "Browser ID:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].Outputs[?OutputKey==`BrowserId`].OutputValue' \
            --output text \
            --region "$REGION"
        echo ""
        echo "Code Interpreter ID:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].Outputs[?OutputKey==`CodeInterpreterId`].OutputValue' \
            --output text \
            --region "$REGION"
        echo ""
        echo "Memory ID:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].Outputs[?OutputKey==`MemoryId`].OutputValue' \
            --output text \
            --region "$REGION"
        echo ""
        echo "Results Bucket:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].Outputs[?OutputKey==`ResultsBucket`].OutputValue' \
            --output text \
            --region "$REGION"
        echo ""
        echo "Note: Template bucket '$S3_BUCKET' is retained for future updates"
        echo ""
        echo "To delete this stack, run:"
        echo "  ./cleanup.sh $STACK_NAME $REGION"
        echo ""
    else
        echo ""
        echo "✗ Stack $OPERATION failed or timed out"
        echo "Check the CloudFormation console for details"
        exit 1
    fi
else
    echo ""
    echo "✗ Failed to initiate stack $OPERATION"
    echo "Error: $DEPLOY_OUTPUT"
    exit 1
fi
