# Project RAG 与代码导航能力改进方案

日期：2026-08-29

## 1. 结论

Lumi 已经具备完整的 Project RAG 基础设施：项目索引、SQLite 存储、sqlite-vec 向量检索、Apple NaturalLanguage embedding、后台索引调度，以及 `search_code` Agent 工具。

当前主要问题不是“没有 RAG”，而是 RAG 尚未成为 AgentLoop 的默认代码导航路径：它被注册成一个可选工具，是否调用由模型临时决定。意图分析器和上下文构建器虽然已经存在，但当前没有接入生产请求链路。因此模型仍可能先使用通用的 `ls`、`glob`、`read_file` 和 `run_command` 工具，进行多轮目录探索。

目标不是重新实现 RAG，而是把现有 Project RAG 与精确文本搜索、Swift 符号检索、依赖关系分析和 AgentLoop 编排组合成统一的 `CodeNavigation` 能力。

## 2. 当前实现事实

### 2.1 ProjectRAG 已经被装配

`DefaultPluginFactory` 显式装配了 `ProjectRAGSuperPlugin`。插件在 `onBoot` 中：

1. 创建 `RAGService`。
2. 注册 `ProjectRAGProviding`。
3. 向 `ToolManagerProviding` 注册 `RAGCodeSearchTool`，工具名为 `search_code`。
4. 在后台初始化并索引当前项目。

相关实现：

- [`PluginFactory.swift`](../Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift)
- [`ProjectRAGPlugin.swift`](../Packages/PluginProjectRAG/Sources/PluginProjectRAG/ProjectRAGPlugin.swift)
- [`ProjectRAGProvider.swift`](../Packages/PluginProjectRAG/Sources/PluginProjectRAG/ProjectRAGProvider.swift)
- [`RAGCodeSearchTool.swift`](../Packages/PluginProjectRAG/Sources/PluginProjectRAG/Tools/RAGCodeSearchTool.swift)

### 2.2 RAG 的检索能力

索引器会扫描允许的代码和文档文件，按文件变化状态增量索引，并将 chunk 与 embedding 写入 SQLite。检索器的当前排序大致为：

```text
语义相似度 75% + 词法匹配 20% + 路径匹配 5%
```

它还具备以下能力：

- sqlite-vec ANN 候选检索；
- ANN 无结果时的词法 fallback；
- 查询缓存；
- 每个文件最多优先返回两个 chunk；
- 后台索引、取消、暂停和增量更新；
- 对 `.git`、`.build`、`DerivedData`、`node_modules` 等目录的过滤。

相关实现：

- [`RAGService.swift`](../Packages/PluginProjectRAG/Sources/ProjectRAGEngine/Services/RAGService.swift)
- [`RAGIndexer.swift`](../Packages/PluginProjectRAG/Sources/ProjectRAGEngine/Services/RAGIndexer.swift)
- [`RAGRetriever.swift`](../Packages/PluginProjectRAG/Sources/ProjectRAGEngine/Services/RAGRetriever.swift)
- [`RAGFileScanner.swift`](../Packages/PluginProjectRAG/Sources/ProjectRAGEngine/Utils/RAGFileScanner.swift)

### 2.3 当前 AgentLoop 只把 RAG 当作普通工具

AgentLoop 请求 LLM 时，会把 `toolManager.allTools()` 中的所有工具转换成 schema，再将它们一并暴露给模型。它没有在请求前执行一个固定的代码定位阶段，也没有根据用户消息自动选择 RAG。

相关实现：

- [`AgentLoopProvider+Tool.swift`](../Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift)
- [`DefaultAgentLoopProvider.swift`](../Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/DefaultAgentLoopProvider.swift)

因此当前行为可能是：

```text
用户问题
  ↓
LLM 自行选择工具
  ├─ search_code       （可能调用）
  └─ ls / glob / read_file / run_command （也可能调用）
```

### 2.4 已有的意图分析和上下文构建器没有接入

