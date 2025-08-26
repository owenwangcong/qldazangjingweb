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

// Enhanced request logging middleware
const logRequest = (req, res, next) => {
  const startTime = Date.now();
  const ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress || 'unknown';
  const userAgent = req.headers['user-agent'] || 'unknown';
  
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} - IP: ${ip} - User-Agent: ${userAgent}`);
  
  // Log when response finishes
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const logEntry = {
      timestamp: new Date().toISOString(),
      method: req.method,
      url: req.url,
      ip,
      userAgent,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      memoryUsage: process.memoryUsage()
    };
    
    const logMessage = JSON.stringify(logEntry) + '\n';
    fs.appendFileSync(path.join(process.cwd(), 'requests.log'), logMessage);
    
    console.log(`[${logEntry.timestamp}] ${req.method} ${req.url} - ${res.statusCode} - ${duration}ms`);
  });
  
  if (next) next();
};

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

// Enhanced error logging function with comprehensive system information
const logError = (error, context) => {
  const errorLog = {
    timestamp: new Date().toISOString(),
    context,
    message: error.message,
    stack: error.stack,
    processId: process.pid,
    parentProcessId: process.ppid,
    memoryUsage: process.memoryUsage(),
    uptime: process.uptime(),
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
    workingDirectory: process.cwd(),
    environment: process.env.NODE_ENV,
    argv: process.argv,
    execPath: process.execPath,
    versions: process.versions,
    loadavg: require('os').loadavg(),
    totalmem: require('os').totalmem(),
    freemem: require('os').freemem(),
    cpus: require('os').cpus().length,
    networkInterfaces: Object.keys(require('os').networkInterfaces()),
    hostname: require('os').hostname()
  };
  
  const logMessage = JSON.stringify(errorLog) + '\n';
  fs.appendFileSync(path.join(process.cwd(), 'crash.log'), logMessage);
  console.error(`[CRASH] ${errorLog.timestamp} - ${context}:`, error);
  
  // Also write to a separate abnormal exit log for easier analysis
  fs.appendFileSync(path.join(process.cwd(), 'abnormal-exit.log'), logMessage);
};

// Comprehensive exit logging function
const logAbnormalExit = (reason, data, signal = null) => {
  try {
    const exitInfo = {
      timestamp: new Date().toISOString(),
      reason,
      signal,
      processId: process.pid,
      parentProcessId: process.ppid,
      uptime: process.uptime(),
      memoryUsage: process.memoryUsage(),
      cpuUsage: process.cpuUsage(),
      resourceUsage: process.resourceUsage ? process.resourceUsage() : null,
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      workingDirectory: process.cwd(),
      environment: process.env.NODE_ENV,
      argv: process.argv,
      execPath: process.execPath,
      versions: process.versions,
      loadavg: require('os').loadavg(),
      totalmem: require('os').totalmem(),
      freemem: require('os').freemem(),
      cpus: require('os').cpus(),
      hostname: require('os').hostname(),
      networkInterfaces: require('os').networkInterfaces(),
      data: data || null,
      stackTrace: new Error().stack
    };

    const logMessage = JSON.stringify(exitInfo, null, 2) + '\n' + '='.repeat(80) + '\n';
    
    // Write to multiple log files for redundancy
    fs.appendFileSync(path.join(process.cwd(), 'abnormal-exit.log'), logMessage);
    fs.appendFileSync(path.join(process.cwd(), 'crash.log'), logMessage);
    
    console.error(`[ABNORMAL EXIT] ${exitInfo.timestamp} - ${reason}`);
    console.error('Full exit details written to abnormal-exit.log');
  } catch (logError) {
    console.error('Failed to log abnormal exit:', logError);
  }
};

// Handle uncaught exceptions with comprehensive logging
process.on('uncaughtException', (error) => {
  console.error('UNCAUGHT EXCEPTION - Application will exit');
  logError(error, 'UNCAUGHT_EXCEPTION');
  logAbnormalExit('UNCAUGHT_EXCEPTION', {
    error: {
      message: error.message,
      stack: error.stack,
      name: error.name,
      code: error.code
    }
  });
  removePidFile();
  
  // Give time for logs to write before exiting
  setTimeout(() => {
    process.exit(1);
  }, 1000);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('UNHANDLED REJECTION - Application will exit');
  const error = reason instanceof Error ? reason : new Error(String(reason));
  logError(error, 'UNHANDLED_REJECTION');
  logAbnormalExit('UNHANDLED_REJECTION', {
    error: {
      message: error.message,
      stack: error.stack,
      name: error.name
    },
    promise: promise.toString(),
    reason: String(reason)
  });
  console.error('Promise:', promise);
  removePidFile();
  
  // Give time for logs to write before exiting
  setTimeout(() => {
    process.exit(1);
  }, 1000);
});

// Handle various process signals
process.on('SIGABRT', () => {
  console.error('SIGABRT received - Abnormal termination');
  logAbnormalExit('SIGABRT', null, 'SIGABRT');
  removePidFile();
  process.exit(1);
});

process.on('SIGFPE', () => {
  console.error('SIGFPE received - Floating point exception');
  logAbnormalExit('SIGFPE', null, 'SIGFPE');
  removePidFile();
  process.exit(1);
});

process.on('SIGILL', () => {
  console.error('SIGILL received - Illegal instruction');
  logAbnormalExit('SIGILL', null, 'SIGILL');
  removePidFile();
  process.exit(1);
});

process.on('SIGSEGV', () => {
  console.error('SIGSEGV received - Segmentation fault');
  logAbnormalExit('SIGSEGV', null, 'SIGSEGV');
  removePidFile();
  process.exit(1);
});

// Handle warnings
process.on('warning', (warning) => {
  const warningLog = {
    timestamp: new Date().toISOString(),
    type: 'WARNING',
    name: warning.name,
    message: warning.message,
    stack: warning.stack,
    processId: process.pid,
    memoryUsage: process.memoryUsage()
  };
  
  fs.appendFileSync(path.join(process.cwd(), 'warnings.log'), JSON.stringify(warningLog) + '\n');
  console.warn(`[WARNING] ${warning.name}: ${warning.message}`);
});

// Enhanced exit handler that logs normal exits too
process.on('exit', (code) => {
  const exitLog = {
    timestamp: new Date().toISOString(),
    exitCode: code,
    processId: process.pid,
    uptime: process.uptime(),
    memoryUsage: process.memoryUsage(),
    type: code === 0 ? 'NORMAL_EXIT' : 'ABNORMAL_EXIT'
  };
  
  // Use synchronous write since process is exiting
  try {
    fs.appendFileSync(path.join(process.cwd(), 'process-exits.log'), JSON.stringify(exitLog) + '\n');
    console.log(`[EXIT] Process exiting with code ${code} after ${Math.round(process.uptime())} seconds`);
  } catch (e) {
    console.error('Failed to log exit:', e);
  }
});

// Memory monitoring
setInterval(() => {
  const memUsage = process.memoryUsage();
  const memoryMB = {
    rss: Math.round(memUsage.rss / 1024 / 1024),
    heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
    heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
    external: Math.round(memUsage.external / 1024 / 1024)
  };
  
  // Log memory usage if it's high
  if (memoryMB.heapUsed > 500) {
    console.warn(`[MEMORY WARNING] High memory usage: ${JSON.stringify(memoryMB)} MB`);
    const memLog = {
      timestamp: new Date().toISOString(),
      level: 'MEMORY_WARNING',
      memory: memoryMB,
      uptime: process.uptime(),
      processId: process.pid
    };
    fs.appendFileSync(path.join(process.cwd(), 'memory.log'), JSON.stringify(memLog) + '\n');
  }
}, 60000); // Check every minute

app.prepare().then(async () => {
  const server = createServer(async (req, res) => {
    try {
      // Log incoming request
      logRequest(req, res);
      
      const parsedUrl = parse(req.url, true);
      await handle(req, res, parsedUrl);
    } catch (error) {
      logError(error, 'REQUEST_HANDLER');
      res.statusCode = 500;
      res.end('Internal Server Error');
    }
  });

  // Setup graceful shutdown
  setupGracefulShutdown(server);

  // Enhanced error handling for server
  server.on('error', (error) => {
    logError(error, 'SERVER_ERROR');
  });

  server.listen(port, async (err) => {
    if (err) {
      logError(err, 'SERVER_STARTUP');
      throw err;
    }
    console.log(`> Ready on http://${hostname}:${port}`);
    console.log(`> Process ID: ${process.pid}`);
    console.log(`> Memory usage: ${JSON.stringify(process.memoryUsage())}`);
    
    // Write PID file after server starts successfully
    writePidFile();

    // Start application monitoring
    try {
      const { default: monitor } = await import('./src/app/utils/monitor.js');
      monitor.start();
    } catch (monitorError) {
      console.error('Failed to start monitoring:', monitorError);
    }
  });
});