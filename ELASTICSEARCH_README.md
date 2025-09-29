# Elasticsearch Integration for Buddhist Texts Search

## Overview

This implementation adds Elasticsearch support to the Buddhist texts search system, providing:
- **Exact phrase matching** - Find exact sequences of text
- **Fuzzy matching** - Handle typos and variations
- **Smart search** - Intelligent ranking and relevance scoring
- **Traditional to Simplified Chinese conversion** - Automatic handling using OpenCC
- **Custom Buddhist text analyzer** - Optimized for Buddhist terminology

## Project Structure

```
qldazangjingweb/
├── config/
│   └── elasticsearch.config.js      # ES configuration and mappings
├── services/
│   └── elasticsearchService.js      # Core ES service class
├── scripts/
│   ├── setup-elasticsearch.js       # Setup script for ES
│   ├── import-to-elasticsearch.js   # Data import script
│   └── test-elasticsearch.js        # Testing script
├── src/
│   ├── services/
│   │   └── enhancedSearchService.ts # Frontend search service
│   └── app/
│       └── api/
│           ├── elasticsearch/
│           │   └── search/
│           │       └── route.ts     # Search API endpoint
│           └── convert/
│               └── traditional-to-simplified/
│                   └── route.ts     # Text conversion API
├── .env.local                        # Environment configuration
└── elasticsearch-design.md           # Detailed design document
```

## Quick Start

### 1. Prerequisites

- Node.js 18+ installed
- Elasticsearch 8.x installed and running
- 16GB RAM recommended
- 15-30GB disk space for indices

### 2. Installation

```bash
# Install dependencies (already done)
npm install

# Start Elasticsearch (on Ubuntu/Linux)
sudo systemctl start elasticsearch

# Or on Windows/Mac with Docker
docker run -d -p 9200:9200 -e "discovery.type=single-node" elasticsearch:8.12.0
```

### 3. Setup Elasticsearch

```bash
# Create index with mappings
npm run es:setup

# If you need to reset and recreate
npm run es:setup:reset
```

### 4. Import Data

```bash
# Import all books to Elasticsearch
npm run es:import

# Force recreate index and import
npm run es:import:force
```

### 5. Enable Elasticsearch

Edit `.env.local`:
```env
NEXT_PUBLIC_USE_ELASTICSEARCH=true
ELASTICSEARCH_URL=http://localhost:9200
ELASTICSEARCH_USERNAME=elastic
ELASTICSEARCH_PASSWORD=yourpassword
```

### 6. Restart Application

```bash
npm run dev
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXT_PUBLIC_USE_ELASTICSEARCH` | Enable ES for search | `false` |
| `ELASTICSEARCH_URL` | ES server URL | `http://localhost:9200` |
| `ELASTICSEARCH_USERNAME` | ES username | `elastic` |
| `ELASTICSEARCH_PASSWORD` | ES password | (empty) |
| `ELASTICSEARCH_INDEX` | Index name | `buddhist_texts` |

### Search Modes

The system supports 4 search modes:

1. **Smart Search** (`smart`) - Default, combines multiple strategies
2. **Exact Match** (`exact`) - Find exact phrases
3. **Phrase Search** (`phrase`) - Find phrases with word distance
4. **Fuzzy Search** (`fuzzy`) - Handle typos and variations

## API Endpoints

### Search API

```typescript
POST /api/elasticsearch/search
{
  "query": "金刚经",
  "mode": "smart",        // smart | exact | phrase | fuzzy
  "fields": ["title", "author", "content"],
  "from": 0,
  "size": 20,
  "highlight": true
}

// Response
{
  "total": 42,
  "queryTime": 15,
  "query": "金刚经",
  "mode": "smart",
  "hits": [
    {
      "id": "0010",
      "title": "金刚般若波罗蜜经",
      "author": "鸠摩罗什",
      "dynasty": "姚秦",
      "score": 8.5,
      "highlights": {
        "title": ["<mark>金刚</mark>般若波罗蜜<mark>经</mark>"]
      },
      "matchedField": "title"
    }
  ]
}
```

### Status Check API

```typescript
GET /api/elasticsearch/search

// Response
{
  "status": "ok",
  "indexName": "buddhist_texts",
  "stats": {
    "documentCount": 1809,
    "sizeInBytes": 123456789,
    "sizeInMB": "117.74"
  }
}
```

### Text Conversion API

```typescript
POST /api/convert/traditional-to-simplified
{
  "text": "觀世音菩薩"
}

// Response
{
  "original": "觀世音菩薩",
  "simplified": "观世音菩萨"
}
```

