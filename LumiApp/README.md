# LumiApp

Lumi 编辑器主应用入口。

包含应用主窗口、应用委托、菜单栏控制器等核心启动逻辑。

## 结构

| 文件 | 说明 |
|------|------|
| `LumiApp.swift` | SwiftUI 应用入口 |
| `LumiAppDelegate.swift` | 应用生命周期代理 |
| `LumiMenuBarController.swift` | 菜单栏控制器 |
| `WindowAccessor.swift` | 窗口访问工具 |
| `Config/` | 应用配置 |
| `Assets.xcassets/` | 应用资源 |

## 依赖

- `FactoryLumi` — 主应用工厂装配
- `LumiUI` — UI 组件库

## 构建

```sh
open Lumi.xcodeproj
```

或通过命令行:

```sh
xcodebuild -project Lumi.xcodeproj -scheme LumiApp -destination 'platform=macOS' build
```
