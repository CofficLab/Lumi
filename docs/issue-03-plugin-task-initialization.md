# Issue #3: 插件初始化中的 Task 创建风险

**严重程度**: 🔴 Critical  
**状态**: Open  
**涉及文件**: 
- `LumiApp/Plugins/MemoryManagerPlugin/MemoryManagerPlugin.swift`
- `LumiApp/Plugins/NetworkManagerPlugin/NetworkManagerPlugin.swift`

---

## 问题描述

在插件的 `init()` 方法中创建异步 Task 可能导致多种问题，包括初始化时序问题、竞态条件和资源访问问题。

## 当前代码

### MemoryManagerPlugin.swift
```swift
init() {
    Task { @MainActor in
        MemoryHistoryService.shared.startRecording()
    }
}
```

### NetworkManagerPlugin.swift
```swift
init() {
    Task { @MainActor in
        _ = NetworkHistoryService.shared
    }
}
```

## 问题分析

1. **插件初始化时序问题**
   - Task 在 init() 执行后才开始运行
   - 无法确保在插件其他方法被调用前完成初始化

2. **竞态条件风险**
   - 可能在资源未完全初始化时就被访问
   - 多插件并发初始化时可能导致死锁

3. **难以追踪的错误**
   - Task 中的错误不会被 init() 捕获
   - 静默失败难以调试

4. **生命周期管理**
   - Task 创建后无法取消
   - 插件卸载时 Task 可能仍在运行

## 建议修复

**方案一**: 使用显式初始化方法
```swift
class MemoryManagerPlugin {
    static func initialize() async {
        await MemoryHistoryService.shared.startRecording()
    }
}
```

**方案二**: 在应用启动流程中统一初始化
- 创建 PluginBootstrap 组件
- 等待所有插件初始化完成后再启动

**方案三**: 使用 Task.detached 并妥善管理
- 添加初始化完成回调
- 添加超时处理

## 修复优先级

高 - 可能导致应用不稳定和难以调试的运行时问题