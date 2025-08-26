# Enhanced Logging System

This application now includes a comprehensive logging system to help debug crashes and performance issues.

## Log Files Generated

The application creates several log files in the root directory:

- **`api.log`** - General API request logs with structured JSON data
- **`error.log`** - Error-specific logs with stack traces  
- **`crash.log`** - Critical application crashes and fatal errors
- **`abnormal-exit.log`** - Comprehensive system information during abnormal exits
- **`process-exits.log`** - All process exits (normal and abnormal) with exit codes
- **`warnings.log`** - Node.js process warnings and deprecations
- **`debug.log`** - Debug information (only in development mode)
- **`health.log`** - Application health checks and monitoring data
- **`memory.log`** - Memory usage warnings when consumption is high
- **`requests.log`** - Detailed HTTP request/response logging

## Log Levels

The logger supports multiple levels:

- **DEBUG** - Development debugging information
- **INFO** - General informational messages
- **WARN** - Warning conditions that should be investigated
- **ERROR** - Error conditions with stack traces
- **FATAL** - Critical errors that may cause application termination

## Features

### 1. Structured Logging
All logs are in JSON format with consistent fields:
```json
{
  "timestamp": "2024-01-01T12:00:00.000Z",
  "level": "ERROR",
  "ip": "127.0.0.1",
  "message": "API request failed",
  "userAgent": "Mozilla/5.0...",
  "method": "POST",
  "url": "/api/todict",
  "stack": "Error: Connection failed\n    at ...",
  "processId": 1234,
  "memoryUsage": {...}
}
```

### 2. Memory Monitoring
- Tracks heap usage, RSS, and external memory
- Logs warnings when memory usage exceeds thresholds
- Monitors memory growth patterns over time

### 3. Request Tracking
- Logs all HTTP requests with response times
- Tracks status codes and identifies slow requests
- Records user agents and IP addresses for analysis

### 4. Health Checks
- Periodic application health monitoring
- CPU and memory usage tracking
- System uptime and performance metrics

### 5. Enhanced Crash Detection & Exit Logging
- Catches uncaught exceptions and unhandled rejections
- Logs detailed crash information before graceful shutdown
- Comprehensive system state capture during abnormal exits including:
  - Memory usage, CPU usage, and system load
  - Network interfaces and hostname
  - Process information and command line arguments
  - Node.js version and platform details
  - Stack traces and error details
- Handles multiple signal types (SIGABRT, SIGFPE, SIGILL, SIGSEGV)
- Records all process exits with exit codes and uptime
- Captures Node.js process warnings

### 6. Automatic Log Rotation
- Prevents log files from growing too large (5MB limit)
- Archives old logs with timestamps
- Maintains disk space efficiency

## Usage

### Basic Logging
```typescript
import logger from '@/app/utils/logger';

// Info logging
logger.log('User action completed', userIp, userAgent, method, url);

// Error logging with stack trace
logger.error('Database connection failed', error, userIp, userAgent, method, url);

// Warning
logger.warn('High memory usage detected', userIp);

// Debug (development only)
logger.debug('Processing user data', { userId: 123 }, userIp);

// Fatal error
logger.fatal('Critical system failure', error, userIp);
```

### Health Check API
Access real-time application health at: `GET /api/health`

Returns:
```json
{
  "status": "healthy|warning|critical",
  "timestamp": "2024-01-01T12:00:00.000Z", 
  "uptime": 3600,
  "memory": {
    "heapUsed": 45,
    "heapTotal": 67,
    "rss": 89,
    "external": 12,
    "heapUsedPercent": 67
  },
  "processId": 1234,
  "logs": {
    "api.log": { "size": 1024, "lastModified": "...", "exists": true },
    "error.log": { "size": 0, "exists": false }
  }
}
```

### Log Analysis
Run the log analyzer to get insights:

```bash
node log-analyzer.js
```

This generates a comprehensive report including:
- Error frequency and patterns
- Crash analysis and root causes
- Memory usage trends
- Request performance metrics
- Health status over time
- Actionable recommendations

## Troubleshooting Common Issues

### High Memory Usage
1. Check `memory.log` for memory consumption patterns
2. Look for memory leaks in `health.log`
3. Review API endpoints for resource-heavy operations
4. Consider implementing pagination or request throttling

### Frequent Crashes
1. Examine `crash.log` for crash contexts and stack traces
2. Look for unhandled promise rejections
3. Check for resource exhaustion patterns
4. Review recent code changes that might introduce instability

### Slow Performance
1. Analyze `requests.log` for slow endpoints (>5s response time)
2. Check external API response times in debug logs
3. Monitor database query performance
4. Review PDF generation timeouts and resource usage

### API Errors
1. Check `error.log` for detailed error information
2. Look for patterns in failed requests
3. Verify external API connectivity and responses
4. Review input validation and error handling

## Configuration

### Memory Thresholds
Adjust in `src/app/utils/monitor.ts`:
```typescript
private readonly MEMORY_WARNING_THRESHOLD = 512; // MB
private readonly MEMORY_CRITICAL_THRESHOLD = 1024; // MB
```

### Log Rotation Size
Modify in `src/app/utils/logger.ts`:
```typescript
const MAX_LOG_SIZE = 5 * 1024 * 1024; // 5MB
```

### Health Check Interval
Change monitoring frequency in `src/app/utils/monitor.ts`:
```typescript
setInterval(() => {
  this.performHealthCheck();
}, 120000); // 2 minutes
```

## Best Practices

1. **Regular Monitoring**: Run `node log-analyzer.js` daily to identify issues early
2. **Log Cleanup**: Set up automated log archival to prevent disk space issues  
3. **Alert Setup**: Configure monitoring alerts for critical errors and crashes
4. **Performance Tracking**: Monitor request response times and memory usage trends
5. **Error Investigation**: Always investigate and fix recurring errors promptly

## Production Deployment

For production environments:

1. Set `NODE_ENV=production` to disable debug logging
2. Configure log forwarding to centralized logging service
3. Set up automated log rotation and cleanup
4. Enable real-time monitoring and alerting
5. Consider using process managers like PM2 for additional monitoring

The enhanced logging system provides comprehensive visibility into application behavior, making it much easier to identify and resolve issues that cause crashes.