# Issue #15: ConversationRuntimeStore 潜在内存泄漏

**严重程度**: 🟠 High  
**状态**: Open  
**文件**: `LumiApp/Core/Stores/ConversationRuntimeStore.swift`

---

## 问题描述

`ConversationRuntimeStore` 中的多个字典存储会话状态，但 `cleanupConversationState` 方法可能没有完全清理所有状态，导致内存泄漏。

---

## 当前代码分析

```swift
@MainActor
final class ConversationRuntimeStore: ObservableObject {
    // 多个字典存储状态
    @Published var streamStateByConversation: [UUID: StreamSessionState] = [:]
    var thinkingTextByConversation: [UUID: String] = [:]
    var pendingStreamTextByConversation: [UUID: String] = [:]
    var pendingThinkingTextByConversation: [UUID: String] = [:]
    var lastStreamFlushAtByConversation: [UUID: Date] = [:]
    var lastThinkingFlushAtByConversation: [UUID: Date] = [:]
    
    var thinkingConversationIds = Set<UUID>()
    var processingConversationIds = Set<UUID>()
    
    var pendingPermissionByConversation: [UUID: PermissionRequest] = [:]
    var depthWarningByConversation: [UUID: DepthWarning] = [:]
    var errorMessageByConversation: [UUID: String?] = [:]
    var lastHeartbeatByConversation: [UUID: Date?] = [:]
    
    var streamStartedAtByConversation: [UUID: Date] = [:]
    var didReceiveFirstTokenByConversation: Set<UUID> = []
    var statusMessageIdByConversation: [UUID: UUID] = [:]
    
    var lastUserSendAtByConversation: [UUID: Date] = [:]
    var lastUserSendContentByConversation: [UUID: String] = [:]
    var postProcessedMessageIdsByConversation: [UUID: Set<UUID>] = [:]
    
    // 清理方法
    func cleanupConversationState(_ conversationId: UUID) {
        // 清理了部分...
        // 但可能遗漏了一些
    }
}
```

---

## 问题分析

### 1. 遗漏清理的状态

```swift
func cleanupConversationState(_ conversationId: UUID) {
    // ✅ 已清理
    streamStateByConversation.removeValue(forKey: conversationId)
    thinkingTextByConversation.removeValue(forKey: conversationId)
    // ...
    
    // ❌ 可能遗漏
    // lastUserSendAtByConversation - 未清理
    // lastUserSendContentByConversation - 未清理
    // postProcessedMessageIdsByConversation - 未清理
    // didReceiveFirstTokenByConversation - Set 需要移除
}
```

### 2. Set 类型的清理问题

```swift
var thinkingConversationIds = Set<UUID>()
var processingConversationIds = Set<UUID>()
var didReceiveFirstTokenByConversation: Set<UUID> = []

// 清理时：
thinkingConversationIds.remove(conversationId)  // ✅ 正确
processingConversationIds.remove(conversationId)  // ✅ 正确
didReceiveFirstTokenByConversation.remove(conversationId)  // ❌ 可能遗漏
```

### 3. 嵌套结构的清理

```swift
var postProcessedMessageIdsByConversation: [UUID: Set<UUID>] = [:]

// 这个字典的值是 Set，如果只删除 key，Set 中的 UUID 可能不会释放
```

### 4. @Published 属性的副作用

```swift
@Published var streamStateByConversation: [UUID: StreamSessionState] = [:]

// 修改 @Published 属性会触发 UI 更新
// 频繁清理可能导致不必要的 UI 刷新
```

---

## 建议修复

### 1. 完善清理方法

```swift
func cleanupConversationState(_ conversationId: UUID) {
    // 清理所有字典类型的状态
    streamStateByConversation.removeValue(forKey: conversationId)
    thinkingTextByConversation.removeValue(forKey: conversationId)
    pendingStreamTextByConversation.removeValue(forKey: conversationId)
    pendingThinkingTextByConversation.removeValue(forKey: conversationId)
    lastStreamFlushAtByConversation.removeValue(forKey: conversationId)
    lastThinkingFlushAtByConversation.removeValue(forKey: conversationId)
    
    // 清理 Set 类型
    thinkingConversationIds.remove(conversationId)
    processingConversationIds.remove(conversationId)
    didReceiveFirstTokenByConversation.remove(conversationId)
    
    // 清理其他字典
    pendingPermissionByConversation.removeValue(forKey: conversationId)
    depthWarningByConversation.removeValue(forKey: conversationId)
    errorMessageByConversation.removeValue(forKey: conversationId)
    lastHeartbeatByConversation.removeValue(forKey: conversationId)
    streamStartedAtByConversation.removeValue(forKey: conversationId)
    statusMessageIdByConversation.removeValue(forKey: conversationId)
    
    // ✅ 补充遗漏的清理
    lastUserSendAtByConversation.removeValue(forKey: conversationId)
    lastUserSendContentByConversation.removeValue(forKey: conversationId)
    postProcessedMessageIdsByConversation.removeValue(forKey: conversationId)
    
    updateRuntimeState(for: conversationId)
}
```

