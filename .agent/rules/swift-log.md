# Swift 日志记录规范

> 本规范定义了 Lumi 项目中 Swift 代码的日志记录方式和标准。

---

## 核心原则

**使用 `os.Logger` 进行日志记录，统一日志格式和调试体验。禁止使用 `os_log`。**

所有日志输出必须加 `self.t` 或 `Self.t` 前缀（来自 SuperLog），用于统一格式。

---

## Import 要求

```swift
import os  // ✅ 使用 os.Logger，不使用 import OSLog
```

---

## Logger 分配规则

### 1. Core 模块

使用 `AppLogger.core`（定义在 `LumiApp/Core/Bootstrap/AppLogger.swift`）：

```swift
// 实现 SuperLog 的类型，日志前加 self.t 前缀
AppLogger.core.info("\(self.t)操作完成")
AppLogger.core.error("\(self.t)加载失败：\(error.localizedDescription)")
AppLogger.core.warning("\(self.t)使用备选数据")
```

### 2. Plugin 模块

在主插件文件中定义 logger，工具/服务等子文件使用插件 logger：

```swift
// 主插件文件（如 GitHubToolsPlugin.swift）
import os

actor GitHubToolsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-tools")
    nonisolated static let emoji = "🐙"
    // ...
}

// 插件内的 Tool/Service 使用（实例方法用 self.t，静态方法用 Self.t）
GitHubToolsPlugin.logger.info("\(self.t)获取仓库信息：\(owner)/\(repo)")
GitHubToolsPlugin.logger.error("\(self.t)请求失败：\(error.localizedDescription)")
```

### 3. LLM Provider / 独立类

在类型内部定义私有 logger：

```swift
import os

final class AnthropicProvider: SuperLLMProvider, SuperLog {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.anthropic")
    nonisolated static let emoji = "🤖"

    func transformMessage(_ message: ChatMessage) {
        if Self.verbose {
            Self.logger.info("\(self.t)消息包含 \(message.images.count) 张图片")
        }
    }
}
```

### 4. 扩展 / Finder 等

使用所属模块的 logger，并添加 `import os`：

```swift
import os

extension FinderSync {
    func openInVSCode(_ sender: AnyObject?) {
        if Self.verbose {
            FinderSync.logger.info("\(self.t)触发操作")
        }
    }
}
```

---

## 日志级别

| 级别 | 方法 | 用途 |
|------|------|------|
| 信息 | `logger.info(...)` | 正常流程、操作记录 |
| 警告 | `logger.warning(...)` | 非错误但需关注的情况 |
| 错误 | `logger.error(...)` | 错误、异常、失败 |
| 严重 | `logger.critical(...)` | 严重错误 |

---

## Logger 定义格式

```swift
// subsystem 固定为 "com.coffic.lumi"
// category 按模块命名：
//   - 插件："plugin.xxx"（如 plugin.github-tools, plugin.network）
//   - LLM: "llm.xxx"（如 llm.anthropic, llm.mlx）
//   - Finder: "finder"
private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.xxx")
```

---

## 常见模式

### Plugin Tool 日志

```swift
struct GitHubSearchTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = false

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)搜索：\(query)")
        }
        // ...
    }
}
```

### Service 日志

```swift
class NetworkService: SuperLog {
    nonisolated static let emoji = "🌐"

    func fetchData() {
        if Self.verbose {
            NetworkManagerPlugin.logger.info("\(self.t)开始请求")
        }
        // ...
    }
}
```

### 错误与警告

```swift
do {
    try await performTask()
} catch {
    PluginName.logger.error("\(self.t)任务失败：\(error.localizedDescription)")
    throw error
}

// 警告
if !isValid {
    PluginName.logger.warning("\(self.t)使用默认配置")
}
```

---

## SuperLog 协议与 t 前缀

实现 `SuperLog` 的类型可获得 `emoji`、`t` 和 `verbose` 用于日志。

**日志输出必须加 `self.t` 或 `Self.t` 前缀**，格式为 `[QoS] | emoji TypeName | `，便于在 Console 中按线程、类型过滤：

