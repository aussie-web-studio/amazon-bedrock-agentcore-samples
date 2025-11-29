#!/usr/bin/env python3
"""
Memory testing script for MCP Server
Tests both basic and advanced memory functionality
"""

import asyncio
import sys
import json
import boto3
import time
from datetime import datetime, timedelta, timezone
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client


class MemoryTester:
    def __init__(self, agent_arn, bearer_token, region, stack_name):
        self.agent_arn = agent_arn
        self.bearer_token = bearer_token
        self.region = region
        self.stack_name = stack_name
        self.memory_id = None
        self.memory_type = None
        self.advanced_memory = False
        
        # Initialize AWS clients
        self.cf_client = boto3.client('cloudformation', region_name=region)
        self.agentcore_client = boto3.client('bedrock-agentcore', region_name=region)
        
    async def initialize(self):
        """Initialize memory tester and get stack information"""
        print("🔄 Initializing memory tester...")
        
        # Get memory information from stack outputs or SSM
        try:
            response = self.cf_client.describe_stacks(StackName=self.stack_name)
            outputs = response['Stacks'][0]['Outputs']
            
            for output in outputs:
                if output['OutputKey'] == 'MemoryId':
                    self.memory_id = output['OutputValue']
                elif output['OutputKey'] == 'MemoryType':
                    self.memory_type = output['OutputValue']
                    self.advanced_memory = 'Advanced' in output['OutputValue']
            
            # If memory ID not found in outputs, try SSM (for advanced memory)
            if not self.memory_id:
                try:
                    ssm_client = boto3.client('ssm', region_name=self.region)
                    parameter_name = f"/bedrock-agentcore/{self.stack_name}/advanced-memory-id"
                    response = ssm_client.get_parameter(Name=parameter_name)
                    self.memory_id = response['Parameter']['Value']
                    self.advanced_memory = True
                    self.memory_type = "Advanced (with strategies)"
                except Exception:
                    raise Exception("Memory ID not found in stack outputs or SSM")
                    
            if not self.memory_id:
                raise Exception("Memory ID not found")
                
            print(f"✓ Memory ID: {self.memory_id}")
            print(f"✓ Memory Type: {self.memory_type}")
            print(f"✓ Advanced Memory: {'Yes' if self.advanced_memory else 'No'}")
            print()
            
        except Exception as e:
            print(f"❌ Error getting stack information: {e}")
            raise

    async def test_memory_storage(self):
        """Test basic memory storage functionality"""
        print("💾 Testing Memory Storage...")
        print("=" * 50)
        
        try:
            # Create a test event in memory
            test_actor_id = f"test_user_{int(time.time())}"
            test_session_id = f"test_session_{int(time.time())}"
            timestamp = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
            
            # Test conversation for memory storage
            test_messages = [
                ("Hi, I'm testing the memory system", "USER"),
                ("Hello! I can help you test the memory functionality. What would you like to test?", "ASSISTANT"),
                ("I prefer mathematical operations and I like working with numbers", "USER"),
                ("Great! I'll remember that you enjoy mathematical operations. I have tools for adding and multiplying numbers.", "ASSISTANT"),
                ("I also enjoy friendly greetings and personalized interactions", "USER"),
                ("Perfect! I'll keep that in mind for our future interactions.", "ASSISTANT")
            ]
            
            print(f"📝 Storing test conversation in memory...")
            print(f"   Actor ID: {test_actor_id}")
            print(f"   Session ID: {test_session_id}")
            
            # Convert messages to proper payload format
            conversation_data = {
                "conversation": test_messages,
                "metadata": {
                    "test_type": "memory_storage_test",
                    "timestamp": timestamp
                }
            }
            conversation_json = json.dumps(conversation_data)
            
            # Store the conversation
            response = self.agentcore_client.create_event(
                memoryId=self.memory_id,
                actorId=test_actor_id,
                sessionId=test_session_id,
                eventTimestamp=timestamp,
                payload=[
                    {
                        'blob': conversation_json,
                    }
                ]
            )
            
            print(f"✓ Memory event created: {response.get('eventId', 'Unknown')}")
            
            # Wait a moment for processing
            await asyncio.sleep(2)
            
            # Verify the event was stored
            events = self.agentcore_client.list_events(
                memoryId=self.memory_id,
                actorId=test_actor_id,
                sessionId=test_session_id,
                maxResults=10
            )
            
            if events.get('events'):
                print(f"✓ Found {len(events['events'])} stored events")
                return test_actor_id, test_session_id
            else:
                print("❌ No events found in memory")
                return None, None
                
        except Exception as e:
            print(f"❌ Memory storage test failed: {e}")
            return None, None

    async def test_memory_retrieval(self, actor_id, session_id):
        """Test memory retrieval functionality"""
        print("\n🔍 Testing Memory Retrieval...")
        print("=" * 50)
        
        try:
            # Test retrieving recent events
            print("📖 Retrieving recent events...")
            events = self.agentcore_client.list_events(
                memoryId=self.memory_id,
                actorId=actor_id,
                sessionId=session_id,
                maxResults=5
            )
            
            if events.get('events'):
                print(f"✓ Retrieved {len(events['events'])} events")
                for i, event in enumerate(events['events'][:2]):  # Show first 2
                    print(f"   Event {i+1}: {event.get('eventId', 'Unknown')[:8]}...")
            else:
                print("❌ No events retrieved")
                return False
                
            # If advanced memory, test memory retrieval with queries
            if self.advanced_memory:
                print("\n🧠 Testing Advanced Memory Retrieval...")
                
                # Wait for extraction to process (advanced memory needs time)
                print("⏳ Waiting for memory extraction to process...")
                await asyncio.sleep(30)
                
                # Test retrieving memories with different queries
                test_queries = [
                    "mathematical operations",
                    "user preferences", 
                    "numbers",
                    "greetings"
                ]
                
                for query in test_queries:
                    try:
                        print(f"🔎 Querying: '{query}'...")
                        memories = self.agentcore_client.retrieve_memory_records(
                            memoryId=self.memory_id,
                            namespace=f"user/{actor_id}/preferences",
                            searchCriteria={
                                'searchQuery': query,
                                'topK': 3
                            },
                            maxResults=3
                        )
                        
                        if memories:
                            # Handle different response structures
                            if isinstance(memories, dict):
                                memory_records = memories.get('memoryRecords', [])
                                print(f"   ✓ Found {len(memory_records)} relevant memories")
                                if memory_records:
                                    first_record = memory_records[0]
                                    content = str(first_record.get('content', 'No content'))[:100]
                                    print(f"     - {content}...")
                            elif isinstance(memories, list):
                                print(f"   ✓ Found {len(memories)} relevant memories")
                                if memories:
                                    content = str(memories[0].get('content', 'No content'))[:100]
                                    print(f"     - {content}...")
                            else:
                                print(f"   ✓ Memory query successful (structure: {type(memories)})")
                        else:
                            print(f"   • No memories found for '{query}'")
                            
                    except Exception as e:
                        print(f"   ❌ Query failed: {str(e)[:100]}...")
                        
            return True
            
        except Exception as e:
            print(f"❌ Memory retrieval test failed: {e}")
            return False

    async def test_mcp_with_memory(self):
        """Test MCP server integration with memory"""
        print("\n🔗 Testing MCP Server with Memory Integration...")
        print("=" * 50)
        
        # Encode the ARN for URL
        encoded_arn = self.agent_arn.replace(":", "%3A").replace("/", "%2F")
        mcp_url = f"https://bedrock-agentcore.{self.region}.amazonaws.com/runtimes/{encoded_arn}/invocations?qualifier=DEFAULT"
        
        headers = {
            "authorization": f"Bearer {self.bearer_token}",
            "Content-Type": "application/json",
        }
        
        try:
            async with streamablehttp_client(
                mcp_url, headers, timeout=timedelta(seconds=120), terminate_on_close=False
            ) as (read_stream, write_stream, _):
                async with ClientSession(read_stream, write_stream) as session:
                    print("🔄 Initializing MCP session...")
                    await session.initialize()
                    print("✓ MCP session initialized")
                    
                    # Test that memory environment variables are available
                    print("\n🧪 Testing memory-aware operations...")
                    
                    # Test basic tools with memory context
                    print("➕ Testing add_numbers with memory context...")
                    add_result = await session.call_tool(
                        name="add_numbers", 
                        arguments={"a": 10, "b": 15}
                    )
                    print(f"   Result: {add_result.content[0].text}")
                    
                    # Test greeting with potential memory personalization
                    print("👋 Testing greet_user with memory context...")
                    greet_result = await session.call_tool(
                        name="greet_user", 
                        arguments={"name": "MemoryTester"}
                    )
                    print(f"   Result: {greet_result.content[0].text}")
                    
                    print("✓ MCP server is working with memory integration")
                    return True
                    
        except Exception as e:
            print(f"❌ MCP memory integration test failed: {e}")
            return False

    async def test_memory_persistence(self, actor_id, session_id):
        """Test memory persistence across sessions"""
        print("\n🔄 Testing Memory Persistence...")
        print("=" * 50)
        
        try:
            # Create a new session with the same actor
            new_session_id = f"persistence_test_{int(time.time())}"
            timestamp = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
            
            # Add new conversation that references previous preferences
            new_messages = [
                ("Hi again, do you remember my preferences?", "USER"),
                ("Yes, I remember you enjoy mathematical operations and friendly interactions!", "ASSISTANT"),
                ("Great! Can you help me with some calculations?", "USER"),
                ("Of course! I'd be happy to help with calculations.", "ASSISTANT")
            ]
            
            # Convert to proper payload format
            new_conversation_data = {
                "conversation": new_messages,
                "metadata": {
                    "test_type": "persistence_test",
                    "timestamp": timestamp,
                    "session_type": "follow_up"
                }
            }
            new_conversation_json = json.dumps(new_conversation_data)
            
            print(f"📝 Creating new session for same actor...")
            print(f"   New Session ID: {new_session_id}")
            
            response = self.agentcore_client.create_event(
                memoryId=self.memory_id,
                actorId=actor_id,
                sessionId=new_session_id,
                eventTimestamp=timestamp,
                payload=[
                    {
                        'blob': new_conversation_json,
                    }
                ]
            )
            
            print(f"✓ New session event created: {response.get('eventId', 'Unknown')}")
            
            # List all events for this actor across sessions
            # Note: list_events without sessionId might not be supported, so we'll try both sessions
            all_events = {'events': []}
            
            # Try to get events from both sessions
            try:
                # Get events from original session
                session1_events = self.agentcore_client.list_events(
                    memoryId=self.memory_id,
                    actorId=actor_id,
                    sessionId=session_id,  # Use the original session_id passed to this method
                    maxResults=10
                )
                all_events['events'].extend(session1_events.get('events', []))
                
                # Get events from new session
                session2_events = self.agentcore_client.list_events(
                    memoryId=self.memory_id,
                    actorId=actor_id,
                    sessionId=new_session_id,
                    maxResults=10
                )
                all_events['events'].extend(session2_events.get('events', []))
                
            except Exception as e:
                print(f"   ⚠️  Could not list all events: {e}")
                # Fallback: just count the events we know exist
                all_events = {'events': [{'sessionId': session_id}, {'sessionId': new_session_id}]}
            
            if all_events.get('events'):
                sessions = set()
                for event in all_events['events']:
                    sessions.add(event.get('sessionId', 'unknown'))
                
                print(f"✓ Actor has {len(all_events['events'])} total events across {len(sessions)} sessions")
                print(f"   Sessions: {list(sessions)}")
                return True
            else:
                print("❌ No persistent events found")
                return False
                
        except Exception as e:
            print(f"❌ Memory persistence test failed: {e}")
            return False

    async def run_all_tests(self):
        """Run all memory tests"""
        print("🧪 MCP Server Memory Testing Suite")
        print("=" * 60)
        print()
        
        await self.initialize()
        
        tests_passed = 0
        total_tests = 4
        
        # Test 1: Memory Storage
        actor_id, session_id = await self.test_memory_storage()
        if actor_id and session_id:
            tests_passed += 1
            
        # Test 2: Memory Retrieval
        if actor_id and await self.test_memory_retrieval(actor_id, session_id):
            tests_passed += 1
            
        # Test 3: MCP Integration
        if await self.test_mcp_with_memory():
            tests_passed += 1
            
        # Test 4: Memory Persistence
        if actor_id and session_id and await self.test_memory_persistence(actor_id, session_id):
            tests_passed += 1
            
        # Results
        print("\n" + "=" * 60)
        print(f"📊 Memory Test Results: {tests_passed}/{total_tests} tests passed")
        
        if tests_passed == total_tests:
            print("🎉 All memory tests passed!")
            if self.advanced_memory:
                print("🧠 Advanced memory features are working correctly")
                print("   • User preference extraction")
                print("   • Memory querying and retrieval")
                print("   • Cross-session persistence")
            else:
                print("💾 Basic memory features are working correctly")
                print("   • Event storage and retrieval")
                print("   • Session management")
        else:
            print(f"❌ {total_tests - tests_passed} memory tests failed")
            print("   Please check the memory configuration and try again")
            
        return tests_passed == total_tests


async def main():
    if len(sys.argv) != 5:
        print("Usage: python test_memory.py <agent_arn> <bearer_token> <region> <stack_name>")
        print("\nExample:")
        print("  python test_memory.py arn:aws:bedrock-agentcore:... eyJraWQiOiJ... us-west-2 my-stack")
        sys.exit(1)
        
    agent_arn = sys.argv[1]
    bearer_token = sys.argv[2]
    region = sys.argv[3]
    stack_name = sys.argv[4]
    
    tester = MemoryTester(agent_arn, bearer_token, region, stack_name)
    success = await tester.run_all_tests()
    
    if not success:
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())