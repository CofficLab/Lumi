# 改进建议：智能代码上下文管理

**参考产品**: Cursor, Claude Code, GitHub Copilot  
**优先级**: 🔴 高  
**影响范围**: LLMService, AgentTool, Conversation

---

## 背景

Cursor 和 Claude Code 的核心优势在于能够智能地管理代码上下文，只将相关的代码片段发送给 LLM，而不是整个代码库。这既节省了 token 成本，又提高了响应速度。

当前 Lumi 项目的 `ContextService` 可能缺少以下关键功能：

---

## 改进方案

### 1. 代码库智能索引

参考 Cursor 的代码索引机制：

```swift
/// 代码索引服务
protocol CodeIndexService {
    /// 构建项目代码索引
    func buildIndex(for projectPath: String) async throws
    
    /// 增量更新索引
    func updateIndex(for files: [String]) async
    
    /// 语义搜索相关代码
    func search(query: String, limit: Int) async -> [CodeChunk]
    
    /// 查找符号定义
    func findDefinition(symbol: String) async -> [SymbolLocation]
    
    /// 查找引用
    func findReferences(symbol: String) async -> [SymbolLocation]
}

/// 代码片段
struct CodeChunk {
    let filePath: String
    let startLine: Int
    let endLine: Int
    let content: String
    let embedding: [Float]?
    let symbols: [String]
    let relevanceScore: Double
}
```

**实现建议**:
- 使用 Tree-sitter 进行代码解析
- 支持增量索引，避免每次全量重建
- 存储代码 embeddings 支持语义搜索

---

### 2. 智能上下文选择器

根据用户问题自动选择最相关的代码上下文：

```swift
/// 上下文选择策略
enum ContextSelectionStrategy {
    /// 基于关键词匹配
    case keyword
    /// 基于 AST 结构
    case astBased
    /// 基于语义相似度
    case semantic
    /// 混合策略
    case hybrid
}

/// 上下文选择器
class ContextSelector {
    /// 根据用户问题选择相关代码
    func selectContext(
        for query: String,
        in project: ProjectInfo,
        strategy: ContextSelectionStrategy = .hybrid,
        maxTokens: Int = 8000
    ) async -> ContextPackage {
        // 1. 解析问题中的关键符号和意图
        // 2. 搜索相关代码片段
        // 3. 计算 token 预算
        // 4. 组装上下文
    }
    
    /// 追踪上下文使用情况
    func trackContextUsage(
        contextId: UUID,
        wasHelpful: Bool,
        userFeedback: String?
    ) async
}
```

---

### 3. Token 预算管理器

智能分配 token 预算：

```swift
/// Token 预算分配器
class TokenBudgetManager {
    /// 默认 token 预算
    let defaultBudget: Int = 8000
    
    /// 分配 token 预算
    func allocateBudget(
        for request: ChatRequest,
        context: ProjectContext
    ) -> TokenAllocation {
        var allocation = TokenAllocation()
        
        // 系统提示词预算
        allocation.systemPrompt = 500
        
        // 历史对话预算（根据重要性衰减）
        allocation.conversationHistory = min(
            2000,
            calculateHistoryBudget(for: request.conversationId)
        )
        
        // 代码上下文预算（剩余的大部分）
        allocation.codeContext = defaultBudget 
            - allocation.systemPrompt 
            - allocation.conversationHistory
            - 1000 // 预留响应空间
        
        return allocation
    }
    
    /// 压缩上下文（当超出预算时）
    func compressContext(
        _ context: [CodeChunk],
        targetTokens: Int
    ) async -> [CodeChunk] {
        // 策略1: 移除低相关性片段
        // 策略2: 截断长片段
        // 策略3: 使用 LLM 总结
    }
}
```

---

### 4. 文件优先级系统

参考 Cursor 的文件优先级机制：

