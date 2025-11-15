#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env}"

echo "=== Obsidian .env 配置向导 (Bash) ==="

default_app_dir="$(pwd)"
default_user="admin"
default_project="$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
if [ -z "$default_project" ]; then
  default_project="obsidian"
fi

read -rp "APP_DIR (绝对路径) [$default_app_dir]: " app_dir
app_dir="${app_dir:-$default_app_dir}"

read -rp "CUSTOM_USER [$default_user]: " custom_user
custom_user="${custom_user:-$default_user}"

read -rsp "PASSWORD [必填，默认 password123]: " password
echo
password="${password:-password123}"

read -rp "COMPOSE_PROJECT_NAME [$default_project]: " project_name
project_name="${project_name:-$default_project}"

tailscale_default_ip=""
if command -v tailscale >/dev/null 2>&1; then
  tailscale_default_ip="$(tailscale ip -4 2>/dev/null | head -n1)"
fi
read -rp "TAILSCALE_IP (建议先运行 'tailscale ip -4') [$tailscale_default_ip]: " tailscale_ip
tailscale_ip="${tailscale_ip:-$tailscale_default_ip}"

cat > "$ENV_FILE" <<EOF
APP_DIR=$app_dir
CUSTOM_USER=$custom_user
PASSWORD=$password
COMPOSE_PROJECT_NAME=$project_name
TAILSCALE_IP=$tailscale_ip
EOF

echo "已写入 $ENV_FILE："
cat "$ENV_FILE"
