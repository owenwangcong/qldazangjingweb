# Elasticsearch Setup for Windows (Local Development)

## Quick Start Guide for Windows

This guide will help you set up Elasticsearch on your local Windows computer for testing the Buddhist texts search system.

## Option 1: Using Docker (Recommended)

### Prerequisites
- Docker Desktop for Windows installed
- At least 8GB RAM available
- 10GB free disk space

### Steps

1. **Install Docker Desktop**
   - Download from: https://www.docker.com/products/docker-desktop/
   - Install and restart your computer if required

2. **Start Elasticsearch with Docker**
   ```powershell
   # Open PowerShell or Command Prompt
   # Run Elasticsearch container
   docker run -d ^
     --name elasticsearch ^
     -p 9200:9200 ^
     -p 9300:9300 ^
     -e "discovery.type=single-node" ^
     -e "xpack.security.enabled=false" ^
     -e "ES_JAVA_OPTS=-Xms2g -Xmx2g" ^
     docker.elastic.co/elasticsearch/elasticsearch:8.12.0
   ```

3. **Verify Installation**
   ```powershell
   # Check if Elasticsearch is running
   curl http://localhost:9200

   # Or open in browser
   # http://localhost:9200
   ```

4. **Install IK Analyzer Plugin**
   ```powershell
   # Enter the container
   docker exec -it elasticsearch bash

   # Install IK plugin
   bin/elasticsearch-plugin install https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-8.12.0.zip

   # Exit container
   exit

   # Restart container
   docker restart elasticsearch
   ```

5. **Setup Your Project**
   ```powershell
   # Navigate to your project
   cd D:\Projects\Cursor\qldazangjingweb

   # Install dependencies (if not already done)
   npm install

   # Setup Elasticsearch index
   npm run es:setup

   # Import books data
   npm run es:import
   ```

6. **Enable Elasticsearch in Your App**

   Edit `.env.local`:
   ```env
   NEXT_PUBLIC_USE_ELASTICSEARCH=true
   ELASTICSEARCH_URL=http://localhost:9200
   ELASTICSEARCH_USERNAME=
   ELASTICSEARCH_PASSWORD=
   ELASTICSEARCH_INDEX=buddhist_texts
   ```

7. **Start Your Application**
   ```powershell
   npm run dev
   ```

### Optional: Setup Kibana for Elasticsearch Management

Kibana provides a web interface to manage and query your Elasticsearch data.

1. **Start Kibana Container**
   ```powershell
   # Run Kibana container
   docker run -d --name kibana -p 5601:5601 -e "ELASTICSEARCH_HOSTS=http://host.docker.internal:9200" docker.elastic.co/kibana/kibana:8.12.0
   ```

2. **Access Kibana**
   - Open browser: http://localhost:5601
   - Wait 1-2 minutes for Kibana to start
   - No login required (security disabled)

3. **Useful Kibana Features**
   - **Dev Tools**: Console for running queries (Menu → Management → Dev Tools)
   - **Discover**: Browse your indexed documents
   - **Index Management**: View index settings and mappings

4. **Example Kibana Queries**
   ```javascript
   // In Dev Tools Console

   // View index mapping
   GET /buddhist_texts/_mapping

   // Count documents
   GET /buddhist_texts/_count

   // Search for text
   POST /buddhist_texts/_search
   {
     "query": {
       "match": {
         "content": "般若波罗蜜"
       }
     }
   }

   // Analyze text with IK tokenizer
   POST /buddhist_texts/_analyze
   {
     "analyzer": "buddhist_analyzer",
     "text": "金刚般若波罗蜜经"
   }

   // Exact match by title (keyword field)
   POST /buddhist_texts/_search
   {
     "query": {
       "term": {
         "title.keyword": "大般若波罗蜜多经六百卷（第一卷～第十卷）"
       }
     }
   }

   // Exact match by ID
   GET /buddhist_texts/_doc/0001-01

   // Multiple exact matches
   POST /buddhist_texts/_search
   {
     "query": {
       "terms": {
         "id": ["0001-01", "0001-02", "0001-03"]
       }
     }
   }

   // Phrase match (exact phrase in content)
   POST /buddhist_texts/_search
   {
     "query": {
       "match_phrase": {
         "content": "般若波罗蜜多"
       }
     }
   }
   ```

