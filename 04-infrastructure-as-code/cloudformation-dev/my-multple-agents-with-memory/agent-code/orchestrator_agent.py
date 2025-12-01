from strands import Agent, tool
from strands.hooks import AgentInitializedEvent, HookProvider, HookRegistry, MessageAddedEvent
from strands_tools import use_aws
from typing import Dict, Any
from datetime import datetime
import json
import os
import boto3
import logging
from bedrock_agentcore.memory import MemoryClient
from bedrock_agentcore.runtime import BedrockAgentCoreApp

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("orchestrator-agent")

app = BedrockAgentCoreApp()

# Configuration
MEMORY_ID = os.getenv('MEMORY_ID', "")
AGENT2_ARN = os.getenv('AGENT2_ARN', '')
AGENT3_ARN = os.getenv('AGENT3_ARN', '')
RESULTS_BUCKET = os.getenv('RESULTS_BUCKET', "default-results-bucket")
region = os.getenv('AWS_REGION', 'us-west-2')

# Memory configuration
ACTOR_ID = "orchestrator_user_123"
SESSION_ID = "orchestrator_session_001"

# Memory Hook Provider Class
class MemoryHookProvider(HookProvider):
    def __init__(self, memory_client: MemoryClient, memory_id: str, actor_id: str, session_id: str):
        self.memory_client = memory_client
        self.memory_id = memory_id
        self.actor_id = actor_id
        self.session_id = session_id
    
    def on_agent_initialized(self, event: AgentInitializedEvent):
        """Load recent conversation history when agent starts"""
        try:
            recent_turns = self.memory_client.get_last_k_turns(
                memory_id=self.memory_id,
                actor_id=self.actor_id,
                session_id=self.session_id,
                k=5
            )
            
            if recent_turns:
                context_messages = []
                for turn in recent_turns:
                    for message in turn:
                        role = message['role']
                        content = message['content']['text']
                        context_messages.append(f"{role}: {content}")
                
                context = "\n".join(context_messages)
                event.agent.system_prompt += f"\n\nRecent conversation:\n{context}"
                logger.info(f"✅ Loaded {len(recent_turns)} conversation turns")
                
        except Exception as e:
            logger.error(f"Memory load error: {e}")
    
    def on_message_added(self, event: MessageAddedEvent):
        """Store messages in memory"""
        messages = event.agent.messages
        try:
            if messages[-1]["content"][0].get("text"):
                self.memory_client.create_event(
                    memory_id=self.memory_id,
                    actor_id=self.actor_id,
                    session_id=self.session_id,
                    messages=[(messages[-1]["content"][0]["text"], messages[-1]["role"])]
                )
        except Exception as e:
            logger.error(f"Memory save error: {e}")
    
    def register_hooks(self, registry: HookRegistry):
        registry.add_callback(MessageAddedEvent, self.on_message_added)
        registry.add_callback(AgentInitializedEvent, self.on_agent_initialized)

def invoke_agent(agent_arn: str, query: str, agent_name: str) -> str:
    """Helper function to invoke any agent using boto3"""
    try:
        agentcore_client = boto3.client('bedrock-agentcore', region_name=region)
        
        response = agentcore_client.invoke_agent_runtime(
            agentRuntimeArn=agent_arn,
            qualifier="DEFAULT",
            payload=json.dumps({"prompt": query})
        )
        
        # Handle streaming response
        if "text/event-stream" in response.get("contentType", ""):
            result = ""
            for line in response["response"].iter_lines(chunk_size=10):
                if line:
                    line = line.decode("utf-8")
                    if line.startswith("data: "):
                        line = line[6:]
                    result += line
            return result
        
        # Handle JSON response
        elif response.get("contentType") == "application/json":
            content = []
            for chunk in response.get("response", []):
                content.append(chunk.decode('utf-8'))
            response_data = json.loads(''.join(content))
            return json.dumps(response_data)
        
        # Handle other response types
        else:
            response_body = response['response'].read()
            return response_body.decode('utf-8')
            
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        return f"Error invoking {agent_name}: {str(e)}\nDetails: {error_details}"

