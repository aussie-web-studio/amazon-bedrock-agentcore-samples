# Multi-Agent Weather System with Tools and Memory

This CloudFormation template deploys a complete Amazon Bedrock AgentCore Runtime with a sophisticated three-agent architecture for weather-based activity planning and general analysis. This demonstrates the full power of AgentCore by integrating Browser tool, Code Interpreter, Memory, and S3 storage with intelligent agent orchestration.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Testing](#testing)
- [Sample Queries](#sample-queries)
- [How It Works](#how-it-works)
- [Cleanup](#cleanup)
- [Cost Estimate](#cost-estimate)
- [Troubleshooting](#troubleshooting)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

## Overview

This template creates a comprehensive AgentCore deployment with a **three-agent architecture**:

### 🏗️ Multi-Agent Architecture

#### Agent 1: Orchestrator Agent
- **File**: `agent-code/orchestrator_agent.py`
- **Role**: Main entry point for user queries with intelligent routing
- **Capabilities**: 
  - Handles simple queries directly
  - Routes weather queries to Weather Agent
  - Routes general analysis to Specialist Agent
  - Has dedicated memory for conversation history

#### Agent 2: Specialist Agent
- **File**: `agent-code/specialist_agent.py`
- **Role**: Expert agent for general detailed analysis
- **Capabilities**:
  - Provides in-depth analytical responses
  - Handles complex reasoning tasks
  - Focuses on accuracy and completeness for non-weather topics

#### Agent 3: Weather Agent
- **File**: `agent-code/weather_agent.py`
- **Role**: Specialized weather analysis and activity planning
- **Capabilities**:
  - Weather data retrieval and analysis
  - Activity recommendations based on weather
  - Trip planning and outdoor suggestions
  - Full access to browser and code interpreter tools

### Core Components

- **AgentCore Runtime(s)**: Hosts Strands agents with multiple tools
- **Browser Tool**: Web automation for scraping weather data (shared between agents)
- **Code Interpreter**: Python code execution for weather analysis (shared between agents)
- **Memory**: Stores user activity preferences (separate for each agent in multi-agent mode)
- **S3 Bucket**: Stores generated activity recommendations
- **ECR Repository/Repositories**: Container image storage
- **IAM Roles**: Comprehensive permissions for all components

### Agent Capabilities

The Weather Activity Planner system can:

1. **Scrape Weather Data**: Uses browser automation to fetch 8-day forecasts from weather.gov
2. **Analyze Weather**: Generates and executes Python code to classify days as GOOD/OK/POOR
3. **Retrieve Preferences**: Accesses user activity preferences from memory
4. **Generate Recommendations**: Creates personalized activity suggestions based on weather and preferences
5. **Store Results**: Saves recommendations as Markdown files in S3

### Use Cases

- Weather-based activity planning
- Automated web scraping and data analysis
- Multi-tool agent orchestration
- Memory-driven personalization
- Asynchronous task processing

## Architecture

![End-to-End Weather Agent Architecture](architecture.png)

The architecture demonstrates a complete AgentCore deployment with multiple integrated tools:

**Core Components:**
- **User**: Sends weather-based activity planning queries
- **AWS CodeBuild**: Builds the ARM64 Docker container image with the agent code
- **Amazon ECR Repository**: Stores the container image
- **AgentCore Runtime**: Hosts the Weather Activity Planner Agent
  - **Weather Agent**: Strands agent that orchestrates multiple tools
  - Invokes Amazon Bedrock LLMs for reasoning and code generation
- **Browser Tool**: Web automation for scraping weather data from weather.gov
- **Code Interpreter Tool**: Executes Python code for weather analysis
- **Memory**: Stores user activity preferences (30-day retention)
- **S3 Bucket**: Stores generated activity recommendations
- **IAM Roles**: Comprehensive permissions for all components

**Workflow:**
1. User sends query: "What should I do this weekend in Richmond VA?"
2. Agent extracts city and uses Browser Tool to scrape 8-day forecast
3. Agent generates Python code and uses Code Interpreter to classify weather
4. Agent retrieves user preferences from Memory
5. Agent generates personalized recommendations
6. Agent stores results in S3 bucket using use_aws tool

## Prerequisites

### AWS Account Setup

1. **AWS Account**: You need an active AWS account with appropriate permissions
   - [Create AWS Account](https://aws.amazon.com/account/)
   - [AWS Console Access](https://aws.amazon.com/console/)

2. **AWS CLI**: Install and configure AWS CLI with your credentials
   - [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
   - [Configure AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
   
   ```bash
   aws configure
   ```

3. **Bedrock Model Access**: Enable access to Amazon Bedrock models in your AWS region
   - Navigate to [Amazon Bedrock Console](https://console.aws.amazon.com/bedrock/)
   - [Bedrock Model Access Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html)

4. **Required Permissions**: Your AWS user/role needs permissions for:
   - CloudFormation stack operations
   - ECR repository management
   - IAM role creation
   - Lambda function creation
   - CodeBuild project creation
   - BedrockAgentCore resource creation (Runtime, Browser, CodeInterpreter, Memory)
   - S3 bucket creation

## Deployment

### 🚀 Deployment

The infrastructure automatically builds separate Docker images for all three agents and sets up intelligent routing.

#### **Deploy Three-Agent System**

```bash
# Make the script executable
chmod +x deploy.sh

# Deploy with defaults
./deploy.sh
# Uses stack name 'multi-agent-demo' in region 'us-west-2'

# Or specify custom parameters
./deploy.sh my-weather-system us-east-1
./deploy.sh weather-prod us-west-2 anthropic.claude-3-5-sonnet-20241022-v2:0
```

#### **Usage Options**

**Option 1: Use defaults (simplest)**
```bash
./deploy.sh
```
Uses default stack name `multi-agent-demo` in region `us-west-2`

**Option 2: Specify stack name only**
```bash
./deploy.sh my-custom-stack-name
```
Uses `my-custom-stack-name` in default region `us-west-2`

**Option 3: Specify all parameters**
```bash
./deploy.sh my-custom-stack-name us-east-1 anthropic.claude-3-5-sonnet-20241022-v2:0
```

#### **Default Values**
- **Stack Name**: `multi-agent-demo`
- **Region**: `us-west-2`
- **Model**: `amazon.nova-micro-v1:0`

**The script will:**
1. Generate deployment version from agent code hash
2. Upload CloudFormation template and agent code to S3
3. Deploy the CloudFormation stack with both agents
4. Build separate Docker images for Orchestrator and Specialist agents
5. Wait for stack creation to complete (20-25 minutes)
6. Display all resource IDs (Agent1 Runtime, Agent2 Runtime, Browser, CodeInterpreter, Memories, S3 Bucket)

### 📋 What Gets Deployed

#### Three-Agent Architecture
- **Orchestrator Agent**: Intelligent routing and simple query handling
- **Specialist Agent**: General analysis and complex reasoning tasks
- **Weather Agent**: Specialized weather analysis and activity planning
- **Shared Browser Tool**: Web automation capabilities (shared across agents)
- **Shared Code Interpreter**: Python execution environment (shared across agents)
- **Separate Memories**: Individual memory system for each agent
- **Shared S3 Bucket**: Results storage accessible to all agents
- **Triple ECR Repositories**: Separate container images for each agent
- **Comprehensive IAM**: Orchestrator can invoke both specialist agents
- **Complete Observability**: Separate CloudWatch logs and X-Ray traces for each agent

### Option 2: Using AWS CLI

```bash
# Deploy the stack
aws cloudformation create-stack \
  --stack-name weather-agent-demo \
  --template-body file://end-to-end-weather-agent.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2

# Wait for stack creation
aws cloudformation wait stack-create-complete \
  --stack-name weather-agent-demo \
  --region us-west-2

# Get all outputs
aws cloudformation describe-stacks \
  --stack-name weather-agent-demo \
  --region us-west-2 \
  --query 'Stacks[0].Outputs'
```

### Option 3: Using AWS Console

1. Navigate to [CloudFormation Console](https://console.aws.amazon.com/cloudformation/)
2. Click "Create stack" → "With new resources"
3. Upload the `end-to-end-weather-agent.yaml` file
4. Enter stack name: `weather-agent-demo`
5. Review parameters (or use defaults)
6. Check "I acknowledge that AWS CloudFormation might create IAM resources"
7. Click "Create stack"

### Deployment Time

- **Expected Duration**: 25-30 minutes (Multi-Agent)
- **Main Steps**:
  - Stack creation: ~2 minutes
  - Docker image builds (CodeBuild): ~20-23 minutes (3 separate builds)
  - Runtime and tools provisioning: ~3-5 minutes
  - Memory initialization: ~1 minute

### 🎯 Architecture Benefits

**The three-agent system provides:**
- **Intelligent Routing**: Orchestrator automatically chooses the right specialist
- **Domain Expertise**: Weather Agent specialized for weather/activity planning
- **Scalable Architecture**: Clear separation of concerns across three agents
- **Resource Efficiency**: Shared tools (browser, code interpreter) reduce costs
- **Better Maintainability**: Modular code structure with focused responsibilities
- **Easy Extensibility**: Simple to add more specialized agents

**For detailed agent code documentation, see:** `agent-code/README.md`

## Testing

### Test Agent 1 (Orchestrator) - Main Entry Point

The Orchestrator Agent is your main entry point. It intelligently routes queries to the appropriate specialist agent.

#### Using AWS CLI

```bash
# Get Agent1 Runtime ID and construct ARN
AGENT1_ID=$(aws cloudformation describe-stacks \
  --stack-name multi-agent-demo \
  --region us-west-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`Agent1RuntimeId`].OutputValue' \
  --output text)

# Get account ID and construct the ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
AGENT1_ARN="arn:aws:bedrock-agentcore:${REGION}:${ACCOUNT_ID}:runtime/${AGENT1_ID}"

# Test with a simple query (Orchestrator handles directly)
PAYLOAD1=$(echo -n '{"prompt": "Hello, how are you?"}' | base64)
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn $AGENT1_ARN \
  --qualifier DEFAULT \
  --payload $PAYLOAD1 \
  --region us-west-2 \
  response1.json

# Test with a weather query (Orchestrator delegates to Weather Agent)
PAYLOAD2=$(echo -n '{"prompt": "What should I do this weekend in Richmond VA?"}' | base64)
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn $AGENT1_ARN \
  --qualifier DEFAULT \
  --payload $PAYLOAD2 \
  --region us-west-2 \
  response2.json

# Test with a general analysis query (Orchestrator delegates to Specialist Agent)
PAYLOAD3=$(echo -n '{"prompt": "Provide a detailed analysis of cloud computing benefits"}' | base64)
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn $AGENT1_ARN \
  --qualifier DEFAULT \
  --payload $PAYLOAD3 \
  --region us-west-2 \
  response3.json

# View responses
echo "=== Simple Query Response ==="
cat response1.json
echo -e "\n=== Weather Query Response ==="
cat response2.json
echo -e "\n=== Analysis Query Response ==="
cat response3.json
```

### Test Individual Agents Directly

You can also test the specialist agents directly to see their specific capabilities.

#### Test Agent 2 (Specialist) Directly

```bash
# Get Agent2 Runtime ID and construct ARN
AGENT2_ID=$(aws cloudformation describe-stacks \
  --stack-name multi-agent-demo \
  --region us-west-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`Agent2RuntimeId`].OutputValue' \
  --output text)

AGENT2_ARN="arn:aws:bedrock-agentcore:${REGION}:${ACCOUNT_ID}:runtime/${AGENT2_ID}"

# Test Specialist Agent directly
PAYLOAD_SPECIALIST=$(echo -n '{"prompt": "Explain quantum computing in detail"}' | base64)
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn $AGENT2_ARN \
  --qualifier DEFAULT \
  --payload $PAYLOAD_SPECIALIST \
  --region us-west-2 \
  specialist_response.json

cat specialist_response.json
```

#### Test Agent 3 (Weather) Directly

```bash
# Get Agent3 Runtime ID and construct ARN
AGENT3_ID=$(aws cloudformation describe-stacks \
  --stack-name multi-agent-demo \
  --region us-west-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`Agent3RuntimeId`].OutputValue' \
  --output text)

AGENT3_ARN="arn:aws:bedrock-agentcore:${REGION}:${ACCOUNT_ID}:runtime/${AGENT3_ID}"

# Test Weather Agent directly
PAYLOAD_WEATHER=$(echo -n '{"prompt": "Plan activities for next week in San Francisco"}' | base64)
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn $AGENT3_ARN \
  --qualifier DEFAULT \
  --payload $PAYLOAD_WEATHER \
  --region us-west-2 \
  weather_response.json

cat weather_response.json

# Check S3 for weather reports (Weather Agent saves detailed reports)
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name multi-agent-demo \
  --region us-west-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`ResultsBucket`].OutputValue' \
  --output text)

# Wait a few minutes for processing, then check S3 for results
aws s3 ls s3://$BUCKET_NAME/
```

### Using AWS Console

1. Navigate to [Bedrock AgentCore Console](https://console.aws.amazon.com/bedrock-agentcore/)
2. Go to "Runtimes" in the left navigation
3. Find your Orchestrator runtime (name starts with `multi_agent_demo_OrchestratorAgent`)
4. Click on the runtime name
5. Click "Test" button
6. Enter test payload:
   ```json
   {
     "prompt": "What should I do this weekend in Richmond VA?"
   }
   ```
7. Click "Invoke"
8. View the response to see how the Orchestrator routes to the Weather Agent

## Sample Queries

### Queries Handled Directly by Orchestrator

These simple queries don't require specialist knowledge:

1. **Greetings**:
   ```json
   {"prompt": "Hello, how are you?"}
   ```

2. **Simple Questions**:
   ```json
   {"prompt": "What can you help me with?"}
   ```

### Queries Routed to Weather Agent

These weather-related queries are automatically routed to the Weather Agent:

1. **Weekend Planning**:
   ```json
   {"prompt": "What should I do this weekend in Richmond VA?"}
   ```

2. **Trip Planning**:
   ```json
   {"prompt": "Plan activities for next week in San Francisco"}
   ```

3. **Weather-Based Activities**:
   ```json
   {"prompt": "What outdoor activities can I do in Seattle this week?"}
   ```

4. **Vacation Planning**:
   ```json
   {"prompt": "I'm visiting Austin next week. What should I plan based on the weather?"}
   ```

### Queries Routed to Specialist Agent

These complex analysis queries are routed to the Specialist Agent:

1. **Detailed Analysis**:
   ```json
   {"prompt": "Provide a detailed analysis of the benefits and drawbacks of serverless architecture"}
   ```

2. **Expert Knowledge**:
   ```json
   {"prompt": "Explain the CAP theorem and its implications for distributed systems"}
   ```

3. **Complex Reasoning**:
   ```json
   {"prompt": "Compare and contrast different machine learning algorithms for time series forecasting"}
   ```

4. **Technical Analysis**:
   ```json
   {"prompt": "Provide expert analysis on best practices for securing cloud infrastructure"}
   ```

## How It Works

### Step-by-Step Workflow (Three-Agent System)

1. **User Query**: "What should I do this weekend in Richmond VA?"

2. **Orchestrator Agent**: Receives query and analyzes content

3. **Intelligent Routing**: Orchestrator determines this is weather-related and routes to Weather Agent

4. **Weather Agent Processing**: Weather Agent extracts "Richmond VA" from the query

5. **Weather Scraping** (Browser Tool):
   - Navigates to weather.gov
   - Searches for Richmond VA
   - Clicks "Printable Forecast"
   - Extracts 8-day forecast data (date, high, low, conditions, wind, precipitation)
   - Returns JSON array of weather data

4. **Code Generation** (LLM):
   - Agent generates Python code to classify weather days
   - Classification rules:
     - GOOD: 65-80°F, clear, no rain
     - OK: 55-85°F, partly cloudy, slight rain
     - POOR: <55°F or >85°F, cloudy/rainy

5. **Code Execution** (Code Interpreter):
   - Executes the generated Python code
   - Returns list of tuples: `[('2025-09-16', 'GOOD'), ('2025-09-17', 'OK'), ...]`

6. **Preference Retrieval** (Memory):
   - Fetches user activity preferences from memory
   - Preferences stored by weather type:
     ```json
     {
       "good_weather": ["hiking", "beach volleyball", "outdoor picnic"],
       "ok_weather": ["walking tours", "outdoor dining", "park visits"],
       "poor_weather": ["indoor museums", "shopping", "restaurants"]
     }
     ```

7. **Recommendation Generation** (LLM):
   - Combines weather analysis with user preferences
   - Creates day-by-day activity recommendations
   - Formats as Markdown document

8. **Response Chain**: 
   - Weather Agent returns detailed analysis to Orchestrator Agent
   - Orchestrator Agent returns final response to user

9. **Storage** (S3 via use_aws tool):
   - Weather Agent saves detailed reports to S3 bucket with standardized filenames
   - User can download comprehensive weather and activity reports

### Three-Agent Benefits

- **Intelligent Routing**: Orchestrator automatically chooses the right specialist
- **Domain Expertise**: Weather Agent specialized for weather/activity planning
- **General Analysis**: Specialist Agent handles complex non-weather tasks
- **Scalability**: Easy to add more specialist agents for different domains
- **Resource Efficiency**: Shared tools (browser, code interpreter) reduce costs
- **Memory Isolation**: Each agent maintains its own conversation context
- **Fault Tolerance**: If one specialist fails, others can still operate

## Cleanup

The enhanced cleanup script performs a **complete removal** of all resources created by the three-agent system stack.

### 🗂️ **Resources Cleaned Up**

#### **AgentCore Resources**
- ✅ **Agent1 Runtime** - Orchestrator agent execution environment
- ✅ **Agent2 Runtime** - Specialist agent execution environment
- ✅ **Agent3 Runtime** - Weather agent execution environment
- ✅ **Browser Tool** - Web automation capabilities (shared)
- ✅ **Code Interpreter Tool** - Python code execution environment (shared)
- ✅ **Memory Stores** - Individual conversation history for each agent

#### **Infrastructure Resources**
- ✅ **ECR Repositories** - Three container registries (and all Docker images)
- ✅ **Results S3 Bucket** - Agent output files (and all contents)
- ✅ **Template S3 Bucket** - CloudFormation templates
- ✅ **CodeBuild Projects** - Three container image building projects
- ✅ **Lambda Functions** - Custom resource handlers
- ✅ **IAM Roles & Policies** - All permissions and access policies for all agents

#### **Monitoring Resources**
- ✅ **CloudWatch Log Groups** - All application logs (including auto-created Lambda/CodeBuild logs)
- ✅ **CloudWatch Log Delivery** - Log routing configuration
- ✅ **X-Ray Traces** - Distributed tracing data

### Using the Cleanup Script (Recommended)

```bash
# Make the script executable
chmod +x cleanup.sh
```

#### **Usage Options**

**Option 1: Use defaults (simplest)**
```bash
./cleanup.sh
```
Uses default stack name `multi-agent-demo` in region `us-west-2`

**Option 2: Specify stack name only**
```bash
./cleanup.sh my-custom-stack-name
```
Uses `my-custom-stack-name` in default region `us-west-2`

**Option 3: Specify both stack name and region**
```bash
./cleanup.sh my-custom-stack-name us-east-1
```
Uses `my-custom-stack-name` in `us-east-1` region

#### **Default Values**
- **Stack Name**: `multi-agent-demo`
- **Region**: `us-west-2`

**The script automatically:**
1. **Pre-cleanup**: Empties S3 buckets and ECR repositories
2. **Stack Deletion**: Removes all CloudFormation resources
3. **Post-cleanup**: Removes template storage bucket and auto-created log groups

### 📋 **CloudWatch Log Groups Cleanup**

The cleanup script now properly handles **all CloudWatch log groups**, including those automatically created by AWS services:

#### **CloudFormation-Managed Log Groups** (Deleted automatically)
- `/aws/vendedlogs/bedrock-agentcore/{runtime-id}` - AgentCore application logs
- Log delivery sources and destinations

#### **Auto-Created Log Groups** (Cleaned up post-stack deletion)
- `/aws/lambda/{stack-name}-codebuild-trigger` - Lambda function logs
- `/aws/lambda/{stack-name}-memory-initializer` - Lambda function logs  
- `/aws/codebuild/{stack-name}-*-build` - CodeBuild project logs

#### **If Log Groups Persist**

Some log groups may occasionally persist due to AWS eventual consistency or timing issues. If this happens:

**Option 1: Use the standalone cleanup script**
```bash
./cleanup-logs-only.sh [stack-name] [region]
```

**Option 2: Manual cleanup via AWS CLI**
```bash
# List remaining log groups
aws logs describe-log-groups --query 'logGroups[].logGroupName' --output table

# Delete specific log group
aws logs delete-log-group --log-group-name "/aws/lambda/multi-agent-demo-codebuild-trigger"
```

> **Note**: Lambda log groups may recreate automatically if the Lambda function is invoked again. This is normal AWS behavior.
4. **Verification**: Confirms all resources are deleted

### Using AWS CLI (Manual)

```bash
# Get resource information
STACK_NAME="multi-agent-demo"
REGION="us-west-2"

# Empty Results S3 bucket
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ResultsBucket`].OutputValue' \
  --output text)

aws s3 rm s3://$BUCKET_NAME --recursive

# Empty ECR repository
ECR_REPO=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryName`].OutputValue' \
  --output text)

aws ecr batch-delete-image \
  --repository-name $ECR_REPO \
  --region $REGION \
  --image-ids "$(aws ecr list-images --repository-name $ECR_REPO --region $REGION --query 'imageIds' --output json)"

# Delete the stack
aws cloudformation delete-stack \
  --stack-name $STACK_NAME \
  --region $REGION

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name $STACK_NAME \
  --region $REGION
```

### ⚠️ **Important Notes**

- **Irreversible**: All data will be permanently deleted
- **Complete**: No resources will be left behind
- **Safe**: Asks for confirmation before proceeding
- **Thorough**: Handles edge cases and dependencies

### 🛡️ **What Gets Preserved**

- Your local `agent-code/` folder (source code)
- CloudFormation template files
- Deploy and cleanup scripts
- Any other AWS resources not created by this stack

### 🚨 **Before Running Cleanup**

1. **Backup important data** from the Results S3 bucket
2. **Save any logs** you need from CloudWatch
3. **Confirm the stack name** and region
4. **Ensure you have proper AWS permissions**
