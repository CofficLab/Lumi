# Issue #6: 调试日志可能泄露敏感信息

**严重程度**: 🟠 High  
**状态**: Open  
**涉及文件**: 
- `LumiFinder/FinderSync.swift`
- `LumiApp/Plugins/MemoryManagerPlugin/MemoryManagerPlugin.swift`
- `LumiApp/Plugins/NetworkManagerPlugin/NetworkManagerPlugin.swift`

---

## 问题描述

多个核心文件中 `verbose` 标志被设置为 `true`，生产环境会输出详细日志，可能泄露敏感信息。

## 当前代码

### FinderSync.swift
```swift
class FinderSync: FIFinderSync, SuperLog {
    static let emoji = "🧩"
    static let verbose = true  // 问题：生产环境应关闭
    // ...
}
```

### MemoryManagerPlugin.swift
```swift
actor MemoryManagerPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let enable = true
    nonisolated static let verbose = true  // 问题：生产环境应关闭
    // ...
}
```

### NetworkManagerPlugin.swift
```swift
actor NetworkManagerPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🛜"
    static let enable = false
    nonisolated static let verbose = true  // 问题：生产环境应关闭
    // ...
}
```

## 泄露风险

1. **文件路径**: 日志输出选中文件的完整路径
2. **用户行为**: 记录用户的操作行为和时间
3. **系统信息**: 泄露系统配置和目录结构
4. **命令内容**: `ShellTool` 输出完整命令内容

## 建议修复

**方案一**: 根据编译条件切换
```swift
#if DEBUG
static let verbose = true
#else
static let verbose = false
#endif
```

**方案二**: 添加用户设置
```swift
static var verbose: Bool {
    UserDefaults.standard.bool(forKey: "lumi_verbose_logging")
}
```

**方案三**: 限制日志级别
```swift
enum LogLevel: Int {
    case error = 0
    case warning = 1
    case info = 2
    case debug = 3
}
static let logLevel: LogLevel = .error  // 生产环境只记录错误
```

## 修复优先级

高 - 敏感信息泄露风险