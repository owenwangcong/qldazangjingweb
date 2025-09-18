#!/bin/bash

# Quick update script for existing PM2 deployment
# Usage: ./update.sh

set -e

APP_NAME="qldazangjingweb"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔄 Quick update for $APP_NAME${NC}"

# Pull latest changes
echo -e "${YELLOW}📥 Pulling latest changes...${NC}"
git pull origin main

# Install new dependencies (if any)
if [ -f "package-lock.json" ]; then
    echo -e "${YELLOW}📦 Updating dependencies...${NC}"
    npm ci --production
elif [ -f "yarn.lock" ]; then
    echo -e "${YELLOW}📦 Updating dependencies with Yarn...${NC}"
    yarn install --production
fi

# Build if needed
if [ -f "package.json" ] && npm run | grep -q "build"; then
    echo -e "${YELLOW}🔨 Building application...${NC}"
    npm run build
fi

# Reload PM2 application (zero-downtime)
echo -e "${YELLOW}🔄 Reloading PM2 application...${NC}"
pm2 reload $APP_NAME

echo -e "${GREEN}✅ Update completed!${NC}"
pm2 status