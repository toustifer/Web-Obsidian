#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Starting frontend from: $DIR"

# Force UTF-8 locale where available to avoid mojibake when printing Chinese
export LANG=${LANG:-zh_CN.UTF-8}
export LC_ALL=${LC_ALL:-zh_CN.UTF-8}

# Load .env if present (simple parser)
for f in "$DIR/.env" "$DIR/../.env"; do
  if [ -f "$f" ]; then
    echo "Loading env from $f"
    while IFS= read -r line || [ -n "$line" ]; do
      line="$(echo "$line" | sed -e 's/^\s*//;s/\s*$//')"
      case "$line" in
        ''|#*) continue ;;
      esac
      if echo "$line" | grep -q '='; then
        key="$(echo "$line" | cut -d '=' -f1)"
        val="$(echo "$line" | cut -d '=' -f2- | sed -e 's/^\s*//;s/\s*$//' -e 's/^\"//;s/\"$//' -e "s/^'//;s/'$//")"
        export "$key=$val"
      fi
    done < "$f"
    break
  fi
done

# If called with --install or node_modules missing, run npm install
if [ "${1-}" = "--install" ] || [ ! -d "$DIR/node_modules" ]; then
  echo "Installing npm dependencies..."
  (cd "$DIR" && npm install)
fi

# 本机可达性检测：优先使用本地地址（127.0.0.1）和合适的端口
LOCAL_FOUND=0
code=$(curl -sSk -o /dev/null -w "%{http_code}" --max-time 3 https://127.0.0.1:3001/ || echo "000")
if [ "$code" != "000" ]; then
  echo "Detected local HTTPS service at 127.0.0.1:3001 (HTTP $code). Using local address."
  export TAILSCALE_IP=127.0.0.1
  export FRONTEND_PORT=3001
  LOCAL_FOUND=1
else
  code2=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 3 http://127.0.0.1:3000/ || echo "000")
  if [ "$code2" != "000" ]; then
    echo "Detected local HTTP service at 127.0.0.1:3000 (HTTP $code2). Using local address."
    export TAILSCALE_IP=127.0.0.1
    export FRONTEND_PORT=3000
    LOCAL_FOUND=1
  fi
else
  echo "No local service detected on 127.0.0.1:3001/3000; will use configured TAILSCALE_IP."
fi

echo "Running npm start..."
cd "$DIR"
exec npm start
