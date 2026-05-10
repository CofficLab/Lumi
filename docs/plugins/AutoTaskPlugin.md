# AutoTask Plugin Roadmap

## 1. 概述 (Overview)

### 1.1 背景
在开发大型项目或复杂功能时，LLM 往往缺乏**全局状态记忆**和**进度意识**。随着对话轮次增加，上下文窗口可能丢失最初的宏观指令，导致 Agent"迷失方向"，不知道任务进行到哪一步，或者遗漏了关键步骤。这正是之前用户反馈"开发聊天 App 总是停下来"的核心痛点。

### 1.2 目标
- **自动拆解**: 当用户提出复杂目标时，Agent 自动将其拆解为可执行的子任务列表。
- **状态追踪**: 实时记录和更新每个任务的完成状态（To Do / In Progress / Done）。
- **上下文增强**: 在每轮对话中，自动注入当前任务进度，保持 Agent 的全局视野。
- **自我驱动**: Agent 完成任务后自动勾选并触发下一环节，实现"长程自动驾驶"。

### 1.3 设计原则
- **零内核修改**: 纯插件实现，依赖 `SendMiddleware` + `AgentTool`。
- **规范存储**: 遵循插件数据存储规范，任务数据使用 SwiftData 存储在插件专属目录 `AppConfig.getDBFolderURL()/AutoTaskPlugin/` 下。
- **无感运行**: 默认开启，对用户透明，不干扰正常对话流。

---

## 2. 架构设计 (Architecture)

### 2.1 核心组件关系图

```
用户请求 ("开发一个 App")
       │
       ▼
  ┌─────────────────────┐
  │   TaskOrchestrator   │  解析意图，生成/更新任务列表
  └─────────┬───────────┘
            │
            ▼
  ┌─────────────────────┐       ┌─────────────────────────────────┐
  │  TaskStateManager    │──────►│  AutoTaskPlugin/                 │
  │  (SwiftData 读写)    │◄──────┤    tasks.sqlite  (任务数据)      │
  └─────────┬───────────┘       └─────────────────────────────────┘
            │
      ┌─────┴──────┐
      ▼            ▼
┌───────────┐  ┌────────────────┐
│ Middleware │  │  TaskStatusBar │
│ (注入进度)  │  │  (当前任务展示)  │
└─────┬─────┘  └────────────────┘
      │
      ▼
  Agent 对话流
```

### 2.2 插件目录结构

```
LumiApp/Plugins/AutoTaskPlugin/
├── AutoTaskPlugin.swift                     # 插件入口
├── AutoTask.xcstrings                       # 本地化字符串
├── Services/
│   └── TaskStateManager.swift               # SwiftData 任务管理 (Actor)
├── Models/
│   └── TaskItem.swift                       # 任务数据结构 (@Model)
├── Middleware/
│   └── TaskContextMiddleware.swift           # 进度注入中间件 (Order: 70)
├── Tools/
│   ├── CreateTaskTool.swift                  # 创建任务
│   ├── UpdateTaskTool.swift                  # 更新状态
│   └── CheckProgressTool.swift              # 查询进度
└── Views/                                    # (Phase 4)
    └── TaskStatusBarView.swift              # 状态栏入口
```

---

## 3. 详细设计 (Detailed Design)

### 3.1 任务数据模型 (`TaskItem`)

```swift
import Foundation
import SwiftData

@Model
final class TaskItem: @unchecked Sendable {
    var id: String                  // 唯一标识 (UUID)
    var conversationId: String      // 所属会话 ID
    var title: String               // 任务标题
    var detail: String?             // 详细描述
    var status: TaskStatus          // 任务状态
    var order: Int                  // 排序序号
    var createdAt: TimeInterval     // 创建时间
    var updatedAt: TimeInterval     // 更新时间

    enum TaskStatus: String, Codable {
        case pending
        case inProgress
        case completed
        case skipped
    }
}
```

