# DatabaseManagerApp

数据库管理器独立应用入口。

## 结构

| 文件 | 说明 |
|------|------|
| `DatabaseManagerApp.swift` | SwiftUI 应用入口 |
| `App.entitlements` | 应用权限 |
| `DatabaseManager-Info.plist` | 应用信息 |
| `DatabaseManager.xcconfig` | 构建配置 |

## 构建

```sh
xcodebuild -project Lumi.xcodeproj -scheme DatabaseManagerApp -destination 'platform=macOS' build
```
