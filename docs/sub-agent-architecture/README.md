# 内核级子 Agent 架构

> 日期：2026-05-24
> 状态：设计阶段
> 涉及范围：Core + Plugins

## 背景与动机

### 问题

主 Agent 在执行复杂任务时需要调用多个工具（如 `git_status` → `git_diff` → `git_add` → `git_commit`），每次工具调用都会在对话上下文中增加至少 2 条消息（tool_call + tool_result）。这导致：

1. **上下文窗口膨胀**：10+ 条工具消息消耗大量 token，主 Agent 的可用上下文迅速减少
2. **请求成本增加**：每次 LLM 请求都要携带完整的工具历史，token 成本线性增长
3. **响应变慢**：长上下文导致 LLM 推理时间增加
4. **工具集过大**：主 Agent 拥有所有工具，容易误调用不相关工具

### 现状：MultiAgentPlugin

现有 `MultiAgentPlugin` 提供 `spawn_agent` + `collect_agents` 工具，允许主 Agent 运行时创建子 Agent：

```
主 Agent → spawn_agent(task: "分析代码", provider: "anthropic", model: "claude-sonnet")
         → 后台启动隔离 Agent Loop
         → collect_agents(agent_ids: "...") → 返回结果
```

**局限**：
- 子 Agent 使用所有全局工具（无隔离）
- 主 Agent 需手动指定 provider + model
- 主 Agent 需自行管理 agent_id
- 返回结果是 LLM 原始文本，无结构化摘要

### 目标

将子 Agent 能力从**插件工具**升级为**内核基础设施**：

| 维度 | 改进目标 |
|------|---------|
| 上下文 | 主 Agent 上下文只增加 2 条消息（spawn 请求 + 结果摘要），而非 10+ 条工具调用 |
| 工具隔离 | 每个子 Agent 只能使用其定义中声明的工具子集 |
| 易用性 | 主 Agent 只需指定子 Agent 类型（如 `type: "git.commit"`），无需配置 provider/model |
| 结果结构化 | 返回结构化摘要（commit hash、状态、耗时），而非原始文本 |
| 可扩展 | 任何插件可注册自己的子 Agent 类型 |

## 架构设计

### 分层

```
┌─────────────────────────────────────────────────────┐
│                    内核层 (Core)                     │
│                                                      │
│  1. SubAgentDefinition 协议（SuperPlugin 扩展）       │
│  2. SubAgentScheduler（内核调度器）                   │
│  3. 内核工具：spawn_subagent / collect_subagent       │
│  4. 消息管线：子Agent结果自动摘要化                    │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│                    插件层 (Plugins)                   │
│                                                      │
│  GitPlugin:                                          │
│    func subAgentDefinitions() → git_commit_agent     │
│                                                      │
│  TestPlugin:                                         │
│    func subAgentDefinitions() → test_runner_agent    │
│                                                      │
│  LintPlugin:                                         │
│    func subAgentDefinitions() → lint_check_agent     │
└─────────────────────────────────────────────────────┘
```

### 核心组件

#### 1. SubAgentDefinition 协议

插件注册子 Agent 类型的标准格式：

```swift
protocol SubAgentDefinitionProtocol: Sendable {
    /// 唯一标识，如 "git.commit"
    var id: String { get }
    
    /// 显示名称，如 "Git Commit Agent"
    var name: String { get }
    
    /// 任务描述（用于 tool schema 描述）
    var description: String { get }
    
    /// System Prompt（引导子 Agent 行为）
    var systemPrompt: String { get }
    
    /// 该子 Agent 可用的工具（按 name 过滤）
    var allowedToolNames: [String] { get }
    
    /// 最大 Agent Loop 轮次
    var maxTurns: Int { get }
    
    /// 结果摘要模板（定义如何结构化返回结果）
    var resultTemplate: SubAgentResultTemplate { get }
}
```

#### 2. SubAgentResultTemplate

定义子 Agent 完成后的结构化摘要格式：

```swift
struct SubAgentResultTemplate {
    /// 摘要字段列表
    let fields: [SubAgentResultField]
    
    /// 成功时的格式化模板
    let successFormat: String
    
    /// 失败时的格式化模板
    let failureFormat: String
}

enum SubAgentResultField: String {
    case commitHash
    case commitMessage
    case status
    case duration
    case output
    case error
}
```

#### 3. SuperPlugin 扩展

在 `SuperPlugin` 协议中新增 hook：

```swift
/// 插件提供的子 Agent 定义列表
/// 
/// 内核会聚合所有插件注册的子 Agent 定义，
/// 主 Agent 可通过 type 直接调用，无需指定 provider/model。
/// 返回空数组表示该插件不提供子 Agent。
@MainActor func subAgentDefinitions() -> [any SubAgentDefinitionProtocol]
```

#### 4. SubAgentScheduler（内核调度器）