- **实例方法**：使用 `self.t`
- **静态方法**：使用 `Self.t`
- **闭包中（如 Task.detached、weak self）**：使用 `TypeName.t`

```swift
struct MyTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

    func execute() {
        if Self.verbose {
            MyPlugin.logger.info("\(self.t)执行操作")
        }
    }
}

// 闭包内无 self 时（如 Task.detached），用类型名获取前缀
Task.detached {
    NetworkManagerPlugin.logger.error("\(NetworkHistoryService.t)后台保存失败：\(error)")
}
```

---

## 禁止事项

1. **禁止使用 os_log**
   - ❌ `os_log("...")`
   - ❌ `os_log(.error, "...")`
   - ✅ `logger.info(...)` / `logger.error(...)`

2. **禁止 import OSLog**
   - ✅ `import os`

3. **禁止记录敏感信息**
   - ❌ 密码、Token、API Key
   - ✅ 只记录操作结果或脱敏信息

---

## 日志过滤

通过 Console.app 或 `log stream` 可按住户定义：

```bash
# 按子系统过滤
log stream --predicate 'subsystem == "com.coffic.lumi"'

# 按 category 过滤
log stream --predicate 'subsystem == "com.coffic.lumi" AND category == "plugin.github-tools"'
```

---

## Emoji 选择指南

| Emoji | 用途 |
|-------|------|
| 🐙 | GitHub |
| 📁 | 文件/目录 |
| 💾 | 内存/存储 |
| 🔌 | 端口/网络 |
| 🤖 | Anthropic |
| 🔴 | Zhipu |
| 💻 | MLX / Shell |
| 🛡️ | 安全/防火墙 |

---

## 磁盘日志持久化

所有通过 `os.Logger`（subsystem: `com.coffic.lumi`）输出的日志会自动持久化到磁盘，**无需修改任何现有代码**。

### 实现方式

通过 `FileLogCoordinator`（定义在 `LumiApp/Core/Utils/FileLogCoordinator.swift`）使用 `OSLogStore` 轮询子系统日志，异步写入磁盘文件：

- 启动：`MacAgent.applicationDidFinishLaunching` 中调用 `FileLogCoordinator.shared.start()`
- 停止：`MacAgent.applicationWillTerminate` 中调用 `FileLogCoordinator.shared.stop()`

### 存储位置

```
~/Library/Application Support/com.coffic.Lumi/Logs/
├── 2026-05-02_10-36-00.log
├── 2026-05-02_11-02-33.log
└── ...
```

### 自动管理规则

| 规则 | 值 |
|------|-----|
| 单文件大小上限 | 5 MB |
| 过期清理 | 7 天 |
| 轮转触发 | 启动时新建 + 超大小自动轮转 |
| 轮询间隔 | 2 秒 |

### 磁盘日志格式

```
=== Lumi Log ===
Version: 1.0.0 (42)
Date: 2026-05-02 10:36:00 +0000
===

[10:36:01.234] [INFO] [core] 应用启动完成
[10:36:01.567] [ERROR] [plugin.github-tools] 请求失败：网络超时
```

### 查看磁盘日志

```bash
# 实时查看最新日志
tail -f ~/Library/Application\ Support/com.coffic.Lumi/Logs/$(ls -t ~/Library/Application\ Support/com.coffic.Lumi/Logs/ | head -1)

# 按级别过滤
grep "\[ERROR\]" ~/Library/Application\ Support/com.coffic.Lumi/Logs/*.log

# 按模块过滤
grep "\[plugin.github-tools\]" ~/Library/Application\ Support/com.coffic.Lumi/Logs/*.log
```

### 约束

1. **禁止手动写磁盘日志** — 所有日志走 `os.Logger`，磁盘持久化由 `FileLogCoordinator` 自动完成
2. **禁止在磁盘日志中记录敏感信息** — 密码、Token、API Key 等
3. **禁止在高频路径添加 verbose 日志** — 避免影响性能（如鼠标移动、滚动事件）

---

## 相关规范

- [代码组织规范](./swift-code-organization.md)
- [注释规范](./swift-comment.md)
