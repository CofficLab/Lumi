# Issue #005: 严重内存泄漏 - NotificationCenter 观察者未正确移除

## 📋 问题概述

项目中存在**系统性**的 NotificationCenter 观察者内存泄漏问题，多个核心服务和控制器注册了 NotificationCenter 观察者但未在析构时正确移除，导致严重的内存泄漏和潜在的野指针崩溃。

---

## 🔴 严重程度：Critical (最高级别)

**风险等级**: ⚠️ 可能导致：
- 应用内存持续增长，最终被系统终止
- 已释放对象收到通知导致野指针崩溃
- 应用长期运行后性能严重下降
- 用户数据丢失

**优先级**: P0 - 需要立即修复

---

## 📍 问题位置

### 受影响的文件统计：

| # | 文件路径 | addObserver | removeObserver | deinit | 风险级别 |
|---|----------|-------------|----------------|--------|----------|
| 1 | `LumiApp/Core/Services/Tools/ToolService.swift` | 2 | 0 | 0 | 🔴 高 |
| 2 | `LumiApp/Core/Controllers/StatusBarController.swift` | 4 | 1 | 0 | 🔴 高 |
| 3 | `LumiApp/Core/Controllers/UpdateController.swift` | 1 | 0 | 0 | 🔴 高 |
| 4 | `LumiApp/Core/Coordinators/ConversationTurnCoordinator.swift` | 1 | 0 | 0 | 🔴 高 |
| 5 | `LumiApp/Plugins/AgentFilePreviewPlugin/FilePreviewPlugin.swift` | ? | ? | ? | 🟡 中 |
| 6 | `LumiApp/Plugins/NetworkManagerPlugin/ProcessNetworkMonitor/ProcessMonitorService.swift` | ? | ? | ? | 🟡 中 |
| 7 | `LumiApp/Plugins/AgentMessagesAppKitPlugin/Chat/MessageListAppKitContainerView.swift` | ? | ? | ? | 🟡 中 |

**总计**: 至少 **8+ 处** NotificationCenter 观察者可能泄漏

---

## 🐛 问题分析

### 问题 1: ToolService - 观察者 token 未存储

**文件**: `LumiApp/Core/Services/Tools/ToolService.swift`

**问题代码**:
```swift
@MainActor
private func setupPluginObservers() {
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
// ❌ 问题：
// 1. addObserver(forName:object:queue:using:) 返回的观察者 token 未被存储
// 2. 类中没有 deinit 方法来移除观察者
// 3. 即使有 [weak self]，NotificationCenter 仍持有观察者 token
```

**后果**:
- 每次创建 ToolService 实例都会泄漏 2 个观察者
- NotificationCenter 永远不会释放这些观察者
- 即使 self 已被释放，NotificationCenter 仍持有无效的 token

### 问题 2: StatusBarController - 观察者数量不匹配

**文件**: `LumiApp/Core/Controllers/StatusBarController.swift`

**统计**:
- 4 个 `addObserver` 调用
- 仅 1 个 `removeObserver` 调用
- 0 个 `deinit` 方法

**后果**: 至少 3 个观察者泄漏

### 问题 3: UpdateController & ConversationTurnCoordinator

这两个文件都注册了观察者，但：
- 没有 `removeObserver` 调用
- 没有 `deinit` 方法

---

## ⚠️ 为什么这是严重问题？

### 1. 内存泄漏链

```
ToolService 初始化
    ↓
setupPluginObservers() 被调用
    ↓
NotificationCenter 持有观察者 token
    ↓
ToolService 被释放
    ↓
NotificationCenter 仍持有 token ❌
    ↓
内存泄漏 + 潜在野指针
```

### 2. Swift ARC 无法解决

虽然代码使用了 `[weak self]`，但这只防止了闭包捕获 self。**NotificationCenter 仍然持有返回的观察者 token**，这个 token 必须显式移除。

### 3. 长期运行影响

- macOS 应用通常长时间运行
- 每次窗口/会话重建都会累积泄漏
- 几小时/几天后内存占用可能达到数百 MB

---

## ✅ 修复方案

### 方案 1: 存储观察者 token 并在 deinit 中移除（推荐）

```swift
class ToolService: SuperLog, @unchecked Sendable {
    
    // 存储观察者 token
    private var observers: [NSObjectProtocol] = []
    
    @MainActor
    private func setupPluginObservers() {
        let observer1 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PluginsDidLoad"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }
        observers.append(observer1)
        
        let observer2 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("toolSourcesDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }
        observers.append(observer2)
    }
    
    deinit {
        // 移除所有观察者
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
```

### 方案 2: 使用 Combine 替代 NotificationCenter（推荐用于新代码）

```swift
import Combine

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
        // AnyCancellable 自动清理
        cancellables.removeAll()
    }
}
```

### 方案 3: 使用 NotificationCenter 的 selector 模式

```swift
class ToolService: SuperLog, @unchecked Sendable {
    
    @MainActor
    private func setupPluginObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePluginsDidLoad),
            name: NSNotification.Name("PluginsDidLoad"),
            object: nil
        )
    }
    
    @objc private func handlePluginsDidLoad(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.refreshAllTools()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

---

## 🔍 验证方法

### 1. 使用 Instruments Allocations

```
1. 打开 Instruments → Allocations
2. 运行应用
3. 创建/销毁窗口多次
4. 搜索 "ToolService" 或 "NotificationCenter"
5. 观察是否有持续增长的实例
```

### 2. 添加日志验证

```swift
deinit {
    os_log(.info, "🧹 ToolService 正在销毁，移除 \(observers.count) 个观察者")
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers.removeAll()
}
```

### 3. 单元测试

```swift
func testToolServiceMemoryLeak() {
    weak var weakService: ToolService?
    
    autoreleasepool {
        let service = ToolService()
        weakService = service
    }
    
    // 应该为 nil，否则存在内存泄漏
    XCTAssertNil(weakService, "ToolService 应该被正确释放")
}
```

---

## 📝 修复清单

| 优先级 | 文件 | 状态 | 工作量 |
|--------|------|------|--------|
| **P0** | `ToolService.swift` | 🔴 待修复 | 1 小时 |
| **P0** | `StatusBarController.swift` | 🔴 待修复 | 1 小时 |
| **P1** | `UpdateController.swift` | 🔴 待修复 | 30 分钟 |
| **P1** | `ConversationTurnCoordinator.swift` | 🔴 待修复 | 30 分钟 |
| **P2** | 插件文件（3 个） | 🟡 待审计 | 2 小时 |

---

## 🔄 相关 Issue

- **Issue #001**: ChatMessageEntity 强制解包崩溃风险
- **Issue #002**: 系统性并发安全隐患 - @unchecked Sendable
- **Issue #003**: TurnContexts 内存泄漏问题
- **Issue #004**: 详细日志敏感数据泄露

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `memory-leak`, `critical`, `NotificationCenter`, `resource-management`