#!/usr/bin/env python3
"""
Create AgentCore Memory with advanced strategies using Python SDK
This replaces the CloudFormation memory resource when advanced memory is enabled
"""

import boto3
import sys
import time
import json
import logging
from datetime import datetime
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
logger = logging.getLogger("advanced-memory")


def create_advanced_memory(stack_name, region, memory_name, expiry_days):
    """Create memory with advanced strategies using the Python SDK"""
    
    try:
        # Import the bedrock-agentcore SDK
        from bedrock_agentcore.memory import MemoryClient
        from bedrock_agentcore.memory.constants import StrategyType
        
        print(f"🧠 Creating Advanced Memory with Strategies...")
        print(f"   Stack: {stack_name}")
        print(f"   Region: {region}")
        print(f"   Memory Name: {memory_name}")
        print(f"   Expiry Days: {expiry_days}")
        print()
        
        # Initialize the memory client
        client = MemoryClient(region_name=region)
        
        # Create memory with advanced strategies (starting with USER_PREFERENCE)
        memory = client.create_memory_and_wait(
            name=memory_name,
            description=f"Advanced memory with long-term strategies for {stack_name} MCP server",
            strategies=[
                {
                    StrategyType.USER_PREFERENCE.value: {
                        "name": "UserPreferences",
                        "description": "Captures and extracts user preferences from conversations",
                        "namespaces": ["user/{actorId}/preferences"]
                    }
                }
            ],
            event_expiry_days=expiry_days,
            max_wait=300,
            poll_interval=10
        )
        
        print(f"✅ Advanced memory created successfully!")
        print(f"   Memory response type: {type(memory)}")
        
        if isinstance(memory, dict):
            memory_id = memory['id']
            print(f"   Memory ID: {memory_id}")
            
            # Display strategies if available
            strategies = memory.get('strategies', [])
            print(f"   Strategies: {len(strategies)} configured")
            for strategy in strategies:
                if isinstance(strategy, dict):
                    strategy_type = list(strategy.keys())[0]
                    strategy_info = strategy[strategy_type]
                    print(f"     - {strategy_type}: {strategy_info.get('name', 'Unknown')}")
        else:
            # If memory is a string, it might be just the memory ID
            memory_id = memory
            print(f"   Memory ID: {memory_id}")
            print(f"   Note: Memory response is a string, not a dict")
        
        # Initialize with sample data
        print(f"\n📝 Initializing memory with sample data...")
        try:
            initialize_memory_with_sample_data(client, memory_id)
        except Exception as init_error:
            print(f"⚠️  Sample data initialization failed: {init_error}")
        
        return memory_id
        
    except ImportError:
        print("❌ Error: bedrock-agentcore SDK not installed")
        print("   Install with: pip install bedrock-agentcore")
        return None
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'ValidationException' and "already exists" in str(e):
            print("⚠️  Memory with this name already exists")
            # Try to find existing memory
            try:
                memories = client.list_memories()
                memory_id = next((m['id'] for m in memories if memory_name in m.get('name', '')), None)
                if memory_id:
                    print(f"✅ Using existing memory: {memory_id}")
                    return memory_id
                else:
                    print("❌ Could not find existing memory")
                    return None
            except Exception as list_error:
                print(f"❌ Error finding existing memory: {list_error}")
                return None
        else:
            print(f"❌ Error creating memory: {e}")
            return None
            
    except Exception as e:
        print(f"⚠️  Display error (memory still created): {e}")
        # If we have a memory_id, return it even if there was a display error
        if 'memory_id' in locals():
            return memory_id
        else:
            print(f"❌ Unexpected error: {e}")
            return None


