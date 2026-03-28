# 后台任务插件架构设计 (重构版)

## 🎯 核心设计理念

**职责分离 + 事件驱动**

每个模块只关注自己的职责，通过事件（NotificationCenter）进行松耦合通信。

---

## 📊 架构分层

```
┌─────────────────────────────────────────────────────────────┐
│                  BackgroundAgentTaskPlugin                   │
│                   (协调器 / Coordinator)                      │
│                                                              │
│  职责：                                                       │
│  - 生命周期管理                                               │
│  - 启动/停止 Worker                                          │
│  - 监听事件并协调各模块                                       │
└────────────┬────────────┬────────────┬───────────────────────┘
             │            │            │
             ▼            ▼            ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │   Create     │  │   Worker     │  │     Store    │
    │    Tool      │  │              │  │              │
    └──────────────┘  └──────────────┘  └──────────────┘
             │            │            │
             │            │            │
             ▼            ▼            ▼
    ┌────────────────────────────────────────────────────────┐
    │              NotificationCenter (事件总线)              │
    │  - .backgroundAgentTaskDidCreate                       │
    │  - .backgroundAgentTaskDidUpdate                       │
    └────────────────────────────────────────────────────────┘
```

---

## 🔧 各模块职责

### 1️⃣ **BackgroundAgentTaskStore (存储层)**

```swift
// 职责：只负责数据持久化和事件发布

actor BackgroundAgentTaskStore {
    // ✅ 创建任务并发布事件
    func createTask(prompt: String) -> UUID

    // ✅ 查询任务
    func fetchRecent(limit: Int) -> [BackgroundAgentTask]
    func fetchById(_ id: UUID) -> BackgroundAgentTask?

    // ✅ Worker 接口
    func claimNextPendingTask() -> UUID?  // 认领任务
    func updateTask(...)                    // 更新状态
    func fetchTaskDetails(...)              // 获取详情
    func getLLMConfig() -> LLMConfig       // 获取配置
}
```

**特点**：
- 不关心谁调用它
- 不关心任务如何执行
- 只负责存储和发布事件

---

### 2️⃣ **BackgroundAgentTaskWorker (执行层)**

```swift
// 职责：只负责执行任务

actor BackgroundAgentTaskWorker {
    // ✅ 生命周期
    func start()  // 启动主循环
    func stop()   // 停止主循环

    // ✅ 内部逻辑
    private func mainLoop()              // 主循环
    private func fetchAndExecuteNextTask() // 获取并执行
    private func executeTask(taskId:)     // 执行任务
}
```

**特点**：
- 从 Store 获取任务
- 执行任务逻辑
- 更新任务状态到 Store
- 不关心任务从哪里来

---

### 3️⃣ **CreateBackgroundAgentTaskTool (创建工具)**

```swift
// 职责：只负责创建任务

struct CreateBackgroundAgentTaskTool: AgentTool {
    func execute(...) async throws -> String {
        // ✅ 只调用 Store 创建任务
        let taskId = BackgroundAgentTaskStore.shared.createTask(prompt: instruction)
        return ...
    }
}
```

**特点**：
- 不关心任务如何执行
- 不关心 Worker 是否存在
- 只负责创建和返回

---

### 4️⃣ **BackgroundAgentTaskPlugin (协调器)**

```swift
// 职责：协调各个模块

actor BackgroundAgentTaskPlugin: SuperPlugin {
    private var worker: BackgroundAgentTaskWorker?

    func onEnable() {
        // ✅ 启动 Worker
        setupWorkerAndObserver()

        // ✅ 监听事件
        observeTaskCreation()
    }

    func onDisable() {
        // ✅ 停止 Worker
        teardownWorkerAndObserver()
    }
}
```

**特点**：
- 管理插件生命周期
- 启动/停止 Worker
- 监听事件（可选）
- 不关心具体实现细节

---

## 🔄 事件驱动流程

### **任务创建流程**

```
用户通过 LLM 调用
    ↓
CreateBackgroundAgentTaskTool.execute()
    ↓
BackgroundAgentTaskStore.createTask()
    ↓
┌─────────────────────────────────┐
│ 1. 保存任务到数据库              │
│ 2. 发布 .backgroundAgentTaskDidCreate │
└─────────────────────────────────┘
    ↓
Plugin 监听到事件（可选）
    ↓
Worker 在下次循环中自动获取
```

### **任务执行流程**

