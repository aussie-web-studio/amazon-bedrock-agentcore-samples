# Multi-Agent Weather System

This directory contains a sophisticated multi-agent system for weather analysis and activity planning, deployable to AWS BedrockAgentCore. You can deploy either a **single agent** or a **multi-agent architecture**.

## 🏗️ Three-Agent Architecture

### Orchestrator Agent
- **File**: `orchestrator_agent.py`
- **Role**: Main entry point with intelligent routing
- **Capabilities**: 
  - Handles simple queries directly
  - Routes weather queries to Weather Agent
  - Routes general analysis to Specialist Agent
  - Dedicated memory for conversation history

### Specialist Agent
- **File**: `specialist_agent.py`
- **Role**: Expert for general detailed analysis
- **Capabilities**:
  - Complex reasoning and analysis tasks
  - Technical explanations and insights
  - Dedicated memory for analysis history

### Weather Agent
- **File**: `weather_agent.py`
- **Role**: Specialized weather analysis and activity planning
- **Capabilities**:
  - Weather data retrieval and analysis
  - Activity recommendations based on weather
  - Trip planning and outdoor suggestions
  - Full access to browser and code interpreter tools

## 📁 File Structure

```
agent-code/
├── orchestrator_agent.py    # Multi-agent: Orchestrator (routes queries)
├── specialist_agent.py      # Multi-agent: Specialist (general analysis)
├── weather_agent.py         # Multi-agent: Weather specialist
├── requirements.txt         # Python dependencies
├── Dockerfile               # Default (for single agent)
├── Dockerfile.orchestrator  # Multi-agent: Orchestrator container
├── Dockerfile.specialist    # Multi-agent: Specialist container
├── Dockerfile.weather       # Multi-agent: Weather agent container
└── README.md               # This file
```

## 🚀 Deployment Options

### Deploy Three-Agent System
```bash
# From parent directory  
./deploy.sh multi-agent-demo us-west-2

# This deploys all three agents: orchestrator, specialist, and weather
# Takes 25-30 minutes (builds 3 Docker images)
```

### Custom Deployment
```bash
./deploy.sh [STACK_NAME] [REGION] [MODEL_ID]

# Examples:
./deploy.sh my-weather-system us-east-1
./deploy.sh weather-prod us-west-2 anthropic.claude-3-5-sonnet-20241022-v2:0
```

## 🔧 Multi-Agent Architecture Details

### Orchestrator Agent (`orchestrator_agent.py`)
- **Role**: Routes queries and handles simple requests
- **Capabilities**: 
  - Direct response to greetings and basic questions
  - Delegates complex weather analysis to Specialist Agent
  - Has dedicated memory system for conversation history
  - Can save results to S3

### Specialist Agent (`specialist_agent.py`)
- **Role**: Performs general detailed analysis tasks
- **Capabilities**:
  - General data analysis and insights
  - Complex reasoning tasks
  - Dedicated memory system for analysis history
  - Access to browser and code interpreter tools

### Weather Agent (`weather_agent.py`)
- **Role**: Specialized weather analysis and activity planning
- **Capabilities**:
  - Weather data retrieval from wttr.in API
  - Python code generation and execution for weather analysis
  - Activity recommendations based on weather conditions
  - Trip planning and outdoor activity suggestions
  - Dedicated memory system for weather-related conversations
  - Full access to browser and code interpreter tools

### Shared Resources
- **Browser Tool**: Web automation (shared between agents)
- **Code Interpreter**: Python execution (shared between agents)  
- **S3 Bucket**: Report storage (accessible to both agents)
- **Memory Systems**: Separate memory for each agent

## 🛠️ Agent Features & Tools

### Weather Analysis Tools
- `get_weather_data(city)` - Fetch 7-day weather forecast for any city
- `generate_analysis_code(weather_data)` - Create Python code for weather classification
- `execute_code(python_code)` - Execute code using AgentCore Code Interpreter
- `get_activity_preferences()` - Retrieve user preferences from memory
- `generate_report_filename(city)` - Create standardized report filenames

### AWS Integration Tools
- `use_aws` - Upload reports and files to S3 bucket
- `save_to_s3(filename, content)` - Direct S3 upload capability

### Memory & Communication
- **Memory Hooks**: Automatic conversation history storage and retrieval
- **Inter-Agent Communication**: Orchestrator can invoke Specialist via ARN
- **Error Handling**: Robust error handling for all tool operations

## 🧪 Testing

### Test Individual Agent Components
```bash
# Test orchestrator (requires AGENT2_ARN environment variable)
python orchestrator_agent.py

# Test specialist independently  
python specialist_agent.py

# Test weather agent independently
python weather_agent.py
```

### Integration Testing
After deployment, test the complete system:
```bash
# Get runtime IDs from deployment output
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn "arn:aws:bedrock-agentcore:region:account:runtime/orchestrator-id" \
  --qualifier "DEFAULT" \
  --payload '{"prompt": "What should I do this weekend in San Francisco?"}'
```

## 📊 Usage Patterns

### Three-Agent Flow  
```
User Query → Orchestrator Agent → [Simple: Direct Response]
                                → [Weather-related: Weather Agent] → Weather Analysis → Response
                                → [General Analysis: Specialist Agent] → Analysis → Response
```

## 🧹 Cleanup

### Remove Deployment
```bash
# From parent directory
./cleanup.sh [STACK_NAME] [REGION]

# Examples:
./cleanup.sh multi-agent-demo us-west-2
./cleanup.sh single-agent-demo us-west-2
```

The cleanup script automatically:
- Empties and deletes ECR repositories
- Removes S3 buckets and contents
- Deletes AgentCore runtimes, tools, and memories
- Cleans up CloudWatch logs
- Removes all CloudFormation resources

## 🔧 Development Workflow

### Modify Agent Logic
1. **Orchestrator**: Edit `orchestrator_agent.py` for routing logic
2. **Specialist**: Edit `specialist_agent.py` for general analysis capabilities
3. **Weather**: Edit `weather_agent.py` for weather-specific functionality
4. Update `requirements.txt` if adding dependencies
5. Run deployment script to update

### Environment Variables (Auto-configured)
- `BROWSER_ID` - AgentCore Browser tool identifier
- `CODE_INTERPRETER_ID` - AgentCore Code Interpreter identifier  
- `MEMORY_ID` - AgentCore Memory identifier
- `RESULTS_BUCKET` - S3 bucket for storing reports
- `AWS_REGION` - Deployment region
- `BEDROCK_MODEL_ID` - LLM model identifier
- `AGENT2_ARN` - Specialist Agent ARN (multi-agent only)
- `AGENT3_ARN` - Weather Agent ARN (multi-agent only)

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed (for local testing)
- Python 3.11+ (for local testing)
- BedrockAgentCore access in target region

## 🎯 Choosing Your Architecture

**The Three-Agent System provides:**
- **Intelligent Routing**: Orchestrator automatically chooses the right specialist
- **Domain Expertise**: Weather Agent specialized for weather/activity planning
- **General Analysis**: Specialist Agent handles complex non-weather tasks
- **Scalable Architecture**: Clear separation of concerns across three agents
- **Resource Efficiency**: Shared tools reduce infrastructure costs
- **Easy Extensibility**: Simple to add more specialized agents

This architecture is ideal for production deployments requiring both weather analysis and general analytical capabilities with intelligent routing.