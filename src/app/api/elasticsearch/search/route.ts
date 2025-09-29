import { NextRequest, NextResponse } from 'next/server';

// Use dynamic import for CommonJS module
async function getElasticsearchService() {
  const { getInstance } = await import('../../../../../services/elasticsearchService');
  return getInstance();
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const {
      query,
      originalQuery,
      mode = 'smart',
      fields = ['title', 'author', 'content'],
      from = 0,
      size = 20,
      highlight = true
    } = body;

    if (!query || query.trim() === '') {
      return NextResponse.json(
        { error: 'Query is required' },
        { status: 400 }
      );
    }

    // Get Elasticsearch service instance
    const esService = await getElasticsearchService();

    // Initialize connection if needed
    const isConnected = await esService.initialize();
    if (!isConnected) {
      return NextResponse.json(
        { error: 'Elasticsearch service is not available' },
        { status: 503 }
      );
    }

    // Perform search
    const results = await esService.search(query, {
      mode,
      fields,
      from,
      size,
      highlight
    });

    // Add original query to response for display
    return NextResponse.json({
      ...results,
      query: originalQuery || query,
      mode
    });

  } catch (error) {
    console.error('Search API error:', error);
    return NextResponse.json(
      { error: 'Search failed', message: error.message },
      { status: 500 }
    );
  }
}

export async function GET(request: NextRequest) {
  try {
    // Check Elasticsearch connection status
    const esService = await getElasticsearchService();
    const isConnected = await esService.initialize();

    if (!isConnected) {
      return NextResponse.json({
        status: 'error',
        message: 'Elasticsearch is not connected'
      });
    }

    // Get index statistics
    const stats = await esService.getIndexStats();

    return NextResponse.json({
      status: 'ok',
      indexName: esService.indexName,
      stats
    });

  } catch (error) {
    console.error('Status check error:', error);
    return NextResponse.json({
      status: 'error',
      message: error.message
    });
  }
}