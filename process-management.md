  PM2 Process Management

  Install PM2 globally:
  npm install -g pm2

  Start your app:
  pm2 start npm --name "qldazangjingweb" -- run start

  Essential PM2 commands:
  # View running processes
  pm2 list

  # View logs (real-time)
  pm2 logs qldazangjingweb

  # View logs (last 100 lines)
  pm2 logs qldazangjingweb --lines 100

  # Restart app
  pm2 restart qldazangjingweb

  # Stop app
  pm2 stop qldazangjingweb

  # Delete app from PM2
  pm2 delete qldazangjingweb

  # View detailed info
  pm2 show qldazangjingweb

  # Monitor resources
  pm2 monit

  Auto-start on server reboot:
  # Generate startup script
  pm2 startup

  # Save current PM2 processes
  pm2 save

  Alternative: systemd service (more robust for production):
  # Create service file
  sudo nano /etc/systemd/system/qldazangjingweb.service

  Service file content:
  [Unit]
  Description=Qldazangjingweb Node.js App
  After=network.target

  [Service]
  Type=simple
  User=ubuntu
  WorkingDirectory=/var/www/qldazangjingweb
  ExecStart=/home/ubuntu/.nvm/versions/node/v20.18.0/bin/npm run start
  Restart=always
  RestartSec=10
  Environment=NODE_ENV=production

  [Install]
  WantedBy=multi-user.target

  systemd commands:
  # Enable and start service
  sudo systemctl enable qldazangjingweb
  sudo systemctl start qldazangjingweb

  # Check status
  sudo systemctl status qldazangjingweb

  # View logs
  sudo journalctl -u qldazangjingweb -f

  # Restart
  sudo systemctl restart qldazangjingweb

  # Stop
  sudo systemctl stop qldazangjingweb

  PM2 is easier to use, systemd is more robust for production servers.