def invoke_specialist_agent(query: str) -> str:
    """Helper function to invoke specialist agent"""
    return invoke_agent(AGENT2_ARN, query, "specialist agent")

def invoke_weather_agent(query: str) -> str:
    """Helper function to invoke weather agent"""
    return invoke_agent(AGENT3_ARN, query, "weather agent")

@tool
def call_specialist_agent(query: str) -> Dict[str, Any]:
    """
    Call the specialist agent for detailed analysis or complex tasks.
    Use this tool when you need expert analysis or detailed information that's not weather-related.

    Args:
        query: The question or task to send to the specialist agent

    Returns:
        The specialist agent's response
    """
    result = invoke_specialist_agent(query)
    return {
        "status": "success",
        "content": [{"text": result}]
    }

@tool
def call_weather_agent(query: str) -> Dict[str, Any]:
    """
    Call the weather agent for weather forecasts, activity planning, and weather-related analysis.
    Use this tool when the query involves:
    - Weather forecasts
    - Activity planning based on weather
    - Trip planning
    - Outdoor activity recommendations
    - Weather-based decisions

    Args:
        query: The weather-related question or task to send to the weather agent

    Returns:
        The weather agent's response
    """
    result = invoke_weather_agent(query)
    return {
        "status": "success",
        "content": [{"text": result}]
    }

@tool
def save_to_s3(filename: str, content: str) -> Dict[str, Any]:
    """Save content to S3 bucket"""
    try:
        s3_client = boto3.client('s3', region_name=region)
        s3_client.put_object(
            Bucket=RESULTS_BUCKET,
            Key=filename,
            Body=content,
            ContentType='text/markdown'
        )
        return {
            "status": "success",
            "content": [{"text": f"File saved to S3: s3://{RESULTS_BUCKET}/{filename}"}]
        }
    except Exception as e:
        return {
            "status": "error",
            "content": [{"text": f"Error saving to S3: {str(e)}"}]
        }

def create_orchestrator_agent() -> Agent:
    """Create the orchestrator agent with memory and tools"""
    current_date = datetime.utcnow().strftime("%B %d, %Y")
    
    system_prompt = f"""You are an orchestrator agent with memory capabilities.
    Today is {current_date}.
    
    You can handle simple queries directly, but for complex tasks, you should delegate to the appropriate specialist agent:

    **Use the WEATHER AGENT (call_weather_agent) when the query involves:**
    - Weather forecasts or weather conditions
    - Activity planning based on weather
    - Trip planning and travel recommendations
    - Outdoor activity suggestions
    - Weather-related decisions
    - Questions like "What should I do this weekend in [city]?"
    - Questions about weather in specific locations

    **Use the SPECIALIST AGENT (call_specialist_agent) when the query involves:**
    - General detailed analysis (non-weather)
    - Complex topics not related to weather
    - Expert analysis on technical subjects
    - Data analysis tasks

    **Handle directly (no delegation needed):**
    - Simple greetings and basic questions
    - General conversation
    - Questions about your capabilities

    You can save results to S3 using the save_to_s3 tool.
    You remember previous conversations through your memory system.
    
    Always choose the most appropriate agent based on the query content."""
    
    # Initialize memory client and hook provider
    memory_client = MemoryClient(region_name=region)
    memory_hook = MemoryHookProvider(memory_client, MEMORY_ID, ACTOR_ID, SESSION_ID)
    
    return Agent(
        tools=[call_specialist_agent, call_weather_agent, save_to_s3, use_aws],
        system_prompt=system_prompt,
        name="OrchestratorAgent",
        hooks=[memory_hook]
    )

@app.entrypoint
async def invoke(payload=None):
    """Main entrypoint for orchestrator agent"""
    try:
        # Get the query from payload
        query = payload.get("prompt", "Hello, how are you?") if payload else "Hello, how are you?"
        
        # Create and use the orchestrator agent
        agent = create_orchestrator_agent()
        response = agent(query)
        
        return {
            "status": "success",
            "agent": "orchestrator",
            "response": response.message['content'][0]['text']
        }
        
    except Exception as e:
        return {
            "status": "error",
            "agent": "orchestrator",
            "error": str(e)
        }

if __name__ == "__main__":
    app.run()