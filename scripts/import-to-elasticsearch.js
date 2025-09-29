const fs = require('fs').promises;
const path = require('path');
const { getInstance } = require('../services/elasticsearchService');

// Parse command line arguments
const args = process.argv.slice(2);
const forceRecreate = args.includes('--force');
const skipExisting = args.includes('--skip-existing');

async function parseBookMetadata(content, id) {
  const lines = content.split('\n');

  // Extract title (usually first line)
  const title = lines[0]?.trim() || `Book ${id}`;

  // Extract author from second line (format varies)
  let author = '';
  let dynasty = '';

  if (lines[1]) {
    const secondLine = lines[1].trim();
    // Common patterns: "【朝代】作者" or "作者" or "朝代 作者"
    const dynastyMatch = secondLine.match(/【(.+?)】/);
    if (dynastyMatch) {
      dynasty = dynastyMatch[1];
      author = secondLine.replace(dynastyMatch[0], '').trim();
    } else if (secondLine.includes(' ')) {
      const parts = secondLine.split(' ');
      dynasty = parts[0];
      author = parts.slice(1).join(' ');
    } else {
      author = secondLine;
    }
  }

  // Extract part/bu information from filename or metadata
  let part = '';
  let juan = 0;

  if (id.includes('-')) {
    const parts = id.split('-');
    part = parts[0];
    juan = parseInt(parts[1]) || 0;
  }

  // Get content (skip metadata lines)
  const contentStartIndex = lines.findIndex(line =>
    line.trim() &&
    !line.includes('【') &&
    !line.includes('作者') &&
    !line.includes('朝代')
  );

  const content = lines.slice(Math.max(2, contentStartIndex)).join('\n');

  return {
    id,
    title,
    author: author || '佚名',
    dynasty: dynasty || '未知',
    part,
    juan,
    content,
    content_length: content.length,
    created_at: new Date(),
    updated_at: new Date()
  };
}

async function loadBooks() {
  const booksDir = path.join(__dirname, '..', 'public', 'books');

  try {
    const files = await fs.readdir(booksDir);
    const txtFiles = files.filter(file => file.endsWith('.txt'));

    console.log(`Found ${txtFiles.length} book files`);

    const books = [];
    let errorCount = 0;

    for (const file of txtFiles) {
      try {
        const id = file.replace('.txt', '');
        const content = await fs.readFile(path.join(booksDir, file), 'utf-8');

        if (!content || content.trim().length === 0) {
          console.log(`Skipping empty file: ${file}`);
          continue;
        }

        const book = await parseBookMetadata(content, id);
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
    const testResult = await esService.search('金刚经', { size: 5 });
    console.log(`Test search for "金刚经": found ${testResult.total} results`);

    if (testResult.hits.length > 0) {
      console.log('First result:', {
        title: testResult.hits[0].title,
        author: testResult.hits[0].author,
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

module.exports = { parseBookMetadata, loadBooks };