# SuperLogKit

A powerful and flexible logging library for Swift applications, providing structured logging with thread information, emoji context, and unified formatting.

## Features

- **Structured Logging**: Unified log format with thread information and emoji context
- **Thread Awareness**: Automatic thread quality of service (QoS) detection and labeling
- **Multiple Log Levels**: Support for info, warning, error, and debug levels
- **Emoji Context**: Automatic emoji generation based on class names
- **SwiftUI Integration**: Built-in SwiftUI components for log viewing
- **Type-Safe**: Protocol-based design with compile-time safety
- **Observable**: Combine support for reactive UI updates

## Installation

Add `SuperLogKit` to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(path: "../SuperLogKit")
]
```

## Usage

### Basic Protocol Adoption

```swift
import SuperLogKit

class UserManager: SuperLog {
    static var emoji: String { "👤" }

    func login() {
        print("\(Self.t)Starting login process")

        if isMain {
            print("\(t)Running on main thread")
        }

        print("\(t)Login failed\(r("invalid password"))")
    }
}
```

### Using MagicLogger

```swift
import SuperLogKit

// Static methods
MagicLogger.info("User logged in")
MagicLogger.warning("Low disk space")
MagicLogger.error("Failed to save data")
MagicLogger.debug("Debugging information")

// Instance methods
let logger = MagicLogger()
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

Logs are formatted with the following structure:

```
[Thread QoS] | Emoji ClassName | Message
```

Example output:
```
[UI] | 👤 UserManager           | Starting login process
[BG] | 🗄️ DatabaseManager      | Query executed
```

## Thread QoS Labels

- `[UI]` - User Interactive / Main Thread
- `[IN]` - User Initiated
- `[DF]` - Default
- `[UT]` - Utility
- `[BG]` - Background
- `[UN]` - Unspecified

## Requirements

- macOS 14.0+
- Swift 6.0+

## License

MIT License
