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

#### Option A: Install on Ubuntu/Linux

**Step 1: Import Elasticsearch GPG Key**
```bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
```

**Step 2: Add Elasticsearch Repository**
```bash
sudo apt-get install apt-transport-https
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
```

**Step 3: Install Elasticsearch**
```bash
sudo apt-get update && sudo apt-get install elasticsearch
```

**Step 4: Configure Elasticsearch**
```bash
# Edit configuration file
sudo nano /etc/elasticsearch/elasticsearch.yml
```

Add or modify these settings:
```yaml
cluster.name: buddhist-texts-cluster
node.name: node-1
network.host: 127.0.0.1
http.port: 9200
discovery.type: single-node

# Disable security for local development (enable in production!)
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
```

**Step 5: Set JVM Heap Size**
```bash
# Edit JVM options
sudo nano /etc/elasticsearch/jvm.options.d/heap.options
```

Add these lines (adjust based on your RAM):
```
-Xms2g
-Xmx2g
```

**Step 6: Install IK Analyzer Plugin**
```bash
# Navigate to Elasticsearch directory
cd /usr/share/elasticsearch

# Install IK analyzer plugin (use infinilabs mirror for reliability)
sudo bin/elasticsearch-plugin install https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-8.12.0.zip

# Alternative: Official GitHub release (may be slower)
# sudo bin/elasticsearch-plugin install https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v8.12.0/elasticsearch-analysis-ik-8.12.0.zip
```

**Step 7: Start and Enable Elasticsearch**
```bash
# Reload systemd daemon
sudo systemctl daemon-reload

# Enable Elasticsearch to start on boot
sudo systemctl enable elasticsearch

# Start Elasticsearch service
sudo systemctl start elasticsearch

# Check status
sudo systemctl status elasticsearch

# View logs if needed
sudo journalctl -u elasticsearch -f
```

**Step 8: Verify Installation**
```bash
# Wait ~30 seconds for Elasticsearch to start, then test
curl -X GET "localhost:9200/?pretty"

# Should return something like:
# {
#   "name" : "node-1",
#   "cluster_name" : "buddhist-texts-cluster",
#   "version" : {
#     "number" : "8.12.0"
#   }
# }
```

**Step 9: Install Project Dependencies**
```bash
# Navigate to project directory
cd /path/to/qldazangjingweb

# Install dependencies (if not already done)
npm install
```

#### Option B: Install with Docker (Ubuntu/Windows/Mac)

```bash
# Pull and run Elasticsearch container
docker run -d \
  --name elasticsearch \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  -e "ES_JAVA_OPTS=-Xms2g -Xmx2g" \
  elasticsearch:8.12.0

# Install IK Analyzer Plugin in Docker
docker exec -it elasticsearch bash
bin/elasticsearch-plugin install https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-8.12.0.zip
exit

# Restart container to load plugin
docker restart elasticsearch

# Verify it's running
curl -X GET "localhost:9200/?pretty"
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
   ```bash
   # Check if Elasticsearch is running
   sudo systemctl status elasticsearch

   # If not running, start it
   sudo systemctl start elasticsearch

   # Check logs for errors
   sudo journalctl -u elasticsearch -n 100

   # Verify URL in .env.local matches your ES configuration
   ```

2. **Elasticsearch Won't Start (Ubuntu)**
   ```bash
   # Check for port conflicts
   sudo lsof -i :9200

   # Check file permissions
   sudo chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
   sudo chown -R elasticsearch:elasticsearch /var/log/elasticsearch

   # Check disk space
   df -h

   # View detailed logs
   sudo tail -f /var/log/elasticsearch/buddhist-texts-cluster.log
   ```

3. **Index Not Found**
   ```bash
   # Run setup script
   npm run es:setup

   # Verify index was created
   curl -X GET "localhost:9200/_cat/indices?v"

   # Check index name in config/elasticsearch.config.js
   ```

4. **No Search Results**
   ```bash
   # Verify data is imported
   npm run es:import

   # Check document count
   curl -X GET "localhost:9200/buddhist_texts/_count?pretty"

   # Verify environment variable
   # Check NEXT_PUBLIC_USE_ELASTICSEARCH=true in .env.local
   ```

5. **IK Analyzer Not Working**
   ```bash
   # Verify plugin is installed
   sudo /usr/share/elasticsearch/bin/elasticsearch-plugin list

   # Should show: analysis-ik

   # If not installed, install it
   cd /usr/share/elasticsearch
   sudo bin/elasticsearch-plugin install https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-8.12.0.zip

   # Restart Elasticsearch
   sudo systemctl restart elasticsearch
   ```

6. **Memory Issues**
   ```bash
   # Check current heap size
   curl -X GET "localhost:9200/_nodes/stats/jvm?pretty"

   # Increase JVM heap
   sudo nano /etc/elasticsearch/jvm.options.d/heap.options
   # Set: -Xms3g and -Xmx3g for 3GB heap

   # Restart Elasticsearch
   sudo systemctl restart elasticsearch

   # Check available system memory
   free -h
   ```

7. **Permission Denied Errors (Ubuntu)**
   ```bash
   # Fix ownership of Elasticsearch directories
   sudo chown -R elasticsearch:elasticsearch /etc/elasticsearch
   sudo chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
   sudo chown -R elasticsearch:elasticsearch /var/log/elasticsearch
   sudo chown -R elasticsearch:elasticsearch /usr/share/elasticsearch

   # Fix permissions
   sudo chmod 750 /etc/elasticsearch
   sudo chmod 750 /var/lib/elasticsearch
   sudo chmod 750 /var/log/elasticsearch
   ```

8. **"java.lang.OutOfMemoryError"**
   ```bash
   # This means heap is too small
   # Increase heap size (use 50% of available RAM, max 32GB)
   sudo nano /etc/elasticsearch/jvm.options.d/heap.options

   # For 8GB system: -Xms4g -Xmx4g
   # For 16GB system: -Xms8g -Xmx8g

   sudo systemctl restart elasticsearch
   ```

9. **Slow Search Performance**
   ```bash
   # Check index stats
   curl -X GET "localhost:9200/buddhist_texts/_stats?pretty"

   # Force merge segments (do this after initial import)
   curl -X POST "localhost:9200/buddhist_texts/_forcemerge?max_num_segments=1"

   # Clear cache
   curl -X POST "localhost:9200/buddhist_texts/_cache/clear?pretty"
   ```

10. **Ubuntu Firewall Issues**
    ```bash
    # If connecting from another machine, allow port 9200
    sudo ufw allow 9200/tcp

    # Check firewall status
    sudo ufw status

    # WARNING: Only do this if you need remote access
    # It's more secure to keep Elasticsearch local-only
    ```

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

## Ubuntu Quick Reference

### Useful Commands

```bash
# Service Management
sudo systemctl start elasticsearch      # Start service
sudo systemctl stop elasticsearch       # Stop service
sudo systemctl restart elasticsearch    # Restart service
sudo systemctl status elasticsearch     # Check status
sudo systemctl enable elasticsearch     # Enable on boot
sudo systemctl disable elasticsearch    # Disable on boot

