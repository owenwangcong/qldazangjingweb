#!/usr/bin/env bash
#
# update.sh — pull latest code from GitHub, rebuild, and restart via systemd.
#
# Replaces the old PM2-based flow. systemd owns the running process.
#
# Usage:
#   ./update.sh                 # pull main, build, restart service
#   ./update.sh <branch>        # pull a specific branch instead of main
#
set -Eeuo pipefail

APP_DIR="/var/www/qldazangjingweb"
SERVICE="qldazangjingweb"
BRANCH="${1:-main}"
NODE_BIN="/home/ubuntu/.nvm/versions/node/v20.18.0/bin"
HEAP_MB="${HEAP_MB:-4096}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

export PATH="$NODE_BIN:$PATH"
cd "$APP_DIR"

echo -e "${GREEN}🔄 Updating $SERVICE (branch: $BRANCH)${NC}"
echo -e "    Node: $(node -v)  npm: $(npm -v)"

# 1. Pull latest code.
echo -e "${YELLOW}📥 Pulling latest changes...${NC}"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull origin "$BRANCH"

# 2. Install ALL dependencies (NOT --production: devDependencies are needed to build).
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
if [[ -f package-lock.json ]]; then
  npm ci
elif [[ -f yarn.lock ]]; then
  yarn install --frozen-lockfile
else
  npm install
fi

# 3. Clean + build with the production-safe flags.
#    CI=true      -> avoids the interactive-spinner setRawMode EIO crash
#    NODE_OPTIONS -> caps heap so 'next build' isn't OOM-killed
echo -e "${YELLOW}🔨 Building application...${NC}"
rm -rf .next
CI=true NODE_OPTIONS="--max-old-space-size=${HEAP_MB}" npm run build

# 4. Verify the build produced a valid bundle before restarting.
if [[ ! -f .next/BUILD_ID ]]; then
  echo -e "${RED}❌ Build failed: .next/BUILD_ID missing. Service NOT restarted.${NC}" >&2
  exit 1
fi
echo -e "${GREEN}   Build OK (BUILD_ID: $(cat .next/BUILD_ID))${NC}"

# 5. Restart via systemd.
echo -e "${YELLOW}🔄 Restarting service...${NC}"
sudo systemctl restart "$SERVICE"
sleep 2

if systemctl is-active --quiet "$SERVICE"; then
  echo -e "${GREEN}✅ Update completed — service is active.${NC}"
  sudo systemctl --no-pager --full status "$SERVICE" | head -n 10
else
  echo -e "${RED}❌ Service failed to start. Check: journalctl -u $SERVICE -n 50${NC}" >&2
  exit 1
fi