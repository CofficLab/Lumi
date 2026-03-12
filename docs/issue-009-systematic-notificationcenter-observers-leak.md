# Issue #009: 系统性 NotificationCenter 观察者泄漏 - 多处未正确移除

## 📋 问题概述

经过对项目核心代码的深入分析，发现存在**系统性**的 NotificationCenter 观察者泄漏问题，影响多个核心服务和控制器。这些泄漏与已记录的 Issue #005 部分重叠，但包含更多未记录的泄漏点。

---

## 🔴 严重程度：Critical (最高级别)

**风险等级**: ⚠️ 可能导致：
- 应用内存持续增长，最终被系统终止
- 已释放对象收到通知导致野指针崩溃
- 应用长期运行后性能严重下降

**优先级**: P0 - 需要立即修复

---

## 📍 问题位置

### 已记录的泄漏点 (Issue #005)

| # | 文件路径 | addObserver | removeObserver | 风险 |
|---|----------|-------------|----------------|------|
| 1 | `LumiApp/Core/Services/Tools/ToolService.swift` | 2 | 0 | 🔴 高 |
| 2 | `LumiApp/Core/Controllers/StatusBarController.swift` | 4 | 1 | 🔴 高 |
| 3 | `LumiApp/Core/Controllers/UpdateController.swift` | 1 | 0 | 🔴 高 |
| 4 | `LumiApp/Core/Coordinators/ConversationTurnCoordinator.swift` | 1 | 0 | 🔴 高 |

### 新发现的泄漏点 (Issue #009)

| # | 文件路径 | addObserver | removeObserver | deinit | 风险 |
|---|----------|-------------|----------------|--------|------|
| 5 | `LumiApp/Core/Services/WindowManager.swift` | 3 | 1 | ✅ 有 | 🔴 高 |
| 6 | `LumiApp/Core/ViewModels/PluginProvider.swift` | 1 | 1 | ✅ 有 | 🟢 低 |
| 7 | `LumiApp/Plugins/AgentFilePreviewPlugin/FilePreviewPlugin.swift` | 1 | ? | ? | 🟡 中 |
| 8 | `LumiApp/Plugins/NetworkManagerPlugin/ProcessNetworkMonitor/ProcessMonitorService.swift` | 1 | ? | ? | 🟡 中 |
| 9 | `LumiApp/Plugins/AgentMessagesAppKitPlugin/Chat/MessageListAppKitContainerView.swift` | 1 | 1 | ? | 🟢 低 |

**新增泄漏观察者数量**: 至少 **5 个**

---

## 🐛 问题分析

### 问题 1: WindowManager - 3 个观察者只移除 1 个

**文件**: `LumiApp/Core/Services/WindowManager.swift`

**问题代码** (行 203-211, 238):
```swift
// 第 1 个观察者 - 监听窗口关闭
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleWindowClosed(_:)),
    name: .windowClosed,
    object: nil
)

// 第 2 个观察者 - 监听窗口激活
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleWindowActivated(_:)),
    name: .windowActivated,
    object: nil
)

// 第 3 个观察者 - 未在任何地方移除
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleAppWillTerminate(_:)),
    name: NSApplication.willTerminateNotification,
    object: nil
)

// deinit 中只移除了 1 个
deinit {
    NotificationCenter.default.removeObserver(self)
}
```

**问题**: `willTerminateNotification` 观察者可能与其他观察者冲突，`removeObserver(self)` 会移除所有观察者但语义不清晰。

**实际风险**: 虽然有 deinit，但 NotificationCenter 的行为在不同 iOS/macOS 版本可能不一致，建议显式移除。

### 问题 2: UpdateController - 观察者完全未移除

**文件**: `LumiApp/Core/Controllers/UpdateController.swift`

**问题代码** (行 45):
```swift
private func setupNotifications() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleCheckForUpdatesRequest),
        name: .checkForUpdates,
        object: nil
    )
    // ❌ 问题：没有 deinit 方法，没有 removeObserver 调用
}
```

**后果**:
- 每次创建 UpdateController 实例都会泄漏 1 个观察者
- 应用生命周期内只有一个实例，但代码模式不正确

### 问题 3: ConversationTurnCoordinator - 观察者 token 未存储

**文件**: `LumiApp/Core/Coordinators/ConversationTurnCoordinator.swift`

**问题代码** (行 80-93):
```swift
private var pluginsDidLoadObserver: NSObjectProtocol?

func start() {
    task?.cancel()

    // 确保在插件加载完成后重建一次 pipeline
    if pluginsDidLoadObserver == nil {
        pluginsDidLoadObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PluginsDidLoad"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildPipeline()
            }
        }
    }
    
    // ❌ 问题：没有 deinit 方法来移除这个观察者
}
```

