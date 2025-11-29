# MCP Server on AgentCore Runtime - Implementation Guide

Complete guide for deploying, testing, and managing an MCP Server with AgentCore Memory integration.

## ⚡ Quick Reference

### **Just Want to Deploy? Choose One:**

```bash
# 🧠 Smart AI Assistant (Recommended)
./deploy-advanced.sh my-smart-agent

# 💾 Simple & Fast Testing  
./deploy-basic.sh my-test-agent

# 🎯 Need Help Choosing?
./configure-deploy.sh
```

### **After Deployment:**
```bash
# Test everything works
./test.sh YOUR_STACK_NAME us-west-2

# Clean up when done
./cleanup.sh YOUR_STACK_NAME us-west-2
```

---

## Prerequisites

- AWS CLI configured with appropriate permissions
- Python 3.9+ with pip
- Docker (for local testing)
- AWS account with Bedrock AgentCore access

## 🎯 Choose Your Deployment Path

### 🧠 **Advanced Memory (AI-Powered Intelligence)**
**Best for:** Personal assistants, customer support, learning systems

**Features:**
- ✅ AI-powered user preference extraction
- ✅ Intelligent conversation summarization  
- ✅ Cross-session memory continuity
- ✅ Structured namespace organization
- ✅ Long-term learning capabilities

```bash
./deploy-advanced.sh my-smart-agent us-west-2
```

### 💾 **Basic Memory (Simple & Fast)**
**Best for:** Testing, simple tools, stateless operations

**Features:**
- ✅ Simple conversation storage
- ✅ Event logging with actor/session organization
- ✅ Lower cost and complexity
- ✅ Immediate availability
- ✅ Single-stack deployment

```bash
./deploy-basic.sh my-basic-agent us-west-2
```

### 🎯 **Interactive Deployment (Guided)**
**Best for:** First-time users, exploring options

```bash
./configure-deploy.sh
# Guides you through all options with explanations
```

## 🤔 Which Option Should I Choose?

### 🧠 **Choose Advanced Memory If:**
- ✅ Building a **personal assistant** or **customer support** system
- ✅ Need **user preference learning** and **personalization**
- ✅ Want **cross-session memory continuity**
- ✅ Building **long-term user relationships**
- ✅ Need **intelligent conversation summarization**
- ✅ Cost is less important than intelligence
- ✅ Users will have **repeated interactions**

**Examples:** Personal AI assistant, customer support bot, learning companion, therapy chatbot

### 💾 **Choose Basic Memory If:**
- ✅ **Testing** or **prototyping** MCP functionality
- ✅ Building **simple tools** without personalization
- ✅ Need **cost-effective** solution
- ✅ Want **immediate deployment** (single stack)
- ✅ **Stateless operations** are sufficient
- ✅ Simple **conversation logging** is enough
- ✅ **Quick development cycles**

**Examples:** Calculator tools, weather services, simple APIs, development testing

### 🎯 **Still Unsure?**
Start with **Interactive Deployment** to explore both options:
```bash
./configure-deploy.sh
```

---

## 📊 Memory Types Comparison

| Feature | Basic Memory | Advanced Memory |
|---------|--------------|-----------------|
| **Deployment Time** | ~12 minutes | ~15 minutes |
| **Deployment Method** | Single CloudFormation stack | Hybrid (CloudFormation + Python SDK) |
| **Memory Creation** | CloudFormation resource | Python SDK with AI strategies |
| **Intelligence Level** | Simple storage | AI-powered extraction |
| **User Preferences** | Manual retrieval only | Automatic extraction & recall |
| **Cross-session Memory** | Basic event history | Intelligent preference continuity |
| **Namespace Organization** | Basic events | Structured (`user/{actorId}/preferences`) |
| **Cost** | Lower | Higher (AI processing) |
| **Complexity** | Simple | Advanced |
| **Learning Capability** | None | Automatic user preference learning |
| **Personalization** | Manual only | Automatic AI-powered |
| **Use Cases** | Testing, simple tools | Personal assistants, customer support |

## 🚀 Deployment Options

### 🧠 **Advanced Memory Deployment (AI-Powered)**

**When to use:** Personal assistants, customer support, learning systems that need intelligence

```bash
./deploy-advanced.sh STACK_NAME [REGION] [LLM_MODEL] [MEMORY_EXPIRY_DAYS]
```

**Examples:**
```bash
# Default configuration (recommended)
./deploy-advanced.sh my-smart-agent

# Custom region and model
./deploy-advanced.sh my-smart-agent us-west-2 anthropic.claude-3-5-sonnet-20241022-v2:0

# Custom retention period (90 days)
./deploy-advanced.sh my-smart-agent us-west-2 anthropic.claude-3-5-sonnet-20241022-v2:0 90
```

**🔄 Deployment Process (3 Phases):**
1. **Phase 1: Infrastructure** (~10 minutes) - ECR, Cognito, IAM, Docker build
2. **Phase 2: Advanced Memory** (~3 minutes) - AI strategies via Python SDK  
3. **Phase 3: Runtime** (~2 minutes) - MCP Server with memory integration

**✨ What you get:**
- AI-powered user preference extraction
- Intelligent conversation summarization
- Cross-session memory continuity
- Structured namespace organization (`user/{actorId}/preferences`)

---

### 💾 **Basic Memory Deployment (Simple & Fast)**