```
Worker.mainLoop() (无限循环)
    ↓
claimNextPendingTask()
    ↓
┌─────────────────────────────────┐
│ 从数据库获取 pending 任务          │
│ 更新状态为 running                │
│ 返回任务 ID                       │
└─────────────────────────────────┘
    ↓
executeTask(taskId)
    ↓
┌─────────────────────────────────┐
│ 执行 LLM + 工具调用               │
│ 调用 updateTask() 更新状态        │
└─────────────────────────────────┘
    ↓
发布 .backgroundAgentTaskDidUpdate (可选)
```

---

## 📊 模块依赖关系

```
Create Tool ──→ Store ───→ Worker
                    ↑       │
                    │       │
Plugin ──────────────┴───────┘
  (监听事件)          (调用接口)
```

### 依赖方向

- **Create Tool** → **Store**：创建任务
- **Worker** → **Store**：获取/更新任务
- **Plugin** → **Worker**：生命周期管理
- **Plugin** → **NotificationCenter**：监听事件
- **Store** → **NotificationCenter**：发布事件

---

## ✅ 设计优势

### 1. **单一职责原则 (SRP)**

```swift
// ✅ Store：只管存储
actor BackgroundAgentTaskStore {
    func createTask() -> UUID
    func claimNextPendingTask() -> UUID?
    func updateTask(...)
}

// ✅ Worker：只管执行
actor BackgroundAgentTaskWorker {
    func start()
    private func executeTask(taskId:)
}

// ✅ Plugin：只管协调
actor BackgroundAgentTaskPlugin {
    func onEnable()
    func onDisable()
}
```

### 2. **松耦合**

```swift
// ✅ 通过事件通信，无需直接引用
NotificationCenter.postBackgroundAgentTaskDidCreate(taskId: id)

// ✅ Worker 不关心谁创建了任务
guard let taskId = await store.claimNextPendingTask() else { ... }
```

### 3. **易于测试**

```swift
// ✅ 各模块可独立测试
let store = BackgroundAgentTaskStore.shared
let taskId = store.createTask(prompt: "test")

let worker = BackgroundAgentTaskWorker(store: store)
await worker.start()
```

### 4. **易于扩展**

```swift
// ✅ 轻松添加多个 Worker
for _ in 0..<3 {
    let worker = BackgroundAgentTaskWorker(store: store)
    await worker.start()
}

// ✅ 轻松添加新的事件监听器
NotificationCenter.default.addObserver(forName: .backgroundAgentTaskDidCreate) { ... }
```

---

## 🎯 与旧架构对比

| 特性 | 旧架构 | 新架构 |
|------|--------|--------|
| **Store 职责** | 存储 + 执行 + Worker 管理 | 只存储 + 发布事件 |
| **Worker 职责** | 无 | 只执行任务 |
| **Plugin 职责** | 简单工厂 | 生命周期协调器 |
| **耦合度** | 高（Store 管所有事） | 低（通过事件解耦） |
| **可测试性** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **可扩展性** | ⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 🚀 未来扩展方向

### 1. **多 Worker 并发**

```swift
// Plugin 中轻松实现
func onEnable() {
    for i in 0..<3 {
        let worker = BackgroundAgentTaskWorker(store: store)
        await worker.start()
        workers.append(worker)
    }
}
```

### 2. **优先级队列**

```swift
// Store 中扩展
func claimNextPendingTask(priority: TaskPriority) -> UUID? {
    // 按优先级排序
}
```

### 3. **任务进度追踪**

```swift
// 新增事件
extension Notification.Name {
    static let backgroundAgentTaskProgress = Notification.Name("...")
}

// Worker 执行时发布
NotificationCenter.postBackgroundAgentTaskProgress(
    taskId: taskId,
    progress: 0.5
)
```

### 4. **状态栏实时更新**

```swift
// View 中监听
struct BackgroundAgentTaskStatusBarView: View {
    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskRow(task: task)
            }
        }
        .onBackgroundAgentTaskDidUpdate { taskId, status in
            // 自动刷新
            refreshTasks()
        }
    }
}
```

---

## 📝 总结

### 核心原则

1. **Store**：只管存储和发布事件 📦
2. **Worker**：只管执行任务 ⚙️
3. **Plugin**：只管协调 🎯
4. **Tool**：只管创建任务 🔧

### 设计模式

- **单一职责原则 (SRP)**
- **依赖倒置原则 (DIP)**
- **观察者模式 (Observer)**
- **事件驱动架构 (EDA)**

### 优势

✅ 职责清晰
✅ 松耦合
✅ 易测试
✅ 易扩展
✅ 易维护

这是一个符合现代软件设计理念的优秀架构！🎉
