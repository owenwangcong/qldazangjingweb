import { NextRequest, NextResponse } from 'next/server';
import monitor from '../../utils/monitor';
import logger from '../../utils/logger';
import fs from 'fs';
import path from 'path';

export async function GET(request: NextRequest) {
  const userIp = request.headers.get('x-forwarded-for') || request.ip || 'Unknown IP';
  const userAgent = request.headers.get('user-agent') || 'Unknown';

  try {
    logger.log('Health check requested', userIp, userAgent, 'GET', '/api/health');

    // Get current health status
    const health = monitor.getCurrentHealth();
    
    if (!health) {
      logger.error('Health check failed - unable to get status', new Error('Health status unavailable'), userIp, userAgent, 'GET', '/api/health');
      return NextResponse.json({ 
        status: 'error',
        message: 'Unable to determine health status',
        timestamp: new Date().toISOString()
      }, { status: 500 });
    }

    // Read recent log entries for additional context
    const logSummary = await getRecentLogSummary();

    const response = {
      ...health,
      logs: logSummary,
      version: process.env.npm_package_version || '0.1.0',
      nodeVersion: process.version,
      platform: `${process.platform}-${process.arch}`,
      environment: process.env.NODE_ENV
    };

    const statusCode = health.status === 'healthy' ? 200 : 
                      health.status === 'warning' ? 200 : 503;

    return NextResponse.json(response, { status: statusCode });

  } catch (error: any) {
    logger.error('Health check endpoint failed', error, userIp, userAgent, 'GET', '/api/health');
    return NextResponse.json({ 
      status: 'error',
      message: 'Health check failed',
      error: error.message,
      timestamp: new Date().toISOString()
    }, { status: 500 });
  }
}

async function getRecentLogSummary() {
  try {
    const logFiles = ['api.log', 'error.log', 'crash.log'];
    const logSummary: Record<string, any> = {};

    for (const logFile of logFiles) {
      const logPath = path.join(process.cwd(), logFile);
      
      if (fs.existsSync(logPath)) {
        const stats = fs.statSync(logPath);
        logSummary[logFile] = {
          size: Math.round(stats.size / 1024), // Size in KB
          lastModified: stats.mtime.toISOString(),
          exists: true
        };

        // Get recent entries count (last 10 minutes)
        if (logFile === 'error.log') {
          try {
            const content = fs.readFileSync(logPath, 'utf8');
            const lines = content.split('\n').filter(line => line.trim());
            const recentErrors = lines.filter(line => {
              try {
                const entry = JSON.parse(line);
                const entryTime = new Date(entry.timestamp);
                const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
                return entryTime > tenMinutesAgo;
              } catch {
                return false;
              }
            });
            logSummary[logFile].recentErrors = recentErrors.length;
          } catch (readError) {
            logSummary[logFile].recentErrors = 'unavailable';
          }
        }
      } else {
        logSummary[logFile] = { exists: false };
      }
    }

    return logSummary;
  } catch (error) {
    return { error: 'Unable to read log files' };
  }
}