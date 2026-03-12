# Issue #017: 严重 - ToolService NotificationCenter 观察者泄漏

## 📋 问题概述

`ToolService` 在 `setupPluginObservers()` 方法中注册了 `NotificationCenter` 观察者，但该类没有实现 `deinit` 方法来移除这些观察者。由于 `ToolService` 是一个 `@unchecked Sendable` class 而非 actor，它可能被多个地方持有和释放，导致观察者泄漏。

---

## 🔴 严重程度：Critical

**风险等级**: ⚠️ 可能导致：
- NotificationCenter 继续向已释放的对象发送通知
- 内存泄漏（观察者持有的引用无法释放）
- 潜在的崩溃（野指针访问）
- 重复处理通知导致逻辑错误

**优先级**: P0 - 需要立即修复

---

## 📍 问题位置

### 文件: `LumiApp/Core/Services/Tools/ToolService.swift`

| 属性 | 值 |
|------|-----|
| 行号 | 61 (class 定义), 128-150 (addObserver 调用) |
| 问题 | 注册 NotificationCenter 观察者但没有 deinit 清理 |

---

## 🐛 问题分析

### 问题代码

**ToolService.swift (行 61, 128-150)**:
```swift
class ToolService: SuperLog, @unchecked Sendable {
    // ...
    
    @MainActor
    private func setupPluginObservers() {
        // ❌ 问题：注册观察者但没有保存返回值
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PluginsDidLoad"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("toolSourcesDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }
    }
    
    // ❌ 问题：没有 deinit 方法来移除观察者
}
```

### 为什么 [weak self] 不够

虽然闭包使用了 `[weak self]`，但 `addObserver(forName:object:queue:)` 返回一个 `NSObjectProtocol` 观察者令牌，需要显式保存并在 deinit 时移除：

```swift
// 问题链：
NotificationCenter.default.addObserver(...)
    ↓
返回观察者令牌（被丢弃）❌
    ↓
ToolService 被释放
    ↓
观察者仍然存在于 NotificationCenter 中 ❌
    ↓
下次通知触发时，闭包执行但 self 已为 nil
    ↓
虽然不会崩溃（因为 weak self），但观察者对象本身泄漏
```

### 内存泄漏详情

1. **观察者对象泄漏**: `addObserver(forName:object:queue:)` 创建的 `NSObjectProtocol` 对象没有被释放
2. **闭包捕获**: 闭包捕获的 `self` 虽然是 weak，但闭包本身仍被 NotificationCenter 持有
3. **无法清理**: 没有方法可以移除这些观察者

---

## ✅ 修复方案

### 方案 1: 保存观察者令牌并在 deinit 移除（推荐）

```swift
class ToolService: SuperLog, @unchecked Sendable {
    // MARK: - Properties
    
    /// NotificationCenter 观察者令牌
    private var observers: [NSObjectProtocol] = []
    
    // ... 其他属性
    
    @MainActor
    private func setupPluginObservers() {
        let pluginsDidLoadObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PluginsDidLoad"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }
        observers.append(pluginsDidLoadObserver)

        let toolSourcesObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("toolSourcesDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }
        observers.append(toolSourcesObserver)
    }
    
    deinit {
        // 移除所有观察者
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
}
```

### 方案 2: 使用 NotificationCenter 的 publisher（SwiftUI 风格）

```swift
class ToolService: SuperLog, @unchecked Sendable {
    private var cancellables = Set<AnyCancellable>()
    
    @MainActor
    private func setupPluginObservers() {
        NotificationCenter.default
            .publisher(for: NSNotification.Name("PluginsDidLoad"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshAllTools()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSNotification.Name("toolSourcesDidChange"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshAllTools()
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll() // 自动取消所有订阅
    }
}
```

### 方案 3: 使用 Notification.Name 扩展和类型安全的通知

```swift
// 定义类型安全的通知
extension Notification.Name {
    static let pluginsDidLoad = Notification.Name("PluginsDidLoad")
    static let toolSourcesDidChange = Notification.Name("toolSourcesDidChange")
}

// ToolService 使用类型安全的通知
class ToolService: SuperLog, @unchecked Sendable {
    private var observers: [NSObjectProtocol] = []
    
    @MainActor
    private func setupPluginObservers() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .pluginsDidLoad,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshAllTools()
                }
            }
        )
        // ...
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
```

---

## 📝 修复优先级

| 优先级 | 任务 | 预计工作量 |
|--------|------|-----------|
| **P0** | 为 ToolService 添加 deinit 清理观察者 | 30 分钟 |
| **P1** | 审计其他使用 addObserver 的类 | 2 小时 |
| **P2** | 创建统一的通知管理工具类 | 4 小时 |

---

## 🔍 影响范围

### 直接影响
- `ToolService` - 核心工具管理服务
- 所有依赖工具功能的模块

### 间接影响
- 插件系统
- Agent 功能
- MCP 工具集成

---

## 🔄 相关 Issue

- **Issue #005**: 系统性 NotificationCenter 观察者泄漏
- **Issue #011**: Actor Plugin 无法管理观察者
- **Issue #016**: AsyncStream Continuation 资源泄漏

---

## 🧪 测试建议

1. **内存泄漏测试**:
```swift
func testToolServiceNoMemoryLeak() {
    weak var weakToolService: ToolService?
    
    autoreleasepool {
        let toolService = ToolService(llmService: nil)
        weakToolService = toolService
        XCTAssertNotNil(weakToolService)
    }
    
    // 等待 RunLoop 处理
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    
    // 应该已被释放
    XCTAssertNil(weakToolService)
}
```

2. **通知观察者测试**:
```swift
func testNotificationObserversRemoved() {
    let toolService = ToolService(llmService: nil)
    
    // 发送通知，验证处理
    NotificationCenter.default.post(name: NSNotification.Name("PluginsDidLoad"), object: nil)
    
    // 释放后再次发送，不应崩溃
    let expectation = XCTestExpectation(description: "No crash after deinit")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NotificationCenter.default.post(name: NSNotification.Name("PluginsDidLoad"), object: nil)
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 1.0)
}
```

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `memory-leak`, `critical`, `notificationcenter`, `tool-service`