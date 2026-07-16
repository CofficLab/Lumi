# 记忆插件（MemoryPlugin）设计方案

> 参考 Claude Code 的 `memdir` 记忆系统，为 Lumi 设计一个基于插件的持久化记忆系统，让 Lumi 能跨会话记住用户偏好、项目上下文和反馈。

---

## 一、背景与动机

### 1.1 为什么要记忆？

Lumi 当前的 Agent 会话是无状态的——每次新会话，模型对用户的角色、偏好、过往决策一无所知。用户不得不反复告知：
- "我是做后端的，前端不熟"
- "用中文回复"
- "不要每次都总结 diff"

一个记忆系统可以让 Lumi 像一个真正了解用户的助手一样工作。

### 1.2 Claude Code 的做法（参考）

Claude Code 的 `memdir` 系统是一个精心设计的文件式记忆方案：

| 设计点 | Claude Code 实现 |
|--------|-----------------|
| **存储格式** | Markdown 文件 + YAML frontmatter，索引文件 `MEMORY.md` |
| **记忆类型** | 4 种：user / feedback / project / reference |
| **检索方式** | Sonnet side-query 从记忆清单中选出 top-5 |
| **时效感知** | 超过 1 天的记忆附加 "可能过时" 提醒 |
| **团队记忆** | 私有 + 团队两级作用域 |
| **注入时机** | 系统提示词 + 每轮对话的 transient prompt |

**核心哲学**：只记从代码/Git 推导不出来的信息。

### 1.3 Lumi 的差异

| 维度 | Claude Code | Lumi |
|------|-------------|------|
| 运行平台 | Node.js / CLI | macOS 原生 (Swift) |
| 架构 | 单体 | 插件化 |
| 记忆消费者 | 自身模型 | 外部 LLM（通过 system prompt 注入） |
| 检索模型 | 内置 Sonnet | 无内置模型，需调用外部 LLM 或用本地策略 |
| 团队协作 | 支持 | 暂不需要（单用户桌面应用） |

---

## 二、系统架构

### 2.1 整体架构图

```
┌──────────────────────────────────────────────────────┐
│                    MemoryPlugin                       │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │ MemoryStore  │  │ MemoryService│  │   Tools    │  │
│  │  (Plist)     │  │  (CRUD+检索) │  │ save/recall│  │
│  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘  │
│         │                 │                  │        │
│  ┌──────┴─────────────────┴──────────────────┴─────┐  │
│  │        MemorySendMiddleware (注入提示词)         │  │
│  └──────────────────────┬──────────────────────────┘  │
│                         │                             │
│  ┌──────────────────────┴──────────────────────────┐  │
│  │        Memory Files (~/.lumi/memory/)           │  │
│  │  MEMORY.md (索引) + *.md (记忆文件)              │  │
│  └─────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

### 2.2 数据流

```
用户发送消息
    │
    ▼
SendPipeline
    │
    ▼
MemorySendMiddleware
    │
    ├── 1. 读取当前项目记忆目录的 MEMORY.md
    ├── 2. 根据消息内容检索相关记忆（本地匹配）
    ├── 3. 将记忆注入 ctx.transientSystemPrompts
    │
    ▼
LLM 请求（system prompt 中包含记忆上下文）
    │
    ▼
LLM 响应
    │
    ▼
用户通过工具主动保存记忆（或未来自动提取）
```

---

## 三、记忆模型

### 3.1 四种记忆类型

与 Claude Code 保持一致的四类型体系，但针对 Lumi 的桌面场景做适度调整：

| 类型 | 用途 | 示例 |
|------|------|------|
| **user** | 用户角色、偏好、知识水平 | "用户是 10 年 Go 老手，React 新手" |
| **feedback** | 用户对 Lumi 行为的指导 | "不要每次回复都总结 diff" |
| **project** | 项目上下文（非代码可得） | "这个项目的 auth 重构是因为合规要求" |
| **reference** | 外部系统指针 | "bug 追踪在 Linear INGEST 项目" |

### 3.2 什么不该存

与 Claude Code 一致：
- ❌ 代码模式/架构 → 读代码即可
- ❌ Git 历史 → 用 `git log`
- ❌ `.agent/rules` 已有的内容
- ❌ 临时任务状态

### 3.3 存储格式

每条记忆一个 Markdown 文件，带 YAML frontmatter：

```markdown
---
name: user-role
description: 用户是后端工程师，擅长 Go，前端新手
type: user
created: 2025-06-01T10:00:00Z
updated: 2025-06-01T10:00:00Z
---

