# Weather Agent Code

This folder contains the agent application code that gets deployed to AWS BedrockAgentCore.

## Files

- **`my_agent.py`** - Main agent application with weather tools and logic
- **`requirements.txt`** - Python dependencies for the agent
- **`Dockerfile`** - Container configuration for the agent runtime

## Development Workflow

1. **Edit agent logic**: Modify `my_agent.py` to change agent behavior, tools, or system prompts
2. **Update dependencies**: Add/remove packages in `requirements.txt` 
3. **Modify container**: Update `Dockerfile` for runtime environment changes
4. **Deploy**: Run `../deploy.sh` from the parent directory to deploy changes

## Agent Features

- **Weather Data**: Fetches global weather forecasts using wttr.in API
- **Activity Planning**: Generates activity recommendations based on weather conditions
- **Memory**: Remembers user preferences and conversation history
- **S3 Reports**: Saves detailed markdown reports to S3 bucket
- **Code Analysis**: Uses AgentCore Code Interpreter for weather classification

## Tools Available

- `get_weather_data(city)` - Fetch weather forecast for any city worldwide
- `generate_analysis_code(weather_data)` - Create Python code for weather classification  
- `execute_code(python_code)` - Run code using AgentCore Code Interpreter
- `get_activity_preferences()` - Retrieve user preferences from memory
- `generate_report_filename(city)` - Create standardized report filenames
- `use_aws` - Upload reports and files to S3

## Testing Locally

You can test the agent code locally by running:

```bash
python my_agent.py
```

Make sure you have the required environment variables set for AWS credentials and AgentCore resources.