```swift
actor SubAgentScheduler: SuperLog {
    static let shared = SubAgentScheduler()
    
    /// 所有插件注册的子 Agent 定义（id → definition）
    private var definitions: [String: any SubAgentDefinitionProtocol] = [:]
    
    /// 活跃的子 Agent 任务
    private var activeTasks: [String: SubAgentTask] = [:]
    
    /// 最大并发数
    private let maxConcurrency = 5
    
    // MARK: - Registration
    
    /// 启动时注册所有插件的子 Agent 定义
    func registerDefinitions(from plugins: [any SuperPlugin])
    
    // MARK: - Spawn & Collect
    
    /// 启动子 Agent
    /// - Parameters:
    ///   - type: 子 Agent 类型 ID（如 "git.commit"）
    ///   - additionalInstruction: 用户补充指令（可选）
    /// - Returns: 子 Agent 任务引用
    func spawn(type: String, additionalInstruction: String?) async throws -> SubAgentTask
    
    /// 等待子 Agent 完成并返回结构化结果
    func wait(for task: SubAgentTask, timeout: TimeInterval) async -> SubAgentResult
    
    // MARK: - Internal
    
    /// 执行 Agent Loop（隔离上下文 + 受限工具集）
    private func runLoop(
        definition: any SubAgentDefinitionProtocol,
        instruction: String,
        llmService: LLMService,
        toolService: ToolService
    ) async -> SubAgentResult
}
```

#### 5. 内核工具

**SpawnSubAgentTool**：

```swift
struct SpawnSubAgentTool: SuperAgentTool {
    let name = "spawn_subagent"
    
    // schema:
    //   type: string (必填) - 子 Agent 类型 ID
    //   instruction: string (选填) - 补充指令
}
```

**CollectSubAgentTool**：

```swift
struct CollectSubAgentTool: SuperAgentTool {
    let name = "collect_subagent"
    
    // schema:
    //   task_ids: string (必填) - 逗号分隔的任务 ID
    //   timeout: int (选填) - 超时秒数，默认 120
}
```

### 插件注册示例

```swift
// GitPlugin.swift
actor GitPlugin: SuperPlugin {
    
    @MainActor
    func subAgentDefinitions() -> [any SubAgentDefinitionProtocol] {
        let gitTools = self.agentTools(context: ToolContext(...))
        
        return [
            GitCommitSubAgentDefinition(gitTools: gitTools),
            GitPushSubAgentDefinition(gitTools: gitTools),
        ]
    }
}

struct GitCommitSubAgentDefinition: SubAgentDefinitionProtocol {
    let id = "git.commit"
    let name = "Git Commit Agent"
    let description = "分析工作区变更、生成提交信息、暂存并提交"
    
    let systemPrompt = """
        你是 Git 提交助手。严格按以下步骤执行：
        
        1. 调用 git_status 检查当前工作区状态
        2. 如果有变更，调用 git_diff 了解具体改动内容
        3. 根据改动内容生成 conventional commit 格式的提交信息
        4. 调用 git_add 暂存所有变更
        5. 调用 git_commit 创建提交
        6. 返回 commit hash 和提交信息
        
        如果工作区没有任何变更，直接返回 "No changes to commit."，不要执行后续步骤。
        如果任何步骤失败，返回错误信息，不要重试超过 2 次。
        """
    
    let allowedToolNames = ["git_status", "git_diff", "git_add", "git_commit"]
    let maxTurns = 5
    
    let resultTemplate = SubAgentResultTemplate(
        fields: [.commitHash, .commitMessage, .status, .duration],
        successFormat: """
            ✅ Git Commit Agent 完成
            - Commit: {{commit_hash}}
            - Message: {{commit_message}}
            - Duration: {{duration}}s
            """,
        failureFormat: """
            ❌ Git Commit Agent 失败
            - Error: {{error}}
            - Duration: {{duration}}s
            """
    )
}
```

## 数据流

```
┌──────────────────────────────────────────────────────────┐
│                    主 Agent 对话                          │
│                                                          │
│  User: "帮我提交当前变更"                                 │
│    ↓                                                     │
│  LLM 决定调用: spawn_subagent(type: "git.commit")         │
│    ↓                                                     │
│  SpawnSubAgentTool.execute():                             │
│    1. 查找 definition "git.commit"                        │
│    2. 将请求转发给 SubAgentScheduler                      │
└──────────────┬───────────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────────┐
│              SubAgentScheduler                            │
│                                                          │
│  1. 查找 GitCommitSubAgentDefinition                      │
│  2. 从全部工具中过滤出 allowedToolNames 的 4 个 Git 工具   │
│  3. 构建:                                                 │
│     - 隔离的 LLMService（使用默认 provider/model）         │
│     - 受限的 ToolService（只有 4 个工具）                  │
│     - 初始消息: [systemPrompt + additionalInstruction]    │
│  4. 启动后台 Task 执行 Agent Loop                          │
└──────────────┬───────────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────────┐
│              子 Agent（隔离上下文，主 Agent 不可见）        │
│                                                          │
│  System: "你是 Git 提交助手..."                            │
│  User:  "分析变更并创建提交"                               │
│    ↓                                                     │
│  LLM → tool_call: git_status → ✅ 有变更                  │
│  LLM → tool_call: git_diff   → ✅ 了解了内容              │
│  LLM → tool_call: git_add    → ✅ 已暂存                  │
│  LLM → tool_call: git_commit → ✅ abc1234                 │
│  LLM → 最终回复: "已成功提交 abc1234"                      │
└──────────────┬───────────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────────┐
│              SubAgentScheduler                            │
│                                                          │
│  1. 收集 LLM 最终回复                                     │
│  2. 根据 resultTemplate 提取结构化字段                     │
│  3. 返回 SubAgentResult                                  │
└──────────────┬───────────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────────┐
│                    主 Agent 对话                          │
│                                                          │
│  工具结果:                                               │
│  ✅ Git Commit Agent 完成                                │
│    - Commit: abc1234                                     │
│    - Message: fix: update layout panel visibility         │
│    - Duration: 3.2s                                      │
│    ↓                                                     │
│  LLM: "已完成提交，hash 是 abc1234"                       │
│                                                          │
│  ★ 主上下文只增加了 2 条消息（而非 10+ 条）                │
└──────────────────────────────────────────────────────────┘
```

