# 任务执行器插件实现方案

本文档描述了为 Lumi 项目开发任务执行器（Task Executor）插件的完整实现方案，该插件提供一个专为长时间运行任务设计的工具给内核，能够将复杂任务拆分为多个子任务并逐步执行。

## 目录

- [1. 需求分析](#1-需求分析)
- [2. 插件架构](#2-插件架构)
- [3. 目录结构](#3-目录结构)
- [4. 核心实现](#4-核心实现)
- [5. 工具定义](#5-工具定义)
- [6. 状态管理](#6-状态管理)
- [7. UI 设计](#7-ui-设计)
- [8. 实现步骤](#8-实现步骤)

---

## 1. 需求分析

### 1.1 功能需求

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 任务拆解 | 将复杂任务自动拆解为多个可执行的子任务 | P0 |
| 任务队列管理 | 维护任务队列，支持添加、暂停、恢复、取消 | P0 |
| 进度追踪 | 实时追踪每个子任务的执行进度 | P0 |
| 状态持久化 | 任务状态持久化，支持应用重启后恢复 | P1 |
| 并行执行 | 支持多个子任务并行执行（可配置） | P1 |
| 错误恢复 | 失败的子任务支持重试 | P1 |
| 结果聚合 | 聚合所有子任务的执行结果 | P0 |

### 1.2 用户场景

1. **批量处理文件**
   - 用户：「帮我把项目里所有的 `.jpg` 图片转换成 `.png` 格式」
   - Agent：调用 `task_executor` 工具
   - 拆解：扫描文件 → 生成转换任务队列 → 逐个转换 → 汇总结果

2. **大型代码重构**
   - 用户：「把所有使用 `oldMethod` 的地方改成 `newMethod`」
   - Agent：调用 `task_executor` 工具
   - 拆解：全局搜索 → 生成修改列表 → 逐文件修改 → 验证修改

3. **数据导入导出**
   - 用户：「导出数据库中所有用户数据到 CSV」
   - Agent：调用 `task_executor` 工具
   - 拆解：分页查询 → 逐批导出 → 合并文件 → 完成通知

### 1.3 非功能需求

| 需求 | 描述 |
|------|------|
| 长时间运行 | 支持分钟级甚至小时级的任务执行 |
| 内存效率 | 流式处理，避免大量数据一次性加载到内存 |
| 取消安全 | 随时可以取消任务，不会导致数据不一致 |
| 进度可见 | 用户始终能看到当前执行进度 |
| 资源控制 | 可配置 CPU、内存、网络资源使用限制 |

---

## 2. 插件架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      PluginProvider                          │
│                  (插件生命周期管理)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  TaskExecutorPlugin                          │
│                   (任务执行器插件)                            │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ TaskExecutor │  │ TaskSplitter │  │ TaskScheduler│      │
│  │   (工具)     │  │  (任务拆解)   │  │  (任务调度)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ TaskQueue    │  │ TaskProgress │  │ TaskResult   │      │
│  │  (任务队列)   │  │  (进度追踪)   │  │  (结果聚合)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Worker Agent                              │
│              (可选：专用任务执行 Worker)                       │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心协议

#### Task 协议

```swift
/// 任务协议
///
/// 所有可执行的任务必须遵循此协议
protocol Task: Identifiable, Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    associatedtype Progress: TaskProgress

    /// 任务唯一标识符
    var id: String { get }

    /// 任务名称（用于 UI 显示）
    var name: String { get }

    /// 任务描述
    var description: String { get }

    /// 任务输入
    var input: Input { get set }

    /// 任务状态
    var status: TaskStatus { get set }

    /// 任务进度
    var progress: Progress { get set }

    /// 创建时间
    var createdAt: Date { get }

    /// 开始执行时间
    var startedAt: Date? { get set }

    /// 完成时间
    var completedAt: Date? { get set }

    /// 执行任务
    /// - Returns: 任务输出结果
    func execute() async throws -> Output

    /// 取消任务
    func cancel() async

    /// 重试任务
    func retry() async
}
```

#### TaskStatus 枚举

```swift
/// 任务状态
enum TaskStatus: Sendable {
    case pending              // 等待执行
    case running              // 正在执行
    case paused               // 已暂停
    case completed            // 已完成
    case failed(Error)        // 执行失败
    case cancelled            // 已取消
}
```

#### TaskProgress 协议

```swift
/// 任务进度协议
protocol TaskProgress: Sendable {
    /// 当前进度值 (0.0 - 1.0)
    var fractionCompleted: Double { get }

    /// 已完成的工作单元数量
    var completedUnitCount: Int64 { get }

    /// 总工作单元数量
    var totalUnitCount: Int64 { get }

    /// 进度描述（用于 UI 显示）
    var localizedDescription: String { get }
}
```

### 2.3 任务拆解器（TaskSplitter）

```swift
/// 任务拆解器
///
/// 负责将复杂任务拆解为多个可执行的子任务
actor TaskSplitter {

    /// 拆解任务
    /// - Parameters:
    ///   - taskDescription: 任务描述
    ///   - context: 执行上下文
    /// - Returns: 子任务列表
    func split(
        taskDescription: String,
        context: TaskContext
    ) async throws -> [any Task]
}
```

### 2.4 任务调度器（TaskScheduler）

```swift
/// 任务调度器
///
/// 负责任务的调度、并发控制、资源管理
actor TaskScheduler {

    /// 最大并发任务数
    var maxConcurrentTasks: Int

    /// 添加任务到队列
    func enqueue(_ task: any Task) async

    /// 暂停所有任务
    func pauseAll() async

    /// 恢复所有任务
    func resumeAll() async

    /// 取消所有任务
    func cancelAll() async

    /// 获取所有任务状态
    func getAllTasks() async -> [any Task]
}
```

---

## 3. 目录结构

```
LumiApp/Plugins/TaskExecutorPlugin/
├── TaskExecutorPlugin.swift         # 插件主类
├── Core/
│   ├── Task.swift                   # 任务协议与基础实现
│   ├── TaskStatus.swift             # 任务状态定义
│   ├── TaskProgress.swift           # 任务进度协议
│   ├── TaskContext.swift            # 任务执行上下文
│   └── TaskResult.swift             # 任务结果封装
├── Splitter/
│   ├── TaskSplitter.swift           # 任务拆解器
│   └── Strategies/
│       ├── SequentialSplitStrategy.swift   # 顺序执行策略
│       ├── ParallelSplitStrategy.swift     # 并行执行策略
│       └── BatchSplitStrategy.swift        # 批量执行策略
├── Scheduler/
│   ├── TaskScheduler.swift          # 任务调度器
│   ├── TaskQueue.swift              # 任务队列
│   └── TaskPriority.swift           # 任务优先级
├── Services/
│   ├── TaskExecutorService.swift    # 任务执行服务
│   ├── TaskProgressService.swift    # 进度追踪服务
│   └── TaskPersistenceService.swift # 状态持久化服务
├── Models/
│   ├── TaskItem.swift               # 任务项模型
│   └── TaskHistory.swift            # 任务历史记录
├── Tools/
│   └── TaskExecutorTool.swift       # Agent 工具实现
├── Views/
│   ├── TaskExecutorSettingsView.swift    # 设置界面
│   ├── TaskListView.swift                # 任务列表视图
│   ├── TaskProgressView.swift            # 进度视图
│   └── TaskDetailView.swift              # 任务详情视图
└── Resources/
    └── Icons.swift                  # 图标资源
```

---

## 4. 核心实现

### 4.1 插件主类

**文件**: `TaskExecutorPlugin.swift`

```swift
import Foundation
import MagicKit

/// 任务执行器插件
///
/// 提供长时间运行任务的执行能力，支持任务拆解、进度追踪、状态持久化。
actor TaskExecutorPlugin: SuperPlugin {
    // MARK: - Plugin Properties

    static let id: String = "TaskExecutor"
    static let displayName: String = "任务执行器"
    static let description: String = "提供长时间运行任务的执行能力，支持任务拆解、进度追踪和状态管理。"
    static let iconName: String = "list.bullet.clipboard"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var order: Int { 20 }

    static let shared = TaskExecutorPlugin()

    // MARK: - Dependencies

    private let scheduler: TaskScheduler
    private let splitter: TaskSplitter
    private let persistenceService: TaskPersistenceService

    // MARK: - Initialization

    init() {
        self.scheduler = TaskScheduler.shared
        self.splitter = TaskSplitter.shared
        self.persistenceService = TaskPersistenceService.shared
        super.init()
    }

    // MARK: - Agent Tool Factories

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(TaskExecutorToolFactory())]
    }

    // MARK: - Tool Presentation Descriptors

    @MainActor
    func toolPresentationDescriptors() -> [ToolPresentationDescriptor] {
        [
            .init(
                toolName: "task_executor",
                displayName: "任务执行器",
                emoji: "📋",
                category: .custom,
                order: 0
            )
        ]
    }

    // MARK: - Worker Agent Descriptors

    @MainActor
    func workerAgentDescriptors() -> [WorkerAgentDescriptor] {
        [
            .init(
                id: "task_worker",
                displayName: "任务执行专家",
                roleDescription: "专门处理需要长时间执行的复杂任务，包括批量处理、数据转换等。",
                specialty: "长时间任务、批量处理、进度追踪",
                systemPrompt: """
                你是一个任务执行专家，擅长将复杂任务拆解为多个可管理的子任务。

                执行原则：
                1. 始终将大任务拆解为小步骤
                2. 每一步都应该是可验证的
                3. 保持进度透明，让用户知道当前状态
                4. 错误时提供清晰的恢复建议

                可用工具：
                - task_executor: 执行拆解后的子任务
                """,
                order: 0
            )
        ]
    }
}
```

### 4.2 任务定义

**文件**: `Task.swift`

```swift
import Foundation
import OSLog

/// 任务唯一标识符生成器
struct TaskID {
    static func generate() -> String {
        let prefix = "task"
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        return "\(prefix)_\(timestamp)_\(uuid)"
    }
}

/// 任务执行上下文
struct TaskContext: Sendable {
    /// 任务组 ID（相关任务共享同一个组 ID）
    let groupId: String

    /// 父任务 ID
    let parentTaskId: String?

    /// 执行参数
    let parameters: [String: Any]

    /// 取消令牌
    let cancellationToken: CancellationToken

    /// 进度报告器
    let progressReporter: ProgressReporter

    init(
        groupId: String = UUID().uuidString,
        parentTaskId: String? = nil,
        parameters: [String: Any] = [:],
        cancellationToken: CancellationToken,
        progressReporter: ProgressReporter
    ) {
        self.groupId = groupId
        self.parentTaskId = parentTaskId
        self.parameters = parameters
        self.cancellationToken = cancellationToken
        self.progressReporter = progressReporter
    }
}

/// 基础任务实现
class BaseTask<Input: Sendable, Output: Sendable>: Task {
    let id: String
    let name: String
    let description: String
    var input: Input
    var status: TaskStatus = .pending
    var progress: DefaultTaskProgress = DefaultTaskProgress()
    let createdAt: Date = Date()
    var startedAt: Date?
    var completedAt: Date?

    /// 重试次数
    var retryCount: Int = 0

    /// 最大重试次数
    var maxRetryCount: Int = 3

    /// 执行闭包
    let executeBlock: (Input, TaskContext) async throws -> Output

    init(
        id: String = TaskID.generate(),
        name: String,
        description: String,
        input: Input,
        executeBlock: @escaping (Input, TaskContext) async throws -> Output
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.input = input
        self.executeBlock = executeBlock
    }

    func execute() async throws -> Output {
        status = .running
        startedAt = Date()

        // 创建执行上下文
        let context = TaskContext(
            cancellationToken: CancellationToken(),
            progressReporter: ProgressReporter { [weak self] progress in
                self?.progress = progress
            }
        )

        do {
            let result = try await executeBlock(input, context)
            status = .completed
            completedAt = Date()
            return result
        } catch {
            if retryCount < maxRetryCount {
                retryCount += 1
                status = .pending
                return try await execute()
            } else {
                status = .failed(error)
                completedAt = Date()
                throw error
            }
        }
    }

    func cancel() async {
        status = .cancelled
        completedAt = Date()
    }

    func retry() async {
        guard case .failed = status else { return }
        retryCount = 0
        status = .pending
    }
}

/// 默认任务进度实现
struct DefaultTaskProgress: TaskProgress {
    var fractionCompleted: Double {
        guard totalUnitCount > 0 else { return 0 }
        return Double(completedUnitCount) / Double(totalUnitCount)
    }

    var completedUnitCount: Int64 = 0
    var totalUnitCount: Int64 = 1
    var localizedDescription: String = "正在执行..."
}
```

### 4.3 任务拆分器

**文件**: `TaskSplitter.swift`

```swift
import Foundation
import MagicKit

/// 任务拆分器
///
/// 负责分析任务描述，将其拆解为多个可执行的子任务
actor TaskSplitter: SuperLog {
    nonisolated static let emoji = "🔪"
    nonisolated static let verbose = true

    static let shared = TaskSplitter()

    private let llmService: LLMService

    init(llmService: LLMService = .shared) {
        self.llmService = llmService
    }

    /// 拆解任务
    /// - Parameters:
    ///   - taskDescription: 任务描述
    ///   - context: 执行上下文
    /// - Returns: 子任务列表
    func split(
        taskDescription: String,
        context: TaskSplitContext
    ) async throws -> [TaskDefinition] {
        os_log("\(Self.t)开始拆解任务：\(taskDescription)")

        // 使用 LLM 分析任务并生成拆解计划
        let prompt = buildSplitPrompt(
            taskDescription: taskDescription,
            context: context
        )

        let response = try await llmService.generate(
            prompt: prompt,
            systemPrompt: TaskSplitPrompt.systemPrompt
        )

        // 解析 LLM 响应，生成任务定义
        let tasks = try parseTaskDefinitions(from: response)

        if Self.verbose {
            os_log("\(Self.t)拆解完成，生成 \(tasks.count) 个子任务")
        }

        return tasks
    }

    /// 构建拆分提示
    private func buildSplitPrompt(
        taskDescription: String,
        context: TaskSplitContext
    ) -> String {
        """
        请将以下任务拆解为多个可独立执行的子任务：

        任务描述：\(taskDescription)

        可用工具：\(context.availableTools.joined(separator: ", "))
        资源限制：最大并发 \(context.maxConcurrentTasks) 个任务

        请返回 JSON 格式的任务列表：
        {
            "tasks": [
                {
                    "id": "step_1",
                    "name": "步骤 1 名称",
                    "description": "步骤 1 描述",
                    "tool": "使用的工具名称",
                    "input": {},
                    "dependencies": []
                }
            ]
        }
        """
    }

    /// 解析任务定义
    private func parseTaskDefinitions(from response: String) throws -> [TaskDefinition] {
        // 解析 JSON 响应
        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskSplitResult.self, from: Data(response.utf8))
        return result.tasks
    }
}

/// 任务拆分上下文
struct TaskSplitContext: Sendable {
    let availableTools: [String]
    let maxConcurrentTasks: Int
    let estimatedTimeLimit: TimeInterval?
}

/// 任务定义
struct TaskDefinition: Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let tool: String
    let input: [String: AnyCodable]
    let dependencies: [String]
    let estimatedDuration: TimeInterval?
}

/// 任务拆分结果
struct TaskSplitResult: Codable {
    let tasks: [TaskDefinition]
    let estimatedTotalDuration: TimeInterval?
}
```

### 4.4 任务调度器

**文件**: `TaskScheduler.swift`

```swift
import Foundation
import OSLog
import MagicKit

/// 任务调度器
///
/// 负责任务的调度、并发控制、资源管理
actor TaskScheduler: SuperLog {
    nonisolated static let emoji = "📅"
    nonisolated static let verbose = true

    static let shared = TaskScheduler()

    /// 最大并发任务数
    var maxConcurrentTasks: Int = 3

    /// 任务队列
    private var taskQueue: [TaskItem] = []

    /// 正在执行的任务
    private var runningTasks: [String: TaskItem] = [:]

    /// 已完成的任务
    private var completedTasks: [String: TaskItem] = [:]

    /// 当前任务组
    private var currentGroup: TaskGroup?

    /// 调度状态
    private var isPaused: Bool = false

    /// 调度器状态机
    private let stateMachine = TaskSchedulerStateMachine()

    private init() {}

    // MARK: - Public Methods

    /// 添加任务到队列
    func enqueue(_ task: TaskItem) async {
        if Self.verbose {
            os_log("\(Self.t)添加任务到队列：\(task.name)")
        }

        taskQueue.append(task)
        await scheduleNext()
    }

    /// 添加任务组
    func enqueueGroup(_ tasks: [TaskItem]) async {
        let groupId = UUID().uuidString
        currentGroup = TaskGroup(id: groupId, taskCount: tasks.count)

        for task in tasks {
            task.groupId = groupId
            await enqueue(task)
        }
    }

    /// 暂停所有任务
    func pauseAll() async {
        isPaused = true
        for task in runningTasks.values {
            await task.pause()
        }
    }

    /// 恢复所有任务
    func resumeAll() async {
        isPaused = false
        await scheduleNext()
    }

    /// 取消所有任务
    func cancelAll() async {
        for task in runningTasks.values {
            await task.cancel()
        }
        taskQueue.removeAll()
        runningTasks.removeAll()
    }

    /// 获取所有任务状态
    func getAllTasks() async -> [TaskItem] {
        return taskQueue + Array(runningTasks.values) + Array(completedTasks.values)
    }

    /// 获取任务进度
    func getProgress() async -> TaskGroupProgress {
        let allTasks = await getAllTasks()
        let total = allTasks.count
        let completed = allTasks.filter { $0.status == .completed }.count
        let failed = allTasks.filter { case .failed = $0.status }.count

        return TaskGroupProgress(
            total: total,
            completed: completed,
            failed: failed,
            running: runningTasks.count,
            pending: taskQueue.count
        )
    }

    // MARK: - Private Methods

    /// 调度下一个任务
    private func scheduleNext() async {
        guard !isPaused else { return }

        while runningTasks.count < maxConcurrentTasks, let nextTask = taskQueue.first {
            guard stateMachine.canStart(task: nextTask) else {
                break
            }

            taskQueue.removeFirst()
            await executeTask(nextTask)
        }
    }

    /// 执行任务
    private func executeTask(_ task: TaskItem) async {
        if Self.verbose {
            os_log("\(Self.t)开始执行任务：\(task.name)")
        }

        runningTasks[task.id] = task

        Task {
            do {
                let result = try await task.execute()
                await self.handleTaskCompleted(taskId: task.id, result: result)
            } catch {
                await self.handleTaskFailed(taskId: task.id, error: error)
            }
        }
    }

    private func handleTaskCompleted(taskId: String, result: Any) async {
        if let completedTask = runningTasks.removeValue(forKey: taskId) {
            completedTasks[taskId] = completedTask
            if Self.verbose {
                os_log("\(Self.t)任务完成：\(completedTask.name)")
            }
        }
        await scheduleNext()
    }

    private func handleTaskFailed(taskId: String, error: Error) async {
        if let failedTask = runningTasks.removeValue(forKey: taskId) {
            failedTask.status = .failed(error)
            completedTasks[taskId] = failedTask
            os_log(.error, "\(Self.t)任务失败：\(failedTask.name), 错误：\(error)")
        }
        await scheduleNext()
    }
}
```

### 4.5 任务持久化服务

**文件**: `TaskPersistenceService.swift`

```swift
import Foundation
import OSLog
import MagicKit

/// 任务持久化服务
///
/// 负责任务状态的持久化和恢复
class TaskPersistenceService: SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = true

    static let shared = TaskPersistenceService()

    private let fileManager: FileManager
    private let persistenceDirectory: URL

    private init() {
        self.fileManager = FileManager.default

        // 获取应用支持目录
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        self.persistenceDirectory = appSupport
            .appendingPathComponent("TaskExecutor", isDirectory: true)

        // 确保持化目录存在
        try? fileManager.createDirectory(
            at: persistenceDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public Methods

    /// 保存任务状态
    func saveTask(_ task: TaskItem) async throws {
        let fileURL = persistenceDirectory.appendingPathComponent("\(task.id).json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(TaskSnapshot(task: task))

        try data.write(to: fileURL)

        if Self.verbose {
            os_log("\(Self.t)保存任务状态：\(task.id)")
        }
    }

    /// 加载所有待执行任务
    func loadPendingTasks() async throws -> [TaskItem] {
        let files = try fileManager.contentsOfDirectory(
            at: persistenceDirectory,
            includingPropertiesForKeys: nil
        )

        var tasks: [TaskItem] = []

        for fileURL in files where fileURL.pathExtension == "json" {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(TaskSnapshot.self, from: data)

            // 只加载待执行或执行中的任务
            if snapshot.status == .pending || snapshot.status == .running {
                tasks.append(snapshot.toTaskItem())
            }
        }

        return tasks
    }

    /// 删除已完成的任务记录
    func cleanupCompletedTasks(olderThan age: TimeInterval = 86400 * 7) async throws {
        let files = try fileManager.contentsOfDirectory(
            at: persistenceDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )

        let now = Date()

        for fileURL in files where fileURL.pathExtension == "json" {
            let resources = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            if let modifiedDate = resources.contentModificationDate,
               now.timeIntervalSince(modifiedDate) > age {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
}

/// 任务快照（用于持久化）
struct TaskSnapshot: Codable {
    let id: String
    let groupId: String?
    let name: String
    let description: String
    let status: TaskStatus
    let progress: Double
    let createdAt: Date
    let startedAt: Date?
    let completedAt: Date?
    let inputData: Data?
    let resultData: Data?
    let errorMessage: String?

    init(task: TaskItem) {
        self.id = task.id
        self.groupId = task.groupId
        self.name = task.name
        self.description = task.description
        self.status = task.status
        self.progress = task.progress.fractionCompleted
        self.createdAt = task.createdAt
        self.startedAt = task.startedAt
        self.completedAt = task.completedAt

        // 序列化输入和结果（可选）
        self.inputData = nil  // 根据实际情况实现
        self.resultData = nil
        self.errorMessage = nil
    }

    func toTaskItem() -> TaskItem {
        TaskItem(
            id: id,
            groupId: groupId,
            name: name,
            description: description,
            status: status,
            progress: DefaultTaskProgress(
                completedUnitCount: Int64(progress * 100),
                totalUnitCount: 100
            )
        )
    }
}
```

---

## 5. 工具定义

### 5.1 任务执行器工具

**文件**: `TaskExecutorTool.swift`

```swift
import Foundation
import MagicKit
import OSLog

/// 任务执行器工具
struct TaskExecutorTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = true

    let name = "task_executor"
    let description = """
    执行长时间运行的复杂任务。
    该工具会将任务自动拆解为多个子任务，并逐步执行。
    适用于批量处理、数据转换、文件操作等场景。

    返回结果包括：
    - 任务执行状态
    - 当前进度
    - 已完成的任务列表
    - 最终结果摘要
    """

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "taskDescription": [
                    "type": "string",
                    "description": "任务描述（自然语言）"
                ],
                "parameters": [
                    "type": "object",
                    "description": "任务参数（可选）"
                ],
                "maxConcurrentTasks": [
                    "type": "number",
                    "description": "最大并发任务数，默认为 3"
                ],
                "dryRun": [
                    "type": "boolean",
                    "description": "是否仅预览任务拆解结果而不实际执行，默认 false"
                ]
            ],
            "required": ["taskDescription"]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let taskDescription = arguments["taskDescription"]?.value as? String else {
            throw TaskExecutorError.missingParameter("taskDescription")
        }

        let parameters = arguments["parameters"]?.value as? [String: Any] ?? [:]
        let maxConcurrentTasks = arguments["maxConcurrentTasks"]?.value as? Int ?? 3
        let isDryRun = arguments["dryRun"]?.value as? Bool ?? false

        if Self.verbose {
            os_log("\(Self.t)开始执行任务：\(taskDescription)")
        }

        do {
            // 1. 拆解任务
            let splitContext = TaskSplitContext(
                availableTools: getAvailableTools(),
                maxConcurrentTasks: maxConcurrentTasks,
                estimatedTimeLimit: nil
            )

            let subTasks = try await TaskSplitter.shared.split(
                taskDescription: taskDescription,
                context: splitContext
            )

            // 2. 如果是预览模式，返回拆解结果
            if isDryRun {
                return formatDryRunResult(tasks: subTasks)
            }

            // 3. 执行任务
            let taskItems = subTasks.map { $0.toTaskItem(parameters: parameters) }
            await TaskScheduler.shared.enqueueGroup(taskItems)

            // 4. 等待任务完成并返回进度
            return try await waitForCompletion(taskItems: taskItems)

        } catch {
            os_log(.error, "\(Self.t)任务执行失败：\(error.localizedDescription)")
            throw error
        }
    }

    /// 等待任务完成
    private func waitForCompletion(taskItems: [TaskItem]) async throws -> String {
        while true {
            let progress = await TaskScheduler.shared.getProgress()

            if progress.completed + progress.failed == progress.total {
                return formatExecutionResult(progress: progress)
            }

            // 每 500ms 检查一次进度
            try await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func formatDryRunResult(tasks: [TaskDefinition]) -> String {
        var output = "📋 任务拆解预览\n\n"
        output += "共拆解为 \(tasks.count) 个子任务：\n\n"

        for (index, task) in tasks.enumerated() {
            output += """
            \(index + 1). **\(task.name)**
               \(task.description)
               工具：\(task.tool)
               依赖：\(task.dependencies.isEmpty ? "无" : task.dependencies.joined(separator: ", "))

            """
        }

        return output
    }

    private func formatExecutionResult(progress: TaskGroupProgress) -> String {
        var output = "✅ 任务执行完成\n\n"
        output += "📊 执行摘要：\n"
        output += "- 总任务数：\(progress.total)\n"
        output += "- 成功：\(progress.completed)\n"
        output += "- 失败：\(progress.failed)\n"
        output += "- 完成率：\(Int(Double(progress.completed) / Double(progress.total) * 100))%\n"

        return output
    }
}

/// 任务执行错误
enum TaskExecutorError: LocalizedError {
    case missingParameter(String)
    case taskSplitFailed
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingParameter(let param):
            return "缺少必需参数：\(param)"
        case .taskSplitFailed:
            return "任务拆解失败"
        case .executionFailed(let reason):
            return "任务执行失败：\(reason)"
        }
    }
}
```

---

## 6. 状态管理

### 6.1 任务状态机

```swift
/// 任务调度器状态机
actor TaskSchedulerStateMachine {

    /// 任务依赖图
    private var dependencyGraph: [String: Set<String>] = [:]

    /// 检查任务是否可以开始
    func canStart(task: TaskItem) -> Bool {
        // 检查依赖
        if let dependencies = dependencyGraph[task.id] {
            for dependency in dependencies {
                if !isCompleted(dependencyId: dependency) {
                    return false
                }
            }
        }
        return true
    }

    /// 标记任务为已完成
    func markCompleted(taskId: String) {
        dependencyGraph.removeValue(forKey: taskId)
    }

    private func isCompleted(dependencyId: String) -> Bool {
        // 检查任务是否已完成
        return true  // 实现略
    }
}
```

### 6.2 进度追踪

```swift
/// 任务组进度
struct TaskGroupProgress: Sendable {
    /// 总任务数
    let total: Int

    /// 已完成数
    let completed: Int

    /// 失败数
    let failed: Int

    /// 正在执行数
    let running: Int

    /// 等待执行数
    let pending: Int

    /// 完成率
    var completionRate: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    /// 进度描述
    var localizedDescription: String {
        "\(completed)/\(total) 完成，\(running) 进行中，\(pending) 等待中"
    }
}
```

---

## 7. UI 设计

### 7.1 设置界面

```swift
import SwiftUI

/// 任务执行器设置界面
struct TaskExecutorSettingsView: View {
    @State private var maxConcurrentTasks: Int = 3
    @State private var autoRetry: Bool = true
    @State private var maxRetryCount: Int = 3
    @State private var enablePersistence: Bool = true

    var body: some View {
        Form {
            Section(header: Text("并发控制")) {
                Stepper(
                    "最大并发任务数：\(maxConcurrentTasks)",
                    value: $maxConcurrentTasks,
                    in: 1...10
                )

                Text("控制同时执行的任务数量，增加可以提高速度，但会消耗更多资源")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("错误恢复")) {
                Toggle("自动重试失败的任务", isOn: $autoRetry)

                if autoRetry {
                    Stepper(
                        "最大重试次数：\(maxRetryCount)",
                        value: $maxRetryCount,
                        in: 0...5
                    )
                }
            }

            Section(header: Text("持久化")) {
                Toggle("启用任务状态持久化", isOn: $enablePersistence)

                Text("启用后，应用重启可以恢复未完成的任务")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("清理")) {
                Button("清理已完成的任务记录") {
                    Task {
                        try? await TaskPersistenceService.shared
                            .cleanupCompletedTasks()
                    }
                }
            }
        }
        .padding()
    }
}
```

### 7.2 任务列表视图

```swift
import SwiftUI

/// 任务列表视图
struct TaskListView: View {
    @State private var tasks: [TaskItem] = []
    @State private var selectedTask: TaskItem?

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("任务列表")
                    .font(.headline)

                Spacer()

                Button(action: refreshTasks) {
                    Image(systemName: "arrow.clockwise")
                }

                Button(action: pauseAll) {
                    Image(systemName: "pause.fill")
                }

                Button(action: cancelAll) {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .padding()

            Divider()

            // 任务列表
            List(tasks, selection: $selectedTask) { task in
                TaskRowView(task: task)
            }
        }
        .onAppear {
            refreshTasks()
        }
    }

    private func refreshTasks() {
        Task {
            tasks = await TaskScheduler.shared.getAllTasks()
        }
    }

    private func pauseAll() {
        Task {
            await TaskScheduler.shared.pauseAll()
        }
    }

    private func cancelAll() {
        Task {
            await TaskScheduler.shared.cancelAll()
        }
    }
}

/// 任务行视图
struct TaskRowView: View {
    let task: TaskItem

    var body: some View {
        HStack {
            // 状态图标
            statusIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.system(.body, weight: .medium))

                Text(task.description)
                    .font(.system(.caption))
                    .foregroundColor(.secondary)

                // 进度条
                ProgressView(value: task.progress.fractionCompleted)
                    .progressViewStyle(.linear)
            }

            Spacer()

            // 执行时间
            VStack(alignment: .trailing) {
                Text(task.statusDescription)
                    .font(.system(.caption, weight: .medium))

                Text(task.durationDescription)
                    .font(.system(.caption))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .pending:
            Image(systemName: "clock.fill")
                .foregroundColor(.orange)
        case .running:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
                .rotationEffect(.degrees(360))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundColor(.orange)
        }
    }
}
```

### 7.3 任务进度视图

```swift
import SwiftUI

/// 任务进度视图
struct TaskProgressView: View {
    let progress: TaskGroupProgress

    var body: some View {
        VStack(spacing: 12) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: progress.completionRate)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress.completionRate * 100))%")
                    .font(.system(size: 24, weight: .bold))
            }
            .frame(width: 120, height: 120)

            // 进度详情
            HStack(spacing: 20) {
                StatView(label: "已完成", value: "\(progress.completed)", icon: "checkmark.circle")
                StatView(label: "进行中", value: "\(progress.running)", icon: "arrow.triangle.2.circlepath")
                StatView(label: "等待中", value: "\(progress.pending)", icon: "clock")
                StatView(label: "失败", value: "\(progress.failed)", icon: "exclamationmark.circle")
            }
        }
        .padding()
    }

    private var progressColor: Color {
        if progress.failed > 0 {
            return .red
        } else if progress.completionRate == 1.0 {
            return .green
        } else {
            return .blue
        }
    }
}

/// 统计视图
struct StatView: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentColor)

            Text(value)
                .font(.system(size: 20, weight: .bold))

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
```

---

## 8. 实现步骤

### 8.1 开发流程

| 步骤 | 任务 | 预计时间 |
|------|------|----------|
| 1 | 创建插件目录结构 | 10 min |
| 2 | 实现核心协议（Task, TaskStatus, TaskProgress） | 1 h |
| 3 | 实现任务调度器（TaskScheduler） | 2 h |
| 4 | 实现任务拆分器（TaskSplitter） | 2 h |
| 5 | 实现持久化服务（TaskPersistenceService） | 1 h |
| 6 | 实现 Agent 工具（TaskExecutorTool） | 1 h |
| 7 | 实现插件主类 | 30 min |
| 8 | 实现 UI 组件 | 2 h |
| 9 | 集成测试 | 2 h |
| **总计** | | **~11.5 小时** |

### 8.2 使用示例

```swift
// 用户输入：「把项目里所有的图片从 JPG 转换为 PNG」

// 1. Agent 调用 task_executor 工具
let arguments: [String: ToolArgument] = [
    "taskDescription": "把项目里所有的图片从 JPG 转换为 PNG"
]

// 2. TaskExecutorTool 执行
// 2.1 TaskSplitter 拆解任务：
//   - 步骤 1: 扫描项目目录，找到所有 .jpg 文件
//   - 步骤 2: 为每个文件创建转换任务
//   - 步骤 3: 执行转换任务队列
//   - 步骤 4: 汇总结果

// 3. TaskScheduler 调度执行
//   - 最大并发 3 个任务
//   - 实时追踪进度
//   - 错误自动重试

// 4. 返回结果
/*
✅ 任务执行完成

📊 执行摘要：
- 总任务数：156
- 成功：154
- 失败：2
- 完成率：98%

📁 输出目录：/Users/xxx/Pictures/Converted/
*/
```

---

## 9. 参考资料

- [Lumi 插件开发指南](../.claude/rules/SWIFTUI_GUIDE.md)
- [SuperLog 日志规范](../.claude/rules/LOGGING_STANDARDS.md)
- [Grand Central Dispatch (GCD) 文档](https://developer.apple.com/documentation/dispatch)
- [Swift Concurrency 文档](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

*文档创建时间：2026-03-13*