用户是后端工程师，有 10 年 Go 经验。
React 和 SwiftUI 是新领域，解释前端概念时建议用后端类比。
```

### 3.4 索引文件 MEMORY.md

```markdown
# Memory Index

- [user-role](user-role.md) — 后端工程师，擅长 Go，前端新手
- [feedback-no-summary](feedback-no-summary.md) — 不要每次回复都总结 diff
- [project-auth-compliance](project-auth-compliance.md) — auth 重构因合规要求
```

限制：最多 200 行 / 25KB，超出截断并附加警告。

---

## 四、目录结构

### 4.1 文件系统布局

```
~/Library/Application Support/com.coffic.Lumi/db_{debug|production}/
└── Memory/                          # 插件存储根目录
    ├── MemoryPluginLocalStore.swift  # 管理的配置
    │
    ├── global/                       # 全局记忆（跨项目）
    │   ├── MEMORY.md                 # 全局索引
    │   ├── user-role.md
    │   └── feedback-no-summary.md
    │
    └── projects/                     # 按项目的记忆
        ├── <sanitized-project-path>/
        │   ├── MEMORY.md
        │   ├── project-auth-compliance.md
        │   └── reference-linear-board.md
        └── <another-project>/
            ├── MEMORY.md
            └── ...
```

### 4.2 插件代码结构

遵循 [插件目录结构规范](./plugin-directory-rules.md)：

```
LumiApp/Plugins/MemoryPlugin/
├── MemoryPlugin.swift                # 插件主入口
├── Memory.xcstrings                  # 国际化
├── MemoryPluginLocalStore.swift      # 配置存储（启用/禁用开关等）
│
├── Middleware/
│   └── MemorySendMiddleware.swift    # 发送中间件：注入记忆提示词
│
├── Models/
│   ├── MemoryItem.swift              # 记忆数据模型
│   ├── MemoryType.swift              # 记忆类型枚举
│   └── MemoryIndex.swift             # 索引文件模型
│
├── Services/
│   ├── MemoryStorageService.swift    # 文件读写（CRUD）
│   └── MemoryRetrievalService.swift  # 记忆检索（关键词匹配）
│
└── Tools/
    ├── SaveMemoryTool.swift          # save_memory 工具
    ├── RecallMemoryTool.swift        # recall_memory 工具
    ├── ListMemoriesTool.swift        # list_memories 工具
    └── DeleteMemoryTool.swift        # delete_memory 工具