# Logs
sudo journalctl -u elasticsearch -f                    # Follow logs
sudo journalctl -u elasticsearch -n 100                # Last 100 lines
sudo tail -f /var/log/elasticsearch/*.log              # Tail log files
sudo cat /var/log/elasticsearch/buddhist-texts-cluster.log  # View full log

# Configuration
sudo nano /etc/elasticsearch/elasticsearch.yml         # Edit config
sudo nano /etc/elasticsearch/jvm.options.d/heap.options  # Edit JVM heap

# Plugin Management
sudo /usr/share/elasticsearch/bin/elasticsearch-plugin list       # List plugins
sudo /usr/share/elasticsearch/bin/elasticsearch-plugin install <url>  # Install plugin
sudo /usr/share/elasticsearch/bin/elasticsearch-plugin remove analysis-ik  # Remove plugin

# Index Management
curl -X GET "localhost:9200/_cat/indices?v"            # List all indices
curl -X GET "localhost:9200/buddhist_texts/_count"     # Count documents
curl -X DELETE "localhost:9200/buddhist_texts"         # Delete index
curl -X GET "localhost:9200/_cluster/health?pretty"    # Cluster health

# Performance Monitoring
curl -X GET "localhost:9200/_nodes/stats?pretty"       # Node stats
curl -X GET "localhost:9200/_cat/nodes?v"              # Node info
curl -X GET "localhost:9200/_cat/thread_pool?v"        # Thread pool stats
```

### File Locations (Ubuntu)

```
Configuration:  /etc/elasticsearch/
Data:          /var/lib/elasticsearch/
Logs:          /var/log/elasticsearch/
Plugins:       /usr/share/elasticsearch/plugins/
Binary:        /usr/share/elasticsearch/bin/
Service:       /usr/lib/systemd/system/elasticsearch.service
```

### Recommended Ubuntu System Setup

```bash
# Disable swap for better performance (optional)
sudo swapoff -a
# To make permanent, comment out swap line in /etc/fstab

# Increase file descriptor limits
sudo nano /etc/security/limits.conf
# Add these lines:
# elasticsearch soft nofile 65536
# elasticsearch hard nofile 65536

# Increase max map count
sudo sysctl -w vm.max_map_count=262144
# To make permanent:
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

## Support

For issues or questions:
1. Check the [design document](./elasticsearch-design.md)
2. Check the [Windows setup guide](./ELASTICSEARCH_WINDOWS_SETUP.md)
3. Review test output: `npm run es:test`
4. Check Elasticsearch logs: `sudo journalctl -u elasticsearch -n 100`
5. Verify configuration in `config/elasticsearch.config.js`

## License

This implementation follows the project's existing license terms.