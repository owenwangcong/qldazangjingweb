#!/usr/bin/env node

/**
 * Setup script for Elasticsearch
 * Usage: node scripts/setup-elasticsearch.js [--reset]
 */

const { getInstance } = require('../services/elasticsearchService');

async function setup(reset = false) {
  console.log('🚀 Starting Elasticsearch setup...\n');

  const esService = getInstance();

  try {
    // 1. Test connection
    console.log('1. Testing Elasticsearch connection...');
    const connected = await esService.initialize();

    if (!connected) {
      console.error('❌ Failed to connect to Elasticsearch');
      console.log('\nPlease ensure:');
      console.log('  - Elasticsearch is installed and running');
      console.log('  - Connection settings in config/elasticsearch.config.js are correct');
      console.log('  - Environment variables are set properly');
      process.exit(1);
    }
    console.log('✅ Connected to Elasticsearch');

    // 2. Check/Create index
    console.log('\n2. Checking index...');
    const indexExists = await esService.indexExists();

    if (indexExists) {
      console.log(`Index "${esService.indexName}" already exists`);

      if (reset) {
        console.log('Deleting existing index (--reset flag provided)...');
        await esService.deleteIndex();
        console.log('✅ Index deleted');

        console.log('Creating new index...');
        await esService.createIndex();
        console.log('✅ Index created');
      } else {
        console.log('ℹ️  Use --reset flag to recreate the index');
      }
    } else {
      console.log('Creating index...');
      await esService.createIndex();
      console.log('✅ Index created');
    }

    // 3. Test analyzer
    console.log('\n3. Testing Buddhist analyzer...');
    const tokens = await esService.analyzeText('般若波罗蜜多心经');
    console.log('Sample tokenization:', tokens.map(t => t.token).join(', '));
    console.log('✅ Analyzer working');

    // 4. Get index info
    if (await esService.indexExists()) {
      console.log('\n4. Index statistics:');
      const stats = await esService.getIndexStats();
      console.log(`  - Documents: ${stats.documentCount}`);
      console.log(`  - Size: ${stats.sizeInMB} MB`);
    }

    console.log('\n✅ Elasticsearch setup complete!');
    console.log('\nNext steps:');
    console.log('  1. Run: node scripts/import-to-elasticsearch.js');
    console.log('  2. Set NEXT_PUBLIC_USE_ELASTICSEARCH=true in .env.local');
    console.log('  3. Restart the application');

  } catch (error) {
    console.error('\n❌ Setup failed:', error);
    process.exit(1);
  } finally {
    await esService.close();
  }
}

// Parse arguments
const args = process.argv.slice(2);
const reset = args.includes('--reset');

// Run setup
setup(reset).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});