```

---

## 五、核心组件设计

### 5.1 Models

#### MemoryType

```swift
/// 记忆类型
enum MemoryType: String, Codable, CaseIterable {
    case user       // 用户角色、偏好
    case feedback   // 行为指导
    case project    // 项目上下文
    case reference  // 外部系统指针
}
```

#### MemoryItem

```swift
/// 记忆条目
struct MemoryItem: Codable, Identifiable {
    let id: String           // 文件名（不含 .md）
    let filename: String     // 含 .md
    let type: MemoryType
    let name: String         // frontmatter 中的 name
    let description: String  // frontmatter 中的 description
    let content: String      // 记忆正文
    let createdAt: Date
    let updatedAt: Date
    let filePath: String     // 绝对路径
}
```

### 5.2 MemoryStorageService

```swift
/// 记忆文件存储服务
///
/// 负责记忆文件的 CRUD 操作、索引维护和目录管理。
/// 遵循 [插件数据存储规范](./plugin-storage-rules.md)。
actor MemoryStorageService {
    static let shared = MemoryStorageService()

    // MARK: - 路径解析

    /// 全局记忆目录
    func globalMemoryDir() -> URL

    /// 项目记忆目录
    func projectMemoryDir(projectPath: String) -> URL

    // MARK: - CRUD

    /// 创建记忆（自动维护 MEMORY.md 索引）
    func createMemory(
        name: String,
        type: MemoryType,
        description: String,
        content: String,
        scope: MemoryScope  // .global 或 .project(projectPath)
    ) async throws -> MemoryItem

    /// 读取记忆
    func readMemory(id: String, scope: MemoryScope) async throws -> MemoryItem

    /// 更新记忆
    func updateMemory(id: String, content: String, scope: MemoryScope) async throws -> MemoryItem

    /// 删除记忆
    func deleteMemory(id: String, scope: MemoryScope) async throws

    /// 列出所有记忆
    func listMemories(scope: MemoryScope) async throws -> [MemoryItem]

    // MARK: - 索引

    /// 读取 MEMORY.md 索引内容
    func readIndex(scope: MemoryScope) async -> String

    /// 重建索引（遍历所有记忆文件，重写 MEMORY.md）
    func rebuildIndex(scope: MemoryScope) async throws
}
```

### 5.3 MemoryRetrievalService

**关键设计决策**：Lumi 是桌面应用，不能像 Claude Code 那样调用一个轻量 LLM 做 side-query。我们采用**本地策略**：

```swift
/// 记忆检索服务
///
/// 使用纯本地策略检索相关记忆，不依赖外部 LLM 调用。
actor MemoryRetrievalService {
    static let shared = MemoryRetrievalService()

    /// 检索与查询相关的记忆
    ///
    /// 策略：
    /// 1. 关键词匹配（从 description 和 content 中提取关键词）
    /// 2. 类型权重（feedback > user > project > reference）
    /// 3. 时效衰减（越新的记忆权重越高）
    /// 4. 返回 top-K（默认 5 条）
    func findRelevant(
        query: String,
        scope: MemoryScope,
        maxResults: Int = 5
    ) async -> [MemoryItem]
}
```

**检索策略详解**：

| 策略 | 说明 | 权重 |
|------|------|------|
| **关键词命中** | 将 query 分词，在 name/description/content 中匹配 | 40% |
| **类型偏好** | feedback 和 user 类型更可能通用 | 20% |
| **时效衰减** | 半衰期 30 天，越新越好 | 20% |
| **命中密度** | 单条记忆中被命中关键词的比例 | 20% |

> **未来扩展**：如果 Lumi 集成本地嵌入模型（如 `all-MiniLM-L6-v2`），可升级为语义检索。

### 5.4 MemorySendMiddleware

```swift
/// 记忆注入中间件
///
/// 在每次发送消息前：
/// 1. 加载当前项目的 MEMORY.md 索引（全量注入，作为常驻上下文）
/// 2. 根据用户消息检索相关记忆（选择性注入）
/// 3. 将记忆格式化为系统提示词
@MainActor
struct MemorySendMiddleware: SuperSendMiddleware {
    let id = "memory-injection"
    let order = 5  // 在 AgentContextSync 之后执行

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // 1. 确定项目路径
        let projectPath = ctx.projectVM.currentProjectPath
        guard !projectPath.isEmpty else {
            await next(ctx)
            return
        }

        // 2. 构建记忆提示词
        let prompt = await buildMemoryPrompt(
            projectPath: projectPath,
            userMessage: ctx.message.content
        )

        if !prompt.isEmpty {
            ctx.transientSystemPrompts.append(prompt)
        }

        await next(ctx)
    }
}
```

**注入的提示词格式**：

```
## 记忆系统

你有一个持久化的记忆系统。以下是相关的记忆记录：

### 全局记忆
- [user] user-role — 后端工程师，擅长 Go，前端新手
- [feedback] no-summary — 不要每次回复都总结 diff

