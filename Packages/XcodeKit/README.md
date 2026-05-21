# XcodeKit

可复用的 Xcode 项目解析与构建上下文管理库。提供 Xcode 工程识别、Build Settings 解析、PBX 文件归属、Build Server 配置与 LSP 语义辅助能力。

## Package

- Product: `XcodeKit`
- Platform: macOS 14+
- Swift tools: 6.0

## 功能

- **项目发现**：自动检测 `.xcodeproj` / `.xcworkspace`
- **Build Settings 解析**：解析 `xcodebuild -list` 和 `-showBuildSettings` 输出
- **PBXProj 文件归属**：基于 XcodeProj 解析 target 与源文件的 membership
- **Build Context 管理**：生成和管理 `buildServer.json`，提供文件到 target 的映射
- **LSP 错误分类**：将统一的 LSP 错误细分为 Xcode 特定的可操作错误类型
- **Plist/Entitlements 编辑**：提供 key 补全、hover 信息和验证
- **语义可用性检查**：预检 LSP 请求的前置条件，提供精确的错误信息

## 依赖

- [XcodeProj](https://github.com/tuist/XcodeProj) — 解析 `.pbxproj` 文件结构
- [SuperLogKit](../SuperLogKit) — 日志格式化（SuperLog）

## 基本用法

```swift
import XcodeKit

let isXcode = XcodeProjectResolver.isXcodeProjectRoot(projectURL)

let resolver = XcodeProjectResolver()
let context = await resolver.resolve(workspaceURL: workspaceURL)

let settings = try XcodeBuildSettingsParser.parseBuildSettingsOutput(data)
```

## Testing

From this package directory:

```sh
swift test
```
