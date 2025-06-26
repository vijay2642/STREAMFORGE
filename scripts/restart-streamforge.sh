#!/bin/bash
# StreamForge – Quick Restart Script
# ----------------------------------
# Runs shutdown script, waits, then setup script.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] Restarting StreamForge …"

"$SCRIPT_DIR/shutdown-streamforge.sh"

# Give Docker a few seconds to fully release resources
sleep 5

"$SCRIPT_DIR/setup-streamforge.sh"
