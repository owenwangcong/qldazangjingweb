#!/usr/bin/env node

/**
 * Test script for Elasticsearch functionality
 */

const { getInstance } = require('../services/elasticsearchService');

async function runTests() {
  console.log('🧪 Testing Elasticsearch functionality...\n');

  const esService = getInstance();
  const testResults = [];

  try {
    // 1. Connection test
    console.log('1. Testing connection...');
    const connected = await esService.initialize();
    testResults.push({
      test: 'Connection',
      passed: connected,
      message: connected ? 'Connected successfully' : 'Failed to connect'
    });

    if (!connected) {
      console.error('Cannot proceed without connection');
      return testResults;
    }

    // 2. Index existence test
    console.log('2. Testing index existence...');
    const indexExists = await esService.indexExists();
    testResults.push({
      test: 'Index Exists',
      passed: indexExists,
      message: indexExists ? `Index "${esService.indexName}" exists` : 'Index does not exist'
    });

    if (!indexExists) {
      console.log('Creating index for testing...');
      await esService.createIndex();
    }

    // 3. Document indexing test
    console.log('3. Testing document indexing...');
    const testDoc = {
      id: 'test-001',
      title: '般若波罗蜜多心经',
      author: '玄奘',
      dynasty: '唐',
      content: '观自在菩萨，行深般若波罗蜜多时，照见五蕴皆空，度一切苦厄。',
      created_at: new Date()
    };

    try {
      await esService.indexDocument(testDoc);
      testResults.push({
        test: 'Document Indexing',
        passed: true,
        message: 'Document indexed successfully'
      });
    } catch (error) {
      testResults.push({
        test: 'Document Indexing',
        passed: false,
        message: error.message
      });
    }

    // 4. Search tests
    console.log('4. Testing search modes...');

    // Test exact search
    const exactSearch = await esService.search('心经', { mode: 'exact', size: 5 });
    testResults.push({
      test: 'Exact Search',
      passed: exactSearch !== null,
      message: `Found ${exactSearch?.total || 0} results`
    });

    // Test phrase search
    const phraseSearch = await esService.search('般若', { mode: 'phrase', size: 5 });
    testResults.push({
      test: 'Phrase Search',
      passed: phraseSearch !== null,
      message: `Found ${phraseSearch?.total || 0} results`
    });

    // Test fuzzy search
    const fuzzySearch = await esService.search('菩薩', { mode: 'fuzzy', size: 5 });
    testResults.push({
      test: 'Fuzzy Search',
      passed: fuzzySearch !== null,
      message: `Found ${fuzzySearch?.total || 0} results`
    });

    // Test smart search
    const smartSearch = await esService.search('观音菩萨', { mode: 'smart', size: 5 });
    testResults.push({
      test: 'Smart Search',
      passed: smartSearch !== null,
      message: `Found ${smartSearch?.total || 0} results`
    });

    // 5. Traditional to simplified conversion test
    console.log('5. Testing traditional to simplified conversion...');
    const traditionalText = '觀世音菩薩';
    const searchWithTraditional = await esService.search(traditionalText, { size: 5 });
    testResults.push({
      test: 'Traditional Chinese Search',
      passed: searchWithTraditional !== null,
      message: `Searched for "${traditionalText}"`
    });

    // 6. Analyzer test
    console.log('6. Testing text analyzer...');
    const tokens = await esService.analyzeText('阿弥陀佛');
    testResults.push({
      test: 'Text Analyzer',
      passed: tokens && tokens.length > 0,
      message: `Tokenized into ${tokens?.length || 0} tokens`
    });

    // 7. Cleanup test document
    console.log('7. Cleaning up test document...');
    await esService.deleteDocument('test-001');
    testResults.push({
      test: 'Document Deletion',
      passed: true,
      message: 'Test document deleted'
    });

    // 8. Index statistics
    console.log('8. Getting index statistics...');
    const stats = await esService.getIndexStats();
    testResults.push({
      test: 'Index Statistics',
      passed: stats !== null,
      message: `${stats?.documentCount || 0} documents, ${stats?.sizeInMB || 0} MB`
    });

  } catch (error) {
    console.error('Test error:', error);
    testResults.push({
      test: 'General',
      passed: false,
      message: error.message
    });
  } finally {
    await esService.close();
  }

  // Print results summary
  console.log('\n' + '='.repeat(50));
  console.log('TEST RESULTS SUMMARY');
  console.log('='.repeat(50));

  testResults.forEach(result => {
    const status = result.passed ? '✅' : '❌';
    console.log(`${status} ${result.test}: ${result.message}`);
  });

  const passed = testResults.filter(r => r.passed).length;
  const total = testResults.length;
  const allPassed = passed === total;

  console.log('\n' + '='.repeat(50));
  console.log(`Total: ${passed}/${total} tests passed`);
  console.log(allPassed ? '✅ All tests passed!' : '❌ Some tests failed');

  process.exit(allPassed ? 0 : 1);
}

// Run tests
runTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});