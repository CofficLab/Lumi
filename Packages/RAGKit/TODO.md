# RAGKit Package 提取 TODO

> 目标：将 `LumiApp/Plugins/AgentRAGPlugin` 中的核心 RAG 逻辑提取到 `Packages/RAGKit`，使其成为零 MagicKit 依赖的独立 SPM Package。

---

## 阶段一：基础设施搭建

### 1.1 创建 Package.swift
- [x] 创建 `/Packages/RAGKit/Package.swift`
  - `swift-tools-version: 6.0`
  - `platforms: [.macOS(.v14)]`
  - products: `RAGKit`（静态库）
  - targets: `RAGKit`、`RAGKitTests`
  - 无外部依赖（纯 Apple 系统框架：Foundation、CryptoKit、NaturalLanguage、SQLite3、Accelerate）

### 1.2 定义 RAGKit 内部日志协议
- [x] 创建 `Sources/RAGKit/RAGLogger.swift`
  - 定义 `public protocol RAGLogger: Sendable`
  - 方法：`info(_:)`, `error(_:)`, `warning(_:)`
  - 提供默认空实现 `NullRAGLogger`（用于测试和默认场景）
  - 设计参考：当前 `AppLogger.core.info(...)` 的调用模式

### 1.3 定义 RAGKit 配置协议
- [x] 创建 `Sources/RAGKit/RAGConfiguration.swift`
  - 定义 `public protocol RAGConfiguration: Sendable`
  - 需要提供的配置项：
    - `func pluginDatabaseDirectory() -> URL`（替代 `AppConfig.getPluginDBFolderURL(pluginName:)`）
    - `var verboseLogging: Bool { get }`
  - 提供默认实现

### 1.4 定义语言偏好枚举
- [x] 创建 `Sources/RAGKit/RAGLanguagePreference.swift`
  - 定义 `public enum RAGLanguagePreference`
    - `.chinese`, `.english`
  - 替代当前对 `MagicKit.LanguagePreference` 的依赖
  - 仅在 `RAGContextBuilder` 中使用

---

## 阶段二：迁移 Models（无依赖，最先迁移）

### 2.1 迁移 RAGModels.swift
- [x] 复制 `Models/RAGModels.swift` → `Sources/RAGKit/Models/RAGModels.swift`
  - 需要将所有类型标记为 `public`
  - 涉及类型：
    - `RAGSearchResult`（需 public）
    - `RAGResponse`（需 public）
    - `RAGChunk`（需 public）
    - `RAGStoredChunk`（需 public）
    - `RAGVectorMatch`（需 public）
    - `RAGIndexedFileState`（需 public）
    - `RAGIndexStats`（需 public）
    - `RAGProjectIndexState`（需 public）
    - `RAGIndexStatus`（需 public）
    - `RAGVectorBackend`（需 public）
    - `RAGRuntimeInfo`（需 public）
    - `RAGIntentDecision`（需 public，当前未被使用但已定义）

### 2.2 迁移 RAGError.swift
- [x] 复制 `Models/RAGError.swift` → `Sources/RAGKit/Models/RAGError.swift`
  - 标记 `public enum RAGError: LocalizedError`
  - 标记所有 case 和 `errorDescription` 为 public

---

## 阶段三：迁移 Utils（无依赖或仅依赖系统框架）

### 3.1 迁移 Float+Data.swift
- [x] 复制 `Utils/Float+Data.swift` → `Sources/RAGKit/Utils/Float+Data.swift`
  - `Array<Float>.toData()` 和 `Array<Float>.init(data:)` 标记为 `internal`（RAGKit 内部使用）

### 3.2 迁移 RAGTextUtils.swift
- [x] 复制 `Utils/RAGTextUtils.swift` → `Sources/RAGKit/Utils/RAGTextUtils.swift`
  - `RAGTextUtils` 标记为 `public enum`
  - `tokenize(_:)` 标记 `public`
  - `lexicalBoost(query:content:)` 标记 `public`
  - `sourcePathBoost(queryTerms:filePath:)` 标记 `public`
  - 注意：`UnicodeScalar.isCJK` 扩展当前在 `HashEmbeddingProvider.swift` 中，需提取到此处或独立文件

### 3.3 迁移 RAGMathUtils.swift
- [x] 复制 `Utils/RAGMathUtils.swift` → `Sources/RAGKit/Utils/RAGMathUtils.swift`
  - 标记 `public`
  - 依赖 `Accelerate`（系统框架，可正常使用）