5. **Kibana Docker Commands**
   ```powershell
   # Start Kibana
   docker start kibana

   # Stop Kibana
   docker stop kibana

   # View Kibana logs
   docker logs kibana

   # Remove Kibana container
   docker rm kibana
   ```

### Docker Commands Reference

```powershell
# Start Elasticsearch
docker start elasticsearch

# Stop Elasticsearch
docker stop elasticsearch

# View logs
docker logs elasticsearch

# Remove container (data will be lost)
docker rm elasticsearch

# Check container status
docker ps -a | findstr elasticsearch

# Start both Elasticsearch and Kibana
docker start elasticsearch kibana

# Stop both
docker stop elasticsearch kibana
```

## Option 2: Direct Installation on Windows

### Prerequisites
- Windows 10/11
- Java 17 or higher installed
- At least 8GB RAM
- Administrator privileges

### Steps

1. **Install Java (if not installed)**
   - Download Java 17 from: https://adoptium.net/
   - Install with default settings
   - Verify: `java -version`

2. **Download Elasticsearch**
   - Go to: https://www.elastic.co/downloads/elasticsearch
   - Download Windows ZIP file (version 8.12.0)
   - Extract to `C:\elasticsearch-8.12.0`

3. **Configure Elasticsearch**

   Edit `C:\elasticsearch-8.12.0\config\elasticsearch.yml`:
   ```yaml
   cluster.name: buddhist-texts-cluster
   node.name: node-1
   path.data: C:\elasticsearch-8.12.0\data
   path.logs: C:\elasticsearch-8.12.0\logs
   network.host: 127.0.0.1
   http.port: 9200
   discovery.type: single-node
   xpack.security.enabled: false
   ```

4. **Set Heap Size**

   Edit `C:\elasticsearch-8.12.0\config\jvm.options`:
   ```
   -Xms2g
   -Xmx2g
   ```

5. **Install IK Analyzer Plugin**
   ```powershell
   # Open PowerShell as Administrator
   cd C:\elasticsearch-8.12.0

   # Install plugin
   .\bin\elasticsearch-plugin install https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-8.12.0.zip
   ```

6. **Start Elasticsearch**
   ```powershell
   # In PowerShell as Administrator
   cd C:\elasticsearch-8.12.0
   .\bin\elasticsearch.bat

   # Keep this window open while using Elasticsearch
   ```

7. **Setup Your Project**
   ```powershell
   # Open new PowerShell window
   cd D:\Projects\Cursor\qldazangjingweb

   # Setup and import
   npm run es:setup
   npm run es:import
   ```

### Optional: Install Kibana (Direct Installation)

1. **Download Kibana**
   - Go to: https://www.elastic.co/downloads/kibana
   - Download Windows ZIP file (version 8.12.0)
   - Extract to `C:\kibana-8.12.0`

2. **Configure Kibana**

   Edit `C:\kibana-8.12.0\config\kibana.yml`:
   ```yaml
   server.port: 5601
   server.host: "localhost"
   elasticsearch.hosts: ["http://localhost:9200"]
   ```

3. **Start Kibana**
   ```powershell
   # Open new PowerShell window
   cd C:\kibana-8.12.0
   .\bin\kibana.bat

   # Keep this window open while using Kibana
   ```

4. **Access Kibana**
   - Open browser: http://localhost:5601
   - Wait 1-2 minutes for Kibana to start

## Option 3: Using WSL2 (Windows Subsystem for Linux)

### Prerequisites
- Windows 10 version 2004+ or Windows 11
- WSL2 installed
- Ubuntu WSL distribution

### Steps

1. **Install WSL2 and Ubuntu**
   ```powershell
   # Open PowerShell as Administrator
   wsl --install
   wsl --install -d Ubuntu
   ```

2. **Inside Ubuntu WSL**
   ```bash
   # Update packages
   sudo apt update && sudo apt upgrade

   # Install Elasticsearch
   wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
   sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" > /etc/apt/sources.list.d/elastic-8.x.list'
   sudo apt update && sudo apt install elasticsearch

   # Configure
   sudo nano /etc/elasticsearch/elasticsearch.yml
   # Set: network.host: 0.0.0.0

   # Start service
   sudo systemctl start elasticsearch
   sudo systemctl enable elasticsearch
   ```

