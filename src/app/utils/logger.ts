import fs from 'fs';
import path from 'path';

// Define maximum log file size (e.g., 5MB)
const MAX_LOG_SIZE = 5 * 1024 * 1024; // 5MB
const logFilePath = path.join(process.cwd(), 'api.log');
const archiveLogPath = path.join(process.cwd(), `api-${Date.now()}.log`);

const logger = {
  log: (message: string, ip: string) => {
    const timestamp = new Date().toISOString();
    const logMessage = `${timestamp} - ${ip} - ${message}\n`;
    
    // Check the current log file size
    fs.stat(logFilePath, (err, stats) => {
      if (!err && stats.size >= MAX_LOG_SIZE) {
        // Rotate the log file
        fs.rename(logFilePath, archiveLogPath, (renameErr) => {
          if (renameErr) {
            console.error('Failed to rotate log file:', renameErr);
          }
        });
      }

      // Append the log message
      fs.appendFile(logFilePath, logMessage, (appendErr) => {
        if (appendErr) {
          console.error('Failed to write to log file:', appendErr);
        }
      });
    });
  },
};

export default logger; 