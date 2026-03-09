# 多 Agent 协作系统架构设计文档

## 1. 概述

本文档描述了 Lumi 项目中多 Agent 协作系统（Multi-Agent Collaboration System）的架构设计和实现方案。

### 1.1 设计目标

- **用户感知单一 AI**：用户感觉只与一个 AI 对话，不感知后台有多个 Worker Agent
- **Manager 自动协调**：Manager Agent 自动分析需求、创建 Worker、分配任务、汇总结果
- **简单 UI 展示**：用户只看到 Manager 的汇总消息，Worker 执行过程在后台进行
- **Worker 互相独立**：Worker 之间不直接通信，都通过 Manager 协调

### 1.2 核心概念

| 概念 | 说明 |
|------|------|
| **Manager Agent** | AI 团队管理者，负责理解用户需求、创建 Worker、分配任务、汇总结果 |
| **Worker Agent** | 专属 AI 执行者，由 Manager 创建，负责执行具体任务 |
| **Worker Type** | Worker 预定义类型（代码专家、文档专家、测试专家、架构师） |
| **Task** | 由 Manager 分配给 Worker 的具体工作任务 |

---

## 2. 架构设计

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        用户界面层                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  用户："帮我分析这个项目，并写一份文档"                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Manager Agent (AI 管理者)                     │
│                                                                 │
│  System Prompt:                                                 │
│  "你是一个 AI 团队管理者，你有能力创建专属 Worker 来完成任务"     │
│                                                                 │
│  可用工具：                                                     │
│  - create_and_assign_task(worker_type, task) → result          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    Manager 调用工具
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  WorkerAgentManager (后台管理)                   │
│  1. 根据 worker_type 创建 Worker 实例                             │
│  2. 调用 WorkerAgentService 执行任务                             │
│  3. 等待 Worker 完成，返回结果                                   │
│  4. 任务完成后销毁 Worker（不保留）                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
          ┌─────────────────┴─────────────────┐
          ↓                                   ↓
┌─────────────────────┐           ┌─────────────────────┐
│   Worker Agent A    │           │   Worker Agent B    │
│   (代码专家)        │           │   (文档专家)        │
│   [后台执行]        │           │   [后台执行]        │
└─────────────────────┘           └─────────────────────┘
```

### 2.2 与现有架构的集成

```
现有架构：
AgentProvider → ConversationTurnViewModel → LLMService → Provider

集成后：
AgentProvider → ConversationTurnViewModel → LLMService → Provider
       ↓
       └→ WorkerAgentManager → WorkerAgentService → LLMService
              ↓
              └→ [WorkerAgent A, WorkerAgent B, ...]
```

---

## 3. 数据模型

### 3.1 WorkerAgentType（Worker 类型）

```swift
enum WorkerAgentType: String, Codable, Sendable, CaseIterable {
    /// 代码专家：擅长代码分析、修改、重构
    case codeExpert = "code_expert"

    /// 文档专家：擅长编写文档、注释
    case documentExpert = "document_expert"

    /// 测试专家：擅长编写测试、质量检查
    case testExpert = "test_expert"

    /// 架构师：擅长系统设计、代码审查
    case architect = "architect"
}
```

**各类型职责：**

| 类型 | 职责 | 典型任务 |
|------|------|----------|
| codeExpert | 代码分析、修改、重构、优化 | "分析这段代码的问题"、"帮我重构这个函数" |
| documentExpert | 编写技术文档、API 文档、注释 | "给这个项目写一份文档"、"整理 API 说明" |
| testExpert | 编写单元测试、质量检查 | "为这个模块写测试"、"检查代码质量" |
| architect | 系统设计、代码审查、架构优化 | "评审这个架构设计"、"提出优化建议" |

### 3.2 WorkerAgent 模型

```swift
struct WorkerAgent: Identifiable, Codable, Sendable, Equatable {
    /// Worker 唯一标识符
    let id: UUID

    /// Worker 名称（用户可见）
    var name: String

    /// Worker 类型
    var type: WorkerAgentType

    /// 角色描述
    var description: String

    /// 专长领域
    var specialty: String

    /// LLM 配置（可与 Manager 不同）
    var config: LLMConfig

