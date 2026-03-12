# Issue #011: 高 - Actor 类型 Plugin 无法正确管理 NotificationCenter 观察者

## 📋 问题概述

项目中大量 Plugin 使用 `actor` 类型，但 actor 无法定义 `deinit` 方法。当这些 actor 在初始化时注册了 `NotificationCenter` 观察者时，观察者将永远无法被移除，导致严重的内存泄漏。

这是设计层面的系统性问题，影响多个 Plugin。

---

## 🔴 严重程度：High (高)

**风险等级**: ⚠️ 可能导致：
- NotificationCenter 观察者无法被移除
- 每个 Plugin 实例都会泄漏一个观察者
- 长期运行时内存持续增长
- 可能收到已释放对象的无效通知

**优先级**: P1 - 需要在下一版本修复

---

## 📍 问题位置

### 受影响的 Actor Plugins

| # | 文件路径 | addObserver | deinit 可能 | 风险 |
|---|----------|-------------|-------------|------|
| 1 | `LumiApp/Plugins/AgentFilePreviewPlugin/FilePreviewPlugin.swift` | ✅ 有 | ❌ 无 | 🔴 高 |
| 2 | 所有其他 actor Plugin（41个） | 需检查 | ❌ 无 | 🟡 中 |

### 详细代码 - FilePreviewPlugin.swift (行 45-60)

```swift
actor FilePreviewPlugin: SuperPlugin, SuperLog {
    /// 当前是否选择了文件
    @MainActor private var isFileSelected: Bool = false

    init() {
        // 监听文件选择变化通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AgentProviderFileSelectionChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.checkFileSelection()
            }
        }
        // ❌ 问题：actor 无法定义 deinit
        // 这个观察者永远无法被移除
    }
}
```

---

## 🐛 问题分析

### 问题 1: Actor 与 deinit 不兼容

Swift 的 actor 是隔离的，无法定义 `deinit` 方法：

```swift
actor FilePreviewPlugin {
    init() {
        // 添加观察者
    }
    
    deinit {  // ❌ 编译错误：actor 不能有 deinit
        // 移除观察者 - 无法实现
    }
}
```

### 问题 2: 观察者生命周期

```
FilePreviewPlugin.shared 初始化
    ↓
NotificationCenter 添加观察者 (无法移除)
    ↓
Plugin 长期存在于内存中
    ↓
每次通知发出，观察者闭包都会被执行
    ↓
即使 Plugin 不再需要，资源也无法释放
```

### 问题 3: 规模化影响

当前项目中约有 **42 个 actor Plugin**：
- 如果每个都有类似问题
- 即使只有部分 Plugin 注册了观察者
- 长期运行也会累积大量泄漏

---

## ✅ 修复方案

### 方案 1: 将 Plugin 改为类 + Actor 隔离（推荐）

将 Plugin 本身改为 class，在内部使用 actor 处理并发：

```swift
// 改为 class
class FilePreviewPlugin: SuperPlugin, SuperLog {
    private let actor = FilePreviewActor()
    
    init() {
        // 在 class 中可以正常管理 deinit
        setupObserver()
    }
    
    deinit {
        // 移除通知观察者
        NotificationCenter.default.removeObserver(observer)
    }
    
    private var observer: NSObjectProtocol?
    
    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(...)
    }
}

// 内部 actor 处理并发逻辑
actor FilePreviewActor {
    @MainActor private var isFileSelected: Bool = false
    
    func checkFileSelection() { ... }
}
```

### 方案 2: 使用静态观察者管理

在 SuperPlugin 基类中集中管理所有观察者：

```swift
class SuperPlugin {
    static var observers: [String: NSObjectProtocol] = [:]
    
    static func registerObserver(id: String, observer: NSObjectProtocol) {
        observers[id] = observer
    }
    
    static func cleanupObservers() {
        observers.values.forEach { 
            NotificationCenter.default.removeObserver($0) 
        }
        observers.removeAll()
    }
}
```

### 方案 3: 使用 token 存储模式

对于确实需要 actor 的场景，使用外部存储管理观察者：

```swift
// 在 PluginProvider 中统一管理
class PluginProvider {
    static var pluginObservers: [String: NSObjectProtocol] = [:]
}
```

---

## 📝 修复优先级

| 优先级 | 任务 | 预计工作量 |
|--------|------|-----------|
| **P1** | 审计所有 42 个 actor Plugin 的 NotificationCenter 使用 | 4 小时 |
| **P1** | 将 FilePreviewPlugin 改为 class + actor 模式 | 2 小时 |
| **P2** | 重构其他有相同问题的 Plugin | 8 小时 |

---

## 🔍 审计命令

```bash
# 查找所有 actor Plugin 中的 addObserver
grep -rn "actor.*Plugin" --include="*.swift" LumiApp/Plugins/ | cut -d: -f1 | uniq | xargs grep -l "addObserver"

# 统计 actor 数量
grep -rn "^actor.*Plugin" --include="*.swift" LumiApp/Plugins/ | wc -l
```

---

## 🔄 相关 Issue

- **Issue #005**: NotificationCenter 观察者内存泄漏
- **Issue #009**: 系统性 NotificationCenter 观察者泄漏
- **Issue #010**: Coordinator Task 泄漏

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `memory-leak`, `actor`, `design-issue`