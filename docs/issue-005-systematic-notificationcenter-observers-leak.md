# Issue #005: 系统性 NotificationCenter 观察者泄漏（Critical）

## 📋 问题概述

项目中存在**系统性**的 NotificationCenter 观察者内存泄漏问题，多个核心服务和控制器注册了 NotificationCenter 观察者但未在析构时正确移除，导致严重的内存泄漏和潜在的野指针崩溃。

这是 macOS/long-running 应用中最危险的内存泄漏类型之一。

---

## 🔴 严重程度：Critical (最高级别)

**风险等级**: ⚠️ 可能导致：
- 应用内存持续增长，最终被系统终止
- 已释放对象收到通知导致野指针崩溃
- 应用长期运行后性能严重下降
- 用户数据丢失

**优先级**: P0 - 需要立即修复

---

## 📍 问题位置汇总

### Core 层（已确认泄漏）

| # | 文件路径 | addObserver | removeObserver | deinit | 风险级别 |
|---|----------|-------------|----------------|--------|----------|
| 1 | `LumiApp/Core/Services/Tools/ToolService.swift` | 2 | 0 | ❌ | 🔴 高 |
| 2 | `LumiApp/Core/Controllers/StatusBarController.swift` | 4 | 1 | ❌ | 🔴 高 |
| 3 | `LumiApp/Core/Controllers/UpdateController.swift` | 1 | 0 | ❌ | 🔴 高 |
| 4 | `LumiApp/Core/Coordinators/ConversationTurnCoordinator.swift` | 1 | 0 | ❌ | 🔴 高 |
| 5 | `LumiApp/Core/Services/WindowManager.swift` | 3 | 1 | ⚠️ 不完整 | 🔴 高 |

### Plugin 层

| # | 文件路径 | addObserver | removeObserver | 风险 |
|---|----------|-------------|----------------|------|
| 1 | `LumiApp/Plugins/AgentFilePreviewPlugin/FilePreviewPlugin.swift` | 1 | ❌ 无 deinit | 🔴 Actor 限制 |
| 2 | `LumiApp/Plugins/NetworkManagerPlugin/ProcessNetworkMonitor/ProcessMonitorService.swift` | 1 | ? | 🟡 中 |
| 3 | `LumiApp/Plugins/AgentMessagesAppKitPlugin/Chat/MessageListAppKitContainerView.swift` | 1 | 1 | 🟢 低 |

**总计**: 至少 **15+ 处** NotificationCenter 观察者存在潜在泄漏

---

## 🐛 问题分析

### 问题模式 1: 观察者 token 未存储

**典型代码** (ToolService.swift):
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
    // ❌ 问题：
    // 1. addObserver 返回的观察者 token 未被存储
    // 2. 类中没有 deinit 方法来移除观察者
    // 3. 即使有 [weak self]，NotificationCenter 仍持有观察者 token
}
```

### 问题模式 2: 观察者数量不匹配

**典型代码** (StatusBarController.swift):
```swift
// 4 个 addObserver 调用
NotificationCenter.default.addObserver(self, selector: #selector(handle1), name: ...)
NotificationCenter.default.addObserver(self, selector: #selector(handle2), name: ...)
NotificationCenter.default.addObserver(self, selector: #selector(handle3), name: ...)
NotificationCenter.default.addObserver(self, selector: #selector(handle4), name: ...)

// 仅 1 个 removeObserver 调用
NotificationCenter.default.removeObserver(self)  // 不完整清理
```

### 问题模式 3: Actor 无法定义 deinit

**典型代码** (FilePreviewPlugin.swift):
```swift
actor FilePreviewPlugin: SuperPlugin {
    init() {
        NotificationCenter.default.addObserver(...)  // ❌ 无法移除
    }
    
    deinit {  // ❌ 编译错误：actor 不能有 deinit
        // 移除观察者 - 无法实现
    }
}
```

### 问题模式 4: 存储了 token 但未移除

**典型代码** (ConversationTurnCoordinator.swift):
```swift
private var pluginsDidLoadObserver: NSObjectProtocol?

func start() {
    pluginsDidLoadObserver = NotificationCenter.default.addObserver(...)
    // ❌ 问题：没有 deinit 方法来移除这个观察者
}
```

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

### 方案 1: 存储观察者 token 并在 deinit 中移除（通用）

```swift
class ToolService: SuperLog, @unchecked Sendable {
    // 存储观察者 token
    private var observers: [NSObjectProtocol] = []
    
    @MainActor
    private func setupPluginObservers() {
        let observer1 = NotificationCenter.default.addObserver(...)
        observers.append(observer1)
        
        let observer2 = NotificationCenter.default.addObserver(...)
        observers.append(observer2)
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
```

### 方案 2: 对于 actor Plugin（改为 class + actor）

```swift
// 改为 class
class FilePreviewPlugin: SuperPlugin, SuperLog {
    private let actor = FilePreviewActor()
    private var observer: NSObjectProtocol?
    
    init() {
        setupObserver()
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(...)
    }
}

// 内部 actor 处理并发逻辑
actor FilePreviewActor {
    func checkFileSelection() { ... }
}
```

### 方案 3: 使用静态观察者管理（全局方案）

```swift
class NotificationObserverManager {
    static var observers: [String: NSObjectProtocol] = [:]
    
    static func register(id: String, observer: NSObjectProtocol) {
        observers[id] = observer
    }
    
    static func unregister(id: String) {
        if let observer = observers[id] {
            NotificationCenter.default.removeObserver(observer)
            observers.removeValue(forKey: id)
        }
    }
    
    static func cleanupAll() {
        observers.values.forEach { 
            NotificationCenter.default.removeObserver($0) 
        }
        observers.removeAll()
    }
}
```

---

## 📝 修复优先级

| 优先级 | 任务 | 预计工作量 |
|--------|------|-----------|
| **P0** | 修复 ToolService (2个观察者) | 1 小时 |
| **P0** | 修复 StatusBarController (3个泄漏) | 1 小时 |
| **P0** | 修复 UpdateController (1个观察者) | 30 分钟 |
| **P0** | 修复 ConversationTurnCoordinator (1个观察者+Task) | 1 小时 |
| **P1** | 修复 WindowManager (2个观察者) | 1 小时 |
| **P1** | 重构 FilePreviewPlugin (actor → class) | 2 小时 |
| **P2** | 审计并修复其他 Plugin | 4 小时 |

---

## 🔍 审计命令

```bash
# 统计 addObserver vs removeObserver 数量
grep -rn "addObserver" --include="*.swift" LumiApp/ | wc -l
grep -rn "removeObserver" --include="*.swift" LumiApp/ | wc -l

# 查找所有 actor Plugin 中的 addObserver
grep -rn "^actor.*Plugin" --include="*.swift" LumiApp/Plugins/ | cut -d: -f1 | uniq | xargs grep -l "addObserver"

# 查找没有 deinit 的类中的 addObserver
find LumiApp -name "*.swift" -exec grep -l "addObserver" {} \; | xargs grep -L "deinit"
```

---

## 📋 相关 Issues

- **Issue #010**: Coordinator 缺少 deinit 导致 Task 泄漏（关联：ConversationTurnCoordinator）
- **Issue #011**: Actor Plugin 无法正确管理 NotificationCenter 观察者（设计问题）

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**合并版本**: 由 Issue #005 和 #009 合并而成
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `memory-leak`, `critical`, `notificationcenter`