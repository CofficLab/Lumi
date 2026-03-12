# Issue #016: 严重 - AsyncStream Continuation 资源泄漏

## 📋 问题概述

`ConversationTurnViewModel` 和 `MessageSenderViewModel` 创建了 `AsyncStream` 及其 `Continuation`，但在类销毁时没有调用 `continuation.finish()` 来正确关闭流。这会导致：
1. 流的消费者永远等待下一个事件
2. 相关的 Task 无法正常完成
3. 潜在的资源泄漏

---

## 🔴 严重程度：Critical

**风险等级**: ⚠️ 可能导致：
- 消费 AsyncStream 的 Task 永远挂起
- 内存泄漏（流和消费者无法释放）
- 应用逻辑异常（无法正常终止处理流程）
- 用户界面卡顿或无响应

**优先级**: P0 - 需要立即修复

---

## 📍 问题位置

### 文件 1: `LumiApp/Core/ViewModels/ConversationTurnViewModel.swift`

| 属性 | 值 |
|------|-----|
| 行号 | 42-47, 105, 185, 202-203 等 |
| 问题 | `eventContinuation` 未在 deinit 时调用 `finish()` |

### 文件 2: `LumiApp/Core/ViewModels/MessageSenderViewModel.swift`

| 属性 | 值 |
|------|-----|
| 行号 | 30-35, 148, 169 等 |
| 问题 | `eventContinuation` 未在 deinit 时调用 `finish()` |

---

## 🐛 问题分析

### 问题代码

**ConversationTurnViewModel.swift (行 42-47)**:
```swift
var events: AsyncStream<ConversationTurnEvent> {
    AsyncStream { continuation in
        self.eventContinuation = continuation
    }
}

private var eventContinuation: AsyncStream<ConversationTurnEvent>.Continuation?

// ❌ 问题：没有 deinit 方法来调用 finish()
// 当 ViewModel 被释放时，流不会关闭
// 消费者（ConversationTurnCoordinator）会永远等待
```

**MessageSenderViewModel.swift (行 30-35)**:
```swift
var events: AsyncStream<MessageSendEvent> {
    AsyncStream { continuation in
        self.eventContinuation = continuation
    }
}

private var eventContinuation: AsyncStream<MessageSendEvent>.Continuation?

// ❌ 问题：没有 deinit 方法来调用 finish()
```

### 内存泄漏链

```
ViewModel 创建 AsyncStream
    ↓
Coordinator 订阅 events (for await event in viewModel.events)
    ↓
ViewModel 被释放（如切换会话/窗口关闭）
    ↓
deinit 未实现 → continuation.finish() 未调用 ❌
    ↓
AsyncStream 未关闭
    ↓
Coordinator 的 for await 循环继续等待
    ↓
Task 永远挂起 → 内存泄漏
```

### 为什么这很危险

1. **隐式泄漏**: 不会立即崩溃，但资源无法释放
2. **累积效应**: 随着用户使用应用，泄漏的资源越来越多
3. **难以调试**: 没有明显的错误信号，问题可能在长时间运行后才显现
4. **影响范围广**: 整个对话处理链都依赖这些流

---

## ✅ 修复方案

### 方案 1: 添加 deinit 调用 finish()（推荐）

```swift
// ConversationTurnViewModel.swift
deinit {
    eventContinuation?.finish()
}

// MessageSenderViewModel.swift
deinit {
    eventContinuation?.finish()
}
```

### 方案 2: 使用 onTermination 回调（更安全）

```swift
// ConversationTurnViewModel.swift
var events: AsyncStream<ConversationTurnEvent> {
    AsyncStream { continuation in
        self.eventContinuation = continuation
        continuation.onTermination = { [weak self] _ in
            self?.eventContinuation = nil
        }
    }
}

deinit {
    eventContinuation?.finish()
}
```

### 方案 3: 使用 Finalizers 确保 cleanup

```swift
// 在初始化时设置清理逻辑
init() {
    // ... 其他初始化
    
    // 当实例被释放时，确保流被关闭
    _ = SelfCleanupBox { [weak self] in
        self?.eventContinuation?.finish()
    }
}

// 辅助类
private class SelfCleanupBox {
    let cleanup: () -> Void
    init(cleanup: @escaping () -> Void) {
        self.cleanup = cleanup
    }
    deinit {
        cleanup()
    }
}
```

---

## 📝 修复优先级

| 优先级 | 任务 | 预计工作量 |
|--------|------|-----------|
| **P0** | 为 ConversationTurnViewModel 添加 deinit | 15 分钟 |
| **P0** | 为 MessageSenderViewModel 添加 deinit | 15 分钟 |
| **P1** | 审计其他使用 AsyncStream 的类 | 1 小时 |
| **P2** | 添加单元测试验证流正确关闭 | 2 小时 |

---

## 🔍 影响范围

### 直接影响
- `ConversationTurnCoordinator` - 订阅 ConversationTurnViewModel.events
- `MessageSendCoordinator` - 订阅 MessageSenderViewModel.events

### 潜在影响
- AgentProvider - 持有这些 ViewModel 的引用
- 整个对话处理流程

---

## 🔄 相关 Issue

- **Issue #010**: Coordinator 缺少 deinit 导致 Task 泄漏
- **Issue #015**: ConversationTurnViewModel 资源泄漏
- **Issue #005**: 系统性 NotificationCenter 观察者泄漏

---

## 🧪 测试建议

1. **单元测试**:
```swift
func testAsyncStreamFinishedOnDeinit() async {
    var viewModel: ConversationTurnViewModel? = ConversationTurnViewModel(...)
    let events = viewModel!.events
    
    // 在另一个 Task 中消费流
    let consumerTask = Task {
        var count = 0
        for await _ in events {
            count += 1
        }
        return count
    }
    
    // 释放 ViewModel
    viewModel = nil
    
    // 流应该结束
    let result = await consumerTask.value
    XCTAssertEqual(result, 0) // 没有事件，但流正常结束
}
```

2. **内存泄漏测试**:
   - 使用 Instruments 的 Allocations 工具
   - 反复创建和销毁 ViewModel
   - 检查内存是否正常释放

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `memory-leak`, `critical`, `async-stream`, `continuation`