`RAGIntentAnalyzer` 已经定义了中文、英文、路径和代码意图判断；`RAGContextBuilder` 也可以把检索结果拼接成上下文。但当前生产代码中没有发现它们被 AgentLoop 或 `willSendToLLM` hook 调用，不能形成：

```text
用户消息 → 判断代码意图 → 自动检索 → 注入相关上下文
```

这两个组件目前更像未完成接线的设计残留，而不是正在工作的导航流程。

## 3. 存在的问题

### 3.1 RAG 的使用权交给了模型，而不是导航编排器

`search_code` 工具的存在不代表每次代码问题都会使用它。模型可能因为工具名称、当前上下文或推理路径选择通用文件工具，导致 RAG 完全没有参与。

这也是 Lumi 和 Codex 体感不同的核心原因：Codex 把代码库定位视为任务开始阶段的默认行为；Lumi 目前把它视为众多工具中的一个选项。

### 3.2 语义检索不能单独承担结构化代码导航

向量检索适合回答：

- 哪些模块可能负责项目索引？
- 哪些代码与授权流程语义相关？
- 这个错误大概涉及哪些文件？

但它不擅长保证以下结果完整且精确：

- 某个符号的唯一声明位置；
- 所有调用方和实现方；
- 一个事件经过的完整调用链；
- `Package.swift` 中的依赖边界；
- 协议、实现、扩展和测试之间的对应关系。

因此需要“语义 + 词法 + 符号 + 依赖”的分层检索，而不是继续单纯调高 `topK`。

### 3.3 首次搜索存在索引未完成问题

`RAGCodeSearchTool` 会先请求后台确保索引，再立即执行查询。后台索引并不保证已经完成，工具本身也明确允许返回“索引可能仍在进行中”。

这会产生两类体验问题：

1. 用户第一次问代码问题时，搜索结果为空或不稳定。
2. 模型收到空结果后，转而使用通用文件工具，开始长时间调查。

应将“索引是否可用”和“是否需要后台更新”分开处理，不能把一个尚未完成的索引当作可靠的零结果。

### 3.4 项目恢复和后台索引之间存在时序风险

`ProjectsPlugin` 恢复当前项目是异步任务；`ProjectRAGSuperPlugin` 也在后台读取当前项目路径。如果 RAG 任务执行时项目尚未恢复，它可能直接结束，直到下一次显式搜索才触发索引。

该问题需要通过日志和集成测试确认，但当前结构确实缺少“项目打开事件 → RAG 确保索引”的明确连接。

### 3.5 意图判断规则过于粗糙

当前 `RAGIntentAnalyzer` 使用字符串包含关系判断意图，例如英文触发词包含 `how`。现有测试甚至验证了普通句子 `hello, how are you today` 会被判定为需要 RAG。

这会造成：

- 非代码对话触发检索；
- 无意义的查询 embedding；
- 不必要的数据库访问；
- 用户感受到响应变慢。

意图分析应从简单关键词触发升级为低成本的规则分层，并允许 AgentLoop 根据任务类型跳过 RAG。

### 3.6 RAG 结果还不是可直接执行的导航计划

`RAGCodeSearchTool` 返回的是若干带分数的代码片段。结果没有明确告诉 Agent：

- 哪个文件是入口；
- 哪个文件是实现；
- 哪些片段属于同一调用链；
- 下一步应该读取哪个文件或搜索哪个符号；
- 当前证据是否足够。

模型仍需自行解释结果、猜测下一步并重复调用工具。

### 3.7 通用 Shell 工具的项目边界不一致

`ShellTool` 当前将工作目录设置为用户 Home，而不是当前项目根目录。RAG 使用的是当前项目路径，但通用 Shell 使用的是另一个默认边界。

相关实现：

- [`ShellTool.swift`](../Packages/PluginToolManager/Sources/PluginToolManager/Tools/ShellTool.swift)

这会增加模型传递绝对路径和执行 `cd` 的次数，也容易导致搜索范围错误。

## 4. 目标架构

