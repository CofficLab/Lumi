# Vendor 目录说明

本目录存放**跨仓库的第三方/上游 SPM 包的本地副本**，通过 SwiftPM 的
`.package(path:)` 机制被引用，而不是 `.package(url:from:)` 的远程引用。

## 为什么需要 Vendor

Lumi 的最低部署目标是 macOS 13.1，但上游包（CofficLab 系列的 LumiUI /
LumiProviders / LumiKernel 等）声明的 `platforms` 是 macOS 14.0。SwiftPM 会
直接拒绝这样的组合：

```
error: The package product 'LumiLocalizationKit-product' requires minimum
platform version 14.0 for the macOS platform, but this target supports 13.0
```

跨仓库发版来修改上游的 `platforms` 代价高昂（需要协调 20 个仓库的版本与
tag）。把上游包以本地副本的形式纳入本仓库，就可以在**不改上游**的前提下
调整其 `platforms` 声明。

## 目录内容与来源版本

每个子目录对应一个上游 Git 仓库，版本与本仓库
`Lumi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
中原本锁定的 revision 一致。`.upstream-version` 记录该来源版本。

| 目录 | 上游仓库 | 来源版本 |
|------|---------|---------|
| LumiKernel | CofficLab/LumiKernel | 1.1.0 |
| LumiKitReminder | CofficLab/LumiKitReminder | 1.0.0 |
| LumiLocalization | CofficLab/LumiLocalization | 1.0.1 |
| LumiLogging | CofficLab/LumiLogging | 1.0.1 |
| LumiProviders | CofficLab/LumiProviders | 1.19.0 |
| LumiSettings | CofficLab/LumiSettings | 1.1.0 |
| LumiThemePack | CofficLab/LumiThemePack | 1.0.12 |
| LumiUI | CofficLab/LumiUI | 1.12.0 |
| LumiPluginActivityBar | CofficLab/LumiPluginActivityBar | 1.0.2 |
| LumiPluginBookletMaker | CofficLab/LumiPluginBookletMaker | 2.1.0 |
| LumiPluginCommand | CofficLab/LumiPluginCommand | 1.0.1 |
| LumiPluginIdleTime | CofficLab/LumiPluginIdleTime | 1.0.0 |
| LumiPluginHydrationReminder | CofficLab/LumiPluginHydrationReminder | 1.0.0 |
| LumiPluginPluginManager | CofficLab/LumiPluginPluginManager | 1.7.0 |
| LumiPluginSettingView | CofficLab/LumiPluginSettingView | 1.0.3 |
| LumiPluginStorage | CofficLab/LumiPluginStorage | 1.1.1 |
| LumiPluginThemeManager | CofficLab/LumiPluginThemeManager | 1.0.1 |
| LumiPluginThemePack | CofficLab/LumiPluginThemePack | 1.2.1 |
| LumiPluginToast | CofficLab/LumiPluginToast | 1.2.3 |
| LumiPluginAbout | CofficLab/LumiPluginAbout | 2.0.0 |
| MagicAlert | nookery/MagicAlert | 1.0.1 |
| MagicLog | nookery/MagicLog | main |
| LibGit2Swift | nookery/LibGit2Swift | main |
| hummingbird | hummingbird-project/hummingbird | 2.28.1 |
| mlx-swift | ml-explore/mlx-swift | 0.32.3 |
| mlx-swift-lm | ml-explore/mlx-swift-lm | 3.32.3 |

## 本地副本相对上游的改动

1. **`platforms` 声明**：`.macOS(.v14)` → `.macOS("13.1")`
   （`mlx-swift` / `mlx-swift-lm` 除外，见下）
2. **包间依赖**：上游仓库之间的 `.package(url:)` 改为相对 `.package(path:)`
3. **macOS 14 独占 API 改造**：
   - `onChange(of:) { _, new in }` → 单参数版（旧值用 `@State` 快照保留）
   - `ContentUnavailableView` → `AppEmptyState`
   - `phaseAnimator` → `@State` + `withAnimation(.repeatForever)`
   - `.inspector(isPresented:)` → `HStack` 自绘面板
   - `.scrollBounceBehavior` → `#available(macOS 13.3, *)` 守卫
   - `onKeyPress` → `onMoveCommand` + `onExitCommand`
   - `withAnimation(_:completionCriteria:_:completion:)` → 单参数版 + 延时回调
   - `UUID: Comparable` → `uuidString` 字典序比较
4. **hummingbird 专项**：
   - `AvailabilityMacro=hummingbird 2.0:macOS 14.0` → `macOS 13.1`
   - `Server.swift` 中唯一的 `withDiscardingTaskGroup` → `withTaskGroup`
5. **mlx-swift / mlx-swift-lm 保持 `.macOS("14.0")`**：
   mlx 的 Metal 后端 C++ 源码使用 `bfloat` 类型（Metal Shading Language 专属，
   macOS 14 才有），无法降到 13.1。因此 `PluginLLMProviderMLX` 及其依赖者
   （仅 ACP 工具链）保持 macOS 14.0。

## 维护约定

- 上游发新版后，需要**手动**更新本目录副本，并同步 `.upstream-version`
  与 `Package.resolved` 中对应 pin。
- 本目录**不保留**上游 git 历史（`.git` 已移除），以避免与本仓库形成
  嵌套仓库；来源版本记录在 `.upstream-version` 文件中。
- `mlx-swift` 含两个 git submodule（`Source/Cmlx/mlx`、`Source/Cmlx/mlx-c`），
  其内容已展开在目录中（不再以 submodule 形式存在）。
