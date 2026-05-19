# BrewKit

可复用的 Homebrew 包管理原语包。用于承载 Homebrew 相关的模型与服务逻辑，供宿主应用或插件复用。

## Package

- Product: `BrewKit`
- Platform: macOS 14+
- Swift tools: 5.9

## Current API

```swift
import BrewKit

let version = BrewKit.version
```

## Testing

From this package directory:

```sh
swift test
```

## Host integration

Keep UI, plugin registration, permissions, and app-specific workflows in the host app. Put reusable Homebrew command parsing, package metadata, and service logic in this package.
