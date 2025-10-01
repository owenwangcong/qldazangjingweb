const { Client } = require('@elastic/elasticsearch');
const config = require('../config/elasticsearch.config');

// OpenCC initialization - handle both browser and Node.js environments
let converter = null;
try {
  const OpenCC = require('opencc-js');
  // Only initialize if OpenCC is available and working
  if (OpenCC && OpenCC.Converter) {
    converter = (text) => {
      try {
        return OpenCC.Converter({ from: 't', to: 's' })(text);
      } catch (e) {
        console.warn('OpenCC conversion failed, returning original text:', e.message);
        return text;
      }
    };
  }
} catch (error) {
  console.warn('OpenCC not available in Node.js environment, traditional to simplified conversion disabled');
}

// Ensure converter is always defined
if (!converter) {
  // Fallback converter that returns text as-is
  converter = (text) => text;
}

class ElasticsearchService {
  constructor() {
    this.client = null;
    this.indexName = config.index.name;
    this.isConnected = false;
  }

  // Initialize Elasticsearch client
  async initialize() {
    if (this.client && this.isConnected) {
      return true;
    }

    try {
      this.client = new Client(config.connection);

      // Test connection
      const info = await this.client.info();
      console.log('Elasticsearch connected:', info.version);
      this.isConnected = true;

      // Check if index exists
      const exists = await this.indexExists();
      if (!exists) {
        console.log(`Index ${this.indexName} does not exist. Run the setup script to create it.`);
      }

      return true;
    } catch (error) {
      console.error('Failed to connect to Elasticsearch:', error);
      this.isConnected = false;
      return false;
    }
  }

  // Check if index exists
  async indexExists() {
    try {
      return await this.client.indices.exists({ index: this.indexName });
    } catch (error) {
      console.error('Error checking index existence:', error);
      return false;
    }
  }

  // Create index with mappings
  async createIndex() {
    try {
      const exists = await this.indexExists();
      if (exists) {
        console.log(`Index ${this.indexName} already exists`);
        return false;
      }

      await this.client.indices.create({
        index: this.indexName,
        body: {
          settings: config.index.settings,
          mappings: config.index.mappings
        }
      });

      console.log(`Index ${this.indexName} created successfully`);
      return true;
    } catch (error) {
      console.error('Error creating index:', error);
      throw error;
    }
  }

  // Delete index
  async deleteIndex() {
    try {
      const exists = await this.indexExists();
      if (!exists) {
        console.log(`Index ${this.indexName} does not exist`);
        return false;
      }

      await this.client.indices.delete({ index: this.indexName });
      console.log(`Index ${this.indexName} deleted successfully`);
      return true;
    } catch (error) {
      console.error('Error deleting index:', error);
      throw error;
    }
  }

  // Index a single document
  async indexDocument(document) {
    try {
      const result = await this.client.index({
        index: this.indexName,
        id: document.id,
        body: document,
        refresh: 'wait_for'
      });
      return result;
    } catch (error) {
      console.error('Error indexing document:', error);
      throw error;
    }
  }

  // Bulk index documents
  async bulkIndex(documents, batchSize = 50) {
    try {
      let indexed = 0;
      const errors = [];

      for (let i = 0; i < documents.length; i += batchSize) {
        const batch = documents.slice(i, i + batchSize);
        const body = batch.flatMap(doc => [
          { index: { _index: this.indexName, _id: doc.id } },
          doc
        ]);

        const result = await this.client.bulk({
          body,
          refresh: i + batchSize >= documents.length ? 'wait_for' : false
        });

        if (result.errors) {
          result.items.forEach(item => {
            if (item.index && item.index.error) {
              errors.push({
                id: item.index._id,
                error: item.index.error
              });
            }
          });
        }

        indexed += batch.length - (result.errors ? result.items.filter(item => item.index.error).length : 0);
        console.log(`Indexed ${indexed}/${documents.length} documents`);
      }

      return {
        indexed,
        total: documents.length,
        errors
      };
    } catch (error) {
      console.error('Error in bulk indexing:', error);
      throw error;
    }
  }

