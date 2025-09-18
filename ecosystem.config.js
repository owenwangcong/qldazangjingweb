module.exports = {
  apps: [{
    name: 'qldazangjingweb',
    script: './server.js', // or your main application file
    instances: 'max', // Use all CPU cores
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'development',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    // Restart settings
    max_memory_restart: '1G',
    min_uptime: '10s',
    max_restarts: 5,

    // Logging
    log_file: './logs/combined.log',
    out_file: './logs/out.log',
    error_file: './logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm Z',

    // Watch for file changes (disable in production)
    watch: false,
    ignore_watch: ['node_modules', 'logs'],

    // Advanced settings
    merge_logs: true,
    autorestart: true,
    time: true
  }],

  // Deployment configuration
  deploy: {
    production: {
      user: 'ubuntu', // Change to your server user
      host: ['15.222.105.96'], // Change to your server IP
      ref: 'origin/main',
      repo: 'https://github.com/owenwangcong/qldazangjingweb.git', // Change to your repo
      path: '/var/www/qldazangjingweb',
      'pre-deploy-local': '',
      'post-deploy': 'npm install && npm run build && pm2 reload ecosystem.config.js --env production',
      'pre-setup': 'apt update && apt install -y nodejs npm'
    }
  }
};