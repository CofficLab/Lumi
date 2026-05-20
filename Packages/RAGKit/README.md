# RAGKit

可复用的检索增强生成（RAG）工具包。提供项目索引、向量嵌入、SQLite 存储与语义检索，供宿主应用集成对话或搜索能力。

## Package

- Product: `RAGKit`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- **RAGService**：初始化本地库、全量/增量索引、检索相关片段
- **RAGIndexer / RAGRetriever**：索引与查询管线
- **RAGEmbeddingProvider**：可插拔嵌入实现（Hash、Apple Native 等）
- **RAGSQLiteStore**：本地向量与元数据持久化

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

From this package directory:

```sh
swift test
```

## Host integration

Keep UI, plugin registration, and conversation policy in the host app. Keep indexing, embedding, storage, and retrieval in this package.