    /// 当前状态
    var status: WorkerStatus

    /// 当前任务（如果有）
    var currentTask: Task?

    /// 独立的消息历史（用于与 Manager 的上下文隔离）
    var messageHistory: [ChatMessage]

    /// 系统提示词
    var systemPrompt: String

    /// 创建时间
    let createdAt: Date

    /// 最后活跃时间
    var lastActiveAt: Date
}
```

### 3.3 WorkerStatus（Worker 状态）

```swift
enum WorkerStatus: Codable, Sendable {
    /// 空闲，可接受新任务
    case idle

    /// 正在执行任务
    case working(taskId: UUID)

    /// 错误状态
    case error(message: String)
}
```

### 3.4 Task（任务模型）

```swift
struct Task: Identifiable, Codable, Sendable {
    /// 任务唯一标识符
    let id: UUID

    /// 任务描述
    var description: String

    /// 分配的 Worker ID
    var assignedTo: UUID?

    /// 任务状态
    var status: TaskStatus

    /// 执行结果
    var result: String?

    /// 创建时间
    let createdAt: Date

    /// 完成时间
    var completedAt: Date?
}

enum TaskStatus: Codable, Sendable {
    case pending
    case running
    case completed
    case failed
}
```

---

## 4. 核心组件

### 4.1 WorkerAgentManager

**职责：**
- 管理 Worker 的生命周期（创建、执行、销毁）
- 提供 `executeTask(type:task:)` 方法
- 维护 Worker 池（可选，当前设计为用完即销毁）

**API 设计：**

```swift
final class WorkerAgentManager: @unchecked Sendable {
    static let shared = WorkerAgentManager()

    /// 执行任务（创建 Worker → 执行 → 返回结果 → 销毁）
    func executeTask(
        type: WorkerAgentType,
        task: String,
        config: LLMConfig
    ) async throws -> String

    /// 获取 Worker 状态（如果需要查询）
    func getWorkerStatus(id: UUID) -> WorkerStatus?
}
```

**执行流程：**

```
executeTask(type: .codeExpert, task: "分析这段代码...")
         ↓
1. 创建 WorkerAgent
   - 设置 systemPrompt（根据 type）
   - 初始化 messageHistory
   - 配置 LLMConfig
         ↓
2. 调用 WorkerAgentService.execute(worker:task:)
         ↓
3. Worker 执行任务（内部可能有多个 LLM 调用 + 工具调用）
         ↓
4. 返回最终结果
         ↓
5. 销毁 Worker（当前设计不保留）
```

### 4.2 WorkerAgentService

**职责：**
- 与 Worker 进行 LLM 通信
- 处理 Worker 的多轮对话（包括工具调用）
- 返回 Worker 的最终执行结果

**API 设计：**

```swift
final class WorkerAgentService: @unchecked Sendable {
    /// 执行 Worker 任务
    func execute(
        worker: WorkerAgent,
        task: String
    ) async throws -> String
}
```

**执行逻辑：**

```swift
func execute(worker: WorkerAgent, task: String) async throws -> String {
    // 1. 初始化消息历史（包含系统提示词）
    var messages: [ChatMessage] = [
        ChatMessage(role: .system, content: worker.systemPrompt)
    ]

    // 2. 添加用户消息（任务）
    messages.append(ChatMessage(role: .user, content: task))

    // 3. 循环调用 LLM（支持多轮工具调用）
    var currentDepth = 0
    let maxDepth = 10  // 限制递归深度

    while currentDepth < maxDepth {
        // 调用 LLM
        let response = try await llmService.sendMessage(
            messages: messages,
            config: worker.config,
            tools: availableTools
        )

        // 添加到历史
        messages.append(response)

        // 检查是否有工具调用
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
            // 执行工具
            for toolCall in toolCalls {
                let result = try await toolExecutionService.executeTool(toolCall)
                messages.append(ChatMessage(
                    role: .user,
                    content: result,
                    toolCallID: toolCall.id
                ))
            }
            currentDepth += 1
            continue  // 继续下一轮
        }

        // 没有工具调用，返回最终结果
        return response.content
    }

    throw WorkerError.maxDepthReached
}
```

### 4.3 CreateAndAssignTaskTool

**职责：**
- Manager Agent 调用的工具
- 创建 Worker 并执行任务
- 返回 Worker 执行结果

**工具定义：**

```swift
struct CreateAndAssignTaskTool: AgentTool {
    let name = "create_and_assign_task"