3. **Access from Windows**
   - Elasticsearch will be available at: `http://localhost:9200`

### Optional: Install Kibana on WSL2

1. **Inside Ubuntu WSL**
   ```bash
   # Install Kibana
   sudo apt install kibana

   # Configure Kibana
   sudo nano /etc/kibana/kibana.yml
   # Set: server.host: "0.0.0.0"

   # Start Kibana service
   sudo systemctl start kibana
   sudo systemctl enable kibana
   ```

2. **Access from Windows**
   - Kibana will be available at: `http://localhost:5601`

## Testing Your Installation

### 1. Quick Test
```powershell
# Run test script
npm run es:test
```

### 2. Manual Test
```powershell
# Test connection
curl http://localhost:9200

# Expected response:
{
  "name" : "node-1",
  "cluster_name" : "buddhist-texts-cluster",
  "version" : {
    "number" : "8.12.0"
  }
}
```

### 3. Search Test
Open browser and go to your app: http://localhost:3000/search
- Search for "般若" or "金刚"
- You should see results with highlighting

### 4. Kibana Test (if installed)
Open browser: http://localhost:5601
- Navigate to Dev Tools (Menu → Management → Dev Tools)
- Run test query:
  ```javascript
  GET /buddhist_texts/_count
  ```
- You should see the document count

## Troubleshooting

### Common Issues and Solutions

#### 1. Port 9200 Already in Use
```powershell
# Find process using port
netstat -ano | findstr :9200

# Kill process (replace PID with actual number)
taskkill /PID <PID> /F

# Or change port in elasticsearch.yml
http.port: 9201
```

#### 2. Out of Memory Error
- Increase heap size in `jvm.options` to `-Xms3g -Xmx3g`
- Close other applications
- Use Docker with memory limits

#### 3. Cannot Connect to Elasticsearch
- Check Windows Firewall settings
- Verify Elasticsearch is running: `docker ps` or check process
- Try: `http://127.0.0.1:9200` instead of `localhost`

#### 4. IK Analyzer Not Working
```powershell
# Verify plugin installation
# For Docker:
docker exec elasticsearch bin/elasticsearch-plugin list

# For direct installation:
C:\elasticsearch-8.12.0\bin\elasticsearch-plugin list
```

#### 5. Slow Performance
- Allocate more memory
- Use SSD for Elasticsearch data
- Reduce number of shards to 1

#### 6. Kibana Won't Start
```powershell
# Check if Kibana can reach Elasticsearch
curl http://localhost:9200

# View Kibana logs (Docker)
docker logs kibana

# View Kibana logs (Direct install)
type C:\kibana-8.12.0\logs\kibana.log

# Common fix: Restart Elasticsearch first, then Kibana
docker restart elasticsearch
docker restart kibana
```

#### 7. Kibana Shows "Kibana server is not ready yet"
- Wait 2-3 minutes for initialization
- Check Elasticsearch is running
- Verify `ELASTICSEARCH_HOSTS` setting is correct

### Windows Firewall Configuration
If needed, allow Elasticsearch and Kibana through firewall:
```powershell
# Run as Administrator
netsh advfirewall firewall add rule name="Elasticsearch" dir=in action=allow protocol=TCP localport=9200
netsh advfirewall firewall add rule name="Kibana" dir=in action=allow protocol=TCP localport=5601
```

## Performance Optimization for Windows

### 1. Disable Windows Search Indexing for ES Folders
- Right-click Elasticsearch data folder
- Properties → Advanced → Uncheck "Allow files to be indexed"

### 2. Windows Defender Exclusions
Add exclusions for better performance:
- Settings → Windows Security → Virus & threat protection
- Manage settings → Add exclusions
- Add folder: Elasticsearch installation directory
- Add folder: Kibana installation directory (if using direct install)

### 3. Power Settings
- Set to High Performance mode
- Disable USB selective suspend
- Disable hard disk sleep

## Development Workflow

### Daily Usage (Docker)
```powershell
# Start Elasticsearch and Kibana (if installed)
docker start elasticsearch
docker start kibana  # optional

# Start your app
cd D:\Projects\Cursor\qldazangjingweb
npm run dev

# Access services
# - App: http://localhost:3000
# - Elasticsearch: http://localhost:9200
# - Kibana: http://localhost:5601

# Stop when done
docker stop elasticsearch kibana
```

