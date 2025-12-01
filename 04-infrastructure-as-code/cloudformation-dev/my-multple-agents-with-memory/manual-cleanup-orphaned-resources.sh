#!/bin/bash

# Manual cleanup script for orphaned BedrockAgentCore resources
# Use this when CloudFormation deployment fails due to "AlreadyExists" errors

set -e

REGION="${1:-us-west-2}"

echo "=========================================="
echo "Manual Cleanup of Orphaned BedrockAgentCore Resources"
echo "=========================================="
echo "Region: $REGION"
echo "=========================================="

echo ""
echo "🔍 Searching for orphaned BedrockAgentCore resources..."

# Function to list and delete orphaned code interpreters
cleanup_code_interpreters() {
    echo ""
    echo "🧹 Cleaning up Code Interpreters..."
    
    # List all code interpreters and look for ones with weather_agent_demo pattern
    aws bedrock-agentcore list-code-interpreters --region "$REGION" --query 'codeInterpreters[].codeInterpreterId' --output text 2>/dev/null | tr '\t' '\n' | while read code_interpreter_id; do
        if [ -n "$code_interpreter_id" ] && echo "$code_interpreter_id" | grep -q "weather_agent_demo"; then
            echo "  Found orphaned Code Interpreter: $code_interpreter_id"
            
            # First, delete all active sessions for this code interpreter
            echo "    Cleaning up active sessions..."
            aws bedrock-agentcore list-code-interpreter-sessions --code-interpreter-id "$code_interpreter_id" --region "$REGION" --query 'sessions[].sessionId' --output text 2>/dev/null | tr '\t' '\n' | while read session_id; do
                if [ -n "$session_id" ]; then
                    echo "      Deleting session: $session_id"
                    aws bedrock-agentcore delete-code-interpreter-session --code-interpreter-id "$code_interpreter_id" --session-id "$session_id" --region "$REGION" 2>/dev/null || true
                    echo "      ✓ Session deleted"
                fi
            done
            
            # Wait a moment for sessions to be fully deleted
            echo "    Waiting for sessions to be fully deleted..."
            sleep 3
            
            # Now delete the code interpreter itself
            echo "    Deleting Code Interpreter: $code_interpreter_id"
            aws bedrock-agentcore delete-code-interpreter --code-interpreter-id "$code_interpreter_id" --region "$REGION" 2>/dev/null || true
            echo "  ✓ Code Interpreter deleted"
        fi
    done
}

# Function to list and delete orphaned browsers
cleanup_browsers() {
    echo ""
    echo "🧹 Cleaning up Browsers..."
    
    # List all browsers and look for ones with weather_agent_demo pattern
    aws bedrock-agentcore list-browsers --region "$REGION" --query 'browsers[].browserId' --output text 2>/dev/null | tr '\t' '\n' | while read browser_id; do
        if [ -n "$browser_id" ] && echo "$browser_id" | grep -q "weather_agent_demo"; then
            echo "  Found orphaned Browser: $browser_id"
            echo "  Deleting: $browser_id"
            aws bedrock-agentcore delete-browser --browser-id "$browser_id" --region "$REGION" 2>/dev/null || true
            echo "  ✓ Browser deleted"
        fi
    done
}

# Function to list and delete orphaned memories
cleanup_memories() {
    echo ""
    echo "🧹 Cleaning up Memories..."
    
    # List all memories and look for ones with weather_agent_demo pattern
    aws bedrock-agentcore list-memories --region "$REGION" --query 'memories[].memoryId' --output text 2>/dev/null | tr '\t' '\n' | while read memory_id; do
        if [ -n "$memory_id" ] && echo "$memory_id" | grep -q "weather_agent_demo"; then
            echo "  Found orphaned Memory: $memory_id"
            echo "  Deleting: $memory_id"
            aws bedrock-agentcore delete-memory --memory-id "$memory_id" --region "$REGION" 2>/dev/null || true
            echo "  ✓ Memory deleted"
        fi
    done
}

# Function to list and delete orphaned agent runtimes
cleanup_agent_runtimes() {
    echo ""
    echo "🧹 Cleaning up Agent Runtimes..."
    
    # List all agent runtimes and look for ones with weather_agent_demo pattern
    aws bedrock-agentcore list-runtimes --region "$REGION" --query 'runtimes[].agentRuntimeId' --output text 2>/dev/null | tr '\t' '\n' | while read runtime_id; do
        if [ -n "$runtime_id" ] && echo "$runtime_id" | grep -q "weather_agent_demo"; then
            echo "  Found orphaned Agent Runtime: $runtime_id"
            echo "  Deleting: $runtime_id"
            aws bedrock-agentcore delete-runtime --agent-runtime-id "$runtime_id" --region "$REGION" 2>/dev/null || true
            echo "  ✓ Agent Runtime deleted"
        fi
    done
}

# Run cleanup functions
cleanup_code_interpreters
cleanup_browsers  
cleanup_memories
cleanup_agent_runtimes

echo ""
echo "=========================================="
echo "✓ Manual cleanup completed!"
echo "=========================================="
echo ""
echo "You can now try deploying again:"
echo "  ./deploy.sh weather-agent-demo $REGION"
echo ""
echo "If you still get 'AlreadyExists' errors, wait a few minutes"
echo "for AWS to fully process the deletions, then try again."
echo ""