```text
用户自然语言
    ↓
CodeNavigationCoordinator
    ├─ 判断是否是项目/代码问题
    ├─ 获取当前 workspaceRoot
    ├─ 生成搜索词、符号词和路径词
    ├─ 并行执行分层检索
    │    ├─ ProjectRAG 语义搜索
    │    ├─ rg 词法搜索
    │    ├─ 文件名/路径搜索
    │    └─ Swift 符号/引用搜索
    ├─ 合并、去重和排序候选结果
    ├─ 扩展入口、实现、调用方和测试关系
    ├─ 生成有限大小的上下文包
    └─ 给 AgentLoop 返回导航证据和下一步建议
    ↓
AgentLoop 推理、修改和验证
```

职责边界应保持清晰：

| 组件 | 职责 |
|---|---|
| `ProjectRAG` | 项目范围索引和语义/词法候选检索 |
| `CodeNavigationCoordinator` | 意图路由、并行检索、排序、上下文打包 |
| `ProjectProviding` | 当前项目和 `workspaceRoot` |
| `ToolManager` | 工具注册、授权和实际执行 |
| `AgentLoop` | LLM 回合、工具调用循环和最终推理 |
| `MessageRenderer` | 展示导航过程和工具结果 |

`CodeNavigationCoordinator` 不应把所有项目知识硬编码到某个插件中，也不应替代 AgentLoop；它是连接项目检索能力和 AgentLoop 的独立能力层。

## 5. 分阶段改进方案

### Phase 0：先测量当前行为

增加以下指标，先建立真实基线：

| 指标 | 说明 |
|---|---|
| `timeToFirstRelevantFile` | 用户消息到第一个相关文件的耗时 |
| `timeToFirstRAGResult` | RAG 工具首次返回有效结果的耗时 |
| `searchToolSelected` | 是否选择 `search_code` |
| `genericExplorationCalls` | `ls`、`glob`、`read_file`、Shell 调用次数 |
| `duplicateSearchCount` | 等价或高度相似搜索次数 |
| `emptyRAGResultCount` | 索引未完成或无结果的次数 |
| `contextRelevance` | 返回片段是否包含目标实现或调用链 |
| `navigationToPatchTurns` | 定位到首次有效修改之间的 LLM 回合数 |

每次导航都应记录：会话 ID、项目 ID、索引状态、搜索层、查询、候选文件数量、结果耗时和停止原因。日志中不要记录完整源代码或用户敏感内容。

### Phase 1：统一项目上下文和索引生命周期

1. 为会话建立明确的 `workspaceRoot`。
2. `search_code`、`read_file`、`glob`、Shell 全部默认使用同一个 root。
3. 项目打开或切换事件触发 `ProjectRAGProviding.ensureIndexed`。
4. 区分三种状态：

```text
没有索引 → 可用但正在更新 → 可用且最新
```

5. 首次查询时，如果已有旧索引，立即返回旧索引结果，同时后台更新；不要等待新索引，也不要把“更新中”误报成“没有结果”。
6. 如果完全没有索引，优先启动轻量词法搜索，语义索引完成后再补充结果。

这部分应与现有的 [`project-rag-resource-optimization-plan.md`](./project-rag-resource-optimization-plan.md) 保持一致，复用其后台调度、增量索引、取消和资源预算设计。

### Phase 2：实现分层检索

保留现有 Project RAG，并新增以下检索层：

#### 2.1 精确词法搜索

新增专用 `search_text` 或将其作为 `CodeNavigationCoordinator` 的内部能力，底层使用 `rg` 或等价实现，支持：

- 多个搜索词；
- glob include/exclude；
- 项目 root 限制；
- 上下文行数；
- 最大命中数；
- 返回相对路径、行号和命中类型。

词法搜索对 Swift 类型名、中文 UI 文案、错误文本、工具名和配置 key 非常重要，不能被向量搜索替代。

#### 2.2 文件和路径搜索

提供文件名、目录名、扩展名和 Package 名称的快速匹配。该层不需要 embedding，应该在毫秒级完成。

