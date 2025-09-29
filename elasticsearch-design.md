# Elasticsearch 佛经全文检索系统设计方案

## 一、系统架构设计

### 1.1 整体架构
```
[Next.js App] <--> [Node.js API] <--> [Elasticsearch 8.x] <--> [Buddhist Texts Data]
```

### 1.2 技术栈
- **搜索引擎**: Elasticsearch 8.x
- **中文分词**: IK Analyzer + 自定义佛教词典
- **后端集成**: Node.js + @elastic/elasticsearch
- **前端**: 现有 Next.js 搜索页面（保持不变）
- **部署环境**: Ubuntu 22.04 LTS

## 二、Elasticsearch 配置设计

### 2.1 索引映射（Index Mapping）
```json
{
  "mappings": {
    "properties": {
      "id": {
        "type": "keyword"
      },
      "title": {
        "type": "text",
        "analyzer": "buddhist_analyzer",
        "fields": {
          "keyword": {
            "type": "keyword"
          },
          "pinyin": {
            "type": "text",
            "analyzer": "pinyin_analyzer"
          }
        }
      },
      "author": {
        "type": "text",
        "analyzer": "buddhist_analyzer",
        "fields": {
          "keyword": {
            "type": "keyword"
          }
        }
      },
      "dynasty": {
        "type": "keyword"
      },
      "part": {
        "type": "keyword"
      },
      "juan": {
        "type": "integer"
      },
      "content": {
        "type": "text",
        "analyzer": "buddhist_analyzer",
        "term_vector": "with_positions_offsets",
        "fields": {
          "ngram": {
            "type": "text",
            "analyzer": "ngram_analyzer"
          }
        }
      },
      "content_length": {
        "type": "integer"
      },
      "created_at": {
        "type": "date"
      },
      "updated_at": {
        "type": "date"
      }
    }
  }
}
```

### 2.2 自定义分析器配置
```json
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "tokenizer": {
        "buddhist_tokenizer": {
          "type": "ik_max_word",
          "use_smart": false
        },
        "ngram_tokenizer": {
          "type": "ngram",
          "min_gram": 2,
          "max_gram": 4,
          "token_chars": ["letter", "digit"]
        }
      },
      "filter": {
        "buddhist_synonym": {
          "type": "synonym",
          "synonyms_path": "analysis/buddhist_synonyms.txt"
        },
        "buddhist_stop": {
          "type": "stop",
          "stopwords_path": "analysis/buddhist_stopwords.txt"
        }
      },
      "analyzer": {
        "buddhist_analyzer": {
          "type": "custom",
          "tokenizer": "buddhist_tokenizer",
          "filter": [
            "lowercase",
            "buddhist_synonym",
            "buddhist_stop"
          ]
        },
        "ngram_analyzer": {
          "tokenizer": "ngram_tokenizer",
          "filter": ["lowercase"]
        },
        "pinyin_analyzer": {
          "tokenizer": "ik_max_word",
          "filter": ["pinyin", "lowercase"]
        }
      }
    }
  }
}
```

### 2.3 佛教专用词典

#### buddhist_dictionary.txt（IK 自定义词典）
```
如来藏
般若波罗蜜多
阿耨多罗三藐三菩提
南无阿弥陀佛
观自在菩萨
舍利弗
须菩提
大悲咒
楞严经
法华经
金刚经
心经
涅槃经
华严经
地藏经
```

#### buddhist_synonyms.txt（同义词）
```
佛,佛陀,世尊,如来,释迦牟尼
菩萨,菩提萨埵,大士
般若,智慧,般若波罗蜜
涅槃,涅盘,寂灭,圆寂
阿弥陀佛,弥陀,无量寿佛,无量光佛
观音,观世音,观自在,观音菩萨
```

#### buddhist_stopwords.txt（停用词）
```
的
了
在
是
我
有
和
就
```

## 三、搜索查询设计

### 3.1 精确匹配查询
```javascript
{
  "query": {
    "match_phrase": {
      "content": {
        "query": "如是我闻",
        "slop": 0
      }
    }
  },
  "highlight": {
    "fields": {
      "content": {
        "type": "unified",
        "fragment_size": 150,
        "number_of_fragments": 3,
        "pre_tags": ["<mark>"],
        "post_tags": ["</mark>"]
      }
    }
  }
}
```

