// Elasticsearch configuration
module.exports = {
  // Connection settings
  connection: {
    node: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',
    auth: {
      username: process.env.ELASTICSEARCH_USERNAME || 'elastic',
      password: process.env.ELASTICSEARCH_PASSWORD || ''
    },
    maxRetries: 5,
    requestTimeout: 120000,
    sniffOnStart: false,
    sniffInterval: false
  },

  // Index configuration
  index: {
    name: process.env.ELASTICSEARCH_INDEX || 'buddhist_texts',
    settings: {
      number_of_shards: 3,
      number_of_replicas: 1,
      'index.max_ngram_diff': 10,  // Allow larger n-gram differences
      analysis: {
        tokenizer: {
          buddhist_tokenizer: {
            type: 'ik_max_word',
            use_smart: false
          },
          ngram_tokenizer: {
            type: 'ngram',
            min_gram: 2,
            max_gram: 4,
            token_chars: ['letter', 'digit']
          }
        },
        filter: {
          buddhist_synonym: {
            type: 'synonym',
            synonyms: [
              '佛,佛陀,世尊,如来,释迦牟尼',
              '菩萨,菩提萨埵,大士',
              '般若,智慧,般若波罗蜜',
              '涅槃,涅盘,寂灭,圆寂',
              '阿弥陀佛,弥陀,无量寿佛,无量光佛',
              '观音,观世音,观自在,观音菩萨'
            ]
          },
          buddhist_stop: {
            type: 'stop',
            stopwords: ['的', '了', '在', '是', '我', '有', '和', '就']
          }
        },
        analyzer: {
          buddhist_analyzer: {
            type: 'custom',
            tokenizer: 'buddhist_tokenizer',
            filter: [
              'lowercase',
              'buddhist_synonym',
              'buddhist_stop'
            ]
          },
          ngram_analyzer: {
            tokenizer: 'ngram_tokenizer',
            filter: ['lowercase']
          }
        }
      }
    },
    mappings: {
      properties: {
        id: {
          type: 'keyword'
        },
        bu: {
          type: 'text',
          analyzer: 'buddhist_analyzer',
          fields: {
            keyword: {
              type: 'keyword'
            }
          }
        },
        title: {
          type: 'text',
          analyzer: 'buddhist_analyzer',
          fields: {
            keyword: {
              type: 'keyword'
            }
          }
        },
        author: {
          type: 'text',
          analyzer: 'buddhist_analyzer',
          fields: {
            keyword: {
              type: 'keyword'
            }
          }
        },
        last_bu: {
          properties: {
            id: { type: 'keyword' },
            name: { type: 'text', analyzer: 'buddhist_analyzer' }
          }
        },
        next_bu: {
          properties: {
            id: { type: 'keyword' },
            name: { type: 'text', analyzer: 'buddhist_analyzer' }
          }
        },
        juans: {
          type: 'nested',
          properties: {
            id: { type: 'keyword' },
            type: { type: 'keyword' },
            content: { type: 'text', analyzer: 'buddhist_analyzer' }
          }
        },
        content: {
          type: 'text',
          analyzer: 'buddhist_analyzer',
          term_vector: 'with_positions_offsets',
          fields: {
            ngram: {
              type: 'text',
              analyzer: 'ngram_analyzer'
            }
          }
        },
        content_length: {
          type: 'integer'
        },
        created_at: {
          type: 'date'
        },
        updated_at: {
          type: 'date'
        }
      }
    }
  },

  // Search configuration
  search: {
    defaultSize: 20,
    maxSize: 100,
    scrollTimeout: '1m',
    highlightConfig: {
      fields: {
        content: {
          fragment_size: 200,
          number_of_fragments: 3,
          pre_tags: ['<mark class="search-highlight">'],
          post_tags: ['</mark>']
        },
        title: {
          pre_tags: ['<mark class="search-highlight">'],
          post_tags: ['</mark>']
        },
        author: {
          pre_tags: ['<mark class="search-highlight">'],
          post_tags: ['</mark>']
        }
      }
    }
  }
};