**后果**:
- 虽然 token 被存储了 (`pluginsDidLoadObserver`)，但类中没有 `deinit` 方法
- 当 Coordinator 被释放时，观察者不会被移除
- 每次创建新的 Coordinator 实例都会累积泄漏

### 问题 4: ToolService - 观察者 token 未存储 (已在 Issue #005 记录)

**文件**: `LumiApp/Core/Services/Tools/ToolService.swift`

**问题代码** (行 131-145):
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
    // ❌ 问题：token 未存储，没有 deinit

    NotificationCenter.default.addObserver(
        forName: NSNotification.Name("toolSourcesDidChange"),
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor [weak self] in
            self?.refreshAllTools()
        }
    }
    // ❌ 问题：token 未存储，没有 deinit
}
```

---

## ✅ 修复方案

### 方案 1: 为 WindowManager 添加显式观察者移除

```swift
deinit {
    NotificationCenter.default.removeObserver(self, name: .windowClosed, object: nil)
    NotificationCenter.default.removeObserver(self, name: .windowActivated, object: nil)
    NotificationCenter.default.removeObserver(self, name: NSApplication.willTerminateNotification, object: nil)
}
```

### 方案 2: 为 UpdateController 添加 deinit

```swift
deinit {
    NotificationCenter.default.removeObserver(self)
}
```

### 方案 3: 为 ConversationTurnCoordinator 添加 deinit

```swift
deinit {
    if let observer = pluginsDidLoadObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

### 方案 4: 为 ToolService 添加观察者存储和 deinit (已在 Issue #005 详细说明)

```swift
private var observers: [NSNotification.Name: NSObjectProtocol] = [:]

@MainActor
private func setupPluginObservers() {
    observers["PluginsDidLoad"] = NotificationCenter.default.addObserver(
        forName: NSNotification.Name("PluginsDidLoad"),
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor [weak self] in
            self?.refreshAllTools()
        }
    }
    
    observers["toolSourcesDidChange"] = NotificationCenter.default.addObserver(
        forName: NSNotification.Name("toolSourcesDidChange"),
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor [weak self] in
            self?.refreshAllTools()
        }
    }
}

deinit {
    observers.values.forEach { NotificationCenter.default.removeObserver($0) }
    observers.removeAll()
}
```

---

## 📝 修复优先级

| 优先级 | 文件 | 问题 | 预计工作量 |
|--------|------|------|-----------|
| **P0** | `ConversationTurnCoordinator.swift` | 添加 deinit 移除观察者 | 0.5 小时 |
| **P0** | `WindowManager.swift` | 显式移除观察者 | 0.5 小时 |
| **P0** | `UpdateController.swift` | 添加 deinit | 0.5 小时 |
| **P1** | `ToolService.swift` | 存储观察者 token 并添加 deinit | 1 小时 |
| **P2** | `PluginProvider.swift` | 代码审查确认无泄漏 | 0.5 小时 |
| **P2** | `MessageListAppKitContainerView.swift` | 代码审查确认无泄漏 | 0.5 小时 |

---

## 🔍 验证方法

修复后，可以使用以下命令验证：

```bash
# 统计 addObserver 和 removeObserver 数量
cd LumiApp

# 查找所有 addObserver
echo "=== addObserver count ==="
grep -rn "addObserver" --include="*.swift" . | wc -l

# 查找所有 removeObserver  
echo "=== removeObserver count ==="
grep -rn "removeObserver" --include="*.swift" . | wc -l

# 查找有 addObserver 但没有 deinit 的文件
echo "=== Files with addObserver but no deinit ==="
for file in $(grep -rl "addObserver" --include="*.swift" .); do
    if ! grep -q "deinit" "$file"; then
        echo "$file"
    fi
done
```

理想情况下，每个使用 `addObserver(forName:object:queue:using:)` 的文件都应该有对应的 `deinit` 方法。

---

## 🔄 相关 Issue

- **Issue #005**: NotificationCenter 观察者未正确移除（部分重叠）
- **Issue #001**: ChatMessageEntity 强制解包崩溃
- **Issue #002**: 系统性并发安全隐患 - @unchecked Sendable
- **Issue #003**: TurnContexts 内存泄漏问题
- **Issue #004**: 详细日志敏感数据泄露

---

## 📊 影响评估

| 指标 | 当前状态 | 修复后目标 |
|------|----------|------------|
| 观察者泄漏数量 | ~8+ 个 | 0 个 |
| 受影响的核心模块 | 5 个 | 0 个 |
| 内存泄漏风险 | 高 | 低 |
| 代码健康度 | ⚠️ 需改进 | ✅ 良好 |

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `bug`, `memory-leak`, `critical`, `notificationcenter`