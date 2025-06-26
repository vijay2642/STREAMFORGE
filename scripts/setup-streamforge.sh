#!/bin/bash

# StreamForge – Automated Environment Setup
# -----------------------------------------
# This script checks local prerequisites, confirms critical ports are
# available, builds & starts Docker-Compose services, waits for health, and
# finally launches the Python live transcoder for **stream1** so that the
# `adaptive-live-player.html` can immediately play the HLS output.
#
# Usage: ./scripts/setup-streamforge.sh

set -euo pipefail

readonly REQUIRED_PORTS=(1935 8080 8082 8084)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="/tmp/streamforge_setup.log"

echo "[INFO] StreamForge setup started – $(date -Is)" | tee "$LOG_FILE"

# ----------------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------------
print_ok()    { echo -e "  \e[32m✓\e[0m $1"; }
print_warn()  { echo -e "  \e[33m⚠\e[0m $1"; }
print_error() { echo -e "  \e[31m✗\e[0m $1"; }

abort() {
  print_error "$1"
  echo "[ERROR] $1" >> "$LOG_FILE"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || abort "$1 is required but not installed."
}

port_free() {
  ! lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

wait_port() {
  local port=$1 timeout=${2:-30} t=0
  until lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; do
    sleep 1; ((t++));
    [[ $t -ge $timeout ]] && return 1
  done
}

# ----------------------------------------------------------------------------
# 1. Dependency checks
# ----------------------------------------------------------------------------
need_cmd docker
# Support both docker-compose v1 and v2 (plugin)
if command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker-compose"
else
  need_cmd docker
  if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
  else
    abort "docker compose (plugin) is required. Upgrade your Docker installation."
  fi
fi
print_ok "Docker & Docker Compose available"

# ----------------------------------------------------------------------------
# 2. Port availability
# ----------------------------------------------------------------------------
for p in "${REQUIRED_PORTS[@]}"; do
  if port_free "$p"; then
    print_ok "Port $p free"
  else
    abort "Port $p is already in use. Please free it before continuing."
  fi
done

# ----------------------------------------------------------------------------
# 3. Build & start containers
# ----------------------------------------------------------------------------
print_ok "Building Docker images (this may take a while on first run)"
cd "$PROJECT_DIR"
$DOCKER_COMPOSE build > >(tee -a "$LOG_FILE")

print_ok "Starting Docker services"
$DOCKER_COMPOSE up -d postgres redis nginx-rtmp transcoder stream-processing user-management web-player

# ----------------------------------------------------------------------------
# 4. Health-checks (simple port wait) – extend if necessary
# ----------------------------------------------------------------------------
declare -A SERVICE_PORTS=(
  [postgres]=5432
  [redis]=6379
  [nginx-rtmp]=1935
  [transcoder]=8082
  [stream-processing]=8081
  [user-management]=8083
  [web-player]=3000
)

for svc in "${!SERVICE_PORTS[@]}"; do
  port=${SERVICE_PORTS[$svc]}
  printf "  Waiting for %-17s on port %s … " "$svc" "$port"
  if wait_port "$port" 45; then
    echo -e "\e[32mready\e[0m"
  else
    echo -e "\e[31mfailed\e[0m"
    $DOCKER_COMPOSE logs "$svc" | tail -n 30
    abort "$svc did not become healthy. Check logs above."
  fi
done

# ----------------------------------------------------------------------------
# 5. Launch Python auxiliary services (if not running inside Docker)
# ----------------------------------------------------------------------------
if ! pgrep -f "cors_server.py" >/dev/null 2>&1; then
  print_ok "Starting CORS/HLS server (python)"
  nohup python3 "$PROJECT_DIR/cors_server.py" >/dev/null 2>&1 &
fi

if ! pgrep -f "live_transcoder.py" >/dev/null 2>&1; then
  print_ok "Starting live_transcoder for stream1"
  nohup python3 "$PROJECT_DIR/bin/live_transcoder.py" stream1 >/dev/null 2>&1 &
fi

sleep 2

# ----------------------------------------------------------------------------
# 6. Final status summary
# ----------------------------------------------------------------------------
cat <<EOF

========================================
StreamForge environment is \e[32mUP\e[0m 🎉

• Adaptive Player URL : http://localhost:3000/adaptive-live-player.html
• RTMP Ingest URL     : rtmp://localhost:1935/live/stream1
• HLS Playlist        : http://localhost:8085/stream1/playlist.m3u8

Happy streaming!
========================================
EOF
