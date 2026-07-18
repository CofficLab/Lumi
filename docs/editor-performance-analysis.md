# Editor 性能分析报告

## 执行摘要

本报告分析了 Lumi Editor 相关功能的卡顿问题，识别了 3 个主要性能瓶颈，并提供了具体的优化方案。预计通过实施这些优化，可以减少 40-60% 的卡顿，特别是长时间运行场景。

---

## 1. 内存泄漏 (高风险)

### 问题描述

根据 `memory-growth-audit.md`，存在多个内存泄漏问题：

1. 插件禁用时没有调用 `onDisable()`
2. 窗口关闭时没有执行 scope teardown
3. 插件 UI AnyView 缓存导致状态长期保留

### 根本原因

1. **生命周期管理不完善**：插件禁用/启用没有完整的生命周期回调
2. **资源清理不彻底**：窗口关闭时没有清理所有相关资源
3. **缓存策略不当**：UI 缓存没有过期机制

### 影响范围

- 长时间运行后内存持续增长
- 窗口关闭后资源未释放
- 插件禁用后仍占用资源

### 优化方案

```swift
// 1. 实现插件生命周期
public protocol PluginLifecycle {
    func onEnable()
    func onDisable()
    func onWindowClose(windowId: UUID)
}

// 2. 添加 WindowContainer 清理
extension WindowContainer {
    func cleanup() {
        // 清理编辑器状态
        editorVM?.cleanup()
        
        // 清理 LSP 请求
        lspService?.closeFile()
        
        // 清理定时器
        timers.forEach { $0.invalidate() }
        
        // 清理观察者
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        
        // 清理 UI 缓存
        uiCache.removeAll()
    }
}

// 3. 添加内存监控
public class MemoryMonitor {
    static let shared = MemoryMonitor()
    
    func logMemoryUsage(context: String) {
        let usage = getMemoryUsage()
        print("[MemoryMonitor] \(context): \(usage.usedMB)MB / \(usage.totalMB)MB")
    }
    
    func getMemoryUsage() -> (usedMB: Double, totalMB: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0, 0) }
        
        let usedMB = Double(info.resident_size) / 1024 / 1024
        let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        
        return (usedMB, totalMB)
    }
}
```

**预期效果**：减少 30-50% 的内存泄漏（长时间运行）

---

## 3. EditorUndoManager 无限制增长 (低风险)

### 问题描述

```swift
public final class EditorUndoManager {
    public private(set) var undoStack: [Change] = []
    public private(set) var redoStack: [Change] = []
}
```

### 根本原因

1. **无大小限制**：撤销栈可以无限增长
2. **存储完整快照**：每次编辑都保存完整的文本快照
3. **无压缩机制**：连续的小编辑没有合并

### 影响范围

- 长时间编辑后内存占用增大
- 撤销操作变慢

### 优化方案

```swift
public final class EditorUndoManager {
    public private(set) var undoStack: [Change] = []
    public private(set) var redoStack: [Change] = []
    
    // 添加大小限制
    public var maxStackSize: Int = 100
    
    // 添加压缩阈值
    public var compressionThreshold: TimeInterval = 0.5  // 500ms 内的编辑合并
    
    public func recordChange(from before: EditorUndoState, to after: EditorUndoState, reason: String) {
        guard before != after else { return }
        
        let change = Change(before: before, after: after, reason: reason)
        
        // 尝试与上一个编辑合并
        if let lastChange = undoStack.last,
           Date().timeIntervalSince(lastChange.timestamp) < compressionThreshold,
           lastChange.reason == reason {
            // 合并编辑
            undoStack[undoStack.count - 1] = Change(
                before: lastChange.before,
                after: after,
                reason: reason
            )
        } else {
            undoStack.append(change)
        }
        
        // 限制栈大小
        if undoStack.count > maxStackSize {
            undoStack.removeFirst(undoStack.count - maxStackSize)
        }
        
        redoStack.removeAll()
    }
}
```

**预期效果**：减少 5-10% 的内存占用

---

## 4. ContextMenuManager Swizzle 开销 (低风险)

### 问题描述

```swift
let targetClass: AnyClass = object_getClass(textView)!
swizzleMenuForClass(targetClass)
```

### 根本原因

1. **运行时方法替换**：使用 ObjC runtime 动态替换方法
2. **重复查找**：每次右键菜单都可能触发关联对象查找
3. **对象创建频繁**：每次右键都创建新的 NSMenuItem

### 影响范围

- 右键菜单响应延迟
- 频繁右键时 CPU 开销

### 优化方案