### 3.4 迁移 RAGPathUtils.swift
- [x] 复制 `Utils/RAGPathUtils.swift` → `Sources/RAGKit/Utils/RAGPathUtils.swift`
  - 标记 `public`
  - 纯 Foundation，无外部依赖

### 3.5 迁移 RAGFileScanner.swift
- [x] 复制 `Utils/RAGFileScanner.swift` → `Sources/RAGKit/Utils/RAGFileScanner.swift`
  - 标记 `public`
  - 纯 Foundation，无外部依赖
  - 注意：当前 `RAGIndexer` 中有 `discoverFiles` 和 `skipDirectories`/`allowedExtensions` 的私有副本，迁移后应统一使用 `RAGFileScanner`

### 3.6 迁移 RAGUtils.swift
- [x] 复制 `Utils/RAGUtils.swift` → `Sources/RAGKit/Utils/RAGUtils.swift`
  - 标记 `public`

### 3.7 提取 UnicodeScalar+CJK.swift
- [x] 创建 `Sources/RAGKit/Utils/UnicodeScalar+CJK.swift`
  - 从 `HashEmbeddingProvider.swift` 中提取 `UnicodeScalar.isCJK` 扩展
  - 标记 `public`（RAGKit 内部和外部都可能使用）

---

## 阶段四：迁移 Services/Providers（仅依赖系统框架 + 内部 Protocol）

### 4.1 迁移 RAGEmbeddingProvider.swift
- [x] 复制 `Services/Providers/RAGEmbeddingProvider.swift` → `Sources/RAGKit/Services/Providers/RAGEmbeddingProvider.swift`
  - 标记 `public protocol RAGEmbeddingProvider`
  - 标记 `modelID`, `modelVersion`, `dimension`, `embed(_:)`, `embedBatch(_:)` 为 public
  - 标记 extension 中的 `modelIdentifierWithVersion` 为 public

### 4.2 迁移 HashEmbeddingProvider.swift
- [x] 复制 `Services/Providers/HashEmbeddingProvider.swift` → `Sources/RAGKit/Services/Providers/HashEmbeddingProvider.swift`
  - 标记 `public struct HashEmbeddingProvider: RAGEmbeddingProvider`
  - 标记 init 为 public
  - **移除** `UnicodeScalar.isCJK` 扩展（已移至 `UnicodeScalar+CJK.swift`）
  - 依赖：`CryptoKit`（系统框架）
  - 依赖：`RAGTextUtils.tokenize`（提取到 Utils 后可用，注意当前内部有独立 tokenize，应复用 `RAGTextUtils`）

### 4.3 迁移 AppleNativeEmbeddingProvider.swift
- [x] 复制 `Services/Providers/AppleNativeEmbeddingProvider.swift` → `Sources/RAGKit/Services/Providers/AppleNativeEmbeddingProvider.swift`
  - 标记 `public struct AppleNativeEmbeddingProvider: RAGEmbeddingProvider`
  - 标记 init 为 public
  - 依赖：`NaturalLanguage`（系统框架）
  - 内部依赖：`HashEmbeddingProvider`（已迁移）
  - `convertToDoubleArray(_:)` 有两个重载（接受 `[Double]` 和 `[Float]`），确保都正确迁移

### 4.4 迁移 RAGEmbeddingFactory.swift
- [x] 复制 `Services/Providers/RAGEmbeddingFactory.swift` → `Sources/RAGKit/Services/Providers/RAGEmbeddingFactory.swift`
  - 标记 `public enum RAGEmbeddingFactory`
  - 标记所有 factory 方法为 public

---

## 阶段五：迁移 Services/Core（需要解耦的关键部分）

### 5.1 迁移 RAGChunker.swift
- [x] 复制 `Services/RAGChunker.swift` → `Sources/RAGKit/Services/RAGChunker.swift`
  - 标记 `public struct RAGChunker`
  - 标记 init 和 `chunk(_:)` 为 public
  - 无外部依赖 ✅

### 5.2 迁移 RAGIndexingRegistry.swift
- [x] 复制 `Services/RAGIndexingRegistry.swift` → `Sources/RAGKit/Services/RAGIndexingRegistry.swift`
  - 标记 `public final class RAGIndexingRegistry: @unchecked Sendable`
  - 标记所有方法为 public
  - 无外部依赖 ✅

