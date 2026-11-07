# MagicLog

[![中文](https://img.shields.io/badge/中文-README-blue)](README_zh.md)

A Swift logging protocol with emoji support and thread information for iOS and macOS applications.

## Features

- **Unified Logging Format**: Consistent log output with emoji identifiers and thread information
- **Thread Awareness**: Automatic detection and display of current thread QoS level
- **Emoji Generation**: Automatic emoji generation based on context strings
- **Protocol-Based**: Easy to adopt in any Swift class or struct
- **SwiftUI Ready**: Works seamlessly with SwiftUI applications

## Installation

### Swift Package Manager

Add MagicLog as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nookery/MagicLog.git", from: "1.0.0")
]
```

Or add it directly in Xcode:

1. Go to File → Add Packages...
2. Enter the repository URL: `https://github.com/nookery/MagicLog.git`
3. Choose the version you want to use

## Usage

### Basic Logging

```swift
import Foundation
import MagicLog

class UserManager: SuperLog {
    static var emoji: String { "👤" }  // Optional: custom emoji

    func login() {
        log("开始登录处理") // Use os_log to output logs with thread info and emoji

        if isMain {
            log("在主线程执行")
        }

        // Log with reason
        error("登录失败\(r("密码错误"))")
    }
}

// Output example:
// [UI] | 👤 UserManager           | 开始登录处理
// [UI] | 👤 UserManager           | 在主线程执行
// [UI] | 👤 UserManager           | 登录失败 ➡️ 密码错误
```

### Thread Information

MagicLog automatically detects and displays thread QoS information:

- `[UI]` - User Interactive (Main thread)
- `[2️⃣]` - User Initiated
- `[3️⃣]` - Default
- `[4️⃣]` - Utility
- `[5️⃣]` - Background

### Emoji Generation

The library includes automatic emoji generation based on string content:

```swift
import MagicLog

let message = "网络请求失败"
os_log("\(message.withContextEmoji)") // Output: 🌐 网络请求失败

let success = "数据保存成功"
os_log("\(success.withContextEmoji)") // Output: 💾 数据保存成功
```

## Protocol Methods

### Static Properties

- `emoji` - Custom emoji for the class (auto-generated if not provided)
- `t` - Thread information prefix with emoji and class name
- `author` - Class name without generic parameters
- `onAppear` - Standardized "OnAppear" log message
- `onInit` - Standardized "Init" log message

### Instance Properties

- `author` - Same as static author property
- `className` - Alias for author
- `isMain` - Boolean indicating if current thread is main thread
- `t` - Same as static t property
- `a` - Alias for onAppear
- `i` - Alias for onInit

### Instance Methods

- `r(_:)` - Create reason string with arrow separator
- `makeReason(_:)` - Create formatted reason string

## Requirements

- iOS 17.0+
- macOS 14.0+
- Swift 5.9+

## License

This project is licensed under the MIT License - see the LICENSE file for details.