### 项目记忆 (MyProject)
- [project] auth-compliance — auth 重构因合规要求，不是技术债

### 使用规则
- 记忆是时间点快照，可能已过时，遇到冲突以当前代码为准
- 如果用户让你记住什么，使用 save_memory 工具
- 如果用户让你忘记什么，使用 delete_memory 工具
```

### 5.5 Agent Tools

#### SaveMemoryTool

```swift
struct SaveMemoryTool: SuperAgentTool {
    let name = "save_memory"

    func description(for language: LanguagePreference) -> String {
        // "保存一条记忆到持久化记忆系统..."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        // name: String, type: "user|feedback|project|reference",
        // description: String, content: String, scope: "global|project"
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        // 1. 解析参数
        // 2. 调用 MemoryStorageService.createMemory()
        // 3. 返回确认信息
    }
}
```

#### RecallMemoryTool

```swift
struct RecallMemoryTool: SuperAgentTool {
    let name = "recall_memory"

    func description(for language: LanguagePreference) -> String {
        // "检索与查询相关的记忆..."
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        // 1. 解析 query 参数
        // 2. 调用 MemoryRetrievalService.findRelevant()
        // 3. 格式化返回结果（附带时效提醒）
    }
}
```

#### ListMemoriesTool / DeleteMemoryTool

标准 CRUD 工具，结构类似。

### 5.6 MemoryPlugin 主入口

> ⚠️ **2026-07 更新**：从这一版起，`LumiPlugin` 的 `category` / `policy` / `stage` / `iconName`
> 全部合并到 `LumiPluginInfo` 初始化参数里，不再单独写 `static let`。详见
> `LumiPlugin.swift` 与 `LumiPluginInfo.swift` 协议说明。

```swift
public enum MemoryPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.memory",
        displayName: LumiPluginLocalization.string("Memory", bundle: .module),
        description: LumiPluginLocalization.string("持久化记忆系统", bundle: .module),
        order: 15,                  // 在 AgentContextSync 之后
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "brain.head.profile"
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            SaveMemoryTool(),
            RecallMemoryTool(),
            ListMemoriesTool(),
            DeleteMemoryTool(),
        ]
    }

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [AnyLumiSendMiddleware(MemorySendMiddleware())]
    }
}
```

字段说明：
- `id` —— 唯一标识，bundle id 风格
- `displayName` / `description` —— 已本地化字符串
- `order` —— 排序权重，必须派生自 `Self.info.order`（参见「插件 UI 项 order 规范」）
- `category` —— 分类（agent / theme / development / ...）
- `policy` —— 启用策略（`.alwaysOn` / `.optIn` / `.optOut`）
- `stage` —— 开发阶段（dev / alpha / beta / stable / deprecated）
- `iconName` —— SF Symbols 名称

---

## 六、与现有系统的集成点

### 6.1 依赖关系

```
MemoryPlugin
    │
    ├── 实现 SuperPlugin 协议 ──── Core/Proto/SuperPlugin.swift
    ├── 实现 SuperSendMiddleware ── Core/Proto/SuperSendMiddleware.swift
    ├── 实现 SuperAgentTool ────── Packages/AgentToolKit
    ├── 使用 SendMessageContext ── Core/Context/SendMessageContext.swift
    │       └── ctx.projectVM.currentProjectPath  → 确定记忆作用域
    │       └── ctx.transientSystemPrompts        → 注入记忆提示词
    │
    └── 存储遵循规范 ──────────── .agent/rules/plugin-storage-rules.md
            └── AppConfig.getDBFolderURL() + "Memory/"
