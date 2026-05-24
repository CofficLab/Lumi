# GitBranchMonitorKit

通过 DispatchSource 监听 `.git/HEAD` 文件变化，实时检测 Git 分支切换的轻量级库。

## 特性

- **文件监听**：基于 `DispatchSource` 高效监听 `.git/HEAD` 文件写入/删除/重命名事件
- **防抖**：内置可配置的防抖机制，避免短时间内多次回调
- **去重**：仅在分支实际变化时才触发回调
- **多路径**：支持同时监听多个项目路径
- **线程安全**：`@MainActor` 隔离，所有属性访问和回调都在主线程

## 使用

```swift
import GitBranchMonitorKit

@StateObject private var monitor = GitBranchMonitor()

monitor.onBranchChange { projectPath, newBranch in
    print("分支变化: \(projectPath) -> \(newBranch ?? "detached")")
}

monitor.startMonitoring(projectPath: "/path/to/project")
```

## 测试

```bash
swift test
```
