import OpenCC from 'opencc-js';

// Initialize converter for traditional to simplified Chinese
const converter = OpenCC.Converter({ from: 't', to: 's' });

export type SearchMode = 'smart' | 'exact' | 'phrase' | 'fuzzy';
export type SearchField = 'title' | 'author' | 'content';

export interface SearchOptions {
  mode?: SearchMode;
  fields?: SearchField[];
  page?: number;
  limit?: number;
  highlight?: boolean;
  useElasticsearch?: boolean;
}

export interface SearchResult {
  id: string;
  title: string;
  author: string;
  dynasty?: string;
  part?: string;
  juan?: number;
  score: number;
  highlights?: {
    title?: string[];
    author?: string[];
    content?: string[];
  };
  matchedField?: string;
}

export interface SearchResponse {
  total: number;
  queryTime?: number;
  query: string;
  mode?: SearchMode;
  hits: SearchResult[];
}

class EnhancedSearchService {
  private useElasticsearch: boolean;

  constructor() {
    // Check if Elasticsearch is enabled
    this.useElasticsearch = process.env.NEXT_PUBLIC_USE_ELASTICSEARCH === 'true';
  }

  /**
   * Convert traditional Chinese to simplified
   */
  async convertToSimplified(text: string): Promise<string> {
    try {
      // Try client-side conversion first
      return converter(text);
    } catch {
      // Fallback to server API
      const response = await fetch('/api/convert/traditional-to-simplified', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text })
      });

      if (!response.ok) {
        return text; // Return original if conversion fails
      }

      const data = await response.json();
      return data.simplified;
    }
  }

  /**
   * Main search function
   */
  async search(query: string, options: SearchOptions = {}): Promise<SearchResponse> {
    if (!query || query.trim() === '') {
      return {
        total: 0,
        query: query,
        hits: []
      };
    }

    // Check if Elasticsearch is available
    if (this.useElasticsearch || options.useElasticsearch) {
      try {
        const esResponse = await this.searchWithElasticsearch(query, options);
        if (esResponse) {
          return esResponse;
        }
      } catch (error) {
        console.error('Elasticsearch search failed, falling back to local search:', error);
      }
    }

    // Fallback to local search
    return this.searchWithLocalIndex(query, options);
  }

  /**
   * Search using Elasticsearch
   */
  private async searchWithElasticsearch(
    query: string,
    options: SearchOptions
  ): Promise<SearchResponse | null> {
    try {
      const {
        mode = 'smart',
        fields = ['title', 'author', 'content'],
        page = 1,
        limit = 20,
        highlight = true
      } = options;

      // Convert traditional to simplified
      const simplifiedQuery = await this.convertToSimplified(query);

      const response = await fetch('/api/elasticsearch/search', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: simplifiedQuery,
          originalQuery: query,
          mode,
          fields,
          from: (page - 1) * limit,
          size: limit,
          highlight
        })
      });

      if (!response.ok) {
        throw new Error(`Search failed: ${response.statusText}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Elasticsearch search error:', error);
      return null;
    }
  }

  /**
   * Search using local index (existing implementation)
   */
  private async searchWithLocalIndex(
    query: string,
    options: SearchOptions
  ): Promise<SearchResponse> {
    const {
      page = 1,
      limit = 20
    } = options;

    try {
      // Load local data (mls.json)
      const response = await fetch('/mls.json');
      const data = await response.json();

      // Convert query to simplified
      const simplifiedQuery = await this.convertToSimplified(query);
      const queryLower = simplifiedQuery.toLowerCase();

      // Search in local data
      const results: SearchResult[] = [];

      data.forEach((entry: any) => {
        entry.bus?.forEach((book: any) => {
          // Search in title and author
          const titleMatch = book.title?.toLowerCase().includes(queryLower);
          const authorMatch = book.author?.toLowerCase().includes(queryLower);

          if (titleMatch || authorMatch) {
            results.push({
              id: book.id,
              title: book.title || book.name,
              author: book.author || '佚名',
              dynasty: book.dynasty || '',
              part: book.bu || '',
              score: titleMatch ? 2 : 1,
              matchedField: titleMatch ? 'title' : 'author'
            });
          }
        });
      });

      // Sort by score
      results.sort((a, b) => b.score - a.score);

      // Apply pagination
      const start = (page - 1) * limit;
      const paginatedResults = results.slice(start, start + limit);

      return {
        total: results.length,
        query,
        hits: paginatedResults
      };
    } catch (error) {
      console.error('Local search error:', error);
      return {
        total: 0,
        query,
        hits: []
      };
    }
  }

  /**
   * Check Elasticsearch status
   */
  async checkElasticsearchStatus(): Promise<{
    available: boolean;
    indexName?: string;
    stats?: any;
  }> {
    try {
      const response = await fetch('/api/elasticsearch/search', {
        method: 'GET'
      });

      if (!response.ok) {
        return { available: false };
      }

      const data = await response.json();
      return {
        available: data.status === 'ok',
        indexName: data.indexName,
        stats: data.stats
      };
    } catch {
      return { available: false };
    }
  }

  /**
   * Get search suggestions based on query
   */
  async getSuggestions(query: string): Promise<string[]> {
    // This could be expanded to use Elasticsearch suggest API
    const commonTerms = [
      '金刚经', '心经', '法华经', '华严经', '楞严经',
      '地藏经', '药师经', '阿弥陀经', '般若经', '涅槃经'
    ];

    if (!query) return [];

    const simplified = await this.convertToSimplified(query);
    return commonTerms.filter(term =>
      term.includes(simplified) || simplified.includes(term)
    );
  }
}

// Export singleton instance
export const searchService = new EnhancedSearchService();

// Export default for backward compatibility
export default searchService;