### 3.2 存储规范

遵循插件数据存储规范，所有数据存放在插件专属目录：

```
~/Library/Application Support/com.coffic.Lumi/db_{debug|production}/
└── AutoTaskPlugin/
    └── tasks.sqlite          # 任务数据 (SwiftData)
```

### 3.3 核心服务 — `TaskStateManager`

Actor 模式确保线程安全，封装 SwiftData `ModelContainer`/`ModelContext`，提供：

- `createTasks(conversationId:items:)` — 批量创建任务（先清空旧任务）
- `fetchTasks(conversationId:)` — 按序获取所有任务
- `updateTaskStatus(id:status:)` — 更新任务状态
- `getProgressSummary(conversationId:)` — 返回 `TaskProgressSummary`

### 3.4 中间件 — `TaskContextMiddleware`

- **Order**: `70`
- 每轮对话自动查询该会话的任务进度
- 无任务时不注入，不干扰正常对话
- 注入内容：当前焦点 + 待办列表 + 提醒指令

### 3.5 Agent Tools

| 工具 | 功能 | 风险等级 |
|------|------|---------|
| `create_task` | 批量创建任务（需要 `conversation_id` + `tasks` 数组） | Low |
| `update_task` | 更新任务状态（`in_progress` / `completed` / `skipped`） | Low |
| `check_progress` | 查询当前会话的任务列表和进度百分比 | Low |

---

## 4. 交互流程 (Interaction Flow)

### 4.1 任务生成

```
用户输入: "帮我开发一个基于 SwiftUI 的待办事项 App"
    │
    ▼
Agent 分析意图: 这是一个复杂目标，需要规划
    │
    ▼
Agent 调用 create_task 工具
    │
    ▼
TaskStateManager 写入任务到 SQLite 数据库:
    1. Project Setup
    2. Data Model Design
    ...
    │
    ▼
中间件注入进度 -> Agent 回复:
  "好的，我已经制定了 8 个步骤。现在开始第一步：Project Setup..."
```

### 4.2 自动推进

```
Agent 完成 Setup 代码
    │
    ▼
Agent 调用 update_task (id: "1", status: "completed")
    │
    ▼
TaskStateManager 更新数据库 -> 标记 1. Project Setup 为 completed
    │
    ▼
中间件在下一轮注入新的进度 (Focus: 2. Data Model Design)
    │
    ▼
Agent 自动开始写 Data Model 代码
```

---

## 5. 实施计划 (Implementation Plan)

### Phase 1: 核心存储与模型 ✅
- [x] 定义 `TaskItem` SwiftData 模型 (@Model)
- [x] 实现 `TaskStateManager`: SwiftData ModelContainer/ModelContext 封装 (Actor)

### Phase 2: 任务规划与工具 ✅
- [x] 实现 `CreateTaskTool` / `UpdateTaskTool` / `CheckProgressTool`
- [x] 让 Agent 能够自动拆分任务

### Phase 3: 中间件集成 ✅
- [x] 实现 `TaskContextMiddleware` (Order: 70)
- [x] 验证 Prompt 注入效果

### Phase 4: UI 与优化（待实现）
- [ ] 实现 `TaskStatusBarView`
- [ ] 支持手动编辑任务
- [ ] 增加"跳过任务"、"重新规划"功能

---

## 6. 风险与应对

| 风险 | 应对策略 |
|------|----------|
| **数据膨胀** | 设置 `maxTasksPerConversation` (50) 限制，批量创建时先清旧任务 |
| **Agent 忘记更新** | 中间件在 Prompt 中增加提醒指令 ("记得在完成任务后调用 update_task") |
| **上下文过载** | 仅注入当前相关的 3-5 个待办任务，已完成任务不重复注入 |

---

此 Roadmap 定义了 **AutoTask Plugin** 的实现路径，旨在赋予 Lumi 长期记忆和自我驱动能力。
