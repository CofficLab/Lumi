# XcodeKit

Xcode 项目解析与构建上下文管理库，为 Lumi 编辑器提供 Xcode 工程的识别、解析和语义支持能力。

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
- [MagicKit](https://github.com/CofficLab/MagicKit) — 日志格式化（SuperLog）

## 使用

```swift
import XcodeKit

// 检测是否是 Xcode 项目
let isXcode = XcodeProjectResolver.isXcodeProjectRoot(projectURL)

// 解析项目
let resolver = XcodeProjectResolver()
let context = await resolver.resolve(workspaceURL: workspaceURL)

// 解析 build settings
let settings = try XcodeBuildSettingsParser.parseBuildSettingsOutput(data)
```
