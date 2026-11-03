# PluginSettingGeneral

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginSettingGeneral`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

设置窗口的「通用」标签页，包含：

- 说明书 / Lumi 应用信息 / 网站 / 更新通道 / 诊断日志 / 卸载 等分组；
- **命令行工具**分组：安装 / 卸载 `lumi` 命令，用于在终端中把目录打开为
  Lumi 项目。安装逻辑由 `KitLumiCLI` 提供（只写用户可写目录，不需要管理员
  权限，不修改用户的 shell 配置）。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginSettingGeneral"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginSettingGeneral"]),
]
```

## Testing

From this package directory:

```sh
swift test
```