    let description = """
    创建专属 Worker Agent 并分配任务。

    当你需要执行专业任务时调用此工具：
    - 代码分析、修改、重构 → code_expert
    - 编写文档、整理说明 → document_expert
    - 编写测试、质量检查 → test_expert
    - 系统设计、代码审查 → architect

    调用后，Worker 会执行任务并返回完整结果。
    你只需向用户汇总 Worker 的结果即可。
    """

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "workerType": [
                    "type": "string",
                    "enum": ["code_expert", "document_expert", "test_expert", "architect"],
                    "description": "Worker 类型，根据任务需求选择"
                ],
                "taskDescription": [
                    "type": "string",
                    "description": "要分配给 Worker 的具体任务描述"
                ],
                "context": [
                    "type": "string",
                    "description": "上下文信息（如项目路径、相关文件等，可选）"
                ]
            ],
            "required": ["workerType", "taskDescription"]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        // 解析参数
        guard let workerTypeRaw = arguments["workerType"]?.value as? String,
              let workerType = WorkerAgentType(rawValue: workerTypeRaw),
              let taskDescription = arguments["taskDescription"]?.value as? String
        else {
            throw ToolExecutionError.invalidArguments
        }

        let context = arguments["context"]?.value as? String

        // 构建完整任务描述
        let fullTask = context != nil
            ? "\(taskDescription)\n\n上下文：\(context!)"
            : taskDescription

        // 获取当前 LLM 配置（Worker 可使用相同配置）
        let config = LLMConfig.default  // 实际应从项目配置获取

        // 执行任务
        return try await WorkerAgentManager.shared.executeTask(
            type: workerType,
            task: fullTask,
            config: config
        )
    }
}
```

---

## 5. Manager Agent 系统提示词

### 5.1 完整提示词

```swift
let managerSystemPrompt = """
你是一个 AI 团队管理者（Manager Agent）。你有一个特殊能力：
可以根据任务需求，创建专属的 Worker Agent 来执行具体工作。

## 可用的 Worker 类型

1. **code_expert（代码专家）**
   - 专长：代码分析、修改、重构、性能优化
   - 典型任务：分析代码问题、重构函数、优化性能、解释代码

2. **document_expert（文档专家）**
   - 专长：技术文档编写、API 文档生成、代码注释
   - 典型任务：编写项目文档、整理 API 说明、生成注释

3. **test_expert（测试专家）**
   - 专长：单元测试编写、集成测试、质量检查
   - 典型任务：编写测试用例、检查代码质量、覆盖率分析

4. **architect（架构师）**
   - 专长：系统设计、代码审查、架构优化
   - 典型任务：评审架构设计、提出优化建议、技术选型

## 可用工具

你有一个工具：`create_and_assign_task`

调用方式：
```json
{
  "name": "create_and_assign_task",
  "arguments": {
    "workerType": "code_expert",
    "taskDescription": "分析以下代码的问题...",
    "context": "项目路径：/Users/xxx/project"
  }
}
```

## 工作流程

1. **理解用户需求** - 分析用户的请求，确定需要什么类型的帮助

2. **选择 Worker 类型** - 根据任务需求选择合适的 Worker 类型

3. **调用工具** - 使用 `create_and_assign_task` 创建 Worker 并分配任务

4. **等待结果** - 工具会返回 Worker 的执行结果

5. **汇总汇报** - 向用户展示 Worker 的结果，用清晰的方式组织信息

## 示例

### 示例 1：代码分析

用户："帮我分析这段代码有什么问题"

你：[调用 create_and_assign_task，workerType=code_expert]

工具返回：[代码分析结果]

你：

根据代码专家的分析，这段代码有以下问题：

1. **内存泄漏风险**：...
2. **性能问题**：...
3. **建议改进**：...

### 示例 2：多 Worker 协作

用户："帮我分析这个项目，并写一份文档"

你：我需要创建两个 Worker 来处理这个任务。

首先，我让代码专家分析项目结构。

[调用 create_and_assign_task，workerType=code_expert, task=分析项目结构]

[收到代码专家结果]

现在让文档专家编写文档。

[调用 create_and_assign_task，workerType=document_expert, task=编写项目文档]

[收到文档专家结果]

你：

我已完成项目分析和文档编写：

### 项目概述
...

### 核心模块
...

### 使用说明
...

## 注意事项

1. **Worker 执行是后台进行的** - 用户看不到 Worker 的执行过程，只看到你的汇总
2. **可以创建多个 Worker** - 复杂任务可以分解给多个 Worker
3. **结果需要汇总** - 不要直接把 Worker 的原始结果丢给用户，要整理后呈现
4. **选择合适的 Worker** - 根据任务类型选择最匹配的 Worker
"""
```

### 5.2 提示词设计要点

1. **明确 Worker 类型** - 清楚定义每种 Worker 的职责和适用场景
2. **提供调用示例** - 给出工具调用的 JSON 格式示例
3. **说明工作流程** - 让 Manager 知道如何分解任务
4. **给出对话示例** - 让 Manager 理解如何与用户交互
5. **强调注意事项** - 提醒 Manager 汇总结果，而不是直接转发

---

## 6. 用户交互流程

### 6.1 简单任务流程

```
用户："帮我分析这段代码的问题"
         ↓
