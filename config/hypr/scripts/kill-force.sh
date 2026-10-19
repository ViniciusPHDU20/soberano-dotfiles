#!/usr/bin/env bash
# Force-kill active window process and its descendants (SIGKILL -9)
PID=$(hyprctl activewindow -j | jq -r '.pid // empty')

if [ -n "$PID" ] && [ "$PID" -gt 1 ]; then
    # Kill children first to avoid orphan zombie processes, then the process itself
    pkill -9 -P "$PID" 2>/dev/null
    kill -9 "$PID" 2>/dev/null
fi
