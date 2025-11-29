#!/bin/bash
# Standalone memory cleanup script
# Cleans up all memories or specific memory by ID

set -e

REGION="${1:-us-west-2}"
MEMORY_ID="${2}"

echo "=========================================="
echo "🧠 Memory Cleanup Script"
echo "=========================================="
echo "Region: $REGION"

if [ -n "$MEMORY_ID" ]; then
    echo "Target Memory ID: $MEMORY_ID"
    echo ""
    
    # Delete specific memory
    echo "🗑️  Deleting specific memory..."
    python -c "
from bedrock_agentcore.memory import MemoryClient
try:
    client = MemoryClient(region_name='$REGION')
    client.delete_memory_and_wait('$MEMORY_ID', max_wait=300)
    print('✅ Memory $MEMORY_ID deleted successfully')
except Exception as e:
    print(f'❌ Error deleting memory: {e}')
"
else
    echo "Mode: Clean up all test memories"
    echo ""
    
    # List and delete all test memories
    echo "📋 Finding test memories to clean up..."
    python -c "
from bedrock_agentcore.memory import MemoryClient
import re
client = MemoryClient(region_name='$REGION')

try:
    memories = client.list_memories()
    test_memories = []
    
    for memory in memories:
        memory_id = memory.get('id', '')
        # Match test memory patterns
        if any(pattern in memory_id.lower() for pattern in ['test_', 'test-', 'demo', 'example']):
            test_memories.append(memory_id)
    
    if test_memories:
        print(f'Found {len(test_memories)} test memories to delete:')
        for memory_id in test_memories:
            print(f'  - {memory_id}')
        
        print(f'\\n🗑️  Deleting test memories...')
        for memory_id in test_memories:
            try:
                client.delete_memory_and_wait(memory_id, max_wait=300)
                print(f'✅ Deleted: {memory_id}')
            except Exception as e:
                print(f'❌ Failed to delete {memory_id}: {e}')
    else:
        print('ℹ️  No test memories found to clean up')
        
except Exception as e:
    print(f'❌ Error listing memories: {e}')
"
fi

echo ""
echo "=========================================="
echo "✅ Memory Cleanup Complete!"
echo "=========================================="