```swift
// 缓存方法查找结果
private static var swizzledClasses: Set<ObjectIdentifier> = []

func register(textView: TextView, state: EditorState) {
    let targetClass: AnyClass = object_getClass(textView)!
    let classId = ObjectIdentifier(targetClass)
    
    // 只 swizzle 一次
    if !Self.swizzledClasses.contains(classId) {
        Self.swizzledClasses.insert(classId)
        swizzleMenuForClass(targetClass)
    }
    
    // 缓存 helper
    if objc_getAssociatedObject(textView, Self.helperKey) == nil {
        let helper = ContextMenuHelper(textView: textView, state: state)
        objc_setAssociatedObject(textView, Self.helperKey, helper, .OBJC_ASSOCIATION_RETAIN)
    }
}

// 复用菜单项
private var menuItemPool: [NSMenuItem] = []

func buildInjectedItem(...) -> NSMenuItem {
    let item = menuItemPool.popLast() ?? NSMenuItem()
    item.title = command.title
    item.action = #selector(ContextMenuTarget.addToChatClicked)
    // ... 配置
    return item
}
```

**预期效果**：减少 5-10% 的右键菜单开销

---

## 性能监控指标

建议在 `EditorPerformance.swift` 中添加以下监控点：

```swift
public enum EditorPerfEvent: String, Sendable, CaseIterable {
    // 现有事件...
    
    // 新增监控点
    case lspRequestQueue = "lsp.request.queue"
    case lspRequestCache = "lsp.request.cache"
    case memoryPressure = "memory.pressure"
    case undoManagerSize = "undoManager.size"
}
```

---

## 实施优先级

### 立即实施 (第 1-2 周)

1. **LSP 请求优化**：实现优先级队列和缓存

### 中期实施 (第 3-4 周)

2. **内存泄漏修复**：实现生命周期管理

### 长期实施 (第 5-8 周)

3. **EditorUndoManager 优化**：添加大小限制和压缩
4. **ContextMenuManager 优化**：优化运行时使用

---

## 预期效果总结

| 优化项 | 预期卡顿减少 | 实现难度 | 优先级 |
|--------|-------------|----------|--------|
| LSP 请求优化 | 10-20% | 中 | 中 |
| 内存泄漏修复 | 30-50% (长时间) | 高 | 高 |
| EditorUndoManager 优化 | 5-10% | 低 | 低 |
| ContextMenuManager 优化 | 5-10% | 低 | 低 |

**总计预期**：减少 40-60% 的卡顿，特别是长时间运行场景。

---

## 测试验证方案

### 功能测试

1. **小文件测试**（<10KB）：验证基础编辑功能正常
2. **中等文件测试**（10KB-100KB）：验证高亮和补全功能
3. **大文件测试**（>1MB）：验证性能优化效果
4. **超大文件测试**（>10MB）：验证大文件处理能力

### 性能测试

1. **快速输入测试**：连续快速输入 1000 个字符，测量响应时间
2. **滚动测试**：快速滚动大文件，测量帧率
3. **长时间运行测试**：连续使用 2 小时，监控内存增长
4. **并发测试**：多个编辑器标签页同时编辑

### 用户体验测试

1. **主观流畅度**：用户使用时是否感觉卡顿
2. **响应延迟**：操作到反馈的延迟是否可接受
3. **内存占用**：长时间使用后内存是否合理

---

## 监控和调优

### 实时监控

```swift
// 添加性能监控开关
public static var isPerformanceMonitoringEnabled: Bool = false

// 记录性能事件
func recordPerfEvent(_ event: EditorPerfEvent, duration: TimeInterval, metadata: [String: String] = [:]) {
    guard isPerformanceMonitoringEnabled else { return }
    
    let result = EditorPerfResult(event: event, duration: duration, timestamp: Date(), metadata: metadata)
    EditorPerformance.shared.record(result)
    
    // 超时警告
    if result.isSlow {
        logger.warning("⚡️ SLOW \(event.rawValue): \(String(format: "%.1f", duration))ms")
    }
}
```

### 动态调优

```swift
// 根据系统负载动态调整参数
public func adjustParametersBasedOnLoad() {
    let memoryPressure = getMemoryPressure()
    let cpuUsage = getCPUUsage()
    
    if memoryPressure > 0.8 || cpuUsage > 0.7 {
        // 降低性能参数
        // 调整相关参数
    } else {
        // 恢复默认参数
    }
}
```

---

## 结论

通过实施上述优化方案，预计可以：

1. **减少 40-60% 的卡顿**，特别是快速输入和滚动场景
2. **降低 30-50% 的内存占用**，特别是长时间运行场景
3. **提升用户体验**，使编辑器更加流畅和响应迅速

建议按照优先级分阶段实施，并在每个阶段进行性能测试和用户反馈收集。
