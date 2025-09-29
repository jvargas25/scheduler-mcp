#!/bin/bash
# MCP Scheduler Status Checker
# Shows the current status of the scheduler daemon

PID_FILE="/Users/jonvargas/.claude/mcp-scheduler.pid"
LOG_FILE="/Users/jonvargas/.claude/mcp-scheduler.log"
DB_PATH="/Users/jonvargas/.claude/scheduler.db"
PORT=8742

echo "MCP Scheduler Status"
echo "===================="
echo ""

# Check PID file and process
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "✅ Status: RUNNING"
        echo "   PID: $PID"

        # Check if port is actually listening
        if lsof -i:$PORT -P -n | grep LISTEN > /dev/null 2>&1; then
            echo "   Port: http://localhost:$PORT (listening)"
        else
            echo "   Port: $PORT (not listening - may be starting up)"
        fi

        # Show process info
        echo ""
        echo "Process Info:"
        ps -p $PID -o pid,ppid,user,%cpu,%mem,etime,command | head -2

    else
        echo "⚠️  Status: STOPPED (stale PID file)"
        echo "   Last PID: $PID"
        echo "   Run './stop-scheduler-daemon.sh' to clean up"
    fi
else
    echo "❌ Status: NOT RUNNING"
    echo "   No PID file found"
    echo "   Run './run-scheduler-daemon.sh' to start"
fi

echo ""

# Check database
if [ -f "$DB_PATH" ]; then
    SIZE=$(du -h "$DB_PATH" | cut -f1)
    echo "📊 Database: $DB_PATH ($SIZE)"
else
    echo "📊 Database: Not found (will be created on first run)"
fi

# Check log file
if [ -f "$LOG_FILE" ]; then
    SIZE=$(du -h "$LOG_FILE" | cut -f1)
    LINES=$(wc -l < "$LOG_FILE")
    echo "📝 Log file: $LOG_FILE ($SIZE, $LINES lines)"
    echo ""
    echo "Recent logs (last 5 lines):"
    echo "----------------------------"
    tail -5 "$LOG_FILE"
else
    echo "📝 Log file: Not found yet"
fi