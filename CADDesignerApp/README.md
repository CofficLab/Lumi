# CADDesignerApp

CAD 设计器独立应用入口。

## 结构

| 文件 | 说明 |
|------|------|
| `CADDesignerApp.swift` | SwiftUI 应用入口 |
| `Assets.xcassets/` | 应用资源 |
| `App.entitlements` | 应用权限 |
| `CADDesigner-Info.plist` | 应用信息 |
| `CADDesigner.xcconfig` | 构建配置 |

## 构建

```sh
xcodebuild -project Lumi.xcodeproj -scheme CADDesignerApp -destination 'platform=macOS' build
```