## 优势总结

| 维度 | 改进 |
|------|------|
| **主上下文 token 消耗** | 减少 80%+（10 条工具调用 → 2 条摘要） |
| **安全性** | 子 Agent 只能用预定义的工具子集，不会误操作 |
| **可靠性** | 专属 system prompt 保证执行顺序和错误处理 |
| **易用性** | 主 Agent 只需知道类型名，不需要配置 provider/model |
| **可扩展** | 任何插件都可注册自己的子 Agent 类型 |
| **并发** | 多个子 Agent 可并行执行（如同时提交 + 运行测试） |

## 文件清单

### 新增文件

| 文件 | 说明 |
|------|------|
| `Core/Proto/SubAgentDefinition.swift` | 子 Agent 定义协议 + 结果模板 |
| `Core/Services/SubAgentScheduler.swift` | 内核调度器（注册、spawn、collect、Agent Loop） |
| `Core/Tools/SpawnSubAgentTool.swift` | 内核 spawn 工具 |
| `Core/Tools/CollectSubAgentTool.swift` | 内核 collect 工具 |
| `Core/Models/SubAgentTask.swift` | 子 Agent 任务模型 |
| `Core/Models/SubAgentResult.swift` | 子 Agent 结果模型 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `Core/Proto/SuperPlugin.swift` | 新增 `subAgentDefinitions()` hook |
| `Core/Bootstrap/RootContainer.swift` | 启动时注册子 Agent 定义到 SubAgentScheduler |
| `Core/Services/ToolService.swift` | 将内核工具注入到 Agent 管线 |
| `Plugins/GitPlugin/GitPlugin.swift` | 注册 `git.commit` 和 `git.push` 定义 |

## 实现阶段

### Phase 1: 内核基础设施

- [ ] 定义 `SubAgentDefinitionProtocol` 和 `SubAgentResultTemplate`
- [ ] 实现 `SubAgentScheduler`（注册、spawn、collect、Agent Loop）
- [ ] 实现 `SubAgentTask` 和 `SubAgentResult` 模型
- [ ] 在 `SuperPlugin` 中添加 `subAgentDefinitions()` hook

### Phase 2: 内核工具

- [ ] 实现 `SpawnSubAgentTool`
- [ ] 实现 `CollectSubAgentTool`
- [ ] 将工具注册到 Agent 管线（ToolService）

### Phase 3: 插件注册

- [ ] 在 `GitPlugin` 中注册 `git.commit` 定义
- [ ] 在 `GitPlugin` 中注册 `git.push` 定义
- [ ] 验证工具隔离（子 Agent 只能访问 Git 工具）

### Phase 4: 集成与测试

- [ ] 单元测试：SubAgentScheduler 注册/查找/并发限制
- [ ] 集成测试：spawn → run → collect 完整流程
- [ ] 👤 需要用户参与：在 Lumi 中实际触发 git.commit 子 Agent
- [ ] 👤 需要用户参与：验证主 Agent 上下文只增加 2 条消息

### Phase 5: 更多子 Agent 类型

- [ ] TestPlugin 注册 `test.runner` 定义
- [ ] LintPlugin 注册 `lint.check` 定义
- [ ] 支持子 Agent 链式调用（A 完成后触发 B）

## 与 MultiAgentPlugin 的关系

MultiAgentPlugin 是一个**普通插件**，提供 `spawn_agent` + `collect_agents` 工具，允许主 Agent 运行时自由创建子 Agent。

内核级子 Agent 是**基础设施**，插件预注册子 Agent 类型，主 Agent 按类型调用。

两者可以共存：
- **内核子 Agent**：用于预定义的、常见的任务模式（提交、测试、lint）
- **MultiAgentPlugin**：用于临时的、自定义的子 Agent 需求（"用 Claude 分析这段代码"）

## 后续思考

- 子 Agent 能否调用其他子 Agent？（嵌套）
- 子 Agent 结果能否作为主 Agent 上下文的一部分持久化？
- 是否支持子 Agent 的流式状态报告（进度更新）？
- 子 Agent 能否共享文件锁和上下文？