```swift
/// 文件优先级评估器
class FilePriorityEvaluator {
    /// 评估文件相关性优先级
    func evaluatePriority(
        file: FileInfo,
        query: String,
        recentFiles: [String],
        openFiles: [String]
    ) -> FilePriority {
        var score = 0.0
        
        // 当前打开的文件 (权重最高)
        if openFiles.contains(file.path) {
            score += 100
        }
        
        // 最近编辑的文件
        if recentFiles.contains(file.path) {
            score += 50
        }
        
        // 文件名与查询相关
        if query.lowercased().contains(file.name.lowercased()) {
            score += 30
        }
        
        // 文件类型权重
        score += fileTypeWeight(file.type)
        
        // 导入依赖关系
        score += importRelatedScore(file, openFiles)
        
        return FilePriority(score: score, reasons: [])
    }
}
```

---

### 5. 上下文缓存机制

避免重复处理相同上下文：

```swift
/// 上下文缓存
actor ContextCache {
    private var cache: [String: CachedContext] = [:]
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    
    /// 获取缓存的上下文
    func get(for query: String, projectPath: String) -> CachedContext? {
        let key = cacheKey(query: query, project: projectPath)
        return cache[key]
    }
    
    /// 缓存上下文
    func set(
        _ context: ContextPackage,
        for query: String,
        projectPath: String
    ) {
        let key = cacheKey(query: query, project: projectPath)
        cache[key] = CachedContext(
            context: context,
            timestamp: Date(),
            hitCount: 0
        )
        
        // LRU 淘汰
        evictIfNeeded()
    }
    
    /// 文件变更时失效相关缓存
    func invalidate(for changedFiles: [String]) {
        cache = cache.filter { _, cached in
            !cached.context.affectedFiles.contains {
                changedFiles.contains($0)
            }
        }
    }
}
```

---

### 6. 项目结构理解

让 AI 理解项目结构：

```swift
/// 项目分析器
class ProjectAnalyzer {
    /// 分析项目结构
    func analyze(projectPath: String) async throws -> ProjectStructure {
        var structure = ProjectStructure()
        
        // 识别项目类型
        structure.projectType = detectProjectType(at: projectPath)
        
        // 解析目录结构
        structure.directoryTree = try buildDirectoryTree(at: projectPath)
        
        // 识别入口文件
        structure.entryPoints = findEntryPoints(in: structure)
        
        // 分析依赖关系
        structure.dependencies = try analyzeDependencies(at: projectPath)
        
        // 生成项目摘要
        structure.summary = generateSummary(structure)
        
        return structure
    }
    
    /// 生成项目概览文档
    func generateProjectOverview(_ structure: ProjectStructure) -> String {
        // 供 LLM 理解的项目结构描述
    }
}
```

---

## 实施计划

### 阶段 1: 基础设施 (2-3 周)
1. 实现 `CodeIndexService` 基础框架
2. 集成 Tree-sitter 代码解析
3. 实现基础文件优先级评估

### 阶段 2: 智能选择 (2-3 周)
1. 实现 `ContextSelector`
2. 实现 `TokenBudgetManager`
3. 添加上下文缓存机制

### 阶段 3: 高级功能 (2-3 周)
1. 集成 embedding 模型进行语义搜索
2. 实现项目结构分析
3. 添加上下文使用追踪和分析

---

## 预期效果

1. **Token 成本降低 40-60%**: 只发送相关代码
2. **响应速度提升 30-50%**: 减少上下文传输
3. **回答准确性提高**: 更精准的上下文
4. **用户体验优化**: 更智能的代码理解

---

## 参考资源

- [Cursor 上下文管理设计](https://cursor.sh/docs)
- [Sourcegraph 代码智能](https://about.sourcegraph.com/)
- [Tree-sitter 解析器](https://tree-sitter.github.io/)
- [OpenAI Embeddings API](https://platform.openai.com/docs/guides/embeddings)

---

*创建时间: 2026-03-13*