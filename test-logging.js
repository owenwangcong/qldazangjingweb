#!/usr/bin/env node

// Test script to demonstrate the enhanced logging system
const fs = require('fs');
const path = require('path');

console.log('Testing enhanced logging system...\n');

// Test 1: Create a sample error log
console.log('1. Creating sample error log entry...');
const errorEntry = {
  timestamp: new Date().toISOString(),
  level: 'ERROR',
  ip: '127.0.0.1',
  message: 'Test error for demonstration',
  stack: 'Error: Test error\n    at test-logging.js:15:1',
  processId: process.pid,
  memoryUsage: process.memoryUsage()
};

fs.appendFileSync('error.log', JSON.stringify(errorEntry) + '\n');
console.log('   ✅ Sample error logged');

// Test 2: Create a sample request log
console.log('\n2. Creating sample request log entry...');
const requestEntry = {
  timestamp: new Date().toISOString(),
  method: 'GET',
  url: '/test-endpoint',
  ip: '127.0.0.1',
  userAgent: 'Test-Agent/1.0',
  statusCode: 200,
  duration: '150ms',
  memoryUsage: process.memoryUsage()
};

fs.appendFileSync('requests.log', JSON.stringify(requestEntry) + '\n');
console.log('   ✅ Sample request logged');

// Test 3: Create a sample process exit log
console.log('\n3. Creating sample process exit log entry...');
const exitEntry = {
  timestamp: new Date().toISOString(),
  exitCode: 0,
  processId: process.pid,
  uptime: process.uptime(),
  memoryUsage: process.memoryUsage(),
  type: 'NORMAL_EXIT'
};

fs.appendFileSync('process-exits.log', JSON.stringify(exitEntry) + '\n');
console.log('   ✅ Sample process exit logged');

// Test 4: Create a sample warning log
console.log('\n4. Creating sample warning log entry...');
const warningEntry = {
  timestamp: new Date().toISOString(),
  type: 'WARNING',
  name: 'DeprecationWarning',
  message: 'Test deprecation warning for demonstration',
  processId: process.pid,
  memoryUsage: process.memoryUsage()
};

fs.appendFileSync('warnings.log', JSON.stringify(warningEntry) + '\n');
console.log('   ✅ Sample warning logged');

// Test 5: Generate a comprehensive abnormal exit log
console.log('\n5. Creating sample abnormal exit log entry...');
const abnormalExitEntry = {
  timestamp: new Date().toISOString(),
  reason: 'TEST_DEMONSTRATION',
  signal: null,
  processId: process.pid,
  parentProcessId: process.ppid,
  uptime: process.uptime(),
  memoryUsage: process.memoryUsage(),
  cpuUsage: process.cpuUsage(),
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
  hostname: require('os').hostname(),
  networkInterfaces: Object.keys(require('os').networkInterfaces()),
  data: {
    error: {
      message: 'Test abnormal exit simulation',
      stack: 'Error: Simulated error\n    at test-logging.js:50:1',
      name: 'TestError'
    }
  },
  stackTrace: new Error().stack
};

const logMessage = JSON.stringify(abnormalExitEntry, null, 2) + '\n' + '='.repeat(80) + '\n';
fs.appendFileSync('abnormal-exit.log', logMessage);
console.log('   ✅ Sample abnormal exit logged');

console.log('\n📊 Testing complete! Running log analyzer...\n');

// Run the log analyzer
const LogAnalyzer = require('./log-analyzer');
const analyzer = new LogAnalyzer();
analyzer.analyze();

console.log('\n🧹 Cleaning up test logs...');
const testLogs = ['error.log', 'requests.log', 'process-exits.log', 'warnings.log', 'abnormal-exit.log'];
testLogs.forEach(logFile => {
  if (fs.existsSync(logFile)) {
    fs.unlinkSync(logFile);
    console.log(`   🗑️  Removed ${logFile}`);
  }
});

console.log('\n✅ Test complete! The enhanced logging system is ready to capture detailed information when your application exits abnormally.');