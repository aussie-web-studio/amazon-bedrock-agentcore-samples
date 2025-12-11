from strands import Agent, tool
from strands.hooks import AgentInitializedEvent, HookProvider, HookRegistry, MessageAddedEvent
from strands_tools import use_aws
from typing import Dict, Any
from datetime import datetime
import json
import os
import asyncio
from contextlib import suppress
import logging
import shutil
import sys
from pathlib import Path

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("specialist-agent")

def find_browser_use_path():
    """Automatically find the browser_use installation path"""
    try:
        import browser_use
        browser_use_path = Path(browser_use.__file__).parent
        session_file = browser_use_path / "browser" / "session.py"
        return str(session_file)
    except ImportError:
        print("❌ browser_use not installed. Install with: pip install browser-use")
        return None

def patch_browser_use():
    # Auto-detect file path
    file_path = find_browser_use_path()
    if not file_path:
        return False
    
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return False
    
    print(f"📁 Found browser_use at: {file_path}")
    
    # Create backup
    backup_path = file_path + ".backup"
    if not os.path.exists(backup_path):
        shutil.copy2(file_path, backup_path)
        print(f"💾 Created backup: {backup_path}")
    else:
        print(f"📋 Backup already exists: {backup_path}")
    
    # Read file
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Replacement 1: Add headers check after cdp_url check
    old1 = "if not cdp_url:\n\t\t\tprofile_kwargs['is_local'] = True"
    new1 = "if not cdp_url:\n\t\t\tprofile_kwargs['is_local'] = True\n\n\t\tif headers:\n\t\t\tprofile_kwargs['headers'] = headers"
    
    if old1 in content and "if headers:\n\t\t\tprofile_kwargs['headers'] = headers" not in content:
        content = content.replace(old1, new1)
        print("✅ Added headers check")
    elif "if headers:\n\t\t\tprofile_kwargs['headers'] = headers" in content:
        print("✅ Headers check already exists")
    else:
        print("⚠️ Headers check pattern not found")
    
    # Replacement 2: Add headers to CDPClient
    old2 = "self._cdp_client_root = CDPClient(self.cdp_url)"
    new2 = "self._cdp_client_root = CDPClient(self.cdp_url,  additional_headers=self.browser_profile.headers)"
    
    if old2 in content:
        content = content.replace(old2, new2)
        print("✅ Added headers to CDPClient")
    elif "additional_headers=self.browser_profile.headers" in content:
        print("✅ CDPClient headers already exists")
    else:
        print("⚠️ CDPClient pattern not found")
    
    # Write back
    with open(file_path, 'w') as f:
        f.write(content)
    
    print("🎉 Patching complete!")
    return True

patch_browser_use()

from bedrock_agentcore.tools.browser_client import BrowserClient
from browser_use.llm import ChatAnthropicBedrock, ChatAWSBedrock
from browser_use import Agent as BrowserAgent
from browser_use import Browser, BrowserProfile

from bedrock_agentcore.tools.code_interpreter_client import CodeInterpreter
from bedrock_agentcore.memory import MemoryClient
from rich.console import Console
import re

from bedrock_agentcore.runtime import BedrockAgentCoreApp

app = BedrockAgentCoreApp()
console = Console()

# Configuration
BROWSER_ID = os.getenv('BROWSER_ID', "aws.browser.v1")
CODE_INTERPRETER_ID = os.getenv('CODE_INTERPRETER_ID', "aws.codeinterpreter.v1")
MEMORY_ID = os.getenv('MEMORY_ID', "")
RESULTS_BUCKET = os.getenv('RESULTS_BUCKET', "default-results-bucket")
region = os.getenv('AWS_REGION','us-west-2')

# Memory configuration
ACTOR_ID = "specialist_user_123"
SESSION_ID = "specialist_session_001"

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

# Async helper functions
async def run_browser_task(browser_session, bedrock_chat, task: str) -> str:
    """Run a browser automation task using browser_use"""
    try:
        console.print(f"[blue]🤖 Executing browser task:[/blue] {task[:100]}...")
        
        agent = BrowserAgent(
            task=task,
            llm=bedrock_chat,
            browser=browser_session
        )
        
        result = await agent.run()
        console.print("[green]✅ Browser task completed successfully![/green]")
        
        if 'done' in result.last_action() and 'text' in result.last_action()['done']:
            return result.last_action()['done']['text'] 
        else:
            raise ValueError("NO Data")
            
    except Exception as e:
        console.print(f"[red]❌ Browser task error: {e}[/red]")
        raise