```

### 6.2 与 AgentContextSyncPlugin 的关系

| 维度 | AgentContextSync | MemoryPlugin |
|------|-----------------|--------------|
| 注入内容 | 当前项目路径、选中文件 | 历史记忆 |
| 数据来源 | 运行时状态 | 持久化文件 |
| order | 1 | 15 |
| 可配置 | 否 | 是 |

两者互补：ContextSync 提供 "现在在哪"，Memory 提供 "过去知道什么"。

### 6.3 与 AgentRulesPlugin 的关系

| 维度 | AgentRules | MemoryPlugin |
|------|-----------|--------------|
| 存储位置 | 项目内 `.agent/rules/` | 全局 `~/.lumi/memory/` + 项目级 |
| 内容性质 | 开发规范、约束 | 用户偏好、项目上下文 |
| 谁写 | 用户手动或 LLM 辅助 | LLM 自动 / 用户要求 |
| 生命周期 | 随项目（可 git 跟踪） | 跨项目持久 |

**不冲突**：Rules 是 "怎么做"，Memory 是 "记住什么"。

---

## 七、关键设计决策

### D1：为什么不用 SwiftData / SQLite？

| 选项 | 优点 | 缺点 |
|------|------|------|
| **Markdown 文件** ✅ | 人可读、可编辑、可 Git 跟踪、与 Claude Code 生态兼容 | 无结构化查询 |
| SwiftData | 结构化查询、索引 | 人不可读、需要迁移、与 Claude Code 方案不同 |

**选择 Markdown 文件**：因为记忆系统的核心价值在于**人可读和可审查**，用户可以直接用编辑器查看和修改记忆。这与 `.agent/rules` 使用 Markdown 的理念一致。

### D2：为什么不用 LLM 做检索？

Claude Code 用 Sonnet side-query 做记忆检索，但 Lumi 的场景不同：

| 因素 | Claude Code | Lumi |
|------|-------------|------|
| 记忆量级 | 可能很多（长期用户） | 初始阶段较少 |
| 调用成本 | 自有模型 | 额外 API 调用 |
| 延迟容忍 | 低（CLI） | 中（桌面 UI） |
| 本地计算 | Node.js | Swift 原生 |

**选择本地关键词匹配**：在记忆量级 < 200 条时，关键词匹配完全够用。未来如果需要语义检索，可集成轻量嵌入模型。

### D3：全局 vs 项目级记忆

```
global/     → user + feedback（跨项目通用）
projects/   → project + reference（项目专属）
```

**类型与作用域的对应关系**：

| 类型 | 默认作用域 | 原因 |
|------|-----------|------|
| user | 全局 | 用户身份不随项目变 |
| feedback | 全局 | 行为偏好通常跨项目 |
| project | 项目 | 项目上下文特定 |
| reference | 项目 | 外部系统指针通常项目相关 |

### D4：注入策略——全量索引 + 选择性详情

**不要把所有记忆内容都注入 system prompt**——会浪费 token。

```
MEMORY.md 索引（全量注入，很紧凑）
    ↓ 每条就一行
    "[user] user-role — 后端工程师，擅长 Go，前端新手"

+ 检索到的 top-5 记忆的完整内容（选择性注入）
    ↓ 包含 Why / How to apply
```

这与 Claude Code 的策略一致：索引常驻，详情按需加载。

### D5：中间件 order 选择

```
order  0  → AgentContextSync（项目上下文）
order  5  → Memory（记忆注入）       ← 我们
order 10  → ToolCallLoopDetection
order .. → 其他中间件
```

记忆注入在项目上下文之后、业务逻辑之前，确保模型已经知道 "在哪"，再告诉它 "记得什么"。

---

## 八、提示词设计

### 8.1 注入到 transientSystemPrompts 的模板

```swift
/// 记忆系统提示词模板
static func buildMemorySystemPrompt(
    indexContent: String,
    relevantMemories: [MemoryItem],
    language: LanguagePreference
) -> String {
    // 中文版
    """
    ## 记忆系统

    你有一个持久化的文件记忆系统。以下是当前加载的记忆：

    ### 记忆索引
    \(indexContent)

    \(relevantMemories.isEmpty ? "" : """
    ### 相关记忆（本次对话特别相关）
    \(relevantMemories.map { formatMemory($0) }.joined(separator: "\n\n"))
    """)

    ### 记忆使用规则
    - 记忆是时间点快照，不是实时状态。如果记忆与当前代码冲突，以代码为准。
    - 如果用户让你「记住」什么，使用 save_memory 工具保存。
    - 如果用户让你「忘记」什么，使用 delete_memory 工具删除。
    - 不要主动提及「根据记忆」——自然地运用即可。
    """
}
```

### 8.2 记忆工具的描述提示词

```swift
// save_memory 工具描述（中文）
"保存一条记忆到持久化记忆系统。记忆应该是非显而易见的、无法从代码或 Git 历史推导的信息。" +
"可用类型：user（用户偏好）、feedback（行为指导）、project（项目上下文）、reference（外部系统指针）。"

