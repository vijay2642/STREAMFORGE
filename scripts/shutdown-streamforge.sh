#!/bin/bash
# StreamForge – Graceful Shutdown Script
# --------------------------------------
# Stops all StreamForge Docker containers, kills auxiliary Python services,
# and verifies that the key ports are free afterwards.
#
# Usage: ./scripts/shutdown-streamforge.sh

set -euo pipefail

readonly REQUIRED_PORTS=(1935 8080 8082 8084 8085 3000 5432 6379)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="/tmp/streamforge_shutdown.log"

echo "[INFO] StreamForge shutdown started – $(date -Is)" | tee "$LOG_FILE"

print_ok()    { echo -e "  \e[32m✓\e[0m $1"; }
print_warn()  { echo -e "  \e[33m⚠\e[0m $1"; }
print_error() { echo -e "  \e[31m✗\e[0m $1"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { print_error "$1 missing"; exit 1; }
}

need_cmd docker

if command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker-compose"
else
  DOCKER_COMPOSE="docker compose"
fi

# ----------------------------------------------------------------------------
# 1. Stop Python helper processes first (they might hold ports)
# ----------------------------------------------------------------------------
print_ok "Stopping Python helper processes (cors_server, live_transcoder)"

pkill -f "cors_server.py"  || true
pkill -f "live_transcoder.py" || true
sleep 2

# ----------------------------------------------------------------------------
# 2. Bring down Docker services
# ----------------------------------------------------------------------------
print_ok "Stopping Docker containers"
cd "$PROJECT_DIR"
$DOCKER_COMPOSE down -v --remove-orphans > >(tee -a "$LOG_FILE")

# ----------------------------------------------------------------------------
# 3. Verify ports are clear
# ----------------------------------------------------------------------------
all_clear=true
for p in "${REQUIRED_PORTS[@]}"; do
  if lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
    print_warn "Port $p still in use"
    all_clear=false
  else
    print_ok "Port $p freed"
  fi
done

if $all_clear; then
  print_ok "All services stopped and ports released."
else
  print_warn "Some ports remain busy. Investigate above warnings."
fi