Manager：好的，我来分析这段代码。
[调用 create_and_assign_task(workerType=code_expert, task=分析代码...)]
         ↓
[Worker 执行：代码分析，可能有工具调用]
         ↓
Manager：
根据代码专家的分析，这段代码有以下问题：

1. **内存泄漏风险**：...
2. **性能问题**：...
3. **建议改进**：...
```

### 6.2 复杂任务流程

```
用户："帮我分析这个项目，并写一份文档"
         ↓
Manager：好的，我来帮您分析项目并编写文档。
         ↓
[第一步：代码分析]
Manager：[调用 create_and_assign_task(workerType=code_expert, task=分析项目结构)]
[Worker A 执行]
         ↓
[第二步：文档编写]
Manager：[调用 create_and_assign_task(workerType=document_expert, task=编写项目文档)]
[Worker B 执行]
         ↓
Manager 汇总：

我已完成项目分析和文档编写：

### 项目概述
...

### 核心模块
...

### 使用说明
...
```

---

## 7. UI 设计

### 7.1 用户看到的效果

```
┌─────────────────────────────────────────────┐
│ 👤 用户：帮我分析这个项目，并写一份文档       │
├─────────────────────────────────────────────┤
│ 🤖 Manager: 好的，我来帮您分析项目并编写文档。│
│                                             │
│ [后台：Worker A 分析代码]                     │
│ [后台：Worker B 编写文档]                     │
│                                             │
│ 我已完成项目分析和文档编写：                 │
│                                             │
│ ## 项目概述                                 │
│ 这是一个 SwiftUI 应用，采用插件化架构...     │
│                                             │
│ ## 核心模块                                 │
│ 1. AgentProvider - 核心协调者               │
│ 2. WorkerAgentManager - Worker 管理          │
│ ...                                         │
└─────────────────────────────────────────────┘
```

### 7.2 可选增强（未来）

如果需要让用户感知 Worker 存在，可以：

1. **Worker 状态徽章** - 在 Manager 消息旁显示 Worker 图标
2. **来源标识** - Worker 消息显示 "来自代码专家"
3. **进度指示** - 显示 "Worker 正在执行..."

---

## 8. 实现步骤

### Phase 1: 基础框架

1. [ ] 创建 `WorkerAgentType.swift` - Worker 类型枚举
2. [ ] 创建 `WorkerAgent.swift` - Worker 模型
3. [ ] 创建 `WorkerStatus.swift` - Worker 状态
4. [ ] 创建 `Task.swift` - 任务模型
5. [ ] 创建 `WorkerAgentManager.swift` - Worker 管理器
6. [ ] 创建 `WorkerAgentService.swift` - Worker 执行服务

### Phase 2: 工具集成

7. [ ] 创建 `CreateAndAssignTaskTool.swift` - 核心工具
8. [ ] 注册工具到 `ToolService`
9. [ ] 更新 Manager Agent 系统提示词

### Phase 3: 测试验证

10. [ ] 测试单个 Worker 任务执行
11. [ ] 测试多 Worker 协作
12. [ ] 测试工具调用流程

### Phase 4: UI 增强（可选）

13. [ ] Worker 状态展示组件
14. [ ] Worker 消息来源标识
15. [ ] 任务进度指示器

---

## 9. 技术细节

### 9.1 Worker 上下文隔离

每个 Worker 有独立的消息历史：

```swift
// Worker 初始化
var messageHistory: [ChatMessage] = [
    ChatMessage(role: .system, content: worker.systemPrompt)
]

