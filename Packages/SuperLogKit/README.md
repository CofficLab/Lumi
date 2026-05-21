# SuperLogKit

与 [MagicKit](https://github.com/CofficLab/MagicKit) 中 `SuperLog` 行为一致的日志库：结构化输出、线程 QoS emoji、类名上下文 emoji，以及 `MagicLogger` 可观测日志。

## Features

- **Structured Logging**: 统一格式 `QoS | Emoji ClassName | Message`
- **Thread Awareness**: 通过 `Thread.currentQosDescription` 自动标注 QoS（emoji）
- **Multiple Log Levels**: `MagicLogger` 支持 info / warning / error / debug
- **Emoji Context**: 按类名或消息关键词（中英）自动匹配 emoji
- **SwiftUI Integration**: `MagicLogEntry` 提供 `color`、`icon`，便于列表展示
- **Type-Safe**: 基于 `SuperLog` 协议
- **Observable**: `MagicLogger` 支持 Combine

## Installation

```swift
dependencies: [
    .package(path: "../SuperLogKit")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["SuperLogKit"]
    )
]
```

## Usage

### Basic Protocol Adoption

```swift
import SuperLogKit

class UserManager: SuperLog {
    static var emoji: String { "👤" }

    func login() {
        print("\(Self.t)开始登录处理")

        if isMain {
            print("\(t)在主线程执行")
        }

        print("\(t)登录失败\(r("密码错误"))")
    }
}
```

未自定义 `emoji` 时，会根据类型名关键词生成（如含 `data` → `💾`，含 `manager` → `👔`）。

### Using MagicLogger

```swift
import SuperLogKit

MagicLogger.info("User logged in")
MagicLogger.warning("Low disk space")
MagicLogger.error("Failed to save data")
MagicLogger.debug("Debugging information")

let logger = MagicLogger(app: "MyApp")
logger.info("Instance log message")
```

### Observable Logs in SwiftUI

```swift
struct LogView: View {
    @StateObject private var logger = MagicLogger.shared

    var body: some View {
        List(logger.logs) { log in
            HStack {
                Image(systemName: log.level.icon)
                    .foregroundColor(log.level.color)
                Text(log.message)
            }
        }
    }
}
```

## Log Format

### `SuperLog` 前缀（`t`）

```
{QoS emoji} | {emoji} {ClassName (27 chars)} | {message}
```

示例（主线程 / User Interactive）：

```
🔥 | 👤 UserManager           | 开始登录处理
🔥 | 👤 UserManager           | 登录失败 ➡️ 密码错误
```

### `MagicLogger` / `MagicLogEntry`

`message` 字段为：

```
{QoS emoji} | {emoji} {original message}
```

`os_log` 行 additionally 包含 caller 与行号。

## Thread QoS Labels

与 MagicKit `ExtQos` 一致，`description(withName: false)` 返回值：

| QoS | 标识 |
|-----|------|
| userInteractive | `🔥` |
| userInitiated | `2️⃣` |
| default | `3️⃣` |
| utility | `4️⃣` |
| background | `5️⃣` |
| unknown | `6️⃣` |

带名称时例如：`🔥 UserInteractive`、`5️⃣ Background`。

## Context Emoji

`String.generateContextEmoji()` / `withContextEmoji` 使用与 MagicKit 相同的关键词表（含中文，如 `网络` → `🌐`、`错误` → `❌`）。无匹配时默认为 `📝`。

## Requirements

- macOS 14.0+
- Swift 6.0+

## License

MIT License
