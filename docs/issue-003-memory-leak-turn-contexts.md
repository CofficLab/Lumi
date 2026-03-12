# Issue: 严重内存泄漏 - ConversationTurnViewModel 中 turnContexts 字典无清理机制

## 📋 问题概述

`ConversationTurnViewModel` 使用 `turnContexts: [UUID: TurnContext]` 字典来跟踪每个会话的对话轮次上下文，但**没有任何清理机制**。当会话结束、被删除或用户切换会话时，对应的上下文数据永远不会被移除，导致内存持续增长。

---

## 🔴 严重程度：Critical (最高级别)

**风险等级**: ⚠️ 长期使用必然导致内存泄漏

**影响**:
- 内存占用持续增长
- 应用性能逐渐下降
- 长时间使用后可能导致 OOM (Out Of Memory) 崩溃
- 已删除会话的敏感数据残留在内存中

---

## 📍 问题位置

**文件**: `LumiApp/Core/ViewModels/ConversationTurnViewModel.swift`

**代码位置**:
```swift
// 第 56 行
private var turnContexts: [UUID: TurnContext] = [:]
```

**问题代码**:
```swift
// 第 98-106 行：只有写入，没有清理
var context = turnContexts[conversationId] ?? TurnContext()
if depth == 0 {
    context = TurnContext()
    context.chainStartedAt = Date()
}
if context.chainStartedAt == nil {
    context.chainStartedAt = Date()
}
context.currentDepth = depth
context.currentProviderId = config.providerId
turnContexts[conversationId] = context  // ❌ 只写入，永不删除
```

---

## 🐛 问题分析

### 为什么这是严重问题？

#### 1. **内存泄漏路径**

```
用户创建会话 → 发送消息 → processTurn 被调用 → turnContexts[conversationId] 被创建
                                                            ↓
用户删除会话/切换会话 → 会话从 SwiftData 删除 → turnContexts 中的 entry 仍然存在 ❌
                                                            ↓
重复操作 N 次 → turnContexts 字典无限增长 → 内存泄漏
```

#### 2. **泄漏的数据量**

每个 `TurnContext` 包含：
```swift
struct TurnContext {
    var currentDepth: Int = 0                      // 8 bytes
    var pendingToolCalls: [ToolCall] = []          // 可变数组，可能很大
    var currentProviderId: String = ""             // 可变字符串
    var chainStartedAt: Date?                      // 可选日期
    var consecutiveEmptyToolTurns: Int = 0         // 8 bytes
    var lastToolSignature: String?                 // 可选字符串
    var repeatedToolSignatureCount: Int = 0        // 8 bytes
    var recentToolSignatures: [String] = []        // 可变数组，可能很大
}
```

每个会话的上下文可能占用 **数 KB 到数 MB**（取决于工具调用历史）。

#### 3. **泄漏场景**

| 场景 | 触发条件 | 泄漏量 |
|------|----------|--------|
| 删除会话 | 用户删除对话 | 该会话所有上下文 |
| 切换会话 | 用户切换到新会话 | 旧会话上下文残留 |
| 应用长期运行 | 多次对话后 | 累积所有历史会话 |
| Agent 模式深度调用 | 单次对话多次 processTurn | 同一会话多次 entry 更新 |

#### 4. **与其他问题的关联**

此问题与现有的 `issue-002-unchecked-sendable-concurrency.md` 相关，但这是一个**独立的内存管理问题**：
- `@unchecked Sendable` 是并发安全隐患（可能崩溃）
- `turnContexts` 泄漏是确定的内存泄漏（必然发生）

---

## ✅ 建议修复方案

### 方案 1: 添加清理方法（推荐）

```swift
// 在 ConversationTurnViewModel 中添加清理方法
func cleanupConversation(_ conversationId: UUID) {
    turnContexts.removeValue(forKey: conversationId)
    
    if Self.verbose {
        os_log("\(Self.t)🧹 清理会话上下文：\(conversationId)，剩余 \(turnContexts.count) 个")
    }
}

// 在对话完成时调用
func processTurn(...) async {
    defer {
        // 对话完成后清理上下文
        if depth == 0 {  // 只在最外层清理
            cleanupConversation(conversationId)
        }
    }
    // ... 原有逻辑
}
```

### 方案 2: 监听会话删除事件

```swift
// 监听 SwiftData 的删除通知
init(...) {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleConversationDeleted(_:)),
        name: .conversationDidChange,
        object: nil
    )
}

@objc private func handleConversationDeleted(_ notification: Notification) {
    guard let conversationId = notification.userInfo?["conversationId"] as? UUID else { return }
    turnContexts.removeValue(forKey: conversationId)
}
```

### 方案 3: 使用弱引用或 TTL 机制

```swift
// 使用带过期时间的缓存
private var turnContexts: [UUID: (context: TurnContext, expiresAt: Date)] = [:]

private func cleanupExpiredContexts() {
    let now = Date()
    turnContexts = turnContexts.filter { $0.value.expiresAt > now }
}
```

### 方案 4: 结合 Coordinator 统一清理

```swift
// 在 ConversationTurnCoordinator 中添加清理逻辑
func finishTurn(conversationId: UUID) {
    // 通知 ViewModel 清理
    conversationTurnViewModel.cleanupConversation(conversationId)
}
```

---

## 🔍 相关代码位置

需要同时检查和修复的位置：

| 文件 | 类/属性 | 问题 |
|------|---------|------|
| `ConversationTurnViewModel.swift` | `turnContexts` | ❌ 无清理 |
| `ConversationRuntimeStore.swift` | 多个 `ByConversation` 字典 | ⚠️ 需检查清理逻辑 |
| `AgentProvider.swift` | 协调清理逻辑 | ✅ 应负责触发清理 |

---

## 📝 修复优先级

- [ ] **P0 - 立即修复**: 添加 `cleanupConversation(_:)` 方法
- [ ] **P1 - 集成测试**: 验证删除会话后内存正确释放
- [ ] **P2 - 全面审计**: 检查其他 `ByConversation` 字典的清理逻辑
- [ ] **P3 - 监控**: 添加内存使用监控和日志

---

## 🧪 测试建议

```swift
// 内存泄漏测试
func testConversationContextCleanup() async {
    let viewModel = ConversationTurnViewModel(...)
    
    // 创建多个会话
    let conversationIds = (0..<100).map { _ in UUID() }
    
    // 模拟对话
    for id in conversationIds {
        await viewModel.processTurn(conversationId: id, ...)
    }
    
    // 验证上下文数量
    XCTAssertEqual(viewModel.turnContexts.count, 100)
    
    // 清理所有会话
    for id in conversationIds {
        viewModel.cleanupConversation(id)
    }
    
    // 验证清理后为空
    XCTAssertEqual(viewModel.turnContexts.count, 0)
}
```

---

## 📚 参考资源

- [Swift Memory Management](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/)
- [Detecting Memory Leaks with Xcode](https://developer.apple.com/documentation/xcode/addressing-memory-issues-in-your-app)
- [Swift Concurrency Best Practices](https://developer.apple.com/documentation/swift/concurrency)

---

**创建日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `memory-leak`, `high-priority`, `performance`
**相关问题**: issue-002-unchecked-sendable-concurrency.md