**When to use:** Testing, simple tools, stateless operations, cost-sensitive deployments

```bash
./deploy-basic.sh STACK_NAME [REGION] [LLM_MODEL] [ADVANCED_MEMORY] [MEMORY_EXPIRY_DAYS]
```

**Examples:**
```bash
# Quick basic deployment (7-day retention)
./deploy-basic.sh my-basic-agent us-west-2

# Basic with longer retention (30 days)
./deploy-basic.sh my-basic-agent us-west-2 amazon.nova-micro-v1:0 false 30

# Cost-optimized version
./deploy-basic.sh test-agent us-west-2 amazon.nova-micro-v1:0 false 7
```

**🔄 Deployment Process (Single Phase):**
1. **Single-Stack Deployment** (~12 minutes) - Everything in one CloudFormation stack
2. **Basic Memory** - Simple conversation storage via CloudFormation
3. **Immediate Runtime** - MCP Server ready immediately

**✨ What you get:**
- Simple conversation storage
- Event logging with actor/session organization
- Lower cost and complexity
- Immediate availability

---

### 🎯 **Interactive Deployment (Guided)**

**When to use:** First-time deployment, exploring options, unsure which type to choose

```bash
./configure-deploy.sh
```

**What it does:**
- Guides you through all configuration options
- Explains memory types and LLM models
- Shows deployment summary before proceeding
- Automatically chooses the right deployment script

## 📋 Parameters Reference

### 🧠 **Advanced Memory Parameters (deploy-advanced.sh)**

| Parameter | Description | Default | Required | Options |
|-----------|-------------|---------|----------|---------|
| `STACK_NAME` | CloudFormation stack name | - | ✅ Yes | Any valid stack name |
| `REGION` | AWS region | `us-west-2` | ❌ No | Any Bedrock region |
| `LLM_MODEL` | Bedrock model ID | `anthropic.claude-3-5-sonnet-20241022-v2:0` | ❌ No | Any Bedrock model |
| `MEMORY_EXPIRY_DAYS` | Memory retention period | `30` | ❌ No | 1-365 days |

**Usage:**
```bash
./deploy-advanced.sh my-smart-agent us-west-2 anthropic.claude-3-5-sonnet-20241022-v2:0 90
```

### 💾 **Basic Memory Parameters (deploy-basic.sh)**

| Parameter | Description | Default | Required | Options |
|-----------|-------------|---------|----------|---------|
| `STACK_NAME` | CloudFormation stack name | - | ✅ Yes | Any valid stack name |
| `REGION` | AWS region | `us-west-2` | ❌ No | Any Bedrock region |
| `LLM_MODEL` | Bedrock model ID | `amazon.nova-micro-v1:0` | ❌ No | Any Bedrock model |
| `ADVANCED_MEMORY` | Enable advanced memory | `false` | ❌ No | **Must be false** |
| `MEMORY_EXPIRY_DAYS` | Memory retention period | `30` | ❌ No | 1-365 days |

**Usage:**
```bash
./deploy-basic.sh my-basic-agent us-west-2 amazon.nova-micro-v1:0 false 7
```

## 🤖 Available LLM Models

### **Recommended for Advanced Memory**
- `anthropic.claude-3-5-sonnet-20241022-v2:0` - **Best quality** for AI strategies
- `anthropic.claude-3-haiku-20240307-v1:0` - **Balanced** performance and cost

### **Recommended for Basic Memory**
- `amazon.nova-micro-v1:0` - **Most cost-effective** for simple operations
- `amazon.nova-lite-v1:0` - **Good balance** of cost and capability

### **Performance Comparison**
| Model | Cost | Quality | Speed | Best For |
|-------|------|---------|-------|----------|
| `amazon.nova-micro-v1:0` | Lowest | Good | Fastest | Basic memory, testing |
| `amazon.nova-lite-v1:0` | Low | Better | Fast | Basic memory, production |
| `anthropic.claude-3-haiku-20240307-v1:0` | Medium | High | Medium | Advanced memory, balanced |
| `anthropic.claude-3-5-sonnet-20241022-v2:0` | Higher | Highest | Medium | Advanced memory, best quality |

## 🧠 Memory Configuration Deep Dive

### 💾 **Basic Memory**
**Architecture:** Single CloudFormation stack with built-in memory resource

**Features:**
- ✅ Simple conversation storage
- ✅ Event logging with actor/session organization
- ✅ Lower cost and complexity
- ✅ Immediate availability
- ✅ No AI processing overhead

**Storage Structure:**
```
Events:
├── actor_id: "user123"
├── session_id: "session456"  
├── timestamp: "2024-01-15T10:30:00Z"
└── payload: [conversation_data]
```

**Best for:**
- Testing and development
- Simple tools without personalization
- Stateless operations
- Cost-sensitive deployments
- Quick prototyping

---

### 🧠 **Advanced Memory**
**Architecture:** Hybrid deployment with Python SDK-created memory + AI strategies

**Features:**
- ✅ AI-powered user preference extraction
- ✅ Intelligent conversation summarization
- ✅ Cross-session memory continuity
- ✅ Structured namespace organization
- ✅ Long-term learning capabilities
- ✅ Automatic preference recall

**Storage Structure:**
```
Namespaces:
├── user/{actorId}/preferences/
│   ├── food_preferences
│   ├── communication_style
│   └── learning_preferences
├── user/{actorId}/conversations/
│   └── session_summaries
└── global/
    └── system_preferences
```

