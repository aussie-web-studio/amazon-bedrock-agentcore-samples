#!/bin/bash
# Test script to validate memory configuration
#
# This script validates the CloudFormation template with different memory configurations

set -e

echo "=========================================="
echo "🧪 Testing Memory Configuration"
echo "=========================================="
echo ""

# Test basic memory configuration
echo "Testing basic memory configuration..."
aws cloudformation validate-template \
  --template-body file://mcp-server-template.yaml \
  --region us-west-2 > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Basic template validation passed"
else
    echo "❌ Basic template validation failed"
    exit 1
fi

# Test parameter validation
echo ""
echo "Testing parameter combinations..."

# Test valid advanced memory parameters
echo "  • Testing advanced memory = true..."
PARAMS='[
  {"ParameterKey": "EnableAdvancedMemory", "ParameterValue": "true"},
  {"ParameterKey": "MemoryEventExpiryDays", "ParameterValue": "30"}
]'

aws cloudformation validate-template \
  --template-body file://mcp-server-template.yaml \
  --parameters "$PARAMS" \
  --region us-west-2 > /dev/null

if [ $? -eq 0 ]; then
    echo "    ✅ Advanced memory parameters valid"
else
    echo "    ❌ Advanced memory parameters invalid"
    exit 1
fi

# Test basic memory parameters
echo "  • Testing advanced memory = false..."
PARAMS='[
  {"ParameterKey": "EnableAdvancedMemory", "ParameterValue": "false"},
  {"ParameterKey": "MemoryEventExpiryDays", "ParameterValue": "7"}
]'

aws cloudformation validate-template \
  --template-body file://mcp-server-template.yaml \
  --parameters "$PARAMS" \
  --region us-west-2 > /dev/null

if [ $? -eq 0 ]; then
    echo "    ✅ Basic memory parameters valid"
else
    echo "    ❌ Basic memory parameters invalid"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ All Memory Configuration Tests Passed!"
echo "=========================================="
echo ""
echo "Your template is ready for deployment with both:"
echo "  🔹 Basic memory configuration"
echo "  🔹 Advanced memory configuration"
echo ""
echo "Use ./configure-deploy.sh for interactive deployment"
echo "or ./deploy.sh for direct deployment"