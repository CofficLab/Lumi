# AppIconDesignerApp

应用图标设计器独立应用入口。

## 结构

| 文件 | 说明 |
|------|------|
| `AppIconDesignerApp.swift` | SwiftUI 应用入口 |
| `Assets.xcassets/` | 应用资源 |
| `App.entitlements` | 应用权限 |
| `AppIconDesigner-Info.plist` | 应用信息 |
| `AppIconDesigner.xcconfig` | 构建配置 |

## 构建

```sh
xcodebuild -project Lumi.xcodeproj -scheme AppIconDesignerApp -destination 'platform=macOS' build
```
