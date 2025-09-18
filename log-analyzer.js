#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

class LogAnalyzer {
  constructor() {
    this.logFiles = {
      api: 'logs/api.log',
      error: 'logs/error.log',
      crash: 'logs/crash.log',
      debug: 'logs/debug.log',
      health: 'logs/health.log',
      memory: 'logs/memory.log',
      requests: 'logs/requests.log',
      abnormalExit: 'logs/abnormal-exit.log',
      processExits: 'logs/process-exits.log',
      warnings: 'logs/warnings.log'
    };
  }

  analyze() {
    console.log('='.repeat(80));
    console.log('APPLICATION LOG ANALYSIS REPORT');
    console.log(`Generated: ${new Date().toISOString()}`);
    console.log('='.repeat(80));
    
    this.analyzeErrorLogs();
    this.analyzeCrashLogs();
    this.analyzeAbnormalExits();
    this.analyzeProcessExits();
    this.analyzeWarnings();
    this.analyzeMemoryUsage();
    this.analyzeRequestPatterns();
    this.analyzeHealthStatus();
    this.generateRecommendations();
  }

  analyzeErrorLogs() {
    console.log('\n📊 ERROR LOG ANALYSIS');
    console.log('-'.repeat(50));
    
    try {
      const errorLogPath = path.join(process.cwd(), this.logFiles.error);
      if (!fs.existsSync(errorLogPath)) {
        console.log('✅ No error log found - application may be running without errors');
        return;
      }

      const content = fs.readFileSync(errorLogPath, 'utf8');
      const lines = content.split('\n').filter(line => line.trim());
      
      console.log(`📝 Total error entries: ${lines.length}`);
      
      if (lines.length === 0) {
        console.log('✅ No errors found in log');
        return;
      }

      // Count errors by type
      const errorTypes = {};
      const recentErrors = [];
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

      lines.forEach(line => {
        try {
          const entry = JSON.parse(line);
          const errorContext = entry.message || 'Unknown error';
          errorTypes[errorContext] = (errorTypes[errorContext] || 0) + 1;
          
          const errorTime = new Date(entry.timestamp);
          if (errorTime > oneHourAgo) {
            recentErrors.push(entry);
          }
        } catch (parseError) {
          console.log(`⚠️  Could not parse error entry: ${line.substring(0, 100)}...`);
        }
      });

      // Show most common errors
      const sortedErrors = Object.entries(errorTypes)
        .sort(([,a], [,b]) => b - a)
        .slice(0, 5);

      console.log('\n🔥 Top 5 Error Types:');
      sortedErrors.forEach(([error, count], index) => {
        console.log(`${index + 1}. ${error}: ${count} occurrences`);
      });

      console.log(`\n⏰ Recent errors (last hour): ${recentErrors.length}`);
      
      if (recentErrors.length > 0) {
        console.log('\n🚨 Recent Error Details:');
        recentErrors.slice(0, 3).forEach((error, index) => {
          console.log(`${index + 1}. ${error.timestamp}: ${error.message}`);
          if (error.stack) {
            console.log(`   Stack: ${error.stack.split('\n')[0]}`);
          }
        });
      }

    } catch (error) {
      console.log(`❌ Error analyzing error logs: ${error.message}`);
    }
  }

  analyzeCrashLogs() {
    console.log('\n💥 CRASH LOG ANALYSIS');
    console.log('-'.repeat(50));
    
    try {
      const crashLogPath = path.join(process.cwd(), this.logFiles.crash);
      if (!fs.existsSync(crashLogPath)) {
        console.log('✅ No crash log found - application appears stable');
        return;
      }

      const content = fs.readFileSync(crashLogPath, 'utf8');
      const lines = content.split('\n').filter(line => line.trim());
      
      console.log(`💀 Total crash entries: ${lines.length}`);
      
      if (lines.length === 0) {
        console.log('✅ No crashes found');
        return;
      }

      const crashTypes = {};
      lines.forEach(line => {
        try {
          const entry = JSON.parse(line);
          const context = entry.context || 'Unknown';
          crashTypes[context] = (crashTypes[context] || 0) + 1;
        } catch (parseError) {
          console.log(`⚠️  Could not parse crash entry`);
        }
      });

      console.log('\n🔥 Crash Types:');
      Object.entries(crashTypes).forEach(([type, count]) => {
        console.log(`• ${type}: ${count} occurrences`);
      });

      // Show last crash
      if (lines.length > 0) {
        try {
          const lastCrash = JSON.parse(lines[lines.length - 1]);
          console.log(`\n⏰ Last crash: ${lastCrash.timestamp}`);
          console.log(`📋 Context: ${lastCrash.context}`);
          console.log(`📝 Message: ${lastCrash.message}`);
        } catch (e) {
          console.log('⚠️  Could not parse last crash entry');
        }
      }

    } catch (error) {
      console.log(`❌ Error analyzing crash logs: ${error.message}`);
    }
  }