  // Search with different modes
  async search(query, options = {}) {
    const {
      mode = 'smart',
      fields = ['title', 'author', 'content'],
      from = 0,
      size = config.search.defaultSize,
      highlight = true
    } = options;

    try {
      // Convert traditional Chinese to simplified
      const simplifiedQuery = converter(query);
      console.log(`Original: ${query}, Simplified: ${simplifiedQuery}`);

      let esQuery;

      switch (mode) {
        case 'exact':
          esQuery = {
            match_phrase: {
              content: {
                query: simplifiedQuery,
                slop: 0
              }
            }
          };
          break;

        case 'phrase':
          esQuery = {
            match_phrase: {
              content: {
                query: simplifiedQuery,
                slop: 5
              }
            }
          };
          break;

        case 'fuzzy':
          esQuery = {
            multi_match: {
              query: simplifiedQuery,
              fields: fields.map(f =>
                f === 'title' ? 'title^3' :
                f === 'author' ? 'author^2' : f
              ),
              fuzziness: 'AUTO'
            }
          };
          break;

        case 'smart':
        default:
          esQuery = {
            bool: {
              should: [
                {
                  match_phrase: {
                    content: {
                      query: simplifiedQuery,
                      boost: 3
                    }
                  }
                },
                {
                  multi_match: {
                    query: simplifiedQuery,
                    fields: fields.map(f =>
                      f === 'title' ? 'title^3' :
                      f === 'author' ? 'author^2' : f
                    ),
                    type: 'best_fields',
                    boost: 2
                  }
                },
                {
                  match: {
                    'content.ngram': {
                      query: simplifiedQuery,
                      boost: 1
                    }
                  }
                }
              ],
              minimum_should_match: 1
            }
          };
      }

      const searchParams = {
        index: this.indexName,
        body: {
          query: esQuery,
          from: from,
          size: size,
          track_total_hits: true,
          _source: ['id', 'title', 'author', 'dynasty', 'part', 'juan']
        }
      };

      if (highlight) {
        searchParams.body.highlight = {
          ...config.search.highlightConfig,
          highlight_query: esQuery
        };
      }

      const startTime = Date.now();
      const result = await this.client.search(searchParams);
      const queryTime = Date.now() - startTime;

      return {
        total: result.hits.total.value,
        queryTime,
        hits: result.hits.hits.map(hit => ({
          id: hit._source.id,
          title: hit._source.title,
          author: hit._source.author,
          dynasty: hit._source.dynasty,
          part: hit._source.part,
          juan: hit._source.juan,
          score: hit._score,
          highlights: hit.highlight || {},
          matchedField: this.detectMatchedField(hit.highlight)
        }))
      };
    } catch (error) {
      console.error('Search error:', error);
      throw error;
    }
  }

  // Detect which field was matched
  detectMatchedField(highlight) {
    if (!highlight) return 'content';
    if (highlight.title) return 'title';
    if (highlight.author) return 'author';
    if (highlight.content) return 'content';
    return 'content';
  }

  // Get document by ID
  async getDocument(id) {
    try {
      const result = await this.client.get({
        index: this.indexName,
        id: id
      });
      return result._source;
    } catch (error) {
      if (error.statusCode === 404) {
        return null;
      }
      throw error;
    }
  }

  // Update document
  async updateDocument(id, updates) {
    try {
      const result = await this.client.update({
        index: this.indexName,
        id: id,
        body: {
          doc: updates,
          doc_as_upsert: true
        },
        refresh: 'wait_for'
      });
      return result;
    } catch (error) {
      console.error('Error updating document:', error);
      throw error;
    }
  }

  // Delete document
  async deleteDocument(id) {
    try {
      const result = await this.client.delete({
        index: this.indexName,
        id: id,
        refresh: 'wait_for'
      });
      return result;
    } catch (error) {
      if (error.statusCode === 404) {
        return { found: false };
      }
      throw error;
    }
  }

  // Get index statistics
  async getIndexStats() {
    try {
      const stats = await this.client.indices.stats({
        index: this.indexName
      });

      const indexStats = stats.indices[this.indexName];
      return {
        documentCount: indexStats.primaries.docs.count,
        sizeInBytes: indexStats.primaries.store.size_in_bytes,
        sizeInMB: (indexStats.primaries.store.size_in_bytes / 1024 / 1024).toFixed(2)
      };
    } catch (error) {
      console.error('Error getting index stats:', error);
      throw error;
    }
  }

  // Analyze text with the Buddhist analyzer
  async analyzeText(text) {
    try {
      const result = await this.client.indices.analyze({
        index: this.indexName,
        body: {
          analyzer: 'buddhist_analyzer',
          text: text
        }
      });
      return result.tokens;
    } catch (error) {
      console.error('Error analyzing text:', error);
      throw error;
    }
  }

  // Close connection
  async close() {
    if (this.client) {
      await this.client.close();
      this.client = null;
      this.isConnected = false;
      console.log('Elasticsearch connection closed');
    }
  }
}

// Singleton instance
let instance = null;

module.exports = {
  getInstance: () => {
    if (!instance) {
      instance = new ElasticsearchService();
    }
    return instance;
  },
  ElasticsearchService
};