**AI Strategies:**
- **UserPreferences**: Extracts and organizes user preferences automatically
- **ConversationSummarization**: Creates intelligent summaries for long-term context
- **CrossSessionContinuity**: Maintains context across multiple sessions

**Best for:**
- Personal assistants
- Customer support systems
- Learning companions
- Applications requiring personalization
- Long-term user relationships

## 🔄 Deployment Process Explained

### 🧠 **Advanced Memory Deployment Process**

#### **Step 1: Choose Advanced Memory**
```bash
./deploy-advanced.sh my-smart-agent us-west-2
```

#### **Step 2: Automatic 3-Phase Deployment**

**📦 Phase 1: Infrastructure (~10 minutes)**
```
Creating infrastructure stack...
✅ ECR Repository created
✅ Docker image built and pushed  
✅ Cognito User Pool configured
✅ IAM roles and policies created
✅ Infrastructure ready for memory integration
```

**🧠 Phase 2: Advanced Memory (~3 minutes)**
```
Creating advanced memory with AI strategies...
✅ Memory created with UserPreferences strategy
✅ Memory ID stored in SSM Parameter Store
✅ Sample conversation data initialized
✅ AI strategies activated and ready
```

**🚀 Phase 3: Runtime (~2 minutes)**
```
Deploying MCP Server Runtime...
✅ Runtime stack created
✅ Memory integration configured
✅ Environment variables set
✅ MCP Server ready for requests
```

#### **Step 3: Deployment Complete**
```
🎉 Advanced Memory Deployment Complete!
========================================
📋 Deployment Summary:
  Stack Name: my-smart-agent
  Region: us-west-2
  Client ID: abc123...
  Agent ARN: arn:aws:bedrock-agentcore:...
  Memory ID: my_smart_agent_MCPServerMemory-xyz789
  Memory Type: Advanced (with AI strategies)

🧠 Advanced Memory Features Active:
  • User preference extraction
  • Conversation summarization  
  • Long-term memory strategies
  • Structured namespace organization

🧪 Next Steps:
  1. Test everything: ./test.sh my-smart-agent us-west-2
  2. Check AWS Console for memory strategies
  3. Start using your intelligent MCP server!
```

---

### 💾 **Basic Memory Deployment Process**

#### **Step 1: Choose Basic Memory**
```bash
./deploy-basic.sh my-basic-agent us-west-2
```

#### **Step 2: Single-Phase Deployment**

**📦 Single Phase: Complete Stack (~12 minutes)**
```
Creating complete stack with basic memory...
✅ ECR Repository created
✅ Docker image built and pushed
✅ Cognito User Pool configured  
✅ Basic memory created via CloudFormation
✅ MCP Server Runtime deployed
✅ IAM roles and policies configured
✅ Everything ready immediately
```

#### **Step 3: Deployment Complete**
```
🎉 Basic Memory Deployment Complete!
=====================================
📋 Deployment Summary:
  Stack Name: my-basic-agent
  Region: us-west-2
  Client ID: abc123...
  Agent ARN: arn:aws:bedrock-agentcore:...
  Memory ID: BasicMemory-xyz789
  Memory Type: Basic (simple storage)

💾 Basic Memory Features Active:
  • Simple conversation storage
  • Event logging by actor/session
  • Immediate availability
  • Cost-effective operation

🧪 Next Steps:
  1. Test everything: ./test.sh my-basic-agent us-west-2
  2. Start using your MCP server!
```

---

### ✅ **Verify Deployment**

#### **Check Stack Status**
```bash
# For advanced memory (2 stacks)
aws cloudformation describe-stacks --stack-name my-smart-agent --region us-west-2
aws cloudformation describe-stacks --stack-name my-smart-agent-runtime --region us-west-2

# For basic memory (1 stack)
aws cloudformation describe-stacks --stack-name my-basic-agent --region us-west-2
```

#### **Get Stack Outputs**
```bash
aws cloudformation describe-stacks \
  --stack-name YOUR_STACK \
  --query 'Stacks[0].Outputs' \
  --region YOUR_REGION
```

#### **Verify Memory Type**
```bash
# Check if advanced memory exists
python -c "
from bedrock_agentcore.memory import MemoryClient
client = MemoryClient(region_name='us-west-2')
memories = client.list_memories()
for memory in memories:
    print(f'Memory: {memory[\"memoryId\"]} - Type: {memory.get(\"memoryType\", \"Basic\")}')
"
```

## Testing

### Complete Test Suite
```bash
./test.sh my-mcp-server us-west-2
```

**Tests performed:**
1. **Configuration Validation** - Verifies stack outputs
2. **Memory Validation** - Checks memory configuration and access
3. **Authentication** - Gets Cognito JWT token
4. **MCP Tools Testing** - Tests add_numbers, multiply_numbers, greet_user
5. **Memory Functionality** - Comprehensive memory testing

### Memory-Only Testing
```bash
./test-memory-only.sh my-mcp-server us-west-2
```

**Memory tests:**
- Memory storage and retrieval
- Cross-session persistence
- MCP integration with memory
- Advanced memory querying (if enabled)

### Quick Memory Validation
```bash
python validate_memory.py my-mcp-server us-west-2
```

**Validates:**
- Memory exists and is accessible
- Configuration matches deployment
- Basic operations work
- Advanced strategies (if enabled)

