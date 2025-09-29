#!/bin/bash
# MCP Scheduler Universal Installer
# Automatically configures Claude Desktop and Claude Code to use the MCP Scheduler
# Can be run from any vault directory on any computer

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCHEDULER_PORT=8000
SCHEDULER_ENDPOINT="http://localhost:${SCHEDULER_PORT}/sse"
CURRENT_DIR="$(pwd)"
VAULT_DIR="$CURRENT_DIR"

echo -e "${BLUE}🔧 MCP Scheduler Universal Installer${NC}"
echo "=================================="
echo ""
echo "Installing from: $VAULT_DIR"
echo "Scheduler endpoint: $SCHEDULER_ENDPOINT"
echo ""

# Function to backup a file
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        echo "  💾 Backup created: $backup"
    fi
}

# Function to validate JSON
validate_json() {
    local file="$1"
    if ! python3 -m json.tool "$file" > /dev/null 2>&1; then
        echo -e "  ${RED}❌ Invalid JSON in $file${NC}"
        return 1
    fi
    return 0
}

# Function to update Claude Desktop config
update_claude_desktop_config() {
    local config_file="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    local config_dir="$(dirname "$config_file")"

    echo -e "${YELLOW}📱 Updating Claude Desktop configuration...${NC}"

    # Create directory if it doesn't exist
    if [ ! -d "$config_dir" ]; then
        echo "  📁 Creating Claude config directory..."
        mkdir -p "$config_dir"
    fi

    # Create empty config if it doesn't exist
    if [ ! -f "$config_file" ]; then
        echo "  📄 Creating new Claude Desktop config..."
        echo '{"mcpServers": {}}' > "$config_file"
    fi

    # Backup existing config
    backup_file "$config_file"

    # Update config using Python for reliable JSON manipulation
    python3 << EOF
import json
import sys

config_file = "$config_file"
endpoint = "$SCHEDULER_ENDPOINT"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)

    # Ensure mcpServers exists
    if 'mcpServers' not in config:
        config['mcpServers'] = {}

    # Add or update scheduler
    config['mcpServers']['scheduler'] = {
        "command": "npx",
        "args": ["mcp-remote", endpoint]
    }

    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)

    print("  ✅ Claude Desktop config updated")

except Exception as e:
    print(f"  ❌ Error updating Claude Desktop config: {e}")
    sys.exit(1)
EOF

    # Validate the result
    if validate_json "$config_file"; then
        echo "  ✅ Configuration validated successfully"
    else
        echo -e "  ${RED}❌ Configuration validation failed${NC}"
        exit 1
    fi
}

# Function to update Claude project config
update_claude_project_config() {
    local config_file="$HOME/.claude.json"

    echo -e "${YELLOW}💻 Updating Claude Code project configuration...${NC}"

    # Create empty config if it doesn't exist
    if [ ! -f "$config_file" ]; then
        echo "  📄 Creating new Claude project config..."
        echo '{}' > "$config_file"
    fi

    # Backup existing config
    backup_file "$config_file"

    # Update config using Python for reliable JSON manipulation
    python3 << EOF
import json
import sys

config_file = "$config_file"
vault_dir = "$VAULT_DIR"
endpoint = "$SCHEDULER_ENDPOINT"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)

    # Ensure projects exists
    if 'projects' not in config:
        config['projects'] = {}

    # Ensure vault project exists
    if vault_dir not in config['projects']:
        config['projects'][vault_dir] = {}

    # Ensure mcpServers exists in vault project
    if 'mcpServers' not in config['projects'][vault_dir]:
        config['projects'][vault_dir]['mcpServers'] = {}

    # Add or update scheduler
    config['projects'][vault_dir]['mcpServers']['scheduler'] = {
        "command": "npx",
        "args": ["mcp-remote", endpoint]
    }

    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)

    print(f"  ✅ Claude Code config updated for: {vault_dir}")

except Exception as e:
    print(f"  ❌ Error updating Claude Code config: {e}")
    sys.exit(1)
EOF

    # Validate the result
    if validate_json "$config_file"; then
        echo "  ✅ Configuration validated successfully"
    else
        echo -e "  ${RED}❌ Configuration validation failed${NC}"
        exit 1
    fi
}

# Function to check if scheduler is running
check_scheduler_status() {
    echo -e "${YELLOW}🔍 Checking scheduler daemon status...${NC}"

    # Check if port is listening
    if lsof -i:$SCHEDULER_PORT -P -n | grep LISTEN > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Scheduler daemon is running on port $SCHEDULER_PORT${NC}"

        # Try to test the endpoint
        if curl -s "$SCHEDULER_ENDPOINT" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Scheduler endpoint is responding${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Port is listening but SSE endpoint may not be ready${NC}"
        fi
    else
        echo -e "  ${RED}❌ Scheduler daemon is not running on port $SCHEDULER_PORT${NC}"
        echo -e "  ${BLUE}💡 Start the daemon with: cd $SCHEDULER_MCP_DIR && ./scripts/run-scheduler-daemon.sh${NC}"
    fi
}

# Function to show usage instructions
show_usage_instructions() {
    echo ""
    echo -e "${GREEN}🎉 Installation Complete!${NC}"
    echo "=========================="
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo ""
    echo "1. Start the scheduler daemon (if not already running):"
    echo "   cd $SCHEDULER_MCP_DIR && ./scripts/run-scheduler-daemon.sh"
    echo ""
    echo "2. Restart Claude Desktop to load the new configuration"
    echo ""
    echo "3. In Claude Code, use: claude --continue"
    echo "   (or start a new session in any directory with scheduler configured)"
    echo ""
    echo "4. Test the scheduler with:"
    echo "   - Claude Desktop: Ask about available MCP servers"
    echo "   - Claude Code: Use scheduler MCP tools"
    echo ""
    echo -e "${BLUE}🔧 Management Commands (from $SCHEDULER_MCP_DIR):${NC}"
    echo "   ./scripts/run-scheduler-daemon.sh  - Start the daemon"
    echo "   ./scripts/scheduler-status.sh      - Check daemon status"
    echo "   ./scripts/stop-scheduler-daemon.sh - Stop the daemon"
    echo ""
}

# Main installation process
main() {
    echo -e "${BLUE}Starting installation process...${NC}"
    echo ""

    # Update Claude Desktop config
    update_claude_desktop_config
    echo ""

    # Update Claude project config
    update_claude_project_config
    echo ""

    # Check scheduler status
    check_scheduler_status
    echo ""

    # Show usage instructions
    show_usage_instructions
}

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is required but not found${NC}"
    echo "Please install Python 3 and try again"
    exit 1
fi

# Check if we're in the scheduler-mcp directory or can find it
SCHEDULER_MCP_DIR=""
if [ -f "main.py" ] && [ -d "mcp_scheduler" ]; then
    # We're in the scheduler-mcp directory
    SCHEDULER_MCP_DIR="$CURRENT_DIR"
elif [ -d "scheduler-mcp" ] && [ -f "scheduler-mcp/main.py" ]; then
    # We're in a parent directory with scheduler-mcp folder
    SCHEDULER_MCP_DIR="$CURRENT_DIR/scheduler-mcp"
else
    echo -e "${RED}❌ Cannot locate scheduler-mcp directory${NC}"
    echo "This script must be run either:"
    echo "  1. From within the scheduler-mcp repository directory"
    echo "  2. From a directory containing a 'scheduler-mcp' folder"
    echo "Current directory: $CURRENT_DIR"
    exit 1
fi

echo "Scheduler MCP directory: $SCHEDULER_MCP_DIR"

# Run the main installation
main