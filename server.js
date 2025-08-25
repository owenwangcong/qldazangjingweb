const { createServer } = require('http');
const { parse } = require('url');
const next = require('next');
const fs = require('fs');
const path = require('path');

const dev = process.env.NODE_ENV !== 'production';
const hostname = process.env.HOSTNAME || 'localhost';
const port = parseInt(process.env.PORT, 10) || 3000;
const app = next({ dev, hostname, port });
const handle = app.getRequestHandler();

const pidFile = path.join(process.cwd(), 'app.pid');

// Function to write PID file
function writePidFile() {
  try {
    fs.writeFileSync(pidFile, process.pid.toString());
    console.log(`PID ${process.pid} written to ${pidFile}`);
  } catch (error) {
    console.error('Error writing PID file:', error);
  }
}

// Function to remove PID file
function removePidFile() {
  try {
    if (fs.existsSync(pidFile)) {
      fs.unlinkSync(pidFile);
      console.log(`PID file ${pidFile} removed`);
    }
  } catch (error) {
    console.error('Error removing PID file:', error);
  }
}

// Handle process termination signals
function setupGracefulShutdown(server) {
  const shutdown = (signal) => {
    console.log(`\nReceived ${signal}. Shutting down gracefully...`);
    removePidFile();
    server.close(() => {
      console.log('Server closed');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGHUP', () => shutdown('SIGHUP'));
}

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  removePidFile();
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  removePidFile();
  process.exit(1);
});

app.prepare().then(() => {
  const server = createServer(async (req, res) => {
    const parsedUrl = parse(req.url, true);
    await handle(req, res, parsedUrl);
  });

  // Setup graceful shutdown
  setupGracefulShutdown(server);

  server.listen(port, (err) => {
    if (err) throw err;
    console.log(`> Ready on http://${hostname}:${port}`);
    
    // Write PID file after server starts successfully
    writePidFile();
  });
});