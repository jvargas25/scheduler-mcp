#!/bin/bash
# MCP Scheduler Daemon Stopper
# Gracefully stops the running scheduler daemon

PID_FILE="/Users/jonvargas/.claude/mcp-scheduler.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "❌ No PID file found at $PID_FILE"
    echo "   Scheduler doesn't appear to be running"
    exit 1
fi

PID=$(cat "$PID_FILE")

if kill -0 "$PID" 2>/dev/null; then
    echo "🛑 Stopping MCP Scheduler (PID: $PID)..."
    kill "$PID"

    # Wait for graceful shutdown (up to 5 seconds)
    for i in {1..5}; do
        if ! kill -0 "$PID" 2>/dev/null; then
            break
        fi
        sleep 1
    done

    # Force kill if still running
    if kill -0 "$PID" 2>/dev/null; then
        echo "⚠️  Process didn't stop gracefully, forcing..."
        kill -9 "$PID"
    fi

    rm "$PID_FILE"
    echo "✅ MCP Scheduler stopped"
else
    echo "⚠️  Process $PID not found (stale PID file)"
    rm "$PID_FILE"
    echo "✅ Cleaned up PID file"
fi