  analyzeAbnormalExits() {
    console.log('\n🚨 ABNORMAL EXIT ANALYSIS');
    console.log('-'.repeat(50));
    
    try {
      const abnormalExitLogPath = path.join(process.cwd(), this.logFiles.abnormalExit);
      if (!fs.existsSync(abnormalExitLogPath)) {
        console.log('✅ No abnormal exits detected');
        return;
      }

      const content = fs.readFileSync(abnormalExitLogPath, 'utf8');
      const sections = content.split('='.repeat(80)).filter(section => section.trim());
      
      console.log(`🚪 Total abnormal exit events: ${sections.length}`);
      
      if (sections.length === 0) {
        console.log('✅ No abnormal exits found');
        return;
      }

      const exitReasons = {};
      const systemInfo = [];

      sections.forEach(section => {
        try {
          const entry = JSON.parse(section.trim());
          const reason = entry.reason || 'Unknown';
          exitReasons[reason] = (exitReasons[reason] || 0) + 1;
          
          if (systemInfo.length < 3) { // Store system info from recent exits
            systemInfo.push({
              timestamp: entry.timestamp,
              reason: entry.reason,
              uptime: Math.round(entry.uptime / 60), // minutes
              memoryUsed: Math.round(entry.memoryUsage?.heapUsed / 1024 / 1024), // MB
              freeMemory: Math.round(entry.freemem / 1024 / 1024 / 1024), // GB
              loadAvg: entry.loadavg?.[0]?.toFixed(2)
            });
          }
        } catch (parseError) {
          console.log(`⚠️  Could not parse abnormal exit entry`);
        }
      });

      console.log('\n🔥 Exit Reasons:');
      Object.entries(exitReasons).forEach(([reason, count]) => {
        const emoji = reason.includes('EXCEPTION') ? '💥' :
                     reason.includes('REJECTION') ? '🚫' :
                     reason.includes('SIG') ? '⚡' : '❓';
        console.log(`${emoji} ${reason}: ${count} occurrences`);
      });

      console.log('\n📊 Recent Exit Details:');
      systemInfo.forEach((info, index) => {
        console.log(`${index + 1}. ${info.timestamp}`);
        console.log(`   Reason: ${info.reason}`);
        console.log(`   Uptime: ${info.uptime} minutes`);
        console.log(`   Memory: ${info.memoryUsed}MB used, ${info.freeMemory}GB free`);
        console.log(`   Load Average: ${info.loadAvg}`);
        console.log('');
      });

    } catch (error) {
      console.log(`❌ Error analyzing abnormal exit logs: ${error.message}`);
    }
  }

