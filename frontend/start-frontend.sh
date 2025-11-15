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

echo "Running npm start..."
cd "$DIR"
exec npm start
