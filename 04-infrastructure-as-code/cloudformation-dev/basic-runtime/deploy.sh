#!/bin/bash

# Deploy script for Basic Agent Runtime CloudFormation stack
# This script deploys a basic AgentCore Runtime with a simple Strands agent
#
# Usage:
#   ./deploy.sh [STACK_NAME] [REGION] [LLM_MODEL]
#
# Examples:
#   ./deploy.sh                                                    # Uses defaults
#   ./deploy.sh my-stack us-east-1                                 # Custom stack and region
#   ./deploy.sh my-stack us-east-1 anthropic.claude-3-haiku-20240307-v1:0  # Custom model

set -e

# Configuration
STACK_NAME="${1:-basic-agent-demo}"
REGION="${2:-us-west-2}"
LLM_MODEL="${3:-amazon.nova-micro-v1:0}"
TEMPLATE_FILE="template.yaml"

echo "=========================================="
echo "Deploying Basic Agent Runtime"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "LLM Model: $LLM_MODEL"
echo "=========================================="

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found!"
    exit 1
fi

# Deploy the CloudFormation stack
echo ""
echo "Creating CloudFormation stack..."
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --parameters ParameterKey=LLMModel,ParameterValue="$LLM_MODEL" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Stack creation initiated successfully!"
    echo ""
    echo "Waiting for stack creation to complete..."
    echo "This will take approximately 10-15 minutes..."
    echo ""
    
    aws cloudformation wait stack-create-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "=========================================="
        echo "✓ Stack deployed successfully!"
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
        echo "To delete this stack, run:"
        echo "  ./cleanup.sh $STACK_NAME $REGION"
        echo ""
    else
        echo ""
        echo "✗ Stack creation failed or timed out"
        echo "Check the CloudFormation console for details"
        exit 1
    fi
else
    echo ""
    echo "✗ Failed to initiate stack creation"
    exit 1
fi