  analyzeProcessExits() {
    console.log('\n🚪 PROCESS EXIT ANALYSIS');
    console.log('-'.repeat(50));
    
    try {
      const processExitLogPath = path.join(process.cwd(), this.logFiles.processExits);
      if (!fs.existsSync(processExitLogPath)) {
        console.log('✅ No process exit log found');
        return;
      }

      const content = fs.readFileSync(processExitLogPath, 'utf8');
      const lines = content.split('\n').filter(line => line.trim());
      
      console.log(`📊 Total process exits: ${lines.length}`);
      
      if (lines.length === 0) {
        console.log('📝 No process exits recorded');
        return;
      }

      const exitCodes = {};
      let normalExits = 0;
      let abnormalExits = 0;
      let totalUptime = 0;

      lines.forEach(line => {
        try {
          const entry = JSON.parse(line);
          const code = entry.exitCode;
          exitCodes[code] = (exitCodes[code] || 0) + 1;
          
          if (entry.type === 'NORMAL_EXIT') {
            normalExits++;
          } else {
            abnormalExits++;
          }
          
          totalUptime += entry.uptime || 0;
        } catch (parseError) {
          // Skip invalid entries
        }
      });

      console.log(`✅ Normal exits: ${normalExits}`);
      console.log(`❌ Abnormal exits: ${abnormalExits}`);
      
      if (lines.length > 0) {
        const avgUptime = Math.round((totalUptime / lines.length) / 60); // minutes
        console.log(`⏱️  Average uptime: ${avgUptime} minutes`);
      }

      console.log('\n📊 Exit Codes:');
      Object.entries(exitCodes).forEach(([code, count]) => {
        const emoji = code === '0' ? '✅' : '❌';
        const description = code === '0' ? '(normal)' : 
                          code === '1' ? '(general error)' :
                          `(code ${code})`;
        console.log(`${emoji} Exit Code ${code} ${description}: ${count} times`);
      });

    } catch (error) {
      console.log(`❌ Error analyzing process exit logs: ${error.message}`);
    }
  }

  analyzeWarnings() {
    console.log('\n⚠️  WARNING ANALYSIS');
    console.log('-'.repeat(50));
    
    try {
      const warningsLogPath = path.join(process.cwd(), this.logFiles.warnings);
      if (!fs.existsSync(warningsLogPath)) {
        console.log('✅ No warnings found');
        return;
      }

      const content = fs.readFileSync(warningsLogPath, 'utf8');
      const lines = content.split('\n').filter(line => line.trim());
      
      console.log(`📊 Total warnings: ${lines.length}`);
      
      if (lines.length === 0) {
        console.log('✅ No warnings recorded');
        return;
      }

      const warningTypes = {};
      const recentWarnings = [];
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

      lines.forEach(line => {
        try {
          const entry = JSON.parse(line);
          const warningName = entry.name || 'Unknown';
          warningTypes[warningName] = (warningTypes[warningName] || 0) + 1;
          
          const warningTime = new Date(entry.timestamp);
          if (warningTime > oneHourAgo) {
            recentWarnings.push(entry);
          }
        } catch (parseError) {
          // Skip invalid entries
        }
      });

      console.log('\n🔥 Warning Types:');
      Object.entries(warningTypes).forEach(([type, count]) => {
        console.log(`• ${type}: ${count} occurrences`);
      });

      console.log(`\n⏰ Recent warnings (last hour): ${recentWarnings.length}`);
      
      if (recentWarnings.length > 0) {
        console.log('\n📋 Recent Warning Details:');
        recentWarnings.slice(0, 3).forEach((warning, index) => {
          console.log(`${index + 1}. ${warning.timestamp}: ${warning.name}`);
          console.log(`   Message: ${warning.message}`);
        });
      }

    } catch (error) {
      console.log(`❌ Error analyzing warnings: ${error.message}`);
    }
  }

  analyzeMemoryUsage() {
    console.log('\n🧠 MEMORY USAGE ANALYSIS');
    console.log('-'.repeat(50));
    
    try {
      const memoryLogPath = path.join(process.cwd(), this.logFiles.memory);
      if (!fs.existsSync(memoryLogPath)) {
        console.log('✅ No memory warnings found');
        return;
      }

      const content = fs.readFileSync(memoryLogPath, 'utf8');
      const lines = content.split('\n').filter(line => line.trim());
      
      console.log(`📊 Memory warning entries: ${lines.length}`);
      
      if (lines.length > 0) {
        try {
          const lastEntry = JSON.parse(lines[lines.length - 1]);
          console.log(`\n⚠️  Last memory warning: ${lastEntry.timestamp}`);
          console.log(`💾 Memory usage: ${JSON.stringify(lastEntry.memory)} MB`);
          console.log(`⏱️  Uptime at warning: ${Math.round(lastEntry.uptime / 60)} minutes`);
        } catch (e) {
          console.log('⚠️  Could not parse last memory entry');
        }
      }

    } catch (error) {
      console.log(`❌ Error analyzing memory logs: ${error.message}`);
    }
  }

