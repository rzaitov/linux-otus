#!/usr/bin/env bash
set -euo pipefail

echo "Outer Bash PID: $$"

# The inner Bash starts sleep and exits, leaving sleep orphaned.
# Redirect sleep output so it does not keep the capture pipe open.
orphan_pid=$(bash -c 'sleep 60 >/dev/null 2>&1 & echo $!')

ps -o pid,ppid,stat,args -p "$$,$orphan_pid"
kill "$orphan_pid"