## Usage in Frontend

### Using Enhanced Search Service

```typescript
import { searchService } from '@/services/enhancedSearchService';

// Perform search
const results = await searchService.search('心经', {
  mode: 'smart',
  fields: ['title', 'content'],
  page: 1,
  limit: 20,
  highlight: true,
  useElasticsearch: true  // Force ES usage
});

// Check ES availability
const status = await searchService.checkElasticsearchStatus();
if (status.available) {
  console.log('Elasticsearch is available');
}

// Get search suggestions
const suggestions = await searchService.getSuggestions('金刚');
```

## Features

### 1. Chinese Text Processing

- **IK Analyzer** for intelligent Chinese word segmentation
- **Custom Buddhist dictionary** with common Buddhist terms
- **Synonym support** (e.g., 佛/佛陀/世尊)
- **Stop words filtering** for common characters

### 2. Traditional to Simplified Conversion

- Automatic conversion using OpenCC (already installed)
- Supports Taiwan, Hong Kong, and general traditional Chinese
- Client-side and server-side conversion available

### 3. Search Highlighting

- Automatic highlighting of matched terms
- Customizable highlight tags
- Fragment extraction for content preview

### 4. Performance Optimization

- Chunked bulk indexing for large datasets
- Configurable batch sizes
- Connection pooling and retry logic
- Index refresh optimization

## Testing

### Run All Tests

```bash
npm run es:test
```

### Manual Testing

```bash
# Test connection
curl -X GET "localhost:9200/_cluster/health?pretty"

# Test search
curl -X POST "localhost:9200/buddhist_texts/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {
        "content": "般若"
      }
    }
  }'
```

## Maintenance

### Check Index Status

```bash
curl -X GET "localhost:9200/buddhist_texts/_stats?pretty"
```

### View Logs

```bash
# Elasticsearch logs
sudo tail -f /var/log/elasticsearch/elasticsearch.log

# Application logs
# Check console output when running npm run dev
```

### Reindex Data

```bash
# Delete and recreate index with fresh data
npm run es:setup:reset
npm run es:import:force
```

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Check if Elasticsearch is running: `sudo systemctl status elasticsearch`
   - Verify URL in `.env.local`

2. **Index Not Found**
   - Run: `npm run es:setup`
   - Check index name in config

3. **No Search Results**
   - Verify data is imported: `npm run es:import`
   - Check `NEXT_PUBLIC_USE_ELASTICSEARCH=true` in `.env.local`

4. **IK Analyzer Not Working**
   - Install IK plugin for your ES version
   - Restart Elasticsearch after plugin installation

5. **Memory Issues**
   - Increase JVM heap: Edit `/etc/elasticsearch/jvm.options`
   - Set `-Xms3g -Xmx3g` for 3GB heap

### Debug Mode

Enable debug logging in `config/elasticsearch.config.js`:

```javascript
connection: {
  node: process.env.ELASTICSEARCH_URL,
  log: 'debug'  // Add this line
}
```

## Performance Tips

1. **Optimize Index Settings**
   - Use 1-3 shards for <10GB data
   - Set `refresh_interval: 30s` during bulk import
   - Run force merge after initial import

2. **Query Optimization**
   - Use `filter` context for non-scoring queries
   - Limit `size` parameter
   - Use `source` filtering to reduce response size

3. **Hardware Recommendations**
   - SSD storage for better performance
   - At least 8GB RAM, 16GB recommended
   - Dedicate 50% RAM to ES heap (max 32GB)

## Security

### Production Deployment

1. **Enable Security Features**
   ```yaml
   # elasticsearch.yml
   xpack.security.enabled: true
   xpack.security.http.ssl.enabled: true
   ```

2. **Set Strong Passwords**
   ```bash
   /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
   ```

3. **Restrict Network Access**
   ```bash
   # Only allow local connections
   network.host: 127.0.0.1
   ```

4. **Use Environment Variables**
   - Never commit `.env.local` to git
   - Use secure password storage in production

## Next Steps

1. **Enhanced UI Features**
   - Search mode selector
   - Search statistics display
   - Advanced filters

2. **Additional Analyzers**
   - Pinyin search support
   - More sophisticated Buddhist term handling

3. **Performance Monitoring**
   - Add APM integration
   - Query performance tracking

## Support

For issues or questions:
1. Check the [design document](./elasticsearch-design.md)
2. Review test output: `npm run es:test`
3. Check Elasticsearch logs
4. Verify configuration in `config/elasticsearch.config.js`

## License

This implementation follows the project's existing license terms.