async def initialize_browser_session():
    """Initialize Browser-use session with AgentCore WebSocket connection"""
    try:
        client = BrowserClient(region)
        client.start(identifier=BROWSER_ID)
        
        ws_url, headers = client.generate_ws_headers()
        console.print(f"[cyan]🔗 Browser WebSocket URL: {ws_url[:50]}...[/cyan]")
        
        browser_profile = BrowserProfile(
            headers=headers,
            timeout=150000,
        )
        
        browser_session = Browser(
            cdp_url=ws_url,
            browser_profile=browser_profile,
            keep_alive=True
        )
        
        console.print("[cyan]🔄 Initializing browser session...[/cyan]")
        await browser_session.start()
        
        # Create ChatBedrockConverse once
        model_id = os.getenv('BEDROCK_MODEL_ID', 'us.anthropic.claude-sonnet-4-5-20250929-v1:0')
        bedrock_chat = ChatAnthropicBedrock(
            model=model_id,
            aws_region=region
        )
        
        console.print("[green]✅ Browser session initialized and ready[/green]")
        return browser_session, bedrock_chat, client 
        
    except Exception as e:
        console.print(f"[red]❌ Failed to initialize browser session: {e}[/red]")
        raise

# Tools for Specialist Agent
@tool
def get_weather_data(city: str) -> Dict[str, Any]:
    """Get weather data for a city using wttr.in API"""
    import requests
    from datetime import datetime, timedelta
    
    try:
        console.print(f"[cyan]🌐 Getting weather data for {city}[/cyan]")
        
        # Fetch weather data from wttr.in
        url = f"https://wttr.in/{city}?format=j1"
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        console.print(f"[green]✅ Successfully fetched weather data[/green]")
        
        # Extract forecast data
        weather_forecast = []
        base_date = datetime.utcnow()  # Get current date dynamically
        console.print(f"[cyan]📅 Base date: {base_date.strftime('%Y-%m-%d')}[/cyan]")
        
        for i, day in enumerate(data.get('weather', [])[:7]):
            forecast_date = base_date + timedelta(days=i)
            date_str = forecast_date.strftime("%Y-%m-%d")
            
            # Get conditions from hourly data (use midday forecast)
            hourly = day.get('hourly', [])
            midday_data = hourly[len(hourly)//2] if hourly else {}
            
            conditions = midday_data.get('weatherDesc', [{}])[0].get('value', 'Unknown')
            wind = midday_data.get('windspeedMiles', 0)
            precip = midday_data.get('chanceofrain', 0)
            
            weather_forecast.append({
                "date": date_str,
                "high": int(day.get('maxtempF', 0)),
                "low": int(day.get('mintempF', 0)),
                "conditions": conditions,
                "wind": int(wind),
                "precip": int(precip)
            })
        
        result_json = json.dumps(weather_forecast, indent=2)
        console.print(f"[green]✅ Processed {len(weather_forecast)} days of forecast[/green]")
        
        return {
            "status": "success",
            "content": [{"text": result_json}]
        }
        
    except Exception as e:
        console.print(f"[red]❌ Error getting weather data: {e}[/red]")
        return {
            "status": "error",
            "content": [{"text": f"Error getting weather data: {str(e)}"}]
        }

@tool
def generate_analysis_code(weather_data: str) -> Dict[str, Any]:
    """Generate Python code for weather classification"""
    try:
        query = f"""Create Python code to classify weather days as GOOD/OK/POOR:
        
        Rules: 
        - GOOD: 65-80°F, clear conditions, no rain
        - OK: 55-85°F, partly cloudy, slight rain chance  
        - POOR: <55°F or >85°F, cloudy/rainy
        
        Weather data: 
        {weather_data} 

        Store weather data stored in python variable for using it in python code 

        Return code that outputs list of tuples: [('2025-09-16', 'GOOD'), ('2025-09-17', 'OK'), ...]"""
        
        agent = Agent()
        result = agent(query)
        
        pattern = r'```(?:json|python)\n(.*?)\n```'
        match = re.search(pattern, result.message['content'][0]['text'], re.DOTALL)
        python_code = match.group(1).strip() if match else result.message['content'][0]['text']
        
        return {"status": "success", "content": [{"text": python_code}]}
    except Exception as e:
        return {"status": "error", "content": [{"text": f"Error: {str(e)}"}]}

@tool 
def execute_code(python_code: str) -> Dict[str, Any]:
    """Execute Python code using AgentCore Code Interpreter"""
    try:
        code_client = CodeInterpreter('us-west-2')
        code_client.start(identifier=CODE_INTERPRETER_ID)

        response = code_client.invoke("executeCode", {
            "code": python_code,
            "language": "python",
            "clearContext": True
        })

        for event in response["stream"]:
            code_execute_result = json.dumps(event["result"])
        
        analysis_results = json.loads(code_execute_result)
        console.print("Analysis results:", analysis_results)

        return {"status": "success", "content": [{"text": str(analysis_results)}]}

    except Exception as e:
        return {"status": "error", "content": [{"text": f"Error: {str(e)}"}]}

@tool
def get_activity_preferences() -> Dict[str, Any]:
    """Get activity preferences from memory"""
    try:
        client = MemoryClient(region_name='us-west-2')
        response = client.list_events(
            memory_id=MEMORY_ID,
            actor_id="user123",
            session_id="session456",
            max_results=50,
            include_payload=True
        )
        
        preferences = response[0]["payload"][0]['blob'] if response else "No preferences found"
        return {"status": "success", "content": [{"text": preferences}]}
    except Exception as e:
        return {"status": "error", "content": [{"text": f"Error: {str(e)}"}]}

@tool
def generate_report_filename(city: str) -> Dict[str, Any]:
    """Generate a standardized filename for the weather report"""
    try:
        # Get current date in YYYY-MM-DD format
        current_date = datetime.utcnow().strftime("%Y-%m-%d")
        
        # Clean city name: replace spaces with underscores, remove special characters
        clean_city = city.replace(" ", "_").replace(",", "").replace(".", "")
        
        # Generate filename
        filename = f"{clean_city}_{current_date}.md"
        
        return {
            "status": "success", 
            "content": [{
                "text": f"Filename: {filename}\\nCity: {clean_city}\\nDate: {current_date}"
            }]
        }
    except Exception as e:
        return {"status": "error", "content": [{"text": f"Error: {str(e)}"}]}

def create_specialist_agent() -> Agent:
    """Create a specialist agent that handles weather analysis and activity planning"""
    current_date = datetime.utcnow().strftime("%B %d, %Y")
    
    system_prompt = f"""You are a specialist Weather-Based Activity Planning Assistant with memory capabilities.

    CRITICAL DATE CONTEXT: 
    - Today is {current_date}
    - ALL weather forecasts must be for current dates or future dates
    - When generating reports, always verify dates are correct before proceeding

    You are an expert at:
    - Weather data analysis and classification
    - Activity planning based on weather conditions
    - Generating comprehensive reports
    - Code generation and execution for data analysis

    When asked about activities for a location, follow these steps sequentially:
    1. Extract city from user query
    2. Call get_weather_data(city) to get weather information
    3. Call generate_analysis_code(weather_data) to create classification code
    4. Call execute_code(python_code) to get Day Type (GOOD, OK, POOR) for forecasting dates
    5. Call get_activity_preferences() to get user preferences
    6. Call generate_report_filename(city) to get the standardized filename for the report
    7. Generate Activity Recommendations based on weather and preferences
    8. Generate comprehensive Markdown file content

    You can remember previous conversations and user preferences from past interactions.
    Provide complete, detailed analysis and recommendations."""
    
    # Initialize memory client and hook provider
    memory_client = MemoryClient(region_name=region)
    memory_hook = MemoryHookProvider(memory_client, MEMORY_ID, ACTOR_ID, SESSION_ID)
    
    return Agent(
        tools=[get_weather_data, generate_analysis_code, execute_code, get_activity_preferences, generate_report_filename, use_aws],
        system_prompt=system_prompt,
        name="SpecialistAgent",
        hooks=[memory_hook]
    )

@app.entrypoint
async def invoke(payload=None):
    """Main entrypoint for specialist agent"""
    try:
        # Get the query from payload
        query = payload.get("prompt", "Hello") if payload else "Hello"
        
        # Create and use the specialist agent
        agent = create_specialist_agent()
        response = agent(query)
        
        return {
            "status": "success",
            "agent": "specialist",
            "response": response.message['content'][0]['text']
        }
        
    except Exception as e:
        return {
            "status": "error",
            "agent": "specialist",
            "error": str(e)
        }

if __name__ == "__main__":
    app.run()