### 5.3 迁移 RAGSQLiteStore.swift（⚠️ 最复杂）
- [x] 复制 `Services/RAGSQLiteStore.swift` → `Sources/RAGKit/Services/RAGSQLiteStore.swift`
  - 标记必要 API 为 public
  - **依赖分析**：
    - `CryptoKit` → `SHA256`（系统框架 ✅）
    - `SQLite3` → 系统框架 ✅
    - `Darwin` → 系统框架 ✅
    - `RAGError` → 已迁移 ✅
    - `RAGModels` → 已迁移 ✅
    - `Float+Data.toData()` → 已迁移 ✅
  - **不需要改动**：`@_silgen_name` C 函数绑定保持不变
  - **需要注意**：
    - 当前使用 `RAGSQLiteStore.contentHash(_:)` 静态方法，需确保引用路径正确
    - `runtimeInfo` 属性需标记 public
  - 日志：当前无日志调用 ✅（仅通过 `runtimeInfo` 传递状态信息）

### 5.4 迁移 RAGRetriever.swift
- [x] 复制 `Services/RAGRetriever.swift` → `Sources/RAGKit/Services/RAGRetriever.swift`
  - 标记 `public struct RAGRetriever`
  - 标记 `retrieve(...)` 为 public
  - **解耦 `SuperLog`**：
    - 移除 `SuperLog` 协议遵循
    - 移除 `Self.t`、`Self.emoji`、`Self.verbose`
    - 替换 `AppLogger.core.info(...)` → 注入的 `RAGLogger` 实例
  - **依赖注入改造**：
    - 构造函数增加 `logger: RAGLogger = NullRAGLogger()`
    - 或者通过 `RAGConfiguration` 注入
  - **内部方法优化**：
    - `tokenize(_:)` → 复用 `RAGTextUtils.tokenize(_:)`
    - `cosineSimilarity(_:_:)` → 复用 `RAGMathUtils.cosineSimilarity(_:_:)`
    - `displayPath(filePath:projectPath:)` → 复用 `RAGPathUtils.displayPath(filePath:projectPath:)`
    - `lexicalBoost(query:content:)` → 复用 `RAGTextUtils.lexicalBoost(query:content:)`
    - `sourcePathBoost(queryTerms:filePath:)` → 复用 `RAGTextUtils.sourcePathBoost(queryTerms:filePath:)`

### 5.5 迁移 RAGContextBuilder.swift
- [x] 复制 `Services/RAGContextBuilder.swift` → `Sources/RAGKit/Services/RAGContextBuilder.swift`
  - 标记 `public enum RAGContextBuilder`
  - 标记 `buildPrompt(...)` 为 public
  - **解耦 `LanguagePreference`**：
    - 参数类型从 `LanguagePreference` 改为 `RAGLanguagePreference`
  - 无其他外部依赖 ✅

### 5.6 迁移 RAGIndexer.swift
- [x] 复制 `Services/RAGIndexer.swift` → `Sources/RAGKit/Services/RAGIndexer.swift`
  - 标记必要 API 为 public
  - **解耦 `SuperLog`**：同 RAGRetriever
  - **解耦 `AppLogger`**：替换为注入的 `RAGLogger`
  - **统一 `discoverFiles`**：
    - 移除内部的 `discoverFiles(in:)` 和 `shouldSkipPath(_:)`
    - 改用 `RAGFileScanner.discoverFiles(in:)`
    - 移除内部的 `skipDirectories` 和 `allowedExtensions` 静态常量
  - **解耦 `RAGIndexProgressEvent`**：
    - 当前通过 `NotificationCenter.postRAGIndexProgress()` 发送进度
    - 改为通过闭包回调 `onProgress: ((RAGIndexProgressEvent) -> Void)?` 通知外部
  - **依赖注入改造**：
    - 构造函数增加 `logger: RAGLogger = NullRAGLogger()`
    - 构造函数增加 `onProgress: ((RAGIndexProgressEvent) -> Void)? = nil`

