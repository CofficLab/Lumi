# Issue #006: 严重并发安全漏洞 - SwiftData Actor 隔离违规

## 📋 问题概述

项目中存在系统性的 SwiftData Actor 隔离违规问题，`ChatHistoryService` 等核心服务在多个并发上下文中不安全地共享 `ModelContext`，可能导致数据竞争、崩溃和数据损坏。

---

## 🔴 严重程度：极高 (Critical)

**风险等级**: ⚠️ 可能导致数据丢失、应用崩溃、数据竞争

---

## 📍 问题位置

### 主要问题文件

1. **ChatHistoryService.swift** (核心问题)
   - 路径: `LumiApp/Core/Services/ChatHistoryService.swift`
   - 行号: 52-65, 340-470

2. **NewChatButton.swift**
   - 路径: `LumiApp/Plugins/AgentHeaderPlugin/Buttons/NewChatButton.swift`
   - 行号: 21, 86, 124-125

3. **其他涉及文件**
   - `LumiApp/Core/Middleware/Builtins/PersistAndAppendMiddleware.swift`
   - `LumiApp/Plugins/AgentInputPlugin/PendingMessagesView.swift`

---

## 🐛 问题分析

### 核心问题：ModelContext 的 Actor 隔离违规

SwiftData 的 `ModelContext` 是 `MainActor` 绑定的，但 `ChatHistoryService` 被标记为 `@unchecked Sendable`，并在后台队列上执行数据库操作：

```swift
// ❌ 问题代码 - ChatHistoryService.swift
final class ChatHistoryService: SuperLog, @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext  // MainActor 绑定！
    private let storageQueue = DispatchQueue(label: "...", qos: .utility)
    
    init(llmService: LLMService, modelContainer: ModelContainer, reason: String) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)  // 在主线程创建
    }
    
    // ❌ 危险：在后台队列使用 ModelContext
    func someBackgroundOperation() {
        storageQueue.async {
            let context = ModelContext(self.modelContainer)  // 在非主线程创建
            // ... 使用 context 进行操作
        }
    }
}
```

### 具体问题场景

#### 1. 并发上下文创建 (ChatHistoryService.swift:340-470)

```swift
// ❌ 问题代码
storageQueue.async {
    let context = ModelContext(self.modelContainer)  // 在非主线程创建
    // ... 执行数据库操作
}
```

**风险**: 在后台线程创建 `ModelContext` 违反了 SwiftData 的 Actor 隔离规则，可能导致：
- 数据竞争 (Data Race)
- SwiftData 内部状态不一致
- 随机的应用崩溃
- 数据损坏

#### 2. 环境变量注入冲突 (NewChatButton.swift:21)

```swift
// ❌ 问题代码
@Environment(\.modelContext) private var modelContext

// 同时在同一个视图中使用
Task {
    await createNewConversation()  // 可能切换到后台线程
}
```

**风险**: SwiftUI 的 `@Environment(\.modelContext)` 是 MainActor 绑定的，但在异步任务中可能被错误地在后台线程访问。

#### 3. 服务初始化时序问题

```swift
// ChatHistoryService 在初始化时创建 ModelContext
// 但服务本身被设计为可在后台使用
self.modelContext = ModelContext(modelContainer)
```

**风险**: `ModelContext` 的创建线程和使用线程不一致，违反 Actor 隔离。

### 为什么这是严重问题？

1. **数据竞争风险**: 
   - SwiftData 的 `ModelContext` 不是线程安全的
   - 在非主线程访问会导致不可预测的行为
   - 可能导致内存损坏

2. **数据丢失风险**:
   - 数据库操作可能在错误的上下文中执行
   - 保存操作可能失败或部分失败
   - 用户对话历史可能丢失

3. **崩溃风险**:
   - SwiftData 内部断言失败
   - 线程安全检查失败
   - 随机的 EXC_BAD_ACCESS

4. **难以复现**:
   - 竞态条件问题只在特定时序出现
   - 开发和测试环境可能无法捕获
   - 生产环境才会暴露

---

## ✅ 建议修复方案

### 方案 1: 使用 Actor 隔离 (推荐)

将 `ChatHistoryService` 改为 Actor：

```swift
// ✅ 正确做法
actor ChatHistoryService: SuperLog {
    nonisolated static let emoji = "💾"
    
    private let modelContainer: ModelContainer
    
    // 不在 actor 中存储 ModelContext
    // 每次需要时创建新的 context
    
    func saveConversation(_ conversation: Conversation) async {
        await MainActor.run {
            let context = ModelContext(modelContainer)
            context.insert(conversation)
            try? context.save()
        }
    }
    
    func performBackgroundWork() async {
        // 使用 SwiftData 的 background 支持
        let descriptor = FetchDescriptor<Conversation>()
        let results = try? await modelContainer.mainContext.fetch(descriptor)
    }
}
```

### 方案 2: 使用 @ModelActor 宏

```swift
// ✅ 正确做法 - SwiftData 推荐的方式
@ModelActor
final class ChatHistoryService: SuperLog {
    nonisolated static let emoji = "💾"
    
    // modelContext 自动由 @ModelActor 管理
    
    func saveConversation(_ conversation: Conversation) {
        modelContext.insert(conversation)
        try? modelContext.save()
    }
}
```

### 方案 3: 使用 SwiftData 的并发安全 API

```swift
// ✅ 正确做法 - 使用 SwiftData 提供的并发方法
func fetchConversations() async throws -> [Conversation] {
    let descriptor = FetchDescriptor<Conversation>(
        sortBy: [.init(\.updatedAt, order: .reverse)]
    )
    // 使用 ModelContainer 的异步方法
    return try await modelContainer.mainContext.fetch(descriptor)
}
```

---

## 🔍 相关检查

建议检查项目中所有 SwiftData 相关代码：

```bash
# 查找所有 ModelContext 使用
grep -rn "ModelContext" --include="*.swift" LumiApp/

# 查找所有 @unchecked Sendable 与 SwiftData 相关的类
grep -rn "@unchecked Sendable" --include="*.swift" LumiApp/ | grep -i "service\|store\|manager"

# 查找所有 DispatchQueue 与 SwiftData 的组合使用
grep -rn "DispatchQueue" --include="*.swift" LumiApp/ -A 5 | grep -i "context\|swiftdata"
```

**已发现的相关问题**:
- `ChatHistoryService` - 后台队列创建 ModelContext
- `NewChatButton` - 环境变量 ModelContext 使用不当
- 多个 Middleware 可能在后台访问 SwiftData

---

## 📝 修复优先级

| 优先级 | 任务 | 预计工作量 |
|--------|------|-----------|
| **P0** | 重构 `ChatHistoryService` 使用 Actor 隔离 | 2-3 天 |
| **P0** | 修复所有 Middleware 中的 SwiftData 访问 | 1-2 天 |
| **P1** | 审计所有 @unchecked Sendable 类 | 1 天 |
| **P2** | 添加 SwiftData 访问的静态检查 | 1 天 |

---

## 🔄 相关 Issue

- **Issue #001**: ChatMessage 强制解包崩溃
- **Issue #002**: 系统性并发安全隐患 - @unchecked Sendable
- **Issue #005**: NotificationCenter 内存泄漏

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `critical`, `concurrency`, `swiftdata`, `data-integrity`