### Install Test Dependencies
```bash
pip install -r requirements.txt
```

## Manual Testing

### Get Authentication Token
```bash
python get_token.py CLIENT_ID testuser MyPassword123! REGION
```

### Test MCP Server Directly
```bash
python test_mcp_server.py AGENT_ARN JWT_TOKEN REGION
```

### Test Memory Functionality
```bash
python test_memory.py AGENT_ARN JWT_TOKEN REGION STACK_NAME
```

## Monitoring and Management

### View Logs
```bash
# CloudFormation events
aws cloudformation describe-stack-events --stack-name YOUR_STACK --region YOUR_REGION

# AgentCore Runtime logs (check CloudWatch)
aws logs describe-log-groups --log-group-name-prefix "/aws/bedrock-agentcore" --region YOUR_REGION
```

### Memory Operations
```bash
# List memory events
aws bedrock-agentcore list-events --memory-id MEMORY_ID --region YOUR_REGION

# Get memory details
aws bedrock-agentcore get-memory --memory-id MEMORY_ID --region YOUR_REGION

# Retrieve memories (advanced memory only)
aws bedrock-agentcore retrieve-memories \
  --memory-id MEMORY_ID \
  --namespace "user/test_user/preferences" \
  --query "mathematical operations" \
  --top-k 5 \
  --region YOUR_REGION
```

### Stack Management
```bash
# Update stack (change memory configuration)
aws cloudformation update-stack \
  --stack-name YOUR_STACK \
  --template-body file://mcp-server-template.yaml \
  --parameters ParameterKey=EnableAdvancedMemory,ParameterValue=true \
  --capabilities CAPABILITY_NAMED_IAM \
  --region YOUR_REGION

# Check stack status
aws cloudformation describe-stacks --stack-name YOUR_STACK --region YOUR_REGION
```

## Troubleshooting

### Common Issues

#### Deployment Fails
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name YOUR_STACK --region YOUR_REGION

# Common causes:
# - Insufficient IAM permissions
# - Resource limits exceeded
# - Invalid parameter values
```

#### Authentication Errors
```bash
❌ Error: Could not get authentication token
```
**Solutions:**
- Verify Cognito User Pool exists
- Check user credentials (testuser/MyPassword123!)
- Ensure region matches deployment

#### Memory Access Issues
```bash
❌ Memory access failed: AccessDenied
```
**Solutions:**
- Check IAM permissions for bedrock-agentcore
- Verify memory ID in stack outputs
- Ensure memory is in ACTIVE state

#### MCP Server Connection Issues
```bash
❌ Error connecting to MCP server
```
**Solutions:**
- Verify AgentCore Runtime is deployed
- Check authentication token validity
- Ensure network connectivity

#### Advanced Memory Deployment Issues

**❌ Problem: deploy.sh completes but no memory/runtime created**
```bash
✓ Stack deployment complete!
# But no memory ID or runtime ARN shown
```
**Solutions:**
```bash
# Check if advanced memory creation failed
aws ssm get-parameter --name "/bedrock-agentcore/STACK_NAME/advanced-memory-id" --region REGION

# If parameter doesn't exist, manually create advanced memory
python create-advanced-memory.py STACK_NAME REGION MEMORY_NAME 30