// recall_memory 工具描述（中文）
"检索与查询相关的记忆。当你需要回忆过往对话中讨论的内容时使用。"
```

---

## 九、实施计划

### Phase 1：最小可用版本（MVP）

**目标**：基本 CRUD + 中间件注入

| 步骤 | 内容 | 预估 |
|------|------|------|
| 1 | Models：MemoryType、MemoryItem | 0.5 天 |
| 2 | MemoryStorageService：文件 CRUD + 索引维护 | 1 天 |
| 3 | 4 个 Agent Tools | 1 天 |
| 4 | MemorySendMiddleware（全量索引注入） | 0.5 天 |
| 5 | MemoryPlugin 主入口 | 0.5 天 |
| 6 | 集成测试 | 0.5 天 |

**总计**：约 4 天

### Phase 2：智能检索

| 步骤 | 内容 |
|------|------|
| 1 | MemoryRetrievalService：关键词匹配 + 时效衰减 |
| 2 | 中间件升级：索引 + 选择性详情注入 |
| 3 | 配置 UI：启用/禁用开关 |

### Phase 3：增强

| 步骤 | 内容 |
|------|------|
| 1 | 自动记忆提取（类似 Claude Code 的 extractMemories） |
| 2 | 记忆去重与合并 |
| 3 | 记忆过期清理 |
| 4 | 可选：语义检索升级 |

---

## 十、风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| 记忆过多导致 token 浪费 | 增加延迟和成本 | 索引限制 200 行，详情限制 top-5 |
| 记忆过时导致错误建议 | 用户困惑 | 时效提醒，模型指示验证后再用 |
| 关键词检索不准 | 相关记忆未命中 | MVP 阶段可接受，后续升级语义检索 |
| 记忆文件损坏 | 记忆丢失 | 索引可从文件重建，单文件损坏不影响其他 |
| 与 AgentRules 内容重叠 | 冗余 | 在提示词中明确区分，工具说明中排除 rules 内容 |

---

## 附录 A：与 Claude Code memdir 的对照表

| 维度 | Claude Code | Lumi MemoryPlugin |
|------|-------------|-------------------|
| 语言 | TypeScript (Node.js) | Swift (macOS) |
| 存储路径 | `~/.claude/projects/<slug>/memory/` | `AppConfig.getDBFolderURL()/Memory/` |
| 索引文件 | MEMORY.md | MEMORY.md |
| 记忆格式 | Markdown + YAML frontmatter | Markdown + YAML frontmatter |
| 记忆类型 | user/feedback/project/reference | user/feedback/project/reference |
| 检索方式 | Sonnet side-query | 本地关键词匹配 |
| 注入方式 | system prompt + user context | transientSystemPrompts |
| 团队记忆 | 支持 | 暂不支持 |
| 自动提取 | 支持 (extractMemories) | Phase 3 |
| 时效感知 | 有 (memoryAge) | 有 (半衰期衰减) |
| 每日日志 | 有 (KAIROS mode) | 不需要 |

## 附录 B：文件命名规范

```
记忆文件名 = {type}-{short-name}.md

示例：
  user-role.md
  feedback-no-summary.md
  project-auth-compliance.md
  reference-linear-board.md
```

- 使用 kebab-case
- 以类型前缀开头，便于文件系统排序
- 长度限制：100 字符内
