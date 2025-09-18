import fs from 'fs';
import path from 'path';

// Define maximum log file size (e.g., 5MB)
const MAX_LOG_SIZE = 5 * 1024 * 1024; // 5MB

// Ensure logs directory exists
const logsDir = path.join(process.cwd(), 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

const logFilePath = path.join(process.cwd(), 'logs', 'api.log');
const errorLogPath = path.join(process.cwd(), 'logs', 'error.log');
const debugLogPath = path.join(process.cwd(), 'logs', 'debug.log');

enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
  FATAL = 'FATAL'
}

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  ip: string;
  message: string;
  userAgent?: string;
  method?: string;
  url?: string;
  stack?: string;
  processId: number;
  memoryUsage: NodeJS.MemoryUsage;
}

const logger = {
  // Enhanced logging with different levels and structured data
  writeLog: (entry: LogEntry, filePath: string) => {
    const logMessage = JSON.stringify(entry) + '\n';
    
    // Check file size and rotate if needed
    fs.stat(filePath, (err, stats) => {
      if (!err && stats.size >= MAX_LOG_SIZE) {
        const archivePath = filePath.replace('.log', `-${Date.now()}.log`);
        fs.rename(filePath, archivePath, (renameErr) => {
          if (renameErr) {
            console.error('Failed to rotate log file:', renameErr);
          }
        });
      }

      // Append the log message
      fs.appendFile(filePath, logMessage, (appendErr) => {
        if (appendErr) {
          console.error('Failed to write to log file:', appendErr);
        }
      });
    });
  },

  log: (message: string, ip: string, userAgent?: string, method?: string, url?: string) => {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.INFO,
      ip,
      message,
      userAgent,
      method,
      url,
      processId: process.pid,
      memoryUsage: process.memoryUsage()
    };
    
    logger.writeLog(entry, logFilePath);
    console.log(`[${entry.level}] ${entry.timestamp} - ${ip} - ${message}`);
  },

  error: (message: string, error: Error | unknown, ip: string, userAgent?: string, method?: string, url?: string) => {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.ERROR,
      ip,
      message,
      userAgent,
      method,
      url,
      stack: error instanceof Error ? error.stack : String(error),
      processId: process.pid,
      memoryUsage: process.memoryUsage()
    };
    
    logger.writeLog(entry, errorLogPath);
    logger.writeLog(entry, logFilePath);
    console.error(`[${entry.level}] ${entry.timestamp} - ${ip} - ${message}`, error);
  },

  warn: (message: string, ip: string, userAgent?: string, method?: string, url?: string) => {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.WARN,
      ip,
      message,
      userAgent,
      method,
      url,
      processId: process.pid,
      memoryUsage: process.memoryUsage()
    };
    
    logger.writeLog(entry, logFilePath);
    console.warn(`[${entry.level}] ${entry.timestamp} - ${ip} - ${message}`);
  },

  debug: (message: string, data?: any, ip?: string) => {
    if (process.env.NODE_ENV === 'development') {
      const entry: LogEntry = {
        timestamp: new Date().toISOString(),
        level: LogLevel.DEBUG,
        ip: ip || 'system',
        message: data ? `${message} - Data: ${JSON.stringify(data)}` : message,
        processId: process.pid,
        memoryUsage: process.memoryUsage()
      };
      
      logger.writeLog(entry, debugLogPath);
      console.debug(`[${entry.level}] ${entry.timestamp} - ${message}`, data);
    }
  },

  fatal: (message: string, error: Error | unknown, ip: string) => {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.FATAL,
      ip,
      message,
      stack: error instanceof Error ? error.stack : String(error),
      processId: process.pid,
      memoryUsage: process.memoryUsage()
    };
    
    logger.writeLog(entry, errorLogPath);
    logger.writeLog(entry, logFilePath);
    console.error(`[${entry.level}] ${entry.timestamp} - ${ip} - FATAL: ${message}`, error);
  }
};

export default logger; 