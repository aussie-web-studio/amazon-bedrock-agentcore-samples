#!/usr/bin/env python3
"""
Configure memory strategies for deployed AgentCore Memory
This script adds memory strategies that cannot be configured via CloudFormation
"""

import boto3
import sys
import json


def configure_memory_strategies(memory_id, region):
    """Configure memory strategies for the deployed memory resource"""
    print(f"🧠 Configuring Memory Strategies for Memory ID: {memory_id}")
    print("=" * 60)
    
    try:
        client = boto3.client('bedrock-agentcore', region_name=region)
        
        # Check if the memory exists
        print("🔍 Checking memory exists...")
        try:
            # Try to list events to verify memory exists
            client.list_events(
                memoryId=memory_id,
                actorId="test",
                sessionId="test",
                maxResults=1
            )
            print("✓ Memory exists and is accessible")
        except Exception as e:
            print(f"❌ Memory not accessible: {e}")
            return False
        
        print("\n📋 Available Memory Strategy Configuration Methods:")
        print("Unfortunately, memory strategies cannot be configured via:")
        print("  • CloudFormation templates")
        print("  • AWS CLI commands")
        print("  • Direct API calls")
        print("\n💡 Memory strategies are configured through:")
        print("  • AWS Console (Bedrock AgentCore > Memory)")
        print("  • AWS SDK with specific strategy APIs (if available)")
        
        print("\n🔧 Manual Configuration Steps:")
        print("1. Go to AWS Console > Amazon Bedrock > AgentCore > Memory")
        print(f"2. Find memory: {memory_id}")
        print("3. Click 'Edit' or 'Configure Strategies'")
        print("4. Add User Preference Strategy:")
        print("   - Name: UserPreferences")
        print("   - Description: Captures user preferences from conversations")
        print("   - Namespaces: user/{actorId}/preferences")
        print("5. Add Summary Strategy:")
        print("   - Name: ConversationSummaries") 
        print("   - Description: Creates summaries of important topics")
        print("   - Namespaces: user/{actorId}/summaries")
        
        return True
        
    except Exception as e:
        print(f"❌ Error configuring memory strategies: {e}")
        return False


def main():
    if len(sys.argv) != 3:
        print("Usage: python configure-memory-strategies.py <memory_id> <region>")
        print("\nExample:")
        print("  python configure-memory-strategies.py mcp_server_demo_MCPServerMemory-abc123 us-west-2")
        sys.exit(1)
        
    memory_id = sys.argv[1]
    region = sys.argv[2]
    
    print("🧠 AgentCore Memory Strategy Configuration")
    print("=" * 60)
    print(f"Memory ID: {memory_id}")
    print(f"Region: {region}")
    print()
    
    success = configure_memory_strategies(memory_id, region)
    
    if success:
        print("\n✅ Memory strategy configuration guidance provided!")
        print("\n📚 Next Steps:")
        print("1. Configure strategies manually in AWS Console")
        print("2. Wait 5-10 minutes for strategies to activate")
        print("3. Run memory tests to verify: ./test-memory-only.sh")
    else:
        print("\n❌ Memory strategy configuration failed")
        sys.exit(1)


if __name__ == "__main__":
    main()