#### 2.3 Swift 符号搜索

逐步接入 SourceKit-LSP、索引数据或 SwiftSyntax，至少支持：

- 类型和成员声明；
- 协议遵循；
- 方法调用；
- 扩展；
- 测试引用；
- 文件到符号的映射。

#### 2.4 依赖关系搜索

解析 `Package.swift` 和 Xcode 目标依赖，支持回答：

- 哪个 package 提供这个类型？
- 哪些插件注册了这个 provider？
- 某个能力从哪个 Factory 装配？
- 删除一个 package 会影响哪些消费者？

### Phase 3：让 RAG 结果变成导航证据

不要只返回无结构的 Markdown 片段，内部先定义结构化结果：

```swift
struct CodeNavigationHit: Sendable {
    let path: String
    let startLine: Int?
    let endLine: Int?
    let kind: HitKind       // semantic, text, symbol, dependency
    let score: Double
    let summary: String?
    let snippet: String
}

struct CodeNavigationEvidence: Sendable {
    let query: String
    let workspaceRoot: String
    let hits: [CodeNavigationHit]
    let relatedFiles: [String]
    let nextSearches: [String]
    let indexState: IndexState
}
```

排序建议：

1. 精确符号声明；
2. 精确文本命中；
3. 调用方和实现方；
4. 相关测试；
5. 路径和 package 匹配；
6. 语义相似片段。

语义结果仍然重要，但不应因为分数较高就覆盖唯一的精确声明位置。

### Phase 4：接入 AgentLoop，但保持职责分离

推荐增加一个导航入口，而不是让所有插件直接修改 LLM 历史：

```swift
protocol CodeNavigationProviding: AnyObject, Sendable {
    func shouldNavigate(message: String, conversationID: UUID) async -> Bool
    func locate(
        message: String,
        conversationID: UUID,
        workspaceRoot: String
    ) async throws -> CodeNavigationEvidence
}
```

AgentLoop 的请求前流程：

```text
读取用户最新请求
  ↓
CodeNavigationCoordinator 判断是否需要导航
  ↓
需要：执行一次有限预算的定位
  ↓
将导航证据作为本轮临时上下文传给 LLM
  ↓
LLM 再决定是否读取完整文件、修改或运行测试
```

这里不建议每个代码问题都自动注入大量片段。应设置：

- 最大查询时间；
- 最大返回文件数；
- 最大上下文字符数；
- 低置信度时允许 AgentLoop 继续搜索；
- 高置信度且证据充分时停止预检。

`RAGIntentAnalyzer` 可以作为第一版低成本路由器，但应修复 substring 误判，并增加明确的 `false`、`lexicalOnly`、`semanticAndStructural` 等结果，而不是只返回 Boolean。

### Phase 5：让工具选择更稳定

有两种可选策略：

#### 策略 A：导航作为隐藏预检

AgentLoop 在第一次 LLM 请求前自动执行导航，不把 `CodeNavigationCoordinator` 暴露为模型工具。适合希望用户直接看到结果、减少模型试错的场景。

#### 策略 B：导航作为高优先级工具

保留 `search_code`，但重新描述工具用途，明确告诉模型：

- 代码问题优先调用它；
- 它返回的是候选文件，不是最终答案；
- 得到结果后应读取最相关文件；
- 不要在没有解释原因时重复同一查询。

长期建议采用 A+B：自动预检提供稳定起点，模型仍可以在发现新线索后继续主动查询。

## 6. 关键设计决策

### 决策 1：不删除 ProjectRAG，也不立即重做向量引擎

现有 RAG 已经解决了索引持久化、增量更新、本地 embedding 和语义候选检索。当前瓶颈主要在接入和编排，不是 sqlite-vec 本身。

### 决策 2：先做词法和符号层，再考虑更复杂的模型检索

Lumi 的任务大量涉及 Swift 类型名、Provider 名、插件 ID、UI 文案和错误文本。这些内容使用精确搜索和符号索引通常比再次增加 embedding 复杂度更可靠。

