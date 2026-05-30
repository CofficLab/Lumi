# RAGKit

可复用的检索增强生成（RAG）工具包。提供项目索引、向量嵌入、SQLite 存储与语义检索，供宿主应用集成对话或搜索能力。

## Package

- Product: `RAGKit`
- Platform: macOS 14+
- Swift tools: 6.0

## 目录结构

```
Sources/RAGKit/
├── Core/           配置、日志、意图分析、语言偏好
├── Models/         数据模型（Chunk、Error、IndexState、SearchResult、VectorTypes）
├── Services/
│   ├── Providers/  可插拔嵌入实现（Protocol、Apple Native、Mock、Factory）
│   ├── RAGService.swift      核心 Actor 入口
│   ├── RAGIndexer.swift       全量/增量索引
│   ├── RAGRetriever.swift     向量 + 词法混合检索
│   ├── RAGChunker.swift       文本分块
│   ├── RAGContextBuilder.swift Prompt 构建
│   ├── RAGSQLiteStore.swift   SQLite + sqlite-vec 持久化
│   └── ...
└── Utils/          工具（缓存、超时、文件扫描、数学、路径、文本、CJK 检测）
```

## 提供什么

| 组件 | 说明 |
|---|---|
| **RAGService** | 核心 Actor，统一管理初始化、索引、检索生命周期 |
| **RAGIndexer** | 全量重建 + 增量索引，自动检测文件变更 |
| **RAGRetriever** | 向量相似度 + 词法 + 路径三维混合检索，内置查询缓存 |
| **RAGChunker** | 按行数/字符数自适应文本分块，支持重叠 |
| **RAGContextBuilder** | 中英文 Prompt 模板，将检索结果拼入上下文 |
| **RAGIntentAnalyzer** | 纯规则判断查询是否需要 RAG（不依赖 LLM） |
| **RAGEmbeddingProvider** | 可插拔嵌入协议，内置 Apple Native 和 Mock 实现 |
| **RAGEmbeddingFactory** | 一行创建默认/Mock/AppleNative 嵌入提供者 |
| **RAGSQLiteStore** | SQLite 存储层，支持 sqlite-vec 或纯 Swift 余弦计算两种后端 |
| **RAGCache** | 线程安全的查询结果缓存（TTL + 最大条目淘汰） |
| **RAGTimeout** | 带超时的异步操作包装 |
| **RAGFileScanner** | 项目文件发现，自动跳过 .git / build / node_modules 等 |

## 依赖与集成

```swift
dependencies: [
    .package(path: "../RAGKit"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["RAGKit"]),
]
```

## 基本用法

```swift
import RAGKit

let service = RAGService(
    databaseDirectoryProvider: { /* app support URL */ }
)

try await service.initialize()
try await service.ensureIndexed(projectPath: projectRoot.path)
let response = try await service.retrieve(
    query: "authentication flow",
    projectPath: projectRoot.path,
    topK: 8
)
```

## Testing

75 个单元/集成测试，源码行覆盖率 **84.4%**（1607/1904 行）。

```sh
cd Packages/RAGKit && swift test
```

| 文件 | 覆盖率 | 说明 |
|---|---|---|
| Core/RAGConfiguration | 100% | |
| Core/RAGIntentAnalyzer | 82.8% | 未覆盖：`deprecated` 兼容方法和 `containsCodeIntentWord` |
| Core/RAGLogger | 100% | |
| Models/* | 100% | 全部 6 个模型 |
| Providers/* | 83–100% | AppleNative 未覆盖：原生 embedding 不可用时的 fallback |
| RAGChunker | 100% | |
| RAGContextBuilder | 89.5% | |
| RAGIndexer | 91.4% | |
| RAGIndexingRegistry | 100% | |
| RAGRetriever | 94.1% | 含缓存命中路径 |
| RAGSQL | 0% | 纯 SQL 常量，无逻辑 |
| RAGSQLiteStore | 67.1% | 未覆盖：sqlite-vec 扩展加载、向量索引重建 |
| RAGService | 96.3% | |
| Utils/* | 95–100% | 全部 8 个工具 |

## Host integration

Keep UI, plugin registration, and conversation policy in the host app. Keep indexing, embedding, storage, and retrieval in this package.
