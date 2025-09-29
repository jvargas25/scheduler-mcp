#!/bin/bash
# MCP Scheduler Daemon Starter
# Runs the scheduler in SSE mode for network access
# Must be started from an authenticated Claude session

cd /Users/jonvargas/Documents/GitHub/scheduler-mcp
source .venv/bin/activate

# Configuration
PID_FILE="/Users/jonvargas/.claude/mcp-scheduler.pid"
LOG_FILE="/Users/jonvargas/.claude/mcp-scheduler.log"
DB_PATH="/Users/jonvargas/.claude/scheduler.db"
PORT=8742  # Custom port for MCP scheduler (less common)

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p $OLD_PID > /dev/null 2>&1; then
        echo "✅ MCP Scheduler already running (PID: $OLD_PID)"
        echo "   Port: http://localhost:$PORT"
        echo "   Logs: $LOG_FILE"
        exit 0
    else
        echo "⚠️  Stale PID file found, cleaning up..."
        rm "$PID_FILE"
    fi
fi

# Start the scheduler daemon
# Set uvicorn environment variables for FastMCP SSE mode
export UVICORN_HOST=127.0.0.1
export UVICORN_PORT=$PORT

echo "🚀 Starting MCP Scheduler daemon..."
UVICORN_HOST=127.0.0.1 UVICORN_PORT=$PORT python main.py \
  --transport sse \
  --port $PORT \
  --log-file "$LOG_FILE" \
  --db-path "$DB_PATH" \
  > "${LOG_FILE}.out" 2>&1 &

PID=$!
echo $PID > "$PID_FILE"

# Wait a moment and verify it started successfully
sleep 2
if kill -0 $PID 2>/dev/null; then
    echo "✅ MCP Scheduler daemon started successfully"
    echo "   PID: $PID"
    echo "   Port: http://localhost:$PORT"
    echo "   Database: $DB_PATH"
    echo "   Logs: $LOG_FILE"
    echo ""
    echo "📝 To view logs: tail -f $LOG_FILE"
    echo "🛑 To stop: ./stop-scheduler-daemon.sh"
else
    echo "❌ Failed to start MCP Scheduler"
    echo "   Check logs: ${LOG_FILE}.out"
    rm "$PID_FILE" 2>/dev/null
    exit 1
fi