### 3.2 短语匹配查询（允许词间距）
```javascript
{
  "query": {
    "match_phrase": {
      "content": {
        "query": "般若 智慧",
        "slop": 5
      }
    }
  }
}
```

### 3.3 模糊匹配查询
```javascript
{
  "query": {
    "multi_match": {
      "query": "金刚经",
      "fields": ["title^3", "author^2", "content"],
      "type": "best_fields",
      "fuzziness": "AUTO"
    }
  }
}
```

### 3.4 综合搜索查询（推荐）
```javascript
{
  "query": {
    "bool": {
      "should": [
        {
          "match_phrase": {
            "content": {
              "query": "搜索词",
              "boost": 3
            }
          }
        },
        {
          "match": {
            "content": {
              "query": "搜索词",
              "boost": 1
            }
          }
        },
        {
          "match": {
            "content.ngram": {
              "query": "搜索词",
              "boost": 0.5
            }
          }
        }
      ],
      "minimum_should_match": 1
    }
  },
  "highlight": {
    "require_field_match": false,
    "fields": {
      "content": {
        "fragment_size": 200,
        "number_of_fragments": 5,
        "pre_tags": ["<mark class='highlight'>"],
        "post_tags": ["</mark>"],
        "highlight_query": {
          "match_phrase": {
            "content": "搜索词"
          }
        }
      }
    }
  },
  "from": 0,
  "size": 50
}
```

## 四、API 接口设计

### 4.1 搜索 API 端点
```javascript
// /api/elasticsearch/search
POST /api/elasticsearch/search
{
  "query": "般若波罗蜜多",
  "mode": "phrase", // exact | phrase | fuzzy | smart
  "fields": ["title", "author", "content"],
  "from": 0,
  "size": 20,
  "highlight": true
}
```

### 4.2 Node.js 集成代码
```javascript
// services/elasticsearchService.js
const { Client } = require('@elastic/elasticsearch');
const OpenCC = require('opencc-js');  // 项目已安装 v1.0.5

// 初始化 OpenCC 转换器
// from: 'tw' (繁体台湾), 'hk' (繁体香港), 't' (繁体通用)
// to: 'cn' (简体中国), 's' (简体通用)
const converter = OpenCC.Converter({ from: 't', to: 's' });

class ElasticsearchService {
  constructor() {
    this.client = new Client({
      node: 'http://localhost:9200',
      auth: {
        username: 'elastic',
        password: process.env.ELASTIC_PASSWORD
      }
    });
    this.indexName = 'buddhist_texts';
  }

  async search(query, options = {}) {
    const {
      mode = 'smart',
      fields = ['title', 'author', 'content'],
      from = 0,
      size = 20,
      highlight = true
    } = options;

    // 自动转换繁体到简体
    const simplifiedQuery = converter(query);
    console.log(`原始查询: ${query}, 简体查询: ${simplifiedQuery}`);

    let esQuery;

    switch(mode) {
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
                  fields: fields,
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
        size: size
      }
    };

    if (highlight) {
      searchParams.body.highlight = {
        fields: {
          content: {
            fragment_size: 200,
            number_of_fragments: 3,
            pre_tags: ['<mark class="search-highlight">'],
            post_tags: ['</mark>']
          },
          title: {},
          author: {}
        }
      };
    }

    const result = await this.client.search(searchParams);

    return {
      total: result.hits.total.value,
      hits: result.hits.hits.map(hit => ({
        id: hit._source.id,
        title: hit._source.title,
        author: hit._source.author,
        dynasty: hit._source.dynasty,
        score: hit._score,
        highlights: hit.highlight || {}
      }))
    };
  }

  async indexBook(book) {
    await this.client.index({
      index: this.indexName,
      id: book.id,
      body: book
    });
  }

  async bulkIndex(books) {
    const body = books.flatMap(book => [
      { index: { _index: this.indexName, _id: book.id } },
      book
    ]);

    return await this.client.bulk({ body });
  }
}

module.exports = ElasticsearchService;
```

## 五、部署方案

### 5.1 Ubuntu 服务器部署步骤

#### 1. 安装 Elasticsearch
```bash
# 添加 Elasticsearch GPG key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# 添加 repository
sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" > /etc/apt/sources.list.d/elastic-8.x.list'

# 更新并安装
sudo apt update
sudo apt install elasticsearch

# 配置 Elasticsearch
sudo nano /etc/elasticsearch/elasticsearch.yml
```

