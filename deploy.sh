#!/usr/bin/env bash
#
# deploy.sh — build qldazangjingweb for production and (re)start it via systemd.
#
# systemd owns the running process (auto-restart, start-on-boot, journald logs).
# This script's job is: install deps -> build a valid .next -> verify -> restart.
#
# Usage:
#   ./deploy.sh              # install if needed, build, verify, restart service
#   ./deploy.sh --no-restart # build + verify only, don't touch systemd
#
set -Eeuo pipefail

APP_DIR="/var/www/qldazangjingweb"
SERVICE="qldazangjingweb"
NODE_BIN="/home/ubuntu/.nvm/versions/node/v20.18.0/bin"
HEAP_MB="${HEAP_MB:-1536}"          # V8 heap cap for the build. Modest: shared box (ES+MySQL+Apache+Docker); 4096 overflowed RAM and OOM-killed the host.
RESTART=1

[[ "${1:-}" == "--no-restart" ]] && RESTART=0

# Make nvm-installed node/npm reachable in this non-login shell.
export PATH="$NODE_BIN:$PATH"

cd "$APP_DIR"

echo "==> Node: $(node -v)  npm: $(npm -v)  Dir: $APP_DIR"

# 1. Install deps only if missing (use ci for reproducible installs).
if [[ ! -d node_modules ]]; then
  echo "==> Installing dependencies (npm ci)"
  npm ci
fi

# 2. Preserve the live build as a fallback (do NOT blindly delete it). If the
#    new build fails, we restore this so the running app keeps a valid .next
#    instead of crash-looping under systemd.
echo "==> Backing up current .next (if any)"
rm -rf .next.bak
[[ -d .next ]] && cp -a .next .next.bak

# 3. Build.
#    CI=true        -> disables the interactive spinner that throws setRawMode EIO
#    NODE_OPTIONS   -> caps V8 heap so 'next build' isn't OOM-killed
echo "==> Building production bundle"
if ! CI=true NODE_OPTIONS="--max-old-space-size=${HEAP_MB}" npm run build || [[ ! -f .next/BUILD_ID ]]; then
  echo "!! Build failed: restoring previous .next and aborting (no restart)." >&2
  rm -rf .next
  [[ -d .next.bak ]] && mv .next.bak .next && echo "   Previous .next restored."
  exit 1
fi

# 4. Build succeeded — drop the fallback.
rm -rf .next.bak
echo "==> Build OK (BUILD_ID: $(cat .next/BUILD_ID))"

# 5. Hand off to systemd.
if [[ "$RESTART" -eq 1 ]]; then
  echo "==> Restarting service: $SERVICE"
  sudo systemctl restart "$SERVICE"
  sleep 2
  sudo systemctl --no-pager --full status "$SERVICE" | head -n 12
else
  echo "==> --no-restart given; build is ready. Start with: sudo systemctl restart $SERVICE"
fi