### 5.7 迁移 RAGService.swift（⚠️ 核心，需最仔细）
- [x] 复制 `Services/RAGService.swift` → `Sources/RAGKit/Services/RAGService.swift`
  - 标记 `public actor RAGService`
  - 标记公开 API 为 public：
    - `initialize()`
    - `ensureIndexed(projectPath:force:)`
    - `ensureIndexedBackground(projectPath:force:)`
    - `checkNeedsIndex(projectPath:)`
    - `retrieve(query:projectPath:topK:)`
    - `getIndexStatus(projectPath:)`
    - `getRuntimeInfo()`
    - `isIndexing(projectPath:)` (static, nonisolated)
    - `isAnyIndexing()` (static, nonisolated)
    - `isInitialized` (nonisolated property)
  - **解耦 `SuperLog`**：移除协议遵循，用注入的 logger 替代
  - **解耦 `AppConfig`**：
    - `AppConfig.getPluginDBFolderURL(pluginName:)` → 通过构造函数注入 `databaseDirectoryProvider: @Sendable () -> URL`
    - 或通过 `RAGConfiguration` 协议注入
  - **解耦 `AppLogger`**：
    - 构造函数增加 `logger: RAGLogger = NullRAGLogger()`
  - **调整内部子组件创建**：
    - `RAGIndexer` 构造需要传入 `logger` 和 `onProgress` 回调
    - `RAGRetriever` 构造需要传入 `logger`
  - **静态方法 `isIndexing` / `isAnyIndexing`**：
    - 当前使用 `private nonisolated static let indexingRegistry`
    - 需要保留此模式，或改为注入共享 registry

### 5.8 迁移 RAGIntentAnalyzer.swift（可选，建议移入 RAGKit）
- [x] 复制 `Middleware/RAGIntentAnalyzer.swift` → `Sources/RAGKit/RAGIntentAnalyzer.swift`
  - 标记 `public struct RAGIntentAnalyzer`
  - 标记 `shouldUseRAG(for:)` 为 public
  - 标记 `analyzeIntent(for:)` 为 public（如果存在）
  - 当前 `import MagicKit` 但未使用任何 MagicKit API，直接移除 import 即可
  - 无外部依赖 ✅

---

## 阶段六：Plugin 层薄壳适配

### 6.1 修改 RAGPlugin.swift
- [ ] 修改 `LumiApp/Plugins/AgentRAGPlugin/RAGPlugin.swift`
  - 添加 `import RAGKit`
  - 创建 `MagicKitRAGLogger: RAGLogger` 适配器
    ```swift
    struct MagicKitRAGLogger: RAGLogger, Sendable {
        func info(_ message: String) { AppLogger.core.info("🦞 \(message)") }
        func error(_ message: String) { AppLogger.core.error("🦞 \(message)") }
        func warning(_ message: String) { AppLogger.core.warning("🦞 \(message)") }
    }
    ```
  - 替换 `RAGService` 初始化：
    ```swift
    // 旧: RAGService()
    // 新: RAGService(
    //       databaseDirectoryProvider: { AppConfig.getPluginDBFolderURL(pluginName: "RAGPlugin") },
    //       logger: MagicKitRAGLogger()
    //     )
    ```
  - 保持 `SuperPlugin` 协议遵循不变
  - 保持 `shared` 单例模式不变

### 6.2 修改 RAGSendMiddleware.swift
- [ ] 修改 `LumiApp/Plugins/AgentRAGPlugin/Middleware/RAGSendMiddleware.swift`
  - 添加 `import RAGKit`
  - **解耦 `LanguagePreference`**：
    - `ctx.projectVM.languagePreference` → 映射为 `RAGLanguagePreference`
    - 添加映射方法：`LanguagePreference` → `RAGLanguagePreference`
  - 其余逻辑保持不变（已通过 `RAGPlugin.getService()` 使用 RAGService）

### 6.3 修改 Views（4个文件，改动较小）
- [ ] `Views/RAGSettingsView.swift`
  - 添加 `import RAGKit`
  - 类型已通过 public 暴露，无需改名
- [ ] `Views/RAGSettingsPopoverView.swift`
  - 添加 `import RAGKit`
- [ ] `Views/RAGStatusBarView.swift`
  - 添加 `import RAGKit`
- [ ] `Views/RAGAutoIndexOverlay.swift`
  - 添加 `import RAGKit`

### 6.4 修改 RAGIndexEvents.swift
- [ ] 保持不变（`RAGIndexProgressEvent` 定义在 RAGKit 中，Plugin 层的 `Notification.Name` 扩展和 View 扩展仍保留在此文件）
- [ ] 确保 `RAGIndexProgressEvent` 类型引用正确（从 RAGKit 导入）

---

## 阶段七：清理与验证

### 7.1 编译验证
- [ ] 确保 `Packages/RAGKit` 独立编译通过（`swift build`）
- [ ] 确保主项目 `LumiApp` 编译通过（添加 RAGKit 依赖）
- [ ] 确保 `AgentRAGPlugin` 编译通过