#### 2. Elasticsearch 配置文件
```yaml
# /etc/elasticsearch/elasticsearch.yml
cluster.name: buddhist-texts-cluster
node.name: node-1
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 127.0.0.1
http.port: 9200
discovery.type: single-node

# 安全设置（生产环境）
xpack.security.enabled: true
xpack.security.enrollment.enabled: true

# 性能优化
indices.memory.index_buffer_size: 30%
indices.queries.cache.size: 15%
```

#### 3. JVM 堆内存配置
```bash
# /etc/elasticsearch/jvm.options
-Xms3g  # 最小堆内存
-Xmx3g  # 最大堆内存（建议设置为系统内存的50%，但不超过32GB）
```

#### 4. 安装 IK 分词器
```bash
# 下载对应版本的 IK 分词器
cd /usr/share/elasticsearch
sudo bin/elasticsearch-plugin install https://release.infinilabs.com/analysis-ik/stable/elasticsearch-analysis-ik-8.12.0.zip

# 创建自定义词典目录
sudo mkdir -p /etc/elasticsearch/analysis
sudo cp buddhist_dictionary.txt /etc/elasticsearch/analysis/
sudo cp buddhist_synonyms.txt /etc/elasticsearch/analysis/
sudo cp buddhist_stopwords.txt /etc/elasticsearch/analysis/
```

#### 5. 启动 Elasticsearch
```bash
# 启动服务
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch

# 检查状态
sudo systemctl status elasticsearch

# 设置密码（首次安装）
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
```

#### 7. 创建索引和导入数据
```bash
# 创建索引
curl -X PUT "localhost:9200/buddhist_texts" \
  -H 'Content-Type: application/json' \
  -u elastic:your_password \
  -d @index_mapping.json

# 运行数据导入脚本
node scripts/import-to-elasticsearch.js
```

### 5.2 数据导入脚本
```javascript
// scripts/import-to-elasticsearch.js
const { Client } = require('@elastic/elasticsearch');
const fs = require('fs').promises;
const path = require('path');

const client = new Client({
  node: 'http://localhost:9200',
  auth: {
    username: 'elastic',
    password: process.env.ELASTIC_PASSWORD
  }
});

async function importBooks() {
  const booksDir = path.join(__dirname, '../public/books');
  const files = await fs.readdir(booksDir);

  let batch = [];
  const batchSize = 100;

  for (const file of files) {
    if (file.endsWith('.txt')) {
      const id = file.replace('.txt', '');
      const content = await fs.readFile(
        path.join(booksDir, file),
        'utf-8'
      );

      // 解析书籍元数据
      const lines = content.split('\n');
      const title = lines[0] || '';
      const author = extractAuthor(lines[1]) || '';

      batch.push({
        id: id,
        title: title,
        author: author,
        dynasty: extractDynasty(lines[1]) || '',
        content: lines.slice(2).join('\n'),
        content_length: content.length,
        created_at: new Date()
      });

      if (batch.length >= batchSize) {
        await bulkIndex(batch);
        batch = [];
        console.log(`Imported ${files.indexOf(file) + 1}/${files.length} books`);
      }
    }
  }

  if (batch.length > 0) {
    await bulkIndex(batch);
  }

  console.log('Import completed!');
}

async function bulkIndex(books) {
  const body = books.flatMap(book => [
    { index: { _index: 'buddhist_texts', _id: book.id } },
    book
  ]);

  const result = await client.bulk({ body });

  if (result.errors) {
    console.error('Bulk index errors:', result.items);
  }
}

importBooks().catch(console.error);
```

### 5.3 前端集成（修改现有搜索页面）