  analyzeRequestPatterns() {
    console.log('\n🌐 REQUEST PATTERN ANALYSIS');
    console.log('-'.repeat(50));
    
    try {
      const requestLogPath = path.join(process.cwd(), this.logFiles.requests);
      if (!fs.existsSync(requestLogPath)) {
        console.log('⚠️  No request log found');
        return;
      }

      const content = fs.readFileSync(requestLogPath, 'utf8');
      const lines = content.split('\n').filter(line => line.trim());
      
      console.log(`📊 Total requests logged: ${lines.length}`);
      
      if (lines.length === 0) {
        console.log('📝 No requests found in log');
        return;
      }

      const endpoints = {};
      const statusCodes = {};
      let totalDuration = 0;
      let durationsCount = 0;
      const slowRequests = [];

      lines.forEach(line => {
        try {
          const entry = JSON.parse(line);
          
          // Count endpoints
          const endpoint = entry.url || 'unknown';
          endpoints[endpoint] = (endpoints[endpoint] || 0) + 1;
          
          // Count status codes
          const status = entry.statusCode || 'unknown';
          statusCodes[status] = (statusCodes[status] || 0) + 1;
          
          // Analyze response times
          if (entry.duration && entry.duration.includes('ms')) {
            const duration = parseInt(entry.duration.replace('ms', ''));
            totalDuration += duration;
            durationsCount++;
            
            if (duration > 5000) { // Slow requests > 5s
              slowRequests.push({
                url: entry.url,
                duration: entry.duration,
                timestamp: entry.timestamp
              });
            }
          }
        } catch (parseError) {
          // Skip invalid entries
        }
      });

      // Top endpoints
      const topEndpoints = Object.entries(endpoints)
        .sort(([,a], [,b]) => b - a)
        .slice(0, 5);

      console.log('\n🔥 Top 5 Requested Endpoints:');
      topEndpoints.forEach(([endpoint, count], index) => {
        console.log(`${index + 1}. ${endpoint}: ${count} requests`);
      });

      // Status codes
      console.log('\n📊 Response Status Codes:');
      Object.entries(statusCodes).forEach(([status, count]) => {
        const emoji = status.startsWith('2') ? '✅' : 
                     status.startsWith('4') ? '⚠️' : 
                     status.startsWith('5') ? '❌' : '📊';
        console.log(`${emoji} ${status}: ${count} responses`);
      });

      // Average response time
      if (durationsCount > 0) {
        const avgDuration = Math.round(totalDuration / durationsCount);
        console.log(`\n⚡ Average response time: ${avgDuration}ms`);
      }

      // Slow requests
      if (slowRequests.length > 0) {
        console.log(`\n🐌 Slow requests (>5s): ${slowRequests.length}`);
        slowRequests.slice(0, 3).forEach((req, index) => {
          console.log(`${index + 1}. ${req.url} - ${req.duration} at ${req.timestamp}`);
        });
      }

    } catch (error) {
      console.log(`❌ Error analyzing request logs: ${error.message}`);
    }
  }

  analyzeHealthStatus() {
    console.log('\n❤️  HEALTH STATUS ANALYSIS');
    console.log('-'.repeat(50));
    
    try {
      const healthLogPath = path.join(process.cwd(), this.logFiles.health);
      if (!fs.existsSync(healthLogPath)) {
        console.log('⚠️  No health log found');
        return;
      }

      const content = fs.readFileSync(healthLogPath, 'utf8');
      const lines = content.split('\n').filter(line => line.trim());
      
      if (lines.length === 0) {
        console.log('📝 No health checks found');
        return;
      }

      console.log(`📊 Health check entries: ${lines.length}`);

      const statusCounts = { healthy: 0, warning: 0, critical: 0 };
      let lastEntry = null;

      lines.forEach(line => {
        try {
          const entry = JSON.parse(line);
          if (entry.status && statusCounts.hasOwnProperty(entry.status)) {
            statusCounts[entry.status]++;
          }
          lastEntry = entry;
        } catch (parseError) {
          // Skip invalid entries
        }
      });

      console.log('\n📊 Health Status Distribution:');
      console.log(`✅ Healthy: ${statusCounts.healthy}`);
      console.log(`⚠️  Warning: ${statusCounts.warning}`);
      console.log(`❌ Critical: ${statusCounts.critical}`);

      if (lastEntry) {
        console.log(`\n📋 Last Health Check (${lastEntry.timestamp}):`);
        console.log(`   Status: ${lastEntry.status}`);
        console.log(`   Uptime: ${Math.round(lastEntry.uptime / 60)} minutes`);
        if (lastEntry.memory) {
          console.log(`   Memory: ${lastEntry.memory.heapUsed}MB (${lastEntry.memory.heapUsedPercent}%)`);
        }
      }

    } catch (error) {
      console.log(`❌ Error analyzing health logs: ${error.message}`);
    }
  }

