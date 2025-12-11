#!/bin/bash
# Interactive configuration script for MCP Server deployment
#
# This script helps users configure their MCP Server deployment with
# appropriate memory settings based on their use case.

set -e

echo "=========================================="
echo "🚀 MCP Server Configuration Wizard"
echo "=========================================="
echo ""

# Get basic configuration
read -p "Enter stack name (default: mcp-server-demo): " STACK_NAME
STACK_NAME="${STACK_NAME:-mcp-server-demo}"

read -p "Enter AWS region (default: us-west-2): " REGION
REGION="${REGION:-us-west-2}"

echo ""
echo "Available LLM Models:"
echo "1. amazon.nova-micro-v1:0 (Fast, cost-effective)"
echo "2. anthropic.claude-3-5-sonnet-20241022-v2:0 (High quality)"
echo "3. anthropic.claude-3-haiku-20240307-v1:0 (Balanced)"
echo "4. Custom model ID"
echo ""
read -p "Select LLM model (1-4, default: 1): " MODEL_CHOICE

case $MODEL_CHOICE in
    2)
        LLM_MODEL="anthropic.claude-3-5-sonnet-20241022-v2:0"
        ;;
    3)
        LLM_MODEL="anthropic.claude-3-haiku-20240307-v1:0"
        ;;
    4)
        read -p "Enter custom model ID: " LLM_MODEL
        ;;
    *)
        LLM_MODEL="amazon.nova-micro-v1:0"
        ;;
esac

echo ""
echo "Memory Configuration:"
echo "=========================================="
echo ""
echo "Choose your memory configuration based on your use case:"
echo ""
echo "🔹 BASIC MEMORY (Recommended for simple use cases)"
echo "   • Simple conversation storage"
echo "   • Basic event logging"
echo "   • Lower cost and complexity"
echo "   • Good for: Testing, simple tools, stateless operations"
echo ""
echo "🔹 ADVANCED MEMORY (Recommended for conversational agents)"
echo "   • Automatic user preference extraction"
echo "   • Conversation summarization"
echo "   • Long-term memory strategies"
echo "   • Structured namespace organization"
echo "   • Good for: Personal assistants, customer support, learning systems"
echo ""

while true; do
    read -p "Enable advanced memory? (y/n, default: n): " ADVANCED_CHOICE
    ADVANCED_CHOICE="${ADVANCED_CHOICE:-n}"
    
    case $ADVANCED_CHOICE in
        [Yy]* )
            ADVANCED_MEMORY="true"
            echo ""
            echo "Advanced memory selected! 🧠"
            
            read -p "Memory expiry days (1-365, default: 30): " MEMORY_EXPIRY_DAYS
            MEMORY_EXPIRY_DAYS="${MEMORY_EXPIRY_DAYS:-30}"
            
            # Validate expiry days
            if ! [[ "$MEMORY_EXPIRY_DAYS" =~ ^[0-9]+$ ]] || [ "$MEMORY_EXPIRY_DAYS" -lt 1 ] || [ "$MEMORY_EXPIRY_DAYS" -gt 365 ]; then
                echo "❌ Invalid expiry days. Using default: 30"
                MEMORY_EXPIRY_DAYS="30"
            fi
            break
            ;;
        [Nn]* )
            ADVANCED_MEMORY="false"
            MEMORY_EXPIRY_DAYS="30"
            echo ""
            echo "Basic memory selected! 💾"
            break
            ;;
        * )
            echo "Please answer y or n."
            ;;
    esac
done

echo ""
echo "=========================================="
echo "📋 Configuration Summary"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "LLM Model: $LLM_MODEL"
echo "Advanced Memory: $ADVANCED_MEMORY"
echo "Memory Expiry Days: $MEMORY_EXPIRY_DAYS"
echo ""

read -p "Proceed with deployment? (y/n): " DEPLOY_CHOICE

case $DEPLOY_CHOICE in
    [Yy]* )
        echo ""
        echo "🚀 Starting deployment..."
        ./deploy.sh "$STACK_NAME" "$REGION" "$LLM_MODEL" "$ADVANCED_MEMORY" "$MEMORY_EXPIRY_DAYS"
        ;;
    * )
        echo ""
        echo "Deployment cancelled. You can run this script again or use:"
        echo "./deploy.sh \"$STACK_NAME\" \"$REGION\" \"$LLM_MODEL\" \"$ADVANCED_MEMORY\" \"$MEMORY_EXPIRY_DAYS\""
        ;;
esac