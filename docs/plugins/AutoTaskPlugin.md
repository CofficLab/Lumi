# AutoTask Plugin Roadmap

## 1. 概述 (Overview)

### 1.1 背景
在开发大型项目或复杂功能时，LLM 往往缺乏**全局状态记忆**和**进度意识**。随着对话轮次增加，上下文窗口可能丢失最初的宏观指令，导致 Agent“迷失方向”，不知道任务进行到哪一步，或者遗漏了关键步骤。这正是之前用户反馈“开发聊天 App 总是停下来”的核心痛点。

### 1.2 目标
- **自动拆解**: 当用户提出复杂目标时，Agent 自动将其拆解为可执行的子任务列表。
- **状态追踪**: 实时记录和更新每个任务的完成状态（To Do / In Progress / Done）。
- **上下文增强**: 在每轮对话中，自动注入当前任务进度，保持 Agent 的全局视野。
- **自我驱动**: Agent 完成任务后自动勾选并触发下一环节，实现“长程自动驾驶”。

### 1.3 设计原则
- **零内核修改**: 纯插件实现，依赖 `SendMiddleware` + `AgentTool`。
- **轻量存储**: 任务数据存储在项目级 `.agent/tasks.md` 文件中，易于人工编辑和 Git 追踪。
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
  ┌─────────────────────┐       ┌──────────────────┐
  │  TaskStateManager    │──────►│  .agent/tasks.md  │
  │  (本地文件读写)       │◄──────┤  (结构化存储)     │
  └─────────┬───────────┘       └──────────────────┘
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
├── Services/
│   ├── TaskOrchestrator.swift               # 任务拆解与生成逻辑
│   └── TaskStateManager.swift               # 本地文件读写 (Actor)
├── Models/
│   └── TaskItem.swift                       # 任务数据结构
├── Middleware/
│   └── TaskContextMiddleware.swift          # 进度注入中间件 (Order: 70)
├── Tools/
│   ├── CreateTaskTool.swift                 # 创建任务
│   ├── UpdateTaskTool.swift                 # 更新状态
│   └── CheckProgressTool.swift              # 查询进度
└── Views/
    └── TaskStatusBarView.swift              # 状态栏入口
```

---

## 3. 详细设计 (Detailed Design)

### 3.1 任务数据模型 (`TaskItem`)

```swift
struct TaskItem: Codable {
    let id: String                  // 唯一标识 (如 UUID 或 Slug)
    let title: String               // 任务标题
    let description: String?        // 详细描述
    var status: TaskStatus
    var dependencies: [String]      // 前置任务 ID

    enum TaskStatus: String, Codable {
        case pending
        case inProgress
        case completed
        case skipped
    }
}
```

### 3.2 存储规范 (`.agent/tasks.md`)

采用 Markdown Checklist 格式，方便人类阅读和工具解析：

```markdown
# Project Tasks

- [x] **1. Environment Setup**
  - [x] Initialize Swift Package
  - [x] Configure Linting

- [ ] **2. Core Architecture** (Current Focus)
  - [x] Define MVVM Structure
  - [ ] Setup Dependency Injection

- [ ] **3. Feature Implementation**
  - [ ] User Authentication
  - [ ] Main Chat Interface
```

### 3.3 核心服务

#### A. 任务编排器 (`TaskOrchestrator`)
- **职责**: 当用户输入包含复杂意图（如“帮我做一个 xx”、“重构 yy”）时，调用 LLM 生成结构化任务列表。
- **触发**: 首次对话检测到新目标，或用户明确要求规划 (`/plan`)。

#### B. 状态管理器 (`TaskStateManager`)
- **职责**: 解析和更新 `.agent/tasks.md`。
- **同步机制**: 每次更新后立即落盘，防止状态丢失。

### 3.4 中间件 (`TaskContextMiddleware`)

- **Order**: `70` (位于 GitHubInsight(60) 之后，RAG(100) 之前)。
- **逻辑**:
  1. 读取 `.agent/tasks.md`。
  2. 提取 `Current Focus` (进行中) 和 `Pending` (待办) 任务。
  3. 注入 Prompt：
     ```markdown
     ## Project Task Progress
     Current Focus: Setup Dependency Injection
     Remaining:
     - Feature: User Auth
     - Feature: Main Chat
     
     Your goal is to complete the current focus before moving on.
     ```

### 3.5 状态栏 UI (`TaskStatusBarView`)

- **显示内容**:
  - **规划中**: `📋 Planning...`
  - **执行中**: `📋 3/12 Tasks (25%)`
  - **全部完成**: `✅ All Tasks Done`
- **点击交互**: 弹出 `.agent/tasks.md` 预览，允许用户手动修改任务（如增加/删除/调整顺序）。

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
Agent 调用 create_task 工具 (或由 Orchestrator 自动生成)
    │
    ▼
创建 .agent/tasks.md:
  - [ ] 1. Project Setup
  - [ ] 2. Data Model Design
  - ...
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
TaskStateManager 更新文件 -> 标记 [x] 1. Project Setup
    │
    ▼
中间件在下一轮注入新的进度 (Focus: 2. Data Model Design)
    │
    ▼
Agent 自动开始写 Data Model 代码
```

---

## 5. 实施计划 (Implementation Plan)

### Phase 1: 核心存储与模型
- [ ] 定义 `TaskItem` 结构体
- [ ] 实现 `TaskStateManager`: Markdown 解析与生成

### Phase 2: 任务规划与工具
- [ ] 实现 `CreateTaskTool` / `UpdateTaskTool`
- [ ] 让 Agent 能够自动拆分任务

### Phase 3: 中间件集成
- [ ] 实现 `TaskContextMiddleware` (Order: 70)
- [ ] 验证 Prompt 注入效果

### Phase 4: UI 与优化
- [ ] 实现 `TaskStatusBarView`
- [ ] 支持手动编辑任务文件
- [ ] 增加“跳过任务”、“重新规划”功能

---

## 6. 风险与应对

| 风险 | 应对策略 |
|------|----------|
| **任务文件冲突** | 采用追加写入或 Git 锁机制，避免多端同步覆盖 |
| **Agent 忘记更新** | 中间件在 Prompt 中增加提醒指令 ("记得在完成任务后调用 update_task") |
| **上下文过载** | 仅注入当前相关的 3-5 个任务，历史已完成任务折叠为摘要 |

---

此 Roadmap 定义了 **AutoTask Plugin** 的实现路径，旨在赋予 Lumi 长期记忆和自我驱动能力。