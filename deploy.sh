#!/bin/bash

# Deploy script for PM2 with GitHub latest code
# Usage: ./deploy.sh

set -e  # Exit on any error

# Configuration
APP_NAME="qldazangjingweb"
REPO_URL="https://github.com/owenwangcong/qldazangjingweb.git"  # Replace with your repo URL
BRANCH="main"
APP_DIR="/var/www/$APP_NAME"
PM2_ECOSYSTEM_FILE="ecosystem.config.js"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting deployment of $APP_NAME${NC}"

# Check if running as root (not recommended for PM2)
if [[ $EUID -eq 0 ]]; then
   echo -e "${YELLOW}⚠️  Warning: Running as root. Consider using a non-root user for PM2.${NC}"
fi

# Create app directory if it doesn't exist
if [ ! -d "$APP_DIR" ]; then
    echo -e "${YELLOW}📁 Creating app directory: $APP_DIR${NC}"
    sudo mkdir -p "$APP_DIR"
    sudo chown $USER:$USER "$APP_DIR"
fi

# Navigate to app directory
cd "$APP_DIR"

# Check if it's a git repository
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}📥 Cloning repository...${NC}"
    git clone "$REPO_URL" .
else
    echo -e "${YELLOW}🔄 Repository exists, fetching latest changes...${NC}"
    git fetch origin
fi

# Checkout and pull latest code
echo -e "${YELLOW}🔄 Switching to $BRANCH branch and pulling latest code...${NC}"
git checkout "$BRANCH"
git pull origin "$BRANCH"

# Install/update dependencies
if [ -f "package.json" ]; then
    echo -e "${YELLOW}📦 Installing/updating dependencies...${NC}"
    npm ci --production
elif [ -f "yarn.lock" ]; then
    echo -e "${YELLOW}📦 Installing/updating dependencies with Yarn...${NC}"
    yarn install --production
fi

# Build the application if build script exists
if [ -f "package.json" ] && npm run | grep -q "build"; then
    echo -e "${YELLOW}🔨 Building application...${NC}"
    npm run build
fi

# Check if PM2 is installed
if ! command -v pm2 &> /dev/null; then
    echo -e "${RED}❌ PM2 is not installed. Installing PM2 globally...${NC}"
    npm install -g pm2
fi

# Start/restart the application with PM2
if [ -f "$PM2_ECOSYSTEM_FILE" ]; then
    echo -e "${YELLOW}🚀 Using ecosystem file: $PM2_ECOSYSTEM_FILE${NC}"
    pm2 startOrRestart "$PM2_ECOSYSTEM_FILE" --env production
else
    echo -e "${YELLOW}🚀 Starting application with PM2...${NC}"
    pm2 startOrRestart package.json --name "$APP_NAME" --env production
fi

# Save PM2 configuration
echo -e "${YELLOW}💾 Saving PM2 configuration...${NC}"
pm2 save

# Setup PM2 startup script (run once)
if ! pm2 startup | grep -q "already"; then
    echo -e "${YELLOW}⚙️  Setting up PM2 startup script...${NC}"
    pm2 startup
fi

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${GREEN}📊 Application status:${NC}"
pm2 status

echo ""
echo -e "${GREEN}🔧 Useful commands:${NC}"
echo -e "  View logs: ${YELLOW}pm2 logs $APP_NAME${NC}"
echo -e "  Monitor:   ${YELLOW}pm2 monit${NC}"
echo -e "  Restart:   ${YELLOW}pm2 restart $APP_NAME${NC}"
echo -e "  Stop:      ${YELLOW}pm2 stop $APP_NAME${NC}"
echo -e "  Status:    ${YELLOW}pm2 status${NC}"