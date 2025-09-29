const fs = require('fs').promises;
const path = require('path');
const { getInstance } = require('../services/elasticsearchService');

// Parse command line arguments
const args = process.argv.slice(2);
const forceRecreate = args.includes('--force');
const skipExisting = args.includes('--skip-existing');

async function parseBookJSON(jsonData, id) {
  // Extract metadata
  const { meta, juans } = jsonData;

  // Combine all content from juans
  let allContent = '';
  if (juans && Array.isArray(juans)) {
    for (const juan of juans) {
      if (juan.content && Array.isArray(juan.content)) {
        allContent += juan.content.join('') + '\n';
      }
    }
  }

  return {
    id: meta.id || id,
    bu: meta.Bu || '',
    title: meta.title || `Book ${id}`,
    author: meta.Arthur || '佚名',
    last_bu: meta.last_bu || null,
    next_bu: meta.next_bu || null,
    juans: juans || [],
    content: allContent.trim(),
    content_length: allContent.length,
    created_at: new Date(),
    updated_at: new Date()
  };
}

async function loadBooks() {
  const booksDir = path.join(__dirname, '..', 'public', 'data', 'books');

  try {
    const files = await fs.readdir(booksDir);
    const jsonFiles = files.filter(file => file.endsWith('.json'));

    console.log(`Found ${jsonFiles.length} book files`);

    const books = [];
    let errorCount = 0;

    for (const file of jsonFiles) {
      try {
        const id = file.replace('.json', '');
        const fileContent = await fs.readFile(path.join(booksDir, file), 'utf-8');

        if (!fileContent || fileContent.trim().length === 0) {
          console.log(`Skipping empty file: ${file}`);
          continue;
        }

        const jsonData = JSON.parse(fileContent);
        const book = await parseBookJSON(jsonData, id);
        books.push(book);

        if (books.length % 100 === 0) {
          console.log(`Loaded ${books.length} books...`);
        }
      } catch (error) {
        console.error(`Error loading ${file}:`, error.message);
        errorCount++;
      }
    }

    console.log(`Successfully loaded ${books.length} books, ${errorCount} errors`);
    return books;
  } catch (error) {
    console.error('Error reading books directory:', error);
    throw error;
  }
}

async function main() {
  console.log('Starting Elasticsearch import...');
  console.log('Options:', { forceRecreate, skipExisting });

  const esService = getInstance();

  try {
    // Initialize connection
    console.log('\n1. Connecting to Elasticsearch...');
    const connected = await esService.initialize();

    if (!connected) {
      console.error('Failed to connect to Elasticsearch');
      process.exit(1);
    }

    // Handle index creation
    console.log('\n2. Checking index...');
    const indexExists = await esService.indexExists();

    if (indexExists && forceRecreate) {
      console.log('Deleting existing index...');
      await esService.deleteIndex();
      console.log('Creating new index...');
      await esService.createIndex();
    } else if (!indexExists) {
      console.log('Creating index...');
      await esService.createIndex();
    } else {
      console.log('Index already exists');
      if (!skipExisting) {
        console.log('Use --force to recreate index or --skip-existing to add to existing index');
        process.exit(0);
      }
    }

    // Load books
    console.log('\n3. Loading books from filesystem...');
    const books = await loadBooks();

    if (books.length === 0) {
      console.log('No books to import');
      process.exit(0);
    }

    // Import books
    console.log(`\n4. Importing ${books.length} books to Elasticsearch...`);
    const startTime = Date.now();

    const result = await esService.bulkIndex(books);

    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log('\n=== Import Complete ===');
    console.log(`Total books: ${result.total}`);
    console.log(`Successfully indexed: ${result.indexed}`);
    console.log(`Errors: ${result.errors.length}`);
    console.log(`Time taken: ${duration} seconds`);

    if (result.errors.length > 0) {
      console.log('\nErrors:');
      result.errors.slice(0, 10).forEach(err => {
        console.log(`  - Book ${err.id}: ${err.error.type} - ${err.error.reason}`);
      });
      if (result.errors.length > 10) {
        console.log(`  ... and ${result.errors.length - 10} more errors`);
      }
    }

    // Get index statistics
    console.log('\n5. Getting index statistics...');
    const stats = await esService.getIndexStats();
    console.log('Index stats:', stats);

    // Test search
    console.log('\n6. Testing search...');
    const testResult = await esService.search('般若', { size: 5 });
    console.log(`Test search for "般若": found ${testResult.total} results`);

    if (testResult.hits.length > 0) {
      console.log('First result:', {
        id: testResult.hits[0].id,
        title: testResult.hits[0].title,
        author: testResult.hits[0].author,
        bu: testResult.hits[0].bu,
        score: testResult.hits[0].score
      });
    }

  } catch (error) {
    console.error('Import failed:', error);
    process.exit(1);
  } finally {
    await esService.close();
  }

  console.log('\n✅ Import process completed successfully!');
  process.exit(0);
}

// Run the import
if (require.main === module) {
  main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { parseBookJSON, loadBooks };