### 决策 3：旧索引可服务查询，后台更新不阻塞首个结果

查询路径和索引路径必须分开。已有索引即使过期，也应尽可能先服务查询，并在结果中标注索引状态。

### 决策 4：CodeNavigation 不直接拥有插件业务知识

它只依赖 `ProjectProviding`、`ProjectRAGProviding`、文件搜索和符号索引协议。具体插件仍通过自己的 provider 和工具提供能力，避免导航层硬编码插件关系。

### 决策 5：保持 AgentLoop、ToolManager 和 Renderer 的边界

AgentLoop 负责回合和 LLM 请求，ToolManager 负责工具注册、授权和执行，CodeNavigation 负责检索编排，Renderer 负责展示。导航结果通过临时上下文或明确事件传递，不把检索逻辑塞进工具授权或消息渲染代码。

## 7. 验收标准

### 功能验收

- 用户说“这个功能在哪里实现”时，默认触发代码导航。
- 用户说出中文 UI 文案、Swift 类型名、错误文本或插件名时，可以定位相关文件。
- RAG 尚未完成首次索引时，仍能通过词法搜索返回结果。
- 当前项目切换后，搜索不会继续使用旧项目的索引。
- 语义结果、精确命中和符号命中可以同时返回并去重。
- 定位结果包含相对路径和行号。
- 低置信度结果不会被当作确定结论。

### 性能验收

建议建立至少 20 个真实 Lumi 任务，记录改造前后：

| 指标 | 目标 |
|---|---:|
| 已有索引时首个导航结果 | < 500 ms |
| 词法搜索首个结果 | < 300 ms |
| 首次索引期间的查询阻塞 | 0 ms 等待完整索引 |
| 导航预检最大时间 | 3 s |
| 进入第一个相关文件前的无效工具调用 | ≤ 1 次 |
| 相同查询重复次数 | 0 次，除非索引状态变化 |
| 导航上下文大小 | ≤ 12,000 字符 |

### 正确性验收

每个任务应定义：

- 目标文件；
- 目标符号或关键文本；
- 相关调用方；
- 允许的候选文件范围；
- Agent 首次定位是否成功；
- 最终修改或解释是否使用了正确证据。

## 8. 推荐实施顺序

1. 增加导航和索引状态日志，建立基线。
2. 统一 `workspaceRoot`，修复 Shell 和文件工具的项目边界。
3. 把项目打开/切换事件接入 RAG 索引生命周期。
4. 修复 `RAGIntentAnalyzer`，接入一次性自动预检。
5. 增加结构化词法搜索，并作为无索引时的 fallback。
6. 将 RAG、词法和路径结果统一为 `CodeNavigationEvidence`。
7. 增加 Swift 符号和 Package 依赖检索。
8. 增加 AgentLoop 导航预算、停止条件和重复搜索检测。
9. 用真实 Lumi 任务做前后对比，再决定是否需要进一步调整 embedding 或索引结构。

## 9. 非目标

本方案不包含：

- 更换 LLM provider；
- 删除或重写现有 ProjectRAG SQLite schema；
- 把所有项目文件一次性注入 prompt；
- 让每个插件直接依赖其他插件的实现；
- 用向量检索替代编译器、SourceKit 或精确文本搜索；
- 在没有评测数据的情况下盲目增加并发索引线程。

## 10. 最终判断

Lumi 的 ProjectRAG 已经是有价值的基础设施，但目前处于“能力存在、入口暴露、决策未接管”的状态。Codex 体感更快，不是因为它单纯拥有一个更大的向量数据库，而是因为代码导航被放进了 coding agent 的默认执行协议中。

对 Lumi 来说，最高收益的改造是把现有 `search_code` 从普通 Agent 工具提升为 `CodeNavigationCoordinator` 的一个后端，并通过 AgentLoop 请求前预检、分层检索和结构化证据输出，让模型从第一轮就拿到正确的候选文件。
