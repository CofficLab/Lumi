# LumiApp

Lumi 编辑器主应用入口。

壳（窗口场景、应用代理、状态栏宿主、启动失败页）来自共享包 `LumiFactory`，
本目录只保留 Lumi 与兄弟 App 的差异。

## 结构

| 文件 | 说明 |
|------|------|
| `LumiApp.swift` | SwiftUI 应用入口（注入清单 + 共享壳场景） |
| `LumiManifest.swift` | 宿主清单：身份 / 存储 / 主题 / 插件与 Provider 装配钩子 / 深链 |
| `LumiStatusBarView.swift` | 状态栏图标区的常驻小组件 |
| `Config/` | 应用配置 |
| `Assets.xcassets/` | 应用资源 |

## 依赖

- `LumiFactory` — 共享宿主壳与装配流水线
- `FactoryLumi` — Lumi 的 Provider / 插件工厂与区域接线
- `LumiUI` — UI 组件库

## 构建

```sh
open Lumi.xcodeproj
```

或通过命令行:

```sh
xcodebuild -project Lumi.xcodeproj -scheme LumiApp -destination 'platform=macOS' build
```
