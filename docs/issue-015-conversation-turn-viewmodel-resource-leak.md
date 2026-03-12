# Issue #015: ConversationTurnViewModel 资源泄漏与 AsyncStream 生命周期缺失（Critical）

## 📋 问题概述

`ConversationTurnViewModel` 是对话轮次处理的核心组件，但存在**严重的资源管理缺陷**：

1. **`turnContexts` 字典无限制增长** - 每个会话的上下文永不清理
2. **`eventContinuation` 从未结束** - AsyncStream continuation 未正确 finish
3. **缺少 deinit 清理** - ViewModel 销毁时资源未释放
4. **与 ConversationRuntimeStore 状态不同步** - 可能导致状态泄漏

这是长期运行应用中最危险的内存泄漏类型之一，会导致：
- 内存随使用时间持续增长
- AsyncStream 订阅者永远无法收到完成信号
- 已删除会话的数据仍驻留内存

---

## 🔴 严重程度：Critical (最高级别)

**风险等级**: ⚠️ 可能导致：
- 长时间使用后内存占用持续增长
- AsyncStream 消费者（Coordinator）无法感知流结束
- 已删除会话的敏感数据残留在内存中
- 多会话切换时状态污染

**优先级**: P0 - 需要立即修复

---

## 📍 问题位置

| # | 文件路径 | 问题类型 | 风险级别 |
|---|----------|----------|----------|
| 1 | `LumiApp/Core/ViewModels/ConversationTurnViewModel.swift` | `turnContexts` 无清理 | 🔴 高 |
| 2 | `LumiApp/Core/ViewModels/ConversationTurnViewModel.swift` | `eventContinuation` 未 finish | 🔴 高 |
| 3 | `LumiApp/Core/ViewModels/ConversationTurnViewModel.swift` | 缺少 deinit | 🔴 高 |
| 4 | `LumiApp/Core/Stores/ConversationRuntimeStore.swift` | `cleanupConversationState` 未被调用 | 🟠 中 |

---

## 🐛 问题分析

### 问题 1: turnContexts 字典无限制增长

**代码位置**: `ConversationTurnViewModel.swift:54-55`

```swift
// MARK: - 会话上下文
private var turnContexts: [UUID: TurnContext] = [:]
private let maxDepth = 60
```

**问题代码**: `processTurn` 方法中

```swift
func processTurn(conversationId: UUID, depth: Int = 0, ...) async {
    // ❌ 问题：每次都写入 turnContexts，但从未删除
    var context = turnContexts[conversationId] ?? TurnContext()
    if depth == 0 {
        context = TurnContext()
        context.chainStartedAt = Date()
    }
    context.currentDepth = depth
    turnContexts[conversationId] = context  // 写入但永不删除
    
    // ... 处理逻辑 ...
    
    // ❌ 问题：轮次完成后没有清理 turnContexts[conversationId]
    // 即使会话被删除，这个条目仍然存在
}
```

**内存泄漏示意**:

```
用户创建会话 A
    ↓
processTurn(conversationId: A) 被调用
    ↓
turnContexts[A] = TurnContext(...)
    ↓
用户删除会话 A
    ↓
❌ turnContexts[A] 仍然存在！
    ↓
用户创建 100 个会话
    ↓
turnContexts 有 100 个条目（包含已删除的会话）
```

**TurnContext 大小估算**:

```swift
struct TurnContext {
    var currentDepth: Int                    // 8 bytes
    var pendingToolCalls: [ToolCall]         // 可变，假设平均 500 bytes
    var currentProviderId: String            // 50 bytes
    var chainStartedAt: Date?                // 8 bytes
    var consecutiveEmptyToolTurns: Int       // 8 bytes
    var lastToolSignature: String?           // 100 bytes
    var repeatedToolSignatureCount: Int      // 8 bytes
    var recentToolSignatures: [String]       // 500 bytes
}
// 单个 TurnContext ≈ 1.2 KB

// 100 个会话 = 120 KB（仅 TurnContext）
// 1000 个会话 = 1.2 MB
// 长时间运行可能达到 10+ MB
```

---

### 问题 2: eventContinuation 从未 finish

**代码位置**: `ConversationTurnViewModel.swift:38-45`

```swift
// MARK: - 事件流
var events: AsyncStream<ConversationTurnEvent> {
    AsyncStream { continuation in
        self.eventContinuation = continuation  // ❌ 存储 continuation
    }
}

private var eventContinuation: AsyncStream<ConversationTurnEvent>.Continuation?
```

**问题**:

```swift
// ❌ 整个类中没有任何地方调用：
// eventContinuation?.finish()

// 这意味着：
// 1. AsyncStream 永远不会结束
// 2. 订阅者（ConversationTurnCoordinator）永远收不到完成信号
// 3. 即使 ViewModel 被销毁，continuation 仍持有引用

// 正确做法：
func cleanup() {
    eventContinuation?.finish()  // ✅ 通知流结束
    eventContinuation = nil      // ✅ 释放引用
}
```

**影响**:

```
ConversationTurnViewModel 创建
    ↓
ConversationTurnCoordinator 订阅 events
    ↓
for await event in viewModel.events { ... }
    ↓
ViewModel 需要销毁（会话切换/删除）
    ↓
❌ eventContinuation.finish() 从未调用
    ↓
Coordinator 的 for-await 循环永远等待
    ↓
Coordinator 也无法释放
    ↓
内存泄漏链形成
```

---

### 问题 3: 缺少 deinit 方法

**整个类没有 deinit 方法**:

```swift
@MainActor
final class ConversationTurnViewModel: ObservableObject, SuperLog {
    // ... 属性 ...
    
    init(...) {
        // 初始化
    }
    
    // ❌ 没有 deinit！
    // 即使有 deinit，也需要手动清理：
    // - eventContinuation.finish()
    // - turnContexts.removeAll()
}
```

---

### 问题 4: ConversationRuntimeStore 清理未被调用

**代码位置**: `ConversationRuntimeStore.swift:76-94`

```swift
func cleanupConversationState(_ conversationId: UUID) {
    streamStateByConversation[conversationId] = StreamSessionState(messageId: nil, messageIndex: nil)
    streamStateByConversation.removeValue(forKey: conversationId)
    
    thinkingTextByConversation.removeValue(forKey: conversationId)
    pendingStreamTextByConversation.removeValue(forKey: conversationId)
    // ... 清理其他状态
}
```

**问题**:

```swift
// ❌ 这个方法存在，但从未被调用！
// 应该在哪里调用：
// 1. 会话删除时
// 2. 轮次处理完成时
// 3. ViewModel 销毁时

// 搜索整个项目：
grep -rn "cleanupConversationState" LumiApp/
// 结果：只有定义，没有调用！
```

---

## ⚠️ 为什么这是严重问题？

### 1. 内存泄漏链

```
ConversationTurnViewModel
    ├── turnContexts (持续增长)
    ├── eventContinuation (持有 AsyncStream)
    └── ConversationTurnCoordinator (订阅 events)
            └── Task (处理事件，无法结束)
```

### 2. 会话切换时的状态污染

```
会话 A 使用中
    ↓
turnContexts[A] = { depth: 10, pendingToolCalls: [...] }
    ↓
用户切换到会话 B
    ↓
❌ turnContexts[A] 仍然存在
    ↓
如果会话 A 的 ID 被重用（罕见但可能）
    ↓
旧的上下文数据污染新会话
```

### 3. 敏感数据残留

```
TurnContext.pendingToolCalls 包含：
- 工具调用参数（可能含 API Key、文件路径）
- 工具执行结果（可能含敏感数据）

❌ 即使会话删除，这些数据仍在内存中
❌ 可能被内存转储工具读取
```

---

## ✅ 修复方案

### 方案 1: 添加完整的清理方法

```swift
@MainActor
final class ConversationTurnViewModel: ObservableObject, SuperLog {
    // ... 现有代码 ...
    
    // MARK: - 清理
    
    /// 清理指定会话的上下文
    func cleanupConversation(_ conversationId: UUID) {
        // ✅ 清理 turnContexts
        turnContexts.removeValue(forKey: conversationId)
        
        // ✅ 清理 RuntimeStore 中的状态
        // (需要 RuntimeStore 引用，见方案 2)
    }
    
    /// 清理所有资源
    func cleanup() {
        // ✅ 结束 AsyncStream
        eventContinuation?.finish()
        eventContinuation = nil
        
        // ✅ 清空所有上下文
        turnContexts.removeAll()
        
        if Self.verbose {
            os_log("\(Self.t)✅ ConversationTurnViewModel 已清理")
        }
    }
    
    deinit {
        // ✅ 确保清理（虽然 @MainActor 类通常由 SwiftUI 管理）
        // 注意：deinit 中不能调用 async 方法
        // 但 can 调用 finish()
        eventContinuation?.finish()
    }
}
```

### 方案 2: 与 ConversationRuntimeStore 集成