# Then manually deploy runtime
# (Get parameters from main stack outputs first)
```

**❌ Problem: Memory created but no runtime stack**
```bash
# Check if runtime stack exists
aws cloudformation describe-stacks --stack-name STACK_NAME-runtime --region REGION
```
**Solutions:**
```bash
# Get required parameters and deploy runtime manually
ECR_URI=$(aws cloudformation describe-stacks --stack-name STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryUri`].OutputValue' --output text --region REGION)
# ... (see manual deployment section)
```

#### Advanced Memory Not Working
```bash
• No memories found for query
```
**Solutions:**
- Wait 30+ seconds for extraction processing
- Verify advanced memory is enabled
- Check memory has conversation data

### Debug Commands
```bash
# Validate CloudFormation template
aws cloudformation validate-template --template-body file://mcp-server-template.yaml

# Test memory configuration
./test-memory-config.sh

# Check ECR repository
aws ecr describe-repositories --repository-names STACK_NAME-mcp-server --region YOUR_REGION

# List AgentCore resources
aws bedrock-agentcore list-memories --region YOUR_REGION
aws bedrock-agentcore list-runtimes --region YOUR_REGION
```

## 🧹 Cleanup Options

### 🎯 **Smart Cleanup (Recommended)**
**Automatically detects your deployment type and uses the right cleanup method:**

```bash
./cleanup.sh YOUR_STACK_NAME [REGION]
```

**What it does:**
- 🔍 **Auto-detects** deployment type (basic vs advanced memory)
- 🧠 **Advanced Memory**: Routes to `cleanup-advanced.sh`
- 💾 **Basic Memory**: Routes to `cleanup-basic.sh`
- ✅ **Complete cleanup** with verification

**Examples:**
```bash
./cleanup.sh my-smart-agent
./cleanup.sh my-basic-agent us-west-2
```

---

### 🧠 **Advanced Memory Cleanup**
**For deployments created with `deploy-advanced.sh`:**

```bash
./cleanup-advanced.sh YOUR_STACK_NAME [REGION]
```

**What it handles:**
1. **Runtime Stack** - Deletes `YOUR_STACK-runtime` first
2. **Advanced Memory** - Removes memory via Python SDK
3. **Main Stack** - Deletes infrastructure stack
4. **SSM Parameters** - Cleans up memory ID parameters
5. **Verification** - Confirms complete cleanup

**Process:**
```
🔄 Advanced Memory Cleanup Process:
📦 Step 1: Delete runtime stack (~2 minutes)
🧠 Step 2: Delete advanced memory (~1 minute)  
🏗️  Step 3: Delete main stack (~5 minutes)
🔧 Step 4: Clean up SSM parameters
🔍 Step 5: Verify cleanup complete
```

---

### 💾 **Basic Memory Cleanup**
**For deployments created with `deploy-basic.sh`:**

```bash
./cleanup-basic.sh YOUR_STACK_NAME [REGION]
```

**What it handles:**
1. **Single Stack** - Deletes everything in one CloudFormation stack
2. **Basic Memory** - Removed automatically with stack
3. **Verification** - Confirms complete cleanup

**Process:**
```
🔄 Basic Memory Cleanup Process:
📦 Step 1: Delete single stack (~8 minutes)
🔍 Step 2: Verify cleanup complete
```

---

### 🎯 **Memory-Only Cleanup**
**Clean up memories without touching infrastructure:**

```bash
# Clean up all test memories in region
./cleanup-memory.sh REGION

# Clean up specific memory by ID
./cleanup-memory.sh REGION MEMORY_ID
```

**Use cases:**
- Testing different memory configurations
- Cleaning up failed deployments
- Removing orphaned memories

---

### 🔧 **Manual Cleanup (If Scripts Fail)**

#### **For Basic Memory Deployments:**
```bash
aws cloudformation delete-stack --stack-name YOUR_STACK --region YOUR_REGION
aws cloudformation wait stack-delete-complete --stack-name YOUR_STACK --region YOUR_REGION
```

#### **For Advanced Memory Deployments:**
```bash
# Step 1: Delete runtime stack first
aws cloudformation delete-stack --stack-name YOUR_STACK-runtime --region YOUR_REGION
aws cloudformation wait stack-delete-complete --stack-name YOUR_STACK-runtime --region YOUR_REGION

# Step 2: Delete advanced memory (Python SDK)
python3 -c "
from bedrock_agentcore.memory import MemoryClient
import boto3

# Get memory ID from SSM
ssm = boto3.client('ssm', region_name='YOUR_REGION')
memory_id = ssm.get_parameter(Name='/bedrock-agentcore/YOUR_STACK/advanced-memory-id')['Parameter']['Value']

# Delete memory
client = MemoryClient(region_name='YOUR_REGION')
client.delete_memory_and_wait(memory_id, max_wait=300)
print(f'✅ Memory {memory_id} deleted')
"

# Step 3: Delete main stack
aws cloudformation delete-stack --stack-name YOUR_STACK --region YOUR_REGION
aws cloudformation wait stack-delete-complete --stack-name YOUR_STACK --region YOUR_REGION

# Step 4: Clean up SSM parameter
aws ssm delete-parameter --name "/bedrock-agentcore/YOUR_STACK/advanced-memory-id" --region YOUR_REGION
```

### 📊 **Cleanup Verification**
**Verify everything was cleaned up properly:**

```bash
# Check remaining stacks
aws cloudformation list-stacks --region YOUR_REGION \
  --query 'StackSummaries[?StackStatus!=`DELETE_COMPLETE`].[StackName,StackStatus]' \
  --output table

# Check remaining memories
python3 -c "
from bedrock_agentcore.memory import MemoryClient
client = MemoryClient(region_name='YOUR_REGION')
memories = client.list_memories()
print(f'Remaining memories: {len(memories)}')
for memory in memories:
    print(f'  - {memory[\"memoryId\"]}')
"

# Check remaining SSM parameters
aws ssm describe-parameters --region YOUR_REGION \
  --query 'Parameters[?contains(Name,`bedrock-agentcore`)].[Name]' \
  --output table
```

## Configuration Examples

### Development Environment
```bash
./deploy.sh dev-mcp us-west-2 amazon.nova-micro-v1:0 false 7
```
- Basic memory, 7-day retention
- Cost-effective model
- Quick testing

### Production Environment
```bash
./deploy.sh prod-mcp us-east-1 anthropic.claude-3-5-sonnet-20241022-v2:0 true 90
```
- Advanced memory configuration (strategies require manual setup)
- High-quality model
- 90-day retention

### Customer Support Use Case
```bash
./deploy.sh support-agent us-west-2 anthropic.claude-3-haiku-20240307-v1:0 true 180
```
- Advanced memory for personalization (strategies require manual setup)
- Balanced performance model
- 6-month retention

## Advanced Memory with AI-Powered Strategies

This solution provides **true advanced memory** with automatic AI-powered strategy configuration, enabling intelligent user preference extraction and long-term memory capabilities.

### 🧠 **Memory Types Comparison**

| Feature | Basic Memory | Advanced Memory |
|---------|--------------|-----------------|
| **Deployment** | Single CloudFormation stack | Two-phase hybrid deployment |
| **Memory Creation** | CloudFormation resource | Python SDK with strategies |
| **AI Features** | Simple storage | User preference extraction |
| **Namespace Organization** | Basic events | Structured (`user/{actorId}/preferences`) |
| **Cross-session Intelligence** | Manual retrieval | Automatic preference recall |
| **Use Cases** | Testing, simple tools | Personal assistants, customer support |

### 🚀 **Complete Advanced Memory Deployment Process**

#### **Step 1: Prerequisites Setup**
```bash
# Install required dependencies
pip install -r requirements.txt

# Verify AWS credentials and permissions
aws sts get-caller-identity
aws bedrock list-foundation-models --region us-west-2
```

#### **Step 2: Deploy with Advanced Memory**
```bash
# Interactive deployment (recommended)
./configure-deploy.sh
# Select "y" for advanced memory when prompted

# OR direct deployment
./deploy.sh my-smart-agent us-west-2 anthropic.claude-3-5-sonnet-20241022-v2:0 true 30
```

#### **Step 3: What Happens After Running deploy.sh**

**🔄 The script runs automatically and handles everything:**

1. **Infrastructure Deployment** (~10 minutes)
   - Creates CloudFormation stack
   - Builds Docker image
   - Sets up authentication

2. **Advanced Memory Creation** (~3 minutes)
   - Creates memory with AI strategies
   - Stores memory ID in SSM
   - Initializes with sample data

3. **Runtime Deployment** (~2 minutes)
   - Deploys MCP Server Runtime
   - Connects to advanced memory
   - Completes integration

**✅ When deployment completes, you'll see:**
```
✅ Runtime stack deployment complete!
✅ MCP Server Runtime deployed with advanced memory!

Stack Name: my-smart-agent
Region: us-west-2
Client ID: abc123...
Agent ARN: arn:aws:bedrock-agentcore:...
Memory ID: my_smart_agent_MCPServerMemory-xyz789
Memory Type: Advanced (with strategies)
```

#### **Step 4: Immediate Next Steps**

**No manual intervention needed!** The deployment is complete and ready to use.

**Verify deployment:**
```bash
# Run complete test suite
./test.sh my-smart-agent us-west-2

# OR just test memory
./test-memory-only.sh my-smart-agent us-west-2
```

## 🎯 **After Deployment: What to Do Next**

### ✅ **Your Advanced Memory MCP Server is Ready!**

When `deploy.sh` completes successfully, you have:
- **🏗️ Infrastructure**: ECR, Cognito, IAM roles
- **🧠 Advanced Memory**: AI-powered user preference extraction  
- **🚀 MCP Server Runtime**: Ready to handle requests
- **🔗 Integration**: Memory connected to runtime

### 📋 **Immediate Actions**

#### **1. Verify Everything Works**
```bash
# Test all components
./test.sh YOUR_STACK_NAME us-west-2

# Expected output:
# ✅ Memory configuration valid
# ✅ MCP tools working (add_numbers, multiply_numbers, greet_user)  
# ✅ Memory storage and retrieval working
# ✅ Advanced memory strategies active
```

#### **2. Check Advanced Memory in AWS Console**
1. Go to **AWS Console** → **Amazon Bedrock** → **AgentCore** → **Memory**
2. Find your memory (name contains your stack name)
3. Verify: **"Long-term memory strategies (1)"** instead of "(0)"
4. Click on the memory to see the **UserPreferences** strategy

#### **3. Test Real Conversations**
```bash
# Get authentication token
python get_token.py CLIENT_ID testuser MyPassword123! us-west-2

# Test MCP server with memory
python test_mcp_server.py AGENT_ARN JWT_TOKEN us-west-2
```

### 🔧 **Integration with Your Applications**

#### **MCP Server Endpoint**
```
https://bedrock-agentcore.us-west-2.amazonaws.com/runtimes/YOUR_RUNTIME_ARN/invocations?qualifier=DEFAULT
```

#### **Authentication**
- **Method**: Cognito JWT tokens
- **Test Credentials**: `testuser` / `MyPassword123!`
- **Client ID**: Available in stack outputs

#### **Available Tools**
- `add_numbers(a, b)` - Mathematical addition
- `multiply_numbers(a, b)` - Mathematical multiplication  
- `greet_user(name)` - Personalized greetings

### 🚨 **If Something Went Wrong**

#### **Check Deployment Status**
```bash
# Verify main stack
aws cloudformation describe-stacks --stack-name YOUR_STACK --region us-west-2

# Verify runtime stack (advanced memory only)
aws cloudformation describe-stacks --stack-name YOUR_STACK-runtime --region us-west-2

# Check memory exists
python -c "
from bedrock_agentcore.memory import MemoryClient
client = MemoryClient(region_name='us-west-2')
memories = client.list_memories()
print(f'Total memories: {len(memories)}')
"
```

#### **Common Issues & Solutions**
- **No runtime stack**: Advanced memory creation may have failed
- **No memory**: Check CloudFormation events for errors
- **Authentication fails**: Verify Cognito user pool exists

### 🎉 **You're Done!**

Your MCP Server with advanced AI-powered memory is ready for:
- **Personal assistants** that remember user preferences
- **Customer support** with conversation history
- **Learning companions** that adapt to user styles
- **Any application** requiring intelligent memory

#### **Step 3: Deployment Process (Automatic)**
The deployment script automatically handles the two-phase process:

**Phase 1: Infrastructure Deployment (~10 minutes)**
- ✅ Creates ECR repository
- ✅ Builds and pushes MCP server Docker image  
- ✅ Sets up Cognito authentication
- ✅ Configures IAM roles and permissions
- ✅ **Skips memory creation** (handled in Phase 2)

**Phase 2: Advanced Memory Creation (~3 minutes)**
- ✅ Creates memory with AI strategies using Python SDK
- ✅ Configures User Preference extraction strategy
- ✅ Stores memory ID in SSM Parameter Store
- ✅ Initializes with sample conversation data

**Phase 3: Runtime Deployment (~2 minutes)**
- ✅ Deploys MCP Server Runtime in separate stack
- ✅ Integrates with advanced memory
- ✅ Configures environment variables

#### **Step 4: Verify Advanced Memory**
```bash
# Run complete test suite
./test.sh my-smart-agent us-west-2

# Verify memory strategies in AWS Console
# Go to: Amazon Bedrock > AgentCore > Memory
# Look for: "Long-term memory strategies (1)"

# Check memory strategies programmatically
python -c "
from bedrock_agentcore.memory import MemoryClient
client = MemoryClient(region_name='us-west-2')
strategies = client.get_memory_strategies(memory_id='YOUR_MEMORY_ID')
print(f'Strategies: {len(strategies)}')
for strategy in strategies:
    print(f'- {strategy[\"type\"]}: {strategy[\"name\"]}')
"
```

### 🔧 **Advanced Memory Architecture**

#### **Two-Stack Deployment Structure**
```
Main Stack (my-smart-agent):
├── ECR Repository
├── Docker Image Build
├── Cognito Authentication  
├── IAM Roles & Policies
└── SSM Parameters

Runtime Stack (my-smart-agent-runtime):
├── MCP Server Runtime
├── Memory Integration
└── Environment Configuration

External Resources (Python SDK):
└── Advanced Memory with Strategies
```

#### **Memory Strategy Configuration**
```json
{
  "strategyId": "UserPreferences-abc123",
  "name": "UserPreferences", 
  "description": "Captures and extracts user preferences from conversations",
  "type": "USER_PREFERENCE",
  "namespaces": ["user/{actorId}/preferences"],
  "status": "ACTIVE"
}
```

### 🧪 **Testing Advanced Memory Features**

#### **Memory Storage & Retrieval Test**
```bash
# Test memory storage
python test_memory.py AGENT_ARN JWT_TOKEN us-west-2 STACK_NAME

# Expected results:
# ✅ Memory Storage: Conversations stored successfully
# ✅ Memory Retrieval: Events retrieved by actor/session  
# ✅ Advanced Querying: AI-powered preference extraction
# ✅ Cross-session Persistence: Memory persists across sessions
```

#### **Manual Memory Testing**
```bash
# Store a conversation with preferences
python -c "
from bedrock_agentcore.memory import MemoryClient
import json
from datetime import datetime

client = MemoryClient(region_name='us-west-2')
memory_id = 'YOUR_MEMORY_ID'

# Sample conversation with clear preferences
conversation = {
    'messages': [
        ('I love Italian food and prefer vegetarian options', 'USER'),
        ('Great! I'll remember your preference for Italian vegetarian cuisine.', 'ASSISTANT')
    ],
    'timestamp': datetime.utcnow().isoformat() + 'Z'
}

response = client.create_event(
    memory_id=memory_id,
    actor_id='test_user_123',
    session_id='session_456', 
    event_timestamp=conversation['timestamp'],
    payload=[{'blob': json.dumps(conversation)}]
)
print('✅ Conversation stored for preference extraction')
"

# Wait for AI processing (30+ seconds)
sleep 30

# Query extracted preferences  
python -c "
from bedrock_agentcore.memory import MemoryClient
client = MemoryClient(region_name='us-west-2')

memories = client.retrieve_memory_records(
    memoryId='YOUR_MEMORY_ID',
    namespace='user/test_user_123/preferences',
    searchCriteria={'searchQuery': 'food preferences', 'topK': 5},
    maxResults=10
)
print(f'Found {len(memories.get(\"memoryRecords\", []))} preference records')
"
```

### 🎯 **Advanced Memory Use Cases**

#### **Personal Assistant**
```bash
./deploy.sh personal-ai us-west-2 anthropic.claude-3-5-sonnet-20241022-v2:0 true 90
```
- **90-day retention** for long-term relationships
- **User preference extraction** for personalized responses
- **Cross-session continuity** for ongoing conversations

#### **Customer Support Agent**
```bash  
./deploy.sh support-bot us-east-1 anthropic.claude-3-haiku-20240307-v1:0 true 180
```
- **6-month retention** for customer history
- **Issue preference tracking** for better support
- **Conversation context** across multiple interactions

#### **Learning Companion**
```bash
./deploy.sh learning-ai us-west-2 amazon.nova-micro-v1:0 true 365
```
- **1-year retention** for learning progress
- **Learning style preferences** extraction
- **Progress tracking** across sessions

### 🔍 **Monitoring Advanced Memory**

#### **Memory Health Check**
```bash
# Check memory status and strategies
python -c "
from bedrock_agentcore.memory import MemoryClient
client = MemoryClient(region_name='us-west-2')

# Get memory status
status = client.get_memory_status(memory_id='YOUR_MEMORY_ID')
print(f'Memory Status: {status}')

# Get configured strategies
strategies = client.get_memory_strategies(memory_id='YOUR_MEMORY_ID')
print(f'Active Strategies: {len(strategies)}')
for strategy in strategies:
    print(f'- {strategy[\"name\"]}: {strategy[\"status\"]}')
"
```

#### **Memory Usage Analytics**
```bash
# List recent events
aws bedrock-agentcore list-events \
  --memory-id YOUR_MEMORY_ID \
  --actor-id test_user \
  --max-results 10 \
  --region us-west-2

# Query extracted memories
aws bedrock-agentcore retrieve-memory-records \
  --memory-id YOUR_MEMORY_ID \
  --namespace "user/test_user/preferences" \
  --search-criteria '{"searchQuery":"preferences","topK":5}' \
  --region us-west-2
```

### 🧹 **Advanced Memory Cleanup**

#### **Complete Cleanup (Infrastructure + Memory)**
```bash
# Automated cleanup (recommended)
./cleanup.sh my-smart-agent us-west-2

# What it does:
# 1. Deletes runtime stack (my-smart-agent-runtime)
# 2. Deletes main stack (my-smart-agent)  
# 3. Deletes advanced memory via Python SDK
# 4. Cleans up SSM parameters
```

#### **Memory-Only Cleanup**
```bash
# Clean up all test memories
./cleanup-memory.sh us-west-2

# Clean up specific memory
./cleanup-memory.sh us-west-2 MEMORY_ID
```

### ⚠️ **Important Notes**

#### **Memory Strategy Activation**
- **Initial Setup**: Strategies are active immediately after creation
- **AI Processing**: Preference extraction takes 30+ seconds after conversation storage
- **Data Requirements**: Meaningful extraction requires clear preference statements
- **Namespace Organization**: Extracted preferences stored in `user/{actorId}/preferences`

#### **Cost Considerations**
- **Advanced Memory**: Higher cost due to AI processing and strategy execution
- **Retention Period**: Longer retention = higher storage costs
- **Model Selection**: Higher-quality models = higher inference costs
- **Usage Patterns**: Frequent conversations = more extraction processing

#### **Performance Optimization**
- **Batch Conversations**: Store multiple turns together for better context
- **Clear Preferences**: Use explicit preference statements for better extraction
- **Namespace Queries**: Query specific namespaces for faster retrieval
- **Memory Limits**: Monitor memory usage and clean up old data periodically

## 📁 File Structure

```
mcp-server-agentcore-runtime/
├── mcp-server-template.yaml      # Main CloudFormation template (infrastructure)
├── mcp-runtime-template.yaml    # Runtime CloudFormation template (advanced memory)
├── deploy-advanced.sh            # 🧠 Advanced memory deployment (AI-powered)
├── deploy-basic.sh               # 💾 Basic memory deployment (simple & fast)
├── configure-deploy.sh           # 🎯 Interactive configuration wizard
├── create-advanced-memory.py     # Advanced memory creation via Python SDK
├── cleanup.sh                    # 🎯 Smart cleanup (auto-detects deployment type)
├── cleanup-advanced.sh           # 🧠 Advanced memory cleanup (specialized)
├── cleanup-basic.sh              # 💾 Basic memory cleanup (specialized)
├── cleanup-memory.sh             # Memory-only cleanup script
├── test.sh                       # Complete test suite
├── test-memory-only.sh          # Memory-focused testing
├── test_mcp_server.py           # MCP tools testing
├── test_memory.py               # Memory functionality testing
├── validate_memory.py           # Quick memory validation
├── get_token.py                 # Authentication helper
├── requirements.txt             # Python dependencies
└── README.md                    # This comprehensive guide
```

### 📋 **Script Categories**

#### **🚀 Deployment Scripts**
- `deploy-advanced.sh` - **Advanced memory deployment** with AI strategies (recommended for production)
- `deploy-basic.sh` - **Basic memory deployment** for simple use cases and testing
- `configure-deploy.sh` - **Interactive wizard** for guided deployment with explanations
- `create-advanced-memory.py` - Standalone advanced memory creation utility

#### **🧪 Testing Scripts**  
- `test.sh` - **Complete test suite** (tools + memory functionality)
- `test-memory-only.sh` - **Memory-specific testing** for validation
- `validate_memory.py` - **Quick memory validation** and health check

#### **🧹 Cleanup Scripts**
- `cleanup.sh` - **Smart cleanup** (auto-detects deployment type and routes appropriately)
- `cleanup-advanced.sh` - **Advanced memory cleanup** (specialized for hybrid deployments)
- `cleanup-basic.sh` - **Basic memory cleanup** (specialized for single-stack deployments)
- `cleanup-memory.sh` - **Memory-only cleanup** for testing scenarios

#### **📄 CloudFormation Templates**
- `mcp-server-template.yaml` - **Infrastructure** (IAM, ECR, Cognito)
- `mcp-runtime-template.yaml` - **MCP Server Runtime** (post-memory creation for advanced deployments)

## Next Steps

After successful deployment and testing:

1. **Customize MCP Tools**: Modify the Docker image build process to add your own tools
2. **Integrate with Applications**: Use the MCP server endpoint in your applications
3. **Monitor Performance**: Set up CloudWatch dashboards for memory and runtime metrics
4. **Scale Configuration**: Adjust memory retention and model selection based on usage
5. **Security Hardening**: Review IAM permissions and network configuration for production

## Support

For issues and questions:
- Check CloudFormation events for deployment issues
- Use validation scripts for configuration problems
- Review CloudWatch logs for runtime issues
- Test with basic memory first, then upgrade to advanced