#### 搜索页面 UI 增强
```typescript
// app/search/page.tsx 修改建议
// 1. 添加搜索模式选择
const searchModes = [
  { value: 'smart', label: '智能搜索', icon: '🔍' },
  { value: 'exact', label: '精确匹配', icon: '📌' },
  { value: 'phrase', label: '短语搜索', icon: '📝' },
  { value: 'fuzzy', label: '模糊搜索', icon: '🔀' }
];

// 2. 添加搜索选项面板
const SearchOptions = () => (
  <div className="mb-4 p-4 bg-gray-50 rounded-lg">
    <div className="flex items-center gap-4">
      <label className="text-sm font-medium">搜索范围：</label>
      <Checkbox checked={searchTitle} onChange={setSearchTitle}>标题</Checkbox>
      <Checkbox checked={searchAuthor} onChange={setSearchAuthor}>作者</Checkbox>
      <Checkbox checked={searchContent} onChange={setSearchContent}>内容</Checkbox>
    </div>
    <div className="flex items-center gap-4 mt-2">
      <label className="text-sm font-medium">搜索模式：</label>
      {searchModes.map(mode => (
        <button
          key={mode.value}
          onClick={() => setSearchMode(mode.value)}
          className={`px-3 py-1 rounded-lg transition-all ${
            searchMode === mode.value
              ? 'bg-amber-500 text-white'
              : 'bg-white text-gray-600 hover:bg-amber-100'
          }`}
        >
          <span className="mr-1">{mode.icon}</span>
          {mode.label}
        </button>
      ))}
    </div>
  </div>
);

// 3. 优化搜索结果显示
const SearchResult = ({ result }) => (
  <div className="border-b border-gray-200 pb-4 mb-4 hover:bg-amber-50 p-4 rounded-lg transition-all">
    <Link href={`/books/${result.id}?highlight=${encodeURIComponent(searchQuery)}`}>
      <h3 className="text-xl font-medium text-gray-900 mb-2">
        {result.highlights?.title ? (
          <span dangerouslySetInnerHTML={{ __html: result.highlights.title[0] }} />
        ) : (
          result.title
        )}
      </h3>
      <p className="text-sm text-gray-600 mb-2">
        {result.author} · {result.dynasty}
      </p>
      {result.highlights?.content && (
        <div className="text-gray-700 text-sm">
          <p className="mb-1 font-medium text-amber-600">📍 匹配片段：</p>
          {result.highlights.content.map((fragment, idx) => (
            <p
              key={idx}
              className="mb-2 pl-4 border-l-2 border-amber-300"
              dangerouslySetInnerHTML={{ __html: fragment }}
            />
          ))}
        </div>
      )}
      <div className="flex items-center gap-4 mt-2 text-xs text-gray-500">
        <span>相关度：{(result.score * 100).toFixed(1)}%</span>
        <span>匹配字段：{result.matchedField}</span>
      </div>
    </Link>
  </div>
);

// 4. 添加搜索统计和建议
const SearchStats = ({ total, queryTime }) => (
  <div className="mb-4 text-sm text-gray-600">
    找到 <span className="font-bold text-amber-600">{total}</span> 个结果
    （用时 {queryTime}ms）
  </div>
);
```

#### 修改 `searchService.ts` 添加 Elasticsearch 支持：
```typescript
// services/searchService.ts
class SearchService {
  private useElasticsearch = process.env.NEXT_PUBLIC_USE_ELASTICSEARCH === 'true';

  async search(query: string, options: SearchOptions): Promise<SearchResult[]> {
    if (this.useElasticsearch) {
      return this.searchWithElasticsearch(query, options);
    }
    // 保留原有搜索逻辑作为后备
    return this.searchWithLocalIndex(query, options);
  }

  private async searchWithElasticsearch(
    query: string,
    options: SearchOptions
  ): Promise<SearchResult[]> {
    // 繁体转简体处理
    const simplifiedQuery = await this.convertToSimplified(query);

    const response = await fetch('/api/elasticsearch/search', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query: simplifiedQuery,
        originalQuery: query,  // 保留原始查询用于显示
        mode: options.mode || 'smart',
        fields: this.getFieldsByMode(options.mode),
        from: (options.page - 1) * options.limit,
        size: options.limit,
        highlight: true
      })
    });

    const data = await response.json();
    return data.hits;
  }

  // 繁体转简体函数
  private async convertToSimplified(text: string): string {
    // 使用项目已安装的 opencc-js
    const OpenCC = await import('opencc-js');
    const converter = OpenCC.Converter({ from: 't', to: 's' });
    return converter(text);
  }
}
```

## 六、监控和维护

### 6.1 健康检查
```bash
# 检查集群健康
curl -X GET "localhost:9200/_cluster/health?pretty" -u elastic:password

# 检查索引状态
curl -X GET "localhost:9200/buddhist_texts/_stats?pretty" -u elastic:password
```

### 6.2 性能监控
```bash
# 安装 Metricbeat
sudo apt install metricbeat
sudo metricbeat modules enable elasticsearch
sudo systemctl start metricbeat
```

### 6.3 日志管理
```bash
# 查看 Elasticsearch 日志
sudo tail -f /var/log/elasticsearch/buddhist-texts-cluster.log

# 设置日志轮换
sudo nano /etc/logrotate.d/elasticsearch
```