### 7.2 Xcode 项目配置
- [ ] 在 Xcode 项目中添加 RAGKit Package 依赖
  - 或者：如果使用 workspace，添加到 workspace
  - 在 LumiApp target 的 Frameworks 中添加 `RAGKit`
- [ ] 确认 `AgentRAGPlugin` 的编译源文件列表中移除已迁移的文件
  - 移除：`Models/`, `Services/`, `Utils/` 下的已迁移文件
  - 保留：`RAGPlugin.swift`, `RAGIndexEvents.swift`, `RAG.xcstrings`, `Middleware/`, `Views/`

### 7.3 代码清理
- [ ] 移除 RAGKit 源文件中所有残留的 `import MagicKit`
- [ ] 移除 RAGKit 源文件中所有 `SuperLog` 协议遵循
- [ ] 移除 RAGKit 源文件中所有 `Self.t`、`Self.emoji` 引用
- [ ] 统一 RAGIndexer 和 RAGFileScanner 的 `discoverFiles` 实现（消除重复）
- [ ] 统一 RAGRetriever 中 `tokenize`/`cosineSimilarity`/`lexicalBoost`/`sourcePathBoost`/`displayPath` → 复用 Utils

### 7.4 功能验证
- [ ] RAG 索引功能正常（全量/增量）
- [ ] RAG 检索功能正常
- [ ] RAG 设置页面正常
- [ ] RAG 状态栏正常
- [ ] 自动索引覆盖层正常
- [ ] 索引进度通知正常

---

## 阶段八：单元测试（可选但推荐）

### 8.1 基础测试
- [ ] `RAGChunker` 测试：各种文本分块场景
- [ ] `RAGTextUtils` 测试：中英文分词
- [ ] `RAGMathUtils` 测试：余弦相似度计算
- [ ] `RAGPathUtils` 测试：路径标准化和显示

### 8.2 Provider 测试
- [ ] `HashEmbeddingProvider` 测试：向量化一致性
- [ ] `RAGEmbeddingFactory` 测试：工厂方法

### 8.3 集成测试
- [ ] `RAGSQLiteStore` 测试：数据库 CRUD
- [ ] `RAGRetriever` 测试：检索逻辑
- [ ] `RAGService` 测试：完整索引-检索流程

---

## 文件迁移对照表

| 原路径 (AgentRAGPlugin/) | 新路径 (RAGKit/Sources/RAGKit/) | 状态 |
|---|---|---|
| `Models/RAGModels.swift` | `Models/RAGModels.swift` | ✅ 已迁移 |
| `Models/RAGError.swift` | `Models/RAGError.swift` | ✅ 已迁移 |
| `Utils/Float+Data.swift` | `Utils/Float+Data.swift` | ✅ 已迁移 |
| `Utils/RAGTextUtils.swift` | `Utils/RAGTextUtils.swift` | ✅ 已迁移 |
| `Utils/RAGMathUtils.swift` | `Utils/RAGMathUtils.swift` | ✅ 已迁移 |
| `Utils/RAGPathUtils.swift` | `Utils/RAGPathUtils.swift` | ✅ 已迁移 |
| `Utils/RAGFileScanner.swift` | `Utils/RAGFileScanner.swift` | ✅ 已迁移 |
| `Utils/RAGUtils.swift` | `Utils/RAGUtils.swift` | ✅ 已迁移 |
| — | `Utils/UnicodeScalar+CJK.swift` | ✅ 已创建 |
| `Services/Providers/RAGEmbeddingProvider.swift` | `Services/Providers/RAGEmbeddingProvider.swift` | ✅ 已迁移 |
| `Services/Providers/HashEmbeddingProvider.swift` | `Services/Providers/HashEmbeddingProvider.swift` | ✅ 已迁移 |
| `Services/Providers/AppleNativeEmbeddingProvider.swift` | `Services/Providers/AppleNativeEmbeddingProvider.swift` | ✅ 已迁移 |
| `Services/Providers/RAGEmbeddingFactory.swift` | `Services/Providers/RAGEmbeddingFactory.swift` | ✅ 已迁移 |
| `Services/RAGChunker.swift` | `Services/RAGChunker.swift` | ✅ 已迁移 |
| `Services/RAGIndexingRegistry.swift` | `Services/RAGIndexingRegistry.swift` | ✅ 已迁移 |
| `Services/RAGSQLiteStore.swift` | `Services/RAGSQLiteStore.swift` | ✅ 已迁移 |
| `Services/RAGRetriever.swift` | `Services/RAGRetriever.swift` | ✅ 已迁移 |
| `Services/RAGContextBuilder.swift` | `Services/RAGContextBuilder.swift` | ✅ 已迁移 |
| `Services/RAGIndexer.swift` | `Services/RAGIndexer.swift` | ✅ 已迁移 |
| `Services/RAGService.swift` | `Services/RAGService.swift` | ✅ 已迁移 |
| `Middleware/RAGIntentAnalyzer.swift` | `RAGIntentAnalyzer.swift` | ✅ 已迁移 |
| — | `RAGLogger.swift` | ✅ 已创建 |
| — | `RAGConfiguration.swift` | ✅ 已创建 |
| — | `RAGLanguagePreference.swift` | ✅ 已创建 |