```swift
@MainActor
final class ConversationTurnViewModel: ObservableObject, SuperLog {
    // 添加 RuntimeStore 引用
    private let runtimeStore: ConversationRuntimeStore
    
    init(
        llmService: LLMService,
        toolExecutionService: ToolExecutionService,
        promptService: PromptService,
        runtimeStore: ConversationRuntimeStore  // ✅ 新增
    ) {
        self.llmService = llmService
        self.toolExecutionService = toolExecutionService
        self.promptService = promptService
        self.runtimeStore = runtimeStore
    }
    
    func cleanupConversation(_ conversationId: UUID) {
        turnContexts.removeValue(forKey: conversationId)
        
        // ✅ 同步清理 RuntimeStore
        runtimeStore.cleanupConversationState(conversationId)
    }
}
```

### 方案 3: 在适当位置调用清理

**在 AgentProvider 中**:

```swift
@MainActor
final class AgentProvider: ObservableObject {
    // ... 现有代码 ...
    
    func deleteConversation(_ conversation: Conversation) {
        // ✅ 清理 ConversationTurnViewModel 中的状态
        conversationTurnViewModel.cleanupConversation(conversation.id)
        
        // ✅ 清理 RuntimeStore
        runtimeStore.cleanupConversationState(conversation.id)
        
        // 然后删除数据
        conversationViewModel.deleteConversation(conversation)
    }
    
    func switchConversation(to newId: UUID?) {
        if let oldId = conversationViewModel.selectedConversationId {
            // ✅ 切换前清理旧会话状态
            conversationTurnViewModel.cleanupConversation(oldId)
        }
        conversationViewModel.setSelectedConversation(newId)
    }
}
```

### 方案 4: 添加自动清理机制

```swift
func processTurn(conversationId: UUID, ...) async {
    defer {
        // ✅ 轮次结束时自动清理（可选，取决于需求）
        // 如果希望保留上下文用于恢复，则不清理
        if shouldCleanupContext {
            turnContexts.removeValue(forKey: conversationId)
        }
    }
    
    // ... 处理逻辑 ...
}

// 或者添加最大上下文数量限制
private let maxTurnContexts = 100

func pruneOldTurnContexts() {
    if turnContexts.count > maxTurnContexts {
        // 保留最近的 N 个
        let sorted = turnContexts.sorted { 
            $0.value.chainStartedAt ?? .distantPast > 
            $1.value.chainStartedAt ?? .distantPast 
        }
        turnContexts = Dictionary(sorted.prefix(maxTurnContexts)) { ($0, $1) }
    }
}
```

---

## 📝 检查清单

### 代码修复

- [ ] 添加 `cleanupConversation(_:)` 方法
- [ ] 添加 `cleanup()` 方法
- [ ] 添加 `deinit` 并调用 `eventContinuation?.finish()`
- [ ] 在会话删除时调用清理
- [ ] 在会话切换时调用清理
- [ ] 集成 ConversationRuntimeStore 清理

### 集成点

- [ ] `AgentProvider.deleteConversation` → 调用清理
- [ ] `AgentProvider.switchConversation` → 调用清理
- [ ] `ConversationViewModel` 删除通知 → 触发清理
- [ ] 应用终止 → 调用 `cleanup()`

### 测试场景

- [ ] 创建 100 个会话后检查内存
- [ ] 删除会话后验证 turnContexts 清理
- [ ] 验证 AsyncStream 正确结束
- [ ] 长时间运行后验证无泄漏

---

## 🔗 相关问题

- **Issue #003**: TurnContexts 内存泄漏 - 相关但范围较窄
- **Issue #005**: 系统性 NotificationCenter 泄漏 - 类似的资源管理问题
- **Issue #010**: Coordinator Task 泄漏 - Task 生命周期问题
- **Issue #014**: TaskGroup 取消与错误传播缺失 - 并发资源管理

---

## 📚 参考资源

- [Apple Developer: AsyncStream](https://developer.apple.com/documentation/swift/asyncstream)
- [Swift Concurrency: Structured Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [WWDC21: Explore AsyncStream](https://developer.apple.com/videos/play/wwdc2021/10134/)

---

## 📊 修复估算

| 阶段 | 工作量 | 风险 |
|------|--------|------|
| 添加清理方法 | 1 小时 | 低 |
| 集成到 AgentProvider | 2 小时 | 中 |
| 添加测试 | 2 小时 | 低 |
| 验证内存泄漏修复 | 2 小时 | 低 |
| **总计** | **7 小时** | - |

---

*最后更新: 2026-03-12*
*发现者: 代码审计*
