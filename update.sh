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
# Build heap cap. Kept modest because this box is SHARED (ES + MySQL + Apache/
# Plesk + Docker). A 4 GB build heap on top of a 4 GB ES heap overflowed RAM,
# spilled into swap, and OOM-killed the box. 1536 MB is enough for this app.
HEAP_MB="${HEAP_MB:-1536}"

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

# verify_build — confirm a build is COMPLETE, not just that it started.
#   Checking only for .next/BUILD_ID is not enough: an OOM-killed 'next build'
#   can write BUILD_ID and the JS chunks but die before emitting the CSS, so
#   BUILD_ID exists yet the page references a stylesheet that 404/400s. That
#   exact failure shipped a styleless site (CSS -> Next 400 'text/html').
#   Here we parse the build manifests and assert every referenced .css/.js file
#   actually exists on disk, so a half-written build is rejected and rolled back.
verify_build() {
  [[ -f .next/BUILD_ID ]] || { echo "verify: .next/BUILD_ID missing" >&2; return 1; }
  node -e '
    const fs = require("fs"), p = require("path"), root = ".next";
    const manifests = ["app-build-manifest.json", "build-manifest.json"]
      .map(f => p.join(root, f)).filter(fs.existsSync);
    if (!manifests.length) { console.error("verify: no build manifest found"); process.exit(1); }
    const refs = new Set();
    const collect = o => {
      if (Array.isArray(o)) o.forEach(collect);
      else if (o && typeof o === "object") Object.values(o).forEach(collect);
      else if (typeof o === "string" && /\.(css|js)$/.test(o)) refs.add(o);
    };
    for (const m of manifests) collect(JSON.parse(fs.readFileSync(m, "utf8")));
    const missing = [...refs].filter(f => !fs.existsSync(p.join(root, f)));
    if (missing.length) {
      console.error("verify: " + missing.length + " referenced build asset(s) missing:");
      console.error(missing.slice(0, 20).join("\n"));
      process.exit(1);
    }
    const css = [...refs].filter(f => f.endsWith(".css")).length;
    console.log("verify: OK — " + refs.size + " referenced assets present (" + css + " css).");
  ' || return 1
}

# 3. Build with the production-safe flags, WITHOUT destroying the live build.
#    Previously this did `rm -rf .next` before building; when the build then
#    failed (e.g. OOM), the app was left with no .next and crash-looped under
#    systemd (~6500 restarts). Now we keep the old build as a fallback and only
#    discard it once a fresh build succeeds AND verifies complete.
#    CI=true      -> avoids the interactive-spinner setRawMode EIO crash
#    NODE_OPTIONS -> caps heap so 'next build' isn't OOM-killed
echo -e "${YELLOW}🔨 Building application...${NC}"
rm -rf .next.bak
[[ -d .next ]] && cp -a .next .next.bak

if ! CI=true NODE_OPTIONS="--max-old-space-size=${HEAP_MB}" npm run build || ! verify_build; then
  echo -e "${RED}❌ Build failed or incomplete. Restoring previous build and NOT restarting.${NC}" >&2
  rm -rf .next
  [[ -d .next.bak ]] && mv .next.bak .next && echo -e "${YELLOW}   Previous .next restored — live app untouched.${NC}"
  exit 1
fi

# 4. Build succeeded — drop the fallback.
rm -rf .next.bak
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