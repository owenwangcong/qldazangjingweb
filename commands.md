# Local Development
## Start the development server
npm run dev

# Deploy on EC2 Ubuntu
## Install Node.js and npm
Need to install Node.js and npm on Ubuntu.
node version: v20.18.0
npm version: v9.6.3

## Get the latest code from GitHub
git pull origin main

## Install dependencies
npm install

## Build the project
npm run build

## Start the production server
npm run start

## Install Chromium dependencies
sudo apt install -y \
    libgbm-dev \
    libnss3 \
    libxshmfence-dev \
    libasound2 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxcomposite1 \
    libxrandr2 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libwayland-client0 \
    libwayland-cursor0 \
    libwayland-egl1 \
    fonts-liberation \
    libfontconfig1
