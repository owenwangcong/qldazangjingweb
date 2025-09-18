#!/bin/bash

# Fix PM2 duplicate processes script
# Usage: ./fix-pm2-duplicates.sh

set -e

APP_NAME="qldazangjingweb"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔍 Checking PM2 processes...${NC}"

# Show current PM2 status
echo -e "${YELLOW}Current PM2 processes:${NC}"
pm2 status

echo ""
echo -e "${YELLOW}🔧 Fixing duplicate processes for $APP_NAME...${NC}"

# Method 1: Stop all instances of the app
echo -e "${YELLOW}Stopping all instances of $APP_NAME...${NC}"
pm2 stop $APP_NAME 2>/dev/null || echo "No processes to stop"

# Method 2: Delete all instances
echo -e "${YELLOW}Deleting all instances of $APP_NAME...${NC}"
pm2 delete $APP_NAME 2>/dev/null || echo "No processes to delete"

# Method 3: If there are still orphaned processes, kill by name
echo -e "${YELLOW}Checking for any remaining processes...${NC}"
pm2 list | grep $APP_NAME && {
    echo -e "${RED}Found remaining processes. Force killing...${NC}"
    pm2 kill
    echo -e "${YELLOW}Restarting PM2 daemon...${NC}"
    pm2 resurrect 2>/dev/null || echo "No saved processes to resurrect"
} || echo -e "${GREEN}No remaining processes found${NC}"

echo ""
echo -e "${YELLOW}📊 Current status after cleanup:${NC}"
pm2 status

echo ""
echo -e "${GREEN}✅ Cleanup completed!${NC}"
echo -e "${YELLOW}To restart your application:${NC}"
echo -e "  Single instance: ${GREEN}pm2 start ecosystem.config.js --env production${NC}"
echo -e "  Or use: ${GREEN}./deploy.sh${NC}"

echo ""
echo -e "${YELLOW}🔧 Additional commands if needed:${NC}"
echo -e "  Kill all PM2: ${RED}pm2 kill${NC}"
echo -e "  Reset PM2: ${RED}pm2 kill && pm2 resurrect${NC}"
echo -e "  Save config: ${GREEN}pm2 save${NC}"