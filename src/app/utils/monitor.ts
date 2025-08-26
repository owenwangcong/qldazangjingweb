import fs from 'fs';
import path from 'path';
import logger from './logger';

interface HealthCheck {
  timestamp: string;
  status: 'healthy' | 'warning' | 'critical';
  uptime: number;
  memory: {
    rss: number;
    heapTotal: number;
    heapUsed: number;
    external: number;
    heapUsedPercent: number;
  };
  cpu: {
    userTime: number;
    systemTime: number;
  };
  diskSpace?: number;
  processId: number;
}

class ApplicationMonitor {
  private healthCheckInterval: NodeJS.Timeout | null = null;
  private healthLogPath = path.join(process.cwd(), 'health.log');
  
  // Memory thresholds in MB
  private readonly MEMORY_WARNING_THRESHOLD = 512;
  private readonly MEMORY_CRITICAL_THRESHOLD = 1024;
  
  // CPU thresholds (percentage)
  private readonly CPU_WARNING_THRESHOLD = 80;
  private readonly CPU_CRITICAL_THRESHOLD = 95;

  start() {
    console.log('[MONITOR] Application monitoring started');
    
    // Perform initial health check
    this.performHealthCheck();
    
    // Schedule periodic health checks every 2 minutes
    this.healthCheckInterval = setInterval(() => {
      this.performHealthCheck();
    }, 120000);

    // Log startup metrics
    this.logStartupMetrics();
  }

  stop() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
      this.healthCheckInterval = null;
      console.log('[MONITOR] Application monitoring stopped');
    }
  }

  private performHealthCheck() {
    try {
      const memUsage = process.memoryUsage();
      const cpuUsage = process.cpuUsage();
      
      const memoryMB = {
        rss: Math.round(memUsage.rss / 1024 / 1024),
        heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
        heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
        external: Math.round(memUsage.external / 1024 / 1024),
        heapUsedPercent: Math.round((memUsage.heapUsed / memUsage.heapTotal) * 100)
      };

      const healthCheck: HealthCheck = {
        timestamp: new Date().toISOString(),
        status: this.determineHealthStatus(memoryMB, cpuUsage),
        uptime: Math.round(process.uptime()),
        memory: memoryMB,
        cpu: {
          userTime: Math.round(cpuUsage.user / 1000), // Convert microseconds to milliseconds
          systemTime: Math.round(cpuUsage.system / 1000)
        },
        processId: process.pid
      };

      // Log health check
      this.logHealthCheck(healthCheck);

      // Alert if status is not healthy
      if (healthCheck.status !== 'healthy') {
        this.handleUnhealthyStatus(healthCheck);
      }

    } catch (error) {
      logger.error('Health check failed', error, 'system');
    }
  }

  private determineHealthStatus(memory: any, cpu: any): 'healthy' | 'warning' | 'critical' {
    // Check memory usage
    if (memory.heapUsed >= this.MEMORY_CRITICAL_THRESHOLD || memory.heapUsedPercent >= 90) {
      return 'critical';
    }
    if (memory.heapUsed >= this.MEMORY_WARNING_THRESHOLD || memory.heapUsedPercent >= 75) {
      return 'warning';
    }

    return 'healthy';
  }

  private logHealthCheck(healthCheck: HealthCheck) {
    const logMessage = JSON.stringify(healthCheck) + '\n';
    
    fs.appendFile(this.healthLogPath, logMessage, (err) => {
      if (err) {
        console.error('Failed to write health check log:', err);
      }
    });

    // Also log to console if not healthy
    if (healthCheck.status !== 'healthy') {
      console.warn(`[HEALTH] Status: ${healthCheck.status.toUpperCase()} - Memory: ${healthCheck.memory.heapUsed}MB (${healthCheck.memory.heapUsedPercent}%)`);
    }
  }

  private handleUnhealthyStatus(healthCheck: HealthCheck) {
    if (healthCheck.status === 'critical') {
      logger.fatal('Application in critical state', new Error('Critical health status'), 'system');
      
      // Force garbage collection if available
      if (global.gc) {
        console.log('[MONITOR] Running garbage collection...');
        global.gc();
      }
    } else if (healthCheck.status === 'warning') {
      logger.warn('Application health warning', 'system');
    }
  }

  private logStartupMetrics() {
    const startupMetrics = {
      timestamp: new Date().toISOString(),
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      processId: process.pid,
      parentProcessId: process.ppid,
      workingDirectory: process.cwd(),
      memoryAtStartup: process.memoryUsage(),
      environment: process.env.NODE_ENV
    };

    logger.log('Application startup metrics', 'system');
    logger.debug('Startup metrics details', startupMetrics);
  }

  // Get current health status synchronously
  getCurrentHealth(): HealthCheck | null {
    try {
      const memUsage = process.memoryUsage();
      const cpuUsage = process.cpuUsage();
      
      const memoryMB = {
        rss: Math.round(memUsage.rss / 1024 / 1024),
        heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
        heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
        external: Math.round(memUsage.external / 1024 / 1024),
        heapUsedPercent: Math.round((memUsage.heapUsed / memUsage.heapTotal) * 100)
      };

      return {
        timestamp: new Date().toISOString(),
        status: this.determineHealthStatus(memoryMB, cpuUsage),
        uptime: Math.round(process.uptime()),
        memory: memoryMB,
        cpu: {
          userTime: Math.round(cpuUsage.user / 1000),
          systemTime: Math.round(cpuUsage.system / 1000)
        },
        processId: process.pid
      };
    } catch (error) {
      logger.error('Failed to get current health status', error, 'system');
      return null;
    }
  }
}

// Create singleton instance
const monitor = new ApplicationMonitor();

export default monitor;