### 6.4 备份策略
由于佛经数据一经导入不会变化，且可以随时从原始文本文件重新导入，建议：
- **不设置自动备份**，节省磁盘空间
- 保留原始文本文件作为数据源
- 如需恢复，直接重新运行导入脚本即可
- 仅在重大版本升级前手动创建临时快照

## 七、性能优化建议

### 7.1 索引优化
- 使用合适的分片数量（数据量 < 10GB 使用 1-3 个分片）
- 定期执行 force merge 减少段文件数量
- 使用 index.refresh_interval 调整刷新频率

### 7.2 查询优化
- 使用 filter 代替 query 对于不需要评分的条件
- 合理使用缓存
- 避免深分页，使用 search_after

### 7.3 硬件建议
- **内存**: 至少 8GB，建议 16GB
- **CPU**: 4 核心以上
- **磁盘**: SSD 推荐，预留 1.5-2 倍数据大小的空间（无需备份空间）
- **网络**: 确保 Node.js 应用和 Elasticsearch 在同一内网

## 八、安全配置

### 8.1 启用安全特性
```yaml
# elasticsearch.yml
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.http.ssl.enabled: true
```

### 8.2 设置用户权限
```bash
# 创建应用专用用户
curl -X POST "localhost:9200/_security/user/app_user" \
  -H 'Content-Type: application/json' \
  -u elastic:password \
  -d '{
    "password": "app_password",
    "roles": ["buddhist_app_role"]
  }'
```

### 8.3 防火墙配置
```bash
# 只允许本地访问
sudo ufw allow from 127.0.0.1 to any port 9200
sudo ufw deny 9200
```

## 九、故障处理

### 9.1 常见问题
1. **内存不足**: 调整 JVM 堆大小
2. **分词器未生效**: 重启 Elasticsearch
3. **查询超时**: 增加 timeout 参数
4. **磁盘空间不足**: 清理日志和旧快照

### 9.2 调试工具
```bash
# 分析查询性能
curl -X GET "localhost:9200/buddhist_texts/_search?explain=true" \
  -H 'Content-Type: application/json' \
  -u elastic:password \
  -d '{"query": {...}}'

# 查看慢查询日志
curl -X PUT "localhost:9200/buddhist_texts/_settings" \
  -H 'Content-Type: application/json' \
  -u elastic:password \
  -d '{
    "index.search.slowlog.threshold.query.warn": "10s",
    "index.search.slowlog.threshold.query.info": "5s"
  }'
```

## 十、项目时间线

| 阶段 | 任务 | 时间 |
|------|------|------|
| 第一阶段 | Elasticsearch 安装和基础配置 | 1天 |
| 第二阶段 | IK 分词器安装和佛教词典配置 | 1天 |
| 第三阶段 | 数据导入和索引创建 | 2天 |
| 第四阶段 | API 开发和前端集成 | 3天 |
| 第五阶段 | 测试和优化 | 2天 |
| 第六阶段 | 部署和监控配置 | 1天 |
| **总计** | | **10天** |

## 十一、成本估算

- **服务器升级**: 建议升级到 16GB 内存（约 $40-80/月增加）
- **存储空间**: 预计需要 15-30GB SSD 空间（无需备份空间）
- **开发时间**: 10 个工作日
- **维护成本**: 每月 1-2 小时运维（数据不变，维护量小）

## 十二、总结

此方案提供了完整的 Elasticsearch 佛经全文检索系统设计，包括：
- ✅ 精确匹配、短语匹配、模糊匹配
- ✅ 中文分词优化和佛教专用词典
- ✅ 使用 OpenCC 自动处理繁体转简体查询
- ✅ 高亮显示搜索结果
- ✅ 增强现有搜索页面 UI 功能
- ✅ 完整的部署和运维方案
- ✅ 性能优化和安全配置

### OpenCC 优势（项目已集成）：
- 内置完整的繁简转换词库，无需手动维护映射文件
- 支持词汇级别的转换，更准确（如「皇后」不会错误转换为「皇後」）
- 支持多种转换标准（大陆简体、台湾繁体、香港繁体等）
- 项目已安装 opencc-js v1.0.5，无需额外配置

系统上线后预期效果：
- 搜索准确度提升 80%
- 支持复杂查询语法
- 毫秒级搜索响应
- 支持千万级文本检索
- 精确的短语匹配和位置感知