  generateRecommendations() {
    console.log('\n💡 RECOMMENDATIONS');
    console.log('-'.repeat(50));

    const recommendations = [];

    // Check if crash log exists
    if (fs.existsSync(path.join(process.cwd(), this.logFiles.crash))) {
      recommendations.push('🚨 Application has experienced crashes - review crash.log for root causes');
    }

    // Check if abnormal exit log exists
    if (fs.existsSync(path.join(process.cwd(), this.logFiles.abnormalExit))) {
      recommendations.push('🚪 Abnormal exits detected - review abnormal-exit.log for detailed system state at exit');
    }

    // Check if warnings exist
    if (fs.existsSync(path.join(process.cwd(), this.logFiles.warnings))) {
      recommendations.push('⚠️  Process warnings detected - review warnings.log to prevent future issues');
    }

    // Check if error log is large
    try {
      const errorLogPath = path.join(process.cwd(), this.logFiles.error);
      if (fs.existsSync(errorLogPath)) {
        const stats = fs.statSync(errorLogPath);
        if (stats.size > 10 * 1024 * 1024) { // > 10MB
          recommendations.push('📁 Error log is large (>10MB) - consider log rotation and error reduction');
        }
      }
    } catch (e) {
      // Ignore file check errors
    }

    // Check if memory log exists
    if (fs.existsSync(path.join(process.cwd(), this.logFiles.memory))) {
      recommendations.push('💾 Memory warnings detected - monitor memory usage and consider optimization');
    }

    // Check process exits pattern
    try {
      const processExitLogPath = path.join(process.cwd(), this.logFiles.processExits);
      if (fs.existsSync(processExitLogPath)) {
        const content = fs.readFileSync(processExitLogPath, 'utf8');
        const lines = content.split('\n').filter(line => line.trim());
        let abnormalExits = 0;
        
        lines.forEach(line => {
          try {
            const entry = JSON.parse(line);
            if (entry.type === 'ABNORMAL_EXIT') abnormalExits++;
          } catch (e) {}
        });
        
        if (abnormalExits > 0) {
          const ratio = abnormalExits / lines.length;
          if (ratio > 0.5) {
            recommendations.push('📈 High abnormal exit rate detected - investigate stability issues');
          }
        }
      }
    } catch (e) {
      // Ignore file check errors
    }

    // General recommendations
    recommendations.push('📊 Regularly run this analyzer to monitor application health');
    recommendations.push('🔄 Set up automated log rotation to prevent disk space issues');
    recommendations.push('📧 Consider setting up alerts for critical errors and crashes');
    recommendations.push('🔍 Review abnormal-exit.log for comprehensive system information during crashes');
    recommendations.push('⏰ Monitor application uptime patterns in process-exits.log');

    if (recommendations.length <= 5) { // Only general recommendations
      console.log('✅ No immediate issues detected - application appears healthy!');
      console.log('\nGeneral maintenance recommendations:');
      recommendations.slice(-5).forEach((rec, index) => {
        console.log(`${index + 1}. ${rec}`);
      });
    } else {
      console.log('⚠️  Issues detected that require attention:');
      recommendations.forEach((rec, index) => {
        console.log(`${index + 1}. ${rec}`);
      });
    }
  }
}

// Run analyzer if called directly
if (require.main === module) {
  const analyzer = new LogAnalyzer();
  analyzer.analyze();
}

module.exports = LogAnalyzer;