### 2. 添加批量清理方法

```swift
/// 清理所有已结束的会话状态
func cleanupFinishedConversations() {
    let activeIds = Set(streamStateByConversation.keys)
    
    // 清理所有非活跃会话的状态
    for key in thinkingTextByConversation.keys {
        if !activeIds.contains(key) {
            cleanupConversationState(key)
        }
    }
}

/// 清理超过指定时间的会话
func cleanupStaleConversations(olderThan timeInterval: TimeInterval) {
    let cutoff = Date().addingTimeInterval(-timeInterval)
    
    for (id, date) in lastHeartbeatByConversation {
        if let heartbeat = date, heartbeat < cutoff {
            cleanupConversationState(id)
        }
    }
}
```

### 3. 添加状态统计

```swift
/// 获取内存使用统计
func memoryStats() -> MemoryStats {
    MemoryStats(
        activeConversations: streamStateByConversation.count,
        thinkingStates: thinkingTextByConversation.count,
        pendingPermissions: pendingPermissionByConversation.count,
        cachedMessages: postProcessedMessageIdsByConversation.values.reduce(0) { $0 + $1.count }
    )
}

struct MemoryStats {
    let activeConversations: Int
    let thinkingStates: Int
    let pendingPermissions: Int
    let cachedMessages: Int
    
    var estimatedMemory: Int {
        // 粗略估算内存占用
        activeConversations * 1024 +  // 每个会话约 1KB
        thinkingStates * 512 +
        cachedMessages * 64  // 每个 UUID 16 字节
    }
}
```

### 4. 自动清理机制

```swift
/// 定期清理
func startAutoCleanup(interval: TimeInterval = 300) {
    Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.cleanupStaleConversations(olderThan: 3600)  // 1 小时未活动
            self?.logMemoryStats()
        }
    }
}

private func logMemoryStats() {
    let stats = memoryStats()
    os_log(.info, "ConversationRuntimeStore: \(stats.activeConversations) active, ~\(stats.estimatedMemory) bytes")
}
```

### 5. 使用弱引用优化

```swift
// 考虑使用弱引用避免循环引用
final class ConversationState {
    weak var conversation: Conversation?
    // ... 其他状态
}
```

### 6. 添加单元测试

```swift
class ConversationRuntimeStoreTests: XCTestCase {
    var store: ConversationRuntimeStore!
    
    override func setUp() {
        store = ConversationRuntimeStore()
    }
    
    func testCleanupRemovesAllState() {
        let id = UUID()
        
        // 设置所有状态
        store.thinkingTextByConversation[id] = "test"
        store.lastUserSendAtByConversation[id] = Date()
        store.postProcessedMessageIdsByConversation[id] = [UUID(), UUID()]
        store.didReceiveFirstTokenByConversation.insert(id)
        
        // 清理
        store.cleanupConversationState(id)
        
        // 验证所有状态都被清理
        XCTAssertNil(store.thinkingTextByConversation[id])
        XCTAssertNil(store.lastUserSendAtByConversation[id])
        XCTAssertNil(store.postProcessedMessageIdsByConversation[id])
        XCTAssertFalse(store.didReceiveFirstTokenByConversation.contains(id))
    }
    
    func testMemoryDoesNotLeak() {
        // 创建大量会话
        for _ in 0..<1000 {
            let id = UUID()
            store.thinkingTextByConversation[id] = String(repeating: "a", count: 10000)
        }
        
        let beforeMemory = store.memoryStats().estimatedMemory
        
        // 清理所有
        for id in Array(store.thinkingTextByConversation.keys) {
            store.cleanupConversationState(id)
        }
        
        let afterMemory = store.memoryStats().estimatedMemory
        
        // 验证内存被释放
        XCTAssertLessThan(afterMemory, beforeMemory / 10)
    }
}
```

---

## 修复优先级

高 - 内存泄漏可能导致：
- 应用内存持续增长
- 长时间运行后崩溃
- 用户体验下降

---

*创建时间: 2026-03-13*