// 执行任务时，只操作自己的历史
messageHistory.append(userMessage)
let response = try await llmService.sendMessage(messages: messageHistory, ...)
messageHistory.append(response)
```

### 9.2 工具调用处理

Worker 可以调用工具（如读写文件、执行命令）：

```swift
// WorkerAgentService.execute 中的循环
while depth < maxDepth {
    let response = try await llmService.sendMessage(...)

    if let toolCalls = response.toolCalls {
        // 执行工具
        for toolCall in toolCalls {
            let result = try await toolExecutionService.executeTool(toolCall)
            messages.append(toolResultMessage)
        }
        depth += 1
        continue
    }

    return response.content  // 返回最终结果
}
```

### 9.3 Worker 生命周期

```
创建 → 执行 → 返回结果 → 销毁
      (后台)
```

当前设计：Worker 用完即销毁，不保留在池中

**优点：**
- 节省内存
- 避免状态污染
- 实现简单

**缺点：**
- 重复创建相同类型 Worker 无法利用之前上下文

**未来扩展：**
- 添加 Worker 池，支持复用
- 支持 Worker 上下文持久化

---

## 10. 与开源项目对比

| 特性 | AutoGen | CrewAI | LangGraph | 本方案 |
|------|---------|--------|-----------|--------|
| 管理者 | GroupChatManager | Crew Manager | Supervisor | Manager Agent (LLM) |
| Worker 定义 | ConversableAgent | role+goal+backstory | Graph Node | WorkerAgent struct |
| 通信方式 | 直接消息 | Manager 中转 | 状态图 | 工具调用 |
| Worker 生命周期 | 常驻 | 常驻 | 常驻 | 用完即销毁 |
| UI 展示 | 控制台 | 控制台 | 可视化图 | 聊天界面 |

**本方案特点：**
1. Manager 是 LLM Agent，自己决定如何分解任务
2. 工具调用作为通信方式，与现有 Tool 系统集成
3. Worker 动态创建销毁，节省资源
4. 聊天界面，用户只看到 Manager 汇总

---

## 11. 常见问题

### Q1: Worker 是否可以嵌套调用其他 Worker？

当前设计：不可以。Worker 只能调用工具，不能创建其他 Worker。

未来扩展：可以在 Worker 的系统提示词中添加此能力，但需要限制深度。

### Q2: Manager 如何知道 Worker 执行完成？

`create_and_assign_task` 工具是同步的，Worker 执行完成后返回结果，Manager 收到结果后继续。

### Q3: Worker 执行失败怎么办？

WorkerAgentService 应该捕获错误，返回错误信息给 Manager，由 Manager 决定如何处理（重试、换 Worker、告知用户）。

### Q4: 能否让用户看到 Worker 的执行过程？

可以。有两种方式：

1. **Manager 实时汇报** - Manager 在工具调用过程中输出 "正在创建 Worker..."、"Worker 正在执行..."
2. **UI 状态展示** - 添加 Worker 状态组件，显示当前活跃的 Worker

---

## 12. 参考项目

- [AutoGen (Microsoft)](https://github.com/microsoft/autogen) - 多 Agent 对话框架
- [CrewAI](https://github.com/joaomdmoura/crewai) - 角色扮演式 Agent 编排
- [LangGraph](https://github.com/langchain-ai/langgraph) - 基于图的 Agent 工作流

---

## 13. 变更历史

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2026-03-09 | v1.0 | 初始版本 |