### 留在 Plugin 层的文件（不迁移）

| 文件 | 原因 |
|---|---|
| `RAGPlugin.swift` | 依赖 SuperPlugin，是 Plugin 入口 |
| `RAGIndexEvents.swift` | Notification + View 扩展，依赖 SwiftUI |
| `RAG.xcstrings` | 本地化资源 |
| `Middleware/RAGSendMiddleware.swift` | 依赖 SuperSendMiddleware, SendMessageContext, ProjectVM |
| `Views/RAGSettingsView.swift` | 重度依赖 MagicKit UI (ProjectVM, RecentProjectsStore) |
| `Views/RAGSettingsPopoverView.swift` | 重度依赖 MagicKit UI |
| `Views/RAGStatusBarView.swift` | 重度依赖 MagicKit UI (StatusBarHoverContainer, Color.adaptive) |
| `Views/RAGAutoIndexOverlay.swift` | 重度依赖 MagicKit UI (ProjectVM, UIPerformanceSignpost, inRootView) |

---

## 依赖注入总结

### RAGService 构造函数改造

```swift
// 改造前
actor RAGService: SuperLog { ... }

// 改造后
public actor RAGService {
    private let logger: RAGLogger
    private let databaseDirectoryProvider: @Sendable () -> URL
    
    public init(
        databaseDirectoryProvider: @escaping @Sendable () -> URL,
        logger: RAGLogger = NullRAGLogger()
    ) {
        self.databaseDirectoryProvider = databaseDirectoryProvider
        self.logger = logger
    }
}
```

### Plugin 层适配

```swift
// RAGPlugin.swift 中
@MainActor
private(set) static var service: RAGService = RAGService(
    databaseDirectoryProvider: {
        AppConfig.getPluginDBFolderURL(pluginName: "RAGPlugin")
    },
    logger: MagicKitRAGLogger()
)
```

### LanguagePreference 映射

```swift
// 在 RAGSendMiddleware.swift 或 RAGContextBuilder 调用处
extension LanguagePreference {
    var ragPreference: RAGLanguagePreference {
        switch self {
        case .chinese: return .chinese
        case .english: return .english
        }
    }
}
```

---

## 风险点与注意事项

1. **Swift 6 严格并发**：RAGKit 作为 SPM Package，默认启用 Swift 6 并发检查。需确保所有 `public` API 的 `Sendable` 一致性。
2. **sqlite-vec 动态库加载**：`RAGSQLiteStore` 使用 `@_silgen_name` 和 `dlopen` 模式加载 sqlite-vec 扩展。此逻辑是运行时行为，不受 SPM 影响，但需确保 dylib 搜索路径在 Package 编译环境下仍能找到。
3. **RAGIndexProgressEvent 跨层传递**：当前通过 `NotificationCenter` 全局通知传递索引进度。迁移后 RAGKit 内部应改为闭包回调，Plugin 层的 `RAGIndexEvents.swift` 负责将闭包回调桥接为 `NotificationCenter` 通知。
4. **文件删除顺序**：从 Xcode 项目的 AgentRAGPlugin 编译源列表中移除文件时，需确保 RAGKit 已正确引入，否则会编译失败。
5. **`RAGPlugin.getService()` 模式**：Plugin 层通过 `RAGPlugin.getService()` 获取 `RAGService` 实例。RAGService 移入 RAGKit 后，类型变为 `RAGKit.RAGService`，需要确保 `import RAGKit` 后类型解析正确。
