# Issue #010: 严重 - Coordinator 缺少 deinit 导致 Task 泄漏

## 📋 问题概述

`ConversationTurnCoordinator` 和 `MessageSendCoordinator` 在类中创建了 `Task` 对象，但没有实现 `deinit` 方法来在对象释放前取消任务。这导致协程运行时间超过预期，可能引发资源泄漏和意外行为。

---

## 🔴 严重程度：Critical (最高)

**风险等级**: ⚠️ 可能导致：
- Task 继续运行在已释放的对象上，导致未定义行为
- 内存泄漏（Task 捕获的对象无法释放）
- 重复处理相同事件
- 应用性能逐渐下降

**优先级**: P0 - 需要立即修复

---

## 📍 问题位置

### 文件 1: `LumiApp/Core/Coordinators/ConversationTurnCoordinator.swift`

| 属性 | 值 |
|------|-----|
| 行号 | 20, 76, 93, 129 |
| 问题 | `private var task: Task<Void, Never>?` 无 deinit |

### 文件 2: `LumiApp/Core/Coordinators/MessageSendCoordinator.swift`

| 属性 | 值 |
|------|-----|
| 行号 | 32, 54, 101 |
| 问题 | `private var task: Task<Void, Never>?` 无 deinit |

---

## 🐛 问题分析

### 问题代码

**ConversationTurnCoordinator.swift (行 20)**:
```swift
private var task: Task<Void, Never>?

func start() {
    task?.cancel()  // 仅在 start 时取消旧任务
    
    task = Task { [weak self] in
        // ... 长时间运行的协程
        for await event in self?.conversationTurnViewModel.events { ... }
    }
    // ❌ 问题：没有 deinit 方法
    // 当 Coordinator 被释放时，task 不会被取消
    // 任务会继续运行，可能访问已释放的 self
}
```

**MessageSendCoordinator.swift (行 32)**:
```swift
private var task: Task<Void, Never>?

func send() {
    task?.cancel()  // 仅在 send 时取消旧任务
    
    task = Task { [weak self] in
        // ... 发送消息的协程
    }
    // ❌ 问题：没有 deinit 方法
}
```

### 内存泄漏链

```
用户关闭对话窗口
    ↓
ConversationTurnCoordinator 即将释放
    ↓
deinit 未实现 → task 仍在运行 ❌
    ↓
Task 闭包捕获 self (通过 [weak self] 仍可能有引用)
    ↓
Coordinator 无法完全释放 → 内存泄漏
    ↓
Task 完成后才释放，但此时已访问可能已销毁的对象
```

### 为什么 [weak self] 不够

虽然代码使用了 `[weak self]`，但存在以下问题：

1. **Task 启动到完成需要时间**：在 Task 完成前，Coordinator 的释放会被延迟
2. **for await 循环**：在事件流结束前，self 引用会一直保持
3. **后台任务持续运行**：即使 UI 已关闭，后台 Task 仍在消耗资源

---

## ✅ 修复方案

### 方案 1: 添加 deinit 取消 Task（推荐）

```swift
// ConversationTurnCoordinator.swift
deinit {
    task?.cancel()
    task = nil
    
    // 移除通知观察者
    if let observer = pluginsDidLoadObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

```swift
// MessageSendCoordinator.swift
deinit {
    task?.cancel()
    task = nil
}
```

### 方案 2: 使用 withTaskCancellationHandler（替代方案）

```swift
func start() {
    task?.cancel()
    
    task = Task { [weak self] in
        defer {
            // 确保任务完成时清理
            self?.task = nil
        }
        // ... 任务逻辑
    }
}
```

---

## 📝 修复优先级

| 优先级 | 任务 | 预计工作量 |
|--------|------|-----------|
| **P0** | 为 ConversationTurnCoordinator 添加 deinit | 30 分钟 |
| **P0** | 为 MessageSendCoordinator 添加 deinit | 30 分钟 |
| **P1** | 审计其他包含 Task 的类 | 2 小时 |

---

## 🔄 相关 Issue

- **Issue #005**: NotificationCenter 观察者内存泄漏
- **Issue #009**: 系统性 NotificationCenter 观察者泄漏

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `memory-leak`, `critical`, `concurrency`