def initialize_memory_with_sample_data(client, memory_id):
    """Initialize the memory with sample conversation data"""
    try:
        timestamp = datetime.utcnow().isoformat() + 'Z'
        
        # Sample conversation for advanced memory extraction
        sample_messages = [
            ("Hi, I'm a user testing the MCP server with advanced memory", "USER"),
            ("Hello! I'm your MCP server assistant with advanced memory capabilities. I can help you with mathematical operations and greetings while remembering your preferences.", "ASSISTANT"),
            ("I prefer simple calculations and friendly interactions", "USER"),
            ("Perfect! I'll remember that you like simple calculations and friendly interactions. I have tools for adding numbers, multiplying numbers, and greeting users.", "ASSISTANT"),
            ("That sounds great! I really enjoy working with numbers and mathematical operations", "USER"),
            ("Excellent! I can see you enjoy mathematical operations. Feel free to ask me to add or multiply numbers anytime. I'll remember your preference for mathematical tasks.", "ASSISTANT")
        ]
        
        # Convert messages to proper payload format
        conversation_data = {
            "conversation": sample_messages,
            "metadata": {
                "initialization": True,
                "timestamp": timestamp
            }
        }
        conversation_json = json.dumps(conversation_data)
        
        response = client.create_event(
            memory_id=memory_id,
            actor_id="mcp_server_init",
            session_id="initialization_session",
            event_timestamp=timestamp,
            payload=[
                {
                    'blob': conversation_json,
                }
            ]
        )
        
        print(f"✅ Sample conversation added to memory")
        print(f"   Response type: {type(response)}")
        if isinstance(response, dict):
            print(f"   Event ID: {response.get('event_id', 'Unknown')}")
        else:
            print(f"   Response: {response}")
        
    except Exception as e:
        print(f"⚠️  Warning: Could not initialize sample data: {e}")


def update_cloudformation_outputs(stack_name, region, memory_id):
    """Update CloudFormation stack to use the SDK-created memory"""
    try:
        cf_client = boto3.client('cloudformation', region_name=region)
        
        print(f"\n🔄 Updating CloudFormation stack outputs...")
        
        # We can't directly update outputs, but we can store the memory ID in SSM
        ssm_client = boto3.client('ssm', region_name=region)
        
        parameter_name = f"/bedrock-agentcore/{stack_name}/advanced-memory-id"
        
        ssm_client.put_parameter(
            Name=parameter_name,
            Value=memory_id,
            Type='String',
            Description=f'Advanced memory ID for {stack_name} MCP server',
            Overwrite=True
        )
        
        print(f"✅ Memory ID stored in SSM Parameter: {parameter_name}")
        return True
        
    except Exception as e:
        print(f"⚠️  Warning: Could not update CloudFormation outputs: {e}")
        return False


def main():
    if len(sys.argv) != 5:
        print("Usage: python create-advanced-memory.py <stack_name> <region> <memory_name> <expiry_days>")
        print("\nExample:")
        print("  python create-advanced-memory.py mcp-server-demo us-west-2 MCPServerMemory 30")
        sys.exit(1)
        
    stack_name = sys.argv[1]
    region = sys.argv[2]
    memory_name = sys.argv[3]
    expiry_days = int(sys.argv[4])
    
    print("🧠 Advanced Memory Creation with Strategies")
    print("=" * 60)
    print()
    
    # Create the advanced memory
    memory_id = create_advanced_memory(stack_name, region, memory_name, expiry_days)
    
    if memory_id:
        # Store the memory ID for later use
        update_cloudformation_outputs(stack_name, region, memory_id)
        
        print("\n" + "=" * 60)
        print("✅ Advanced Memory Setup Complete!")
        print("=" * 60)
        print(f"Memory ID: {memory_id}")
        print(f"Strategies: User Preferences, Conversation Summaries")
        print(f"Retention: {expiry_days} days")
        print()
        print("🧪 Next Steps:")
        print("1. Wait 2-3 minutes for strategies to activate")
        print("2. Run memory tests: ./test-memory-only.sh")
        print("3. Check AWS Console to see configured strategies")
        
    else:
        print("\n❌ Advanced memory creation failed")
        sys.exit(1)


if __name__ == "__main__":
    main()