### Daily Usage (Direct Install)
```powershell
# Terminal 1: Start Elasticsearch
cd C:\elasticsearch-8.12.0
.\bin\elasticsearch.bat

# Terminal 2: Start Kibana (optional)
cd C:\kibana-8.12.0
.\bin\kibana.bat

# Terminal 3: Start your app
cd D:\Projects\Cursor\qldazangjingweb
npm run dev

# Close terminals when done (Ctrl+C)
```

### Reset Data
```powershell
# Clear and reimport all data
npm run es:setup:reset
npm run es:import:force
```

### View Logs
```powershell
# Docker logs - Elasticsearch
docker logs elasticsearch --tail 50 -f

# Docker logs - Kibana
docker logs kibana --tail 50 -f

# Direct installation logs - Elasticsearch
type C:\elasticsearch-8.12.0\logs\buddhist-texts-cluster.log

# Direct installation logs - Kibana
type C:\kibana-8.12.0\logs\kibana.log
```

## Quick Commands Cheat Sheet

### Elasticsearch Commands
```powershell
# Check ES status
curl http://localhost:9200/_cluster/health?pretty

# Count documents
curl http://localhost:9200/buddhist_texts/_count

# Search test
curl -X POST http://localhost:9200/buddhist_texts/_search -H "Content-Type: application/json" -d "{\"query\":{\"match\":{\"content\":\"般若\"}}}"

# Delete all data (careful!)
curl -X DELETE http://localhost:9200/buddhist_texts

# Restart Docker containers
docker restart elasticsearch
docker restart kibana

# View Docker resource usage
docker stats elasticsearch kibana
```

### Kibana Quick Queries (in Dev Tools)
```javascript
// Check cluster health
GET /_cluster/health

// View index info
GET /buddhist_texts

// Count all documents
GET /buddhist_texts/_count

// Search by content
POST /buddhist_texts/_search
{
  "query": {
    "match": {
      "content": "般若波罗蜜"
    }
  },
  "size": 10
}

// Search by title
POST /buddhist_texts/_search
{
  "query": {
    "match": {
      "title": "金刚"
    }
  }
}

// Test IK analyzer
POST /buddhist_texts/_analyze
{
  "analyzer": "buddhist_analyzer",
  "text": "金刚般若波罗蜜经"
}

// Get index statistics
GET /buddhist_texts/_stats

// View first 10 documents
GET /buddhist_texts/_search
{
  "size": 10
}
```

## Recommended VS Code Extensions

For better development experience:
1. **Elasticsearch for VSCode** - Query ES from VS Code
2. **REST Client** - Test API endpoints
3. **Docker** - Manage Docker containers

## Next Steps

1. ✅ Verify Elasticsearch is running: http://localhost:9200
2. ✅ (Optional) Verify Kibana is running: http://localhost:5601
3. ✅ Run setup: `npm run es:setup`
4. ✅ Import books: `npm run es:import`
5. ✅ Enable in `.env.local`: `NEXT_PUBLIC_USE_ELASTICSEARCH=true`
6. ✅ Start app: `npm run dev`
7. ✅ Test search at: http://localhost:3000/search
8. ✅ (Optional) Explore data in Kibana Dev Tools

## Support

If you encounter issues:
1. Check Docker container logs: `docker logs elasticsearch` or `docker logs kibana`
2. Verify connectivity: `curl http://localhost:9200` and `curl http://localhost:5601`
3. Run tests: `npm run es:test`
4. Check app console for errors (F12 in browser)
5. Use Kibana Dev Tools to debug Elasticsearch queries

Remember to stop services when not in use to save resources:
```powershell
# Docker
docker stop elasticsearch kibana

# Direct install: Press Ctrl+C in terminal windows
```

## Summary

**With Docker (Recommended):**
- Elasticsearch: `docker run` → Port 9200
- Kibana: `docker run` → Port 5601
- Easy to start/stop/manage

**Direct Installation:**
- More control, better for learning
- Run `elasticsearch.bat` and `kibana.bat`
- Requires Java 17+

**Kibana Benefits:**
- Visual query builder
- Index management interface
- Real-time log viewing
- Query testing without code