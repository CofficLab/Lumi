# LumiLogging

Shared logging primitives and in-app log collection for CofficLab apps.

## Product

- `LumiLoggingKit` provides `SuperLog`, `MagicLogger`, and `MagicLogEntry`.
- System log message bodies use private privacy. In-app log entries remain available to the host UI.

## Swift Package Manager

```swift
.package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.0")
```

```swift
.product(name: "LumiLoggingKit", package: "LumiLogging")
```

```swift
import LumiLoggingKit
```
