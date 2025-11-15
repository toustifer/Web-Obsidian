#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=${ENV_FILE:-.env}
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Environment file '$ENV_FILE' not found."
  exit 1
fi
set -a
source "$ENV_FILE"
set +a

COMPOSE_FILE=${COMPOSE_FILE:-docker-compose.yml}
PROJECT_NAME=${COMPOSE_PROJECT_NAME:-obi}
if [[ -n "${LOCAL_PORTS:-}" ]]; then
  IFS=',' read -r -a PORTS <<<"$LOCAL_PORTS"
else
  PORTS=("3000" "3001" "8082")
fi

echo "[1] docker compose down"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down || true

echo "[2] tailscale serve reset"
tailscale serve reset
for port in "${PORTS[@]}"; do
  tailscale serve clear --tcp="$port" || true
done

echo "[3] restart Docker daemon/Desktop if needed..."
echo "    macOS: open /Applications/Docker.app"
echo "    Linux: sudo systemctl restart docker"

echo "[4] docker compose up -d"
if docker ps -a --format '{{.Names}}' | grep -qx obsidian; then
  echo "Removing leftover obsidian container..."
  docker rm -f obsidian >/dev/null
fi
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d

echo "[5] curl check"
curl http://127.0.0.1:3000

echo "[6] tailscale serve re-publish"
for port in "${PORTS[@]}"; do
  tailscale serve --bg --tcp="$port" "tcp://127.0.0.1:$port"
done

echo "[7] tailscale serve status"
tailscale serve status

echo "[8] waiting for 127.0.0.1:3000..."
TARGETS=("http://127.0.0.1:3000" "https://127.0.0.1:3000")
MAX_ATTEMPTS=15
RESPONDED=0
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  for target in "${TARGETS[@]}"; do
    status=$(curl -sk -o /dev/null -w "%{http_code}" "$target" || true)
    if [[ "$status" =~ ^[0-9]+$ && "$status" -ne 000 ]]; then
      echo "Port 3000 is responding via $target (HTTP $status) on attempt $i"
      RESPONDED=1
      break 2
    else
      echo "Attempt $i ($target): still waiting..."
    fi
  done
  sleep 3
done

if [ $RESPONDED -eq 0 ]; then
  echo "Port 3000 did not respond after $MAX_ATTEMPTS attempts."
fi

if [[ -n "${TAILSCALE_IP:-}" ]]; then
  echo "Tailnet access: http://${TAILSCALE_IP}:3000"
fi
