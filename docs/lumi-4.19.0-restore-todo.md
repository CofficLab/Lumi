# Lumi 4.19.0 → 当前版本 功能恢复 TODO

> **目标**：把 4.19.0 的所有功能完美找回到当前 dev 分支。
> **参照基线**：`/Users/colorfy/Downloads/Lumi-4.19.0/` （旧的 LumiAppKit + LumiCoreKit + LumiPluginRegistry 体系）
> **当前状态**：LumiAppKit / LumiCoreKit / LumiCorePlugin / LumiPluginRegistry 已删除，新 LumiFactory + LumiKernel 已就位，但**大量旧版功能未迁入**。
> **执行方式**：本文件按"独立可并行"粒度拆分任务，由多个 agent 同时推进。

---

## 0. 当前已知 Bug（优先修复，影响后续所有 batch）

| 编号 | 位置 | 症状 | 修复方式 |
|---|---|---|---|
| **B0-1** | `Packages/LumiKernel/Sources/LumiKernel/LumiKernel.swift: registerTheme` | 主题插件调用 `kernel.registerTheme(...)` 是 NO-OP，主题栏永远空 | 已修复：`registerTheme` 转发到 `theme?.registerTheme(...)`；LumiThemeServicing 协议补 `registerTheme/unregisterTheme` |
| **B0-2** | `Plugins/PluginManagementPlugin/.../DefaultPluginProviding.swift:59` | `onEnabledPluginsChanged` 闭包定义了但**无任何地方调用**——运行期插件启用/禁用时无任何通知 | 改用 `NotificationCenter` 广播 `.lumiEnabledPluginsDidChange`，所有订阅方（MenuBar/LumiUI/ChatService 等）接 Notification |
| **B0-3** | `Plugins/ThemeStatusBarPlugin/.../DefaultThemeProviding.swift` | 缺 `ThemeSelectionStore`——选中主题后重启丢失 | 移植 `LumiUIService.ThemeSelectionStore` 进来 |
| **B0-4** | `Plugins/ThemeStatusBarPlugin/.../DefaultThemeProviding.swift` | 主题切换不会同步编辑器语法主题 | 移植 `LumiUIService.connectEditorThemeSync` 进来 |

---

## Batch 1 — App 层核心服务（4 个独立任务，可完全并行）

> 这 4 个服务在 4.19.0 旧版位于 `Packages/LumiAppKit/Sources/LumiAppKit/Services/`，总计 827 行。
> 新版要么没有、要么是空壳。**目标**：按 4.19.0 行为在 LumiFactory / 对应 Plugin 包里重建。

### B1-1: `EditorCoreService`（222 行 → 重建）

- **源**：`/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Services/EditorCoreService.swift`
- **当前**：`Plugins/EditorKernelPlugin/.../EditorKernelPlugin.swift` 只有 37 行，只 `kernel.registerEditor(EditorService())`
- **缺失功能**：
  - `LumiEditorServicing` 协议实现（currentProjectPathProvider 双向桥）
  - `configure(lumiCore:)` 注入 + 切换 `EditorSettingsLifecycle.hostPersistenceRootURL`
  - 订阅 `.lumiEnabledPluginsDidChange` → 刷新编辑器扩展
  - `syncAppSyntaxThemes()` 主题→编辑器语法主题同步
- **目标位置**：拆分为两部分
  1. `Plugins/EditorKernelPlugin/.../Services/EditorCoreService.swift` — 业务实现
  2. `LumiCoreAccessing` 协议补 `extensionRegistry: EditorExtensionRegistry` 暴露（如旧版）
- **依赖**：B0-2（notification 修复）完成后才能订阅
- **预计工时**：1 个 agent，4-6h
- **验证**：`LumiEditorServicing.configure(lumiCore:)` 调用后，`hostPersistenceRootURL` 切换到 lumiCore.storage.dataRootDirectory

### B1-2: `LumiUIService` + `ThemeSelectionStore`（168 行 → 重建）

- **源**：`/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Services/LumiUIService.swift`
- **当前**：`Plugins/ThemeStatusBarPlugin/.../DefaultThemeProviding.swift` 是简化版，没有持久化、没有插件启用刷新、没有编辑器主题同步
- **缺失功能**：
  - `ThemeSelectionStore`：plist 持久化选中的主题 ID
  - `reloadThemes(from:)`：从 PluginService 收集主题贡献并 replaceAll
  - 订阅 `.lumiEnabledPluginsDidChange` → 重新 reloadThemes
  - `connectEditorThemeSync(_:)`：主题变更触发编辑器语法主题同步
  - `restoreSavedThemeIfPossible()`：启动时恢复上次选择
- **目标位置**：
  1. `Plugins/ThemeStatusBarPlugin/.../Services/ThemeSelectionStore.swift` — 新增
  2. `Plugins/ThemeStatusBarPlugin/.../Providers/DefaultThemeProviding.swift` — 升级
- **依赖**：B0-2、B0-3、B0-4
- **预计工时**：1 个 agent，3-4h
- **验证**：选主题后重启 App，主题仍为上次选择

### B1-3: `MenuBarService`（437 行 → 重建）

- **源**：`/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Services/MenuBarService.swift`
- **当前**：`Plugins/MenuBarPlugin/.../DefaultMenuBarProviding.swift` 只有 59 行，是 registry 接口，不是 NSStatusItem 真实菜单栏
- **缺失功能**：
  - `NSStatusItem` 创建/管理
  - `MenuBarHostingView<MenuBarIconView>` 真实 SwiftUI 嵌入
  - `NSPopover` 弹窗管理
  - `contentTimer`：1s DispatchSourceTimer 定时刷新内容（已列入"主线程并发优化" P0 但仍是功能缺失）
  - `observeSystemAppearanceChanges / observeThemeWindowSync / observeLogoRegistry / observePluginStateChanges`
  - 事件监听（`eventMonitor`）
- **目标位置**：`Plugins/MenuBarPlugin/.../Services/MenuBarService.swift` — 新增
- **依赖**：B0-2
- **预计工时**：1 个 agent，6-8h（最复杂）
- **验证**：运行 App 看系统状态栏出现 Lumi 图标，点击展开 popup

### B1-4: `UpdateService` + `AppUpdateNotifications` + 4 个 Updates 文件（~300 行 → 重建）

- **源**：
  - `/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Services/UpdateService.swift`
  - `/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Events/AppUpdateNotifications.swift`
  - `/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Updates/FeedURLDetector.swift`
  - `/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Updates/FeedURLReachabilityChecker.swift`
  - `/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Updates/UpdateFeedURLProvider.swift`
  - `/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Updates/UpdateServiceStateMachine.swift`
- **当前**：完全缺失
- **目标位置**：新建 `Plugins/AppUpdatePlugin/`（参考 4.19.0 的 `AppUpdateStatusBarPlugin` 已有部分能力）
- **预计工时**：1 个 agent，4-5h
- **验证**：菜单"检查更新"按钮触发后能看到状态机变化

---

## Batch 2 — App 层辅助文件（3 个独立任务，可完全并行）

### B2-1: Bootstrap 4 个文件（~300 行）

- **源**：
  - `Bootstrap/AppBootstrap.swift`（常量定义）
  - `Bootstrap/MacAgent.swift`（macOS 特定 agent 注册）
  - `Bootstrap/OpenProjectHandler.swift`（从 Finder `application(_:openFile:)` 接项目）
  - `Bootstrap/EditorWindowSaveDelegate.swift`（窗口关闭/失焦自动保存）
- **当前**：`Packages/LumiFactory/Sources/LumiFactory/Bootstrap/AppBootstrap.swift` 只有 12 行常量，其他 3 个文件**完全缺失**
- **目标位置**：
  - `Packages/LumiFactory/Sources/LumiFactory/Bootstrap/OpenProjectHandler.swift`（公开单例）
  - `Packages/LumiFactory/Sources/LumiFactory/Bootstrap/EditorWindowSaveDelegate.swift`
  - `Packages/LumiFactory/Sources/LumiFactory/Bootstrap/MacAgent.swift`
- **依赖**：B1-1（需要 EditorService）
- **预计工时**：1 个 agent，3-4h
- **验证**：
  - 从 Finder 双击项目文件 → App 切换到该项目
  - 主窗口失焦 → 编辑器自动保存
  - 主窗口关闭 → 编辑器自动保存

### B2-2: 7 个 Command 文件（~400 行）

- **源**（4.19.0 的 `Commands/`）：
  - `ChatCommands.swift`（Cmd+L 聚焦 chat 等）
  - `CheckForUpdatesCommand.swift`
  - `DebugCommand.swift`
  - `EditorFocusKeys.swift`（Cmd+1/2/3 切换编辑器面板）
  - `EditorSaveCommands.swift`（Cmd+S）
  - `SettingsCommand.swift`（Cmd+,）
  - `WindowCommand.swift`（Cmd+W 关窗、Cmd+M 最小化等）
- **当前**：`Packages/LumiFactory/Sources/LumiFactory/Commands/AppCommands.swift` 只有 78 行，TODO 一堆
- **目标位置**：在 `LumiFactory/Commands/` 下补齐这 7 个文件
- **依赖**：无
- **预计工时**：1 个 agent，4-5h
- **验证**：所有快捷键（Cmd+, Cmd+S Cmd+1/2/3 Cmd+L 等）都生效

### B2-3: 8 个 Settings 文件（~1200 行）

- **源**（4.19.0 的 `Views/Settings/`）：
  - `SettingsView.swift`（主容器）
  - `SettingsSidebarHeaderView.swift`
  - `SettingsTab.swift`
  - `AboutPage.swift` / `AboutSettingsPage.swift`
  - `AppearanceSettingsPage.swift`
  - `GeneralSettingsPage.swift`
  - `PluginSettingsPage.swift`
- **当前**：`Packages/LumiFactory/Sources/LumiFactory/Windows/WindowSettings.swift` 没有这些页面
- **目标位置**：`Packages/LumiFactory/Sources/LumiFactory/Views/Settings/` 新建 8 个文件
- **依赖**：B0-2（订阅插件启用变化）、B1-2（ThemeSelectionStore 才能做外观设置）
- **预计工时**：1 个 agent，6-8h
- **验证**：Cmd+, 打开设置窗口，能在侧边栏切换 4 个 tab

---

## Batch 3 — 视图层（依赖 Batch 1，可部分并行）

### B3-1: Layout 视图 6 个（~500 行）

- **源**（4.19.0 的 `Views/Layout/`）：
  - `ActivityBar.swift`（侧边活动栏）
  - `AppTitleToolbar.swift`（标题工具栏）
  - `SplitViewPersistence.swift`（已有，需对齐 4.19.0）
  - `StatusBar.swift`（状态栏顶层）
  - `WindowAccessor.swift`（NSWindow 访问器）
  - `WindowToolbarSuppressor.swift`（隐藏窗口 chrome）
- **当前**：大部分缺失
- **目标位置**：`Packages/LumiFactory/Sources/LumiFactory/Views/Layout/`
- **依赖**：B1-3（MenuBar 状态栏要驱动 StatusBar）
- **预计工时**：1 个 agent，4-5h

### B3-2: Chat 视图 4 个（~800 行）

- **源**（4.19.0 的 `Views/Layout/Chat/`）：
  - `ChatView.swift`
  - `ChatSectionView.swift`
  - `ChatSectionToolbarSync.swift`
  - `ChatHeaderView.swift`
  - `ChatToolbarView.swift`
- **当前**：`Packages/LumiFactory/Sources/LumiFactory/Views/Layout/Chat/` 已有但**可能是简化版**（需 diff 验证）
- **依赖**：ChatKernelPlugin / ChatPanelPlugin
- **预计工时**：1 个 agent，6-8h
- **验证**：能完整看到 Chat 区域、Header、Toolbar

### B3-3: Panel / Rail 视图（已在 LumiFactory，但需对齐 4.19.0）

- **源**（4.19.0 的 `Views/Layout/Panel/` + `Rail/`）：已存在
- **任务**：与 4.19.0 diff 对齐，找缺失逻辑
- **预计工时**：1 个 agent，2-3h

### B3-4: 其他视图

- `Views/Common/LoadingView.swift`（独立小视图）
- `Views/Common/CrashedView.swift`（已有但需对齐）
- `Views/Logo/LogoView.swift`
- `Views/MenuBar/MenuBarHostingView.swift`（配合 B1-3 MenuBarService）
- `Views/Editor/EditorScopeView.swift`

---

## Batch 4 — 集成层（依赖 Batch 1+2+3）

### B4-1: 重写 `WindowMain` / `WindowSettings`

- **源**：`/Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Windows/`
- **当前**：`Packages/LumiFactory/Sources/LumiFactory/Windows/WindowMain.swift`（143 行）— 缺 OpenProjectHandler 配置、缺 EditorWindowSaveDelegate 挂载
- **任务**：
  - `WindowMain`：`initializeKernel` 完成后调 `OpenProjectHandler.shared.configure(lumiCore:)`、挂 `EditorWindowSaveDelegate` 到 NSWindow
  - `WindowSettings`：完整 SettingsView 容器
- **依赖**：B1-1、B2-1
- **预计工时**：1 个 agent，2-3h

### B4-2: 重写 `LumiFactory` 启动流程

- **源**：4.19.0 的 `RootContainer.swift`（185 行）
- **当前**：`LumiFactory.createKernel()`（~60 行）— 缺 applyChatPluginContributions、bootstrapToolContributions、pluginsChangedObserver 订阅
- **任务**：
  - 启动后 `chatService.applyPluginContributions(from: kernel, toolExecutionHook: ...)`
  - 启动后 `agentToolComponent.bootstrapToolContributions(...)`
  - 订阅 `.lumiEnabledPluginsDidChange` → 重新 apply + bootstrap
  - `LumiCore.current = lumiCore` 静态指针（供 FileLogPlugin 等用）
- **依赖**：B1-1、B1-2
- **预计工时**：1 个 agent，3-4h

### B4-3: 重写 `AppLayoutView`

- **源**：4.19.0 的 `Views/Layout/AppLayoutView.swift`
- **当前**：`Packages/LumiFactory/Sources/LumiFactory/Views/Layout/AppLayoutView.swift`（约 250 行）— 可能缺 ActivityBar / StatusBar / AppTitleToolbar 集成
- **依赖**：B3-1、B3-2
- **预计工时**：1 个 agent，2-3h

---

## Batch 5 — 插件层补漏

### B5-1: 22 个 LLM Provider 插件目前是空 stub

- **位置**：`Plugins/LLMProvider*Plugin/Sources/`
- **状态**：仅有 stub Plugin 类，**没有 OpenAI / Anthropic / Zhipu / Kimi / etc 实际实现**
- **参照**：`/Users/colorfy/Downloads/Lumi-4.19.0/Plugins/LLMProviderOpenAIPlugin/Sources/OpenAIProvider.swift` 等
- **任务**：补全每个 provider 的真实 API 客户端（HTTP 请求、流式响应、错误处理）
- **预计工时**：每 provider 1-2h，22 个总 ~30h
- **分配**：可分 4 个 agent，每个 5-6 个 provider

### B5-2: 验证 153 个插件无遗漏的旧 API 引用

- **检查命令**：
  ```bash
  grep -rln "LumiAppKit\|LumiCoreKit\|LumiCorePlugin\|LumiPluginRegistry" Plugins/ 2>/dev/null
  ```
- **目标**：0 个匹配
- **预计工时**：1 个 agent，2-3h（grep + 修复）

### B5-3: 旧版 `AppIconDesigner`、`CADDesigner` 等 UI 复杂插件的功能验证

- 可能在迁移到新协议时丢了 view 逻辑
- 每个插件独立 review

---

## Batch 6 — 编译 & 验证

### B6-1: `swift build` 全量通过

```bash
cd /Users/colorfy/Code/CofficLab/Lumi/Packages/LumiFactory
swift build
```

### B6-2: `xcodebuild` 全量通过

```bash
cd /Users/colorfy/Code/CofficLab/Lumi
xcodebuild -project Lumi.xcodeproj -scheme Lumi -destination 'platform=macOS' build
```

### B6-3: 启动 App 冒烟测试

- [ ] App 能正常启动，无 crash
- [ ] 主题栏出现并能切换主题
- [ ] 设置窗口能打开且 4 个 tab 都有内容
- [ ] 菜单栏系统状态栏图标出现
- [ ] 编辑器能打开文件、保存、关闭
- [ ] Chat 能发送消息、收到回复
- [ ] 插件启用/禁用实时刷新 UI
- [ ] 从 Finder 双击项目文件能切换项目
- [ ] 主题选择后重启 App 仍保留

---

## 资源 / 参考

- 旧版完整路径：`/Users/colorfy/Downloads/Lumi-4.19.0/`
- 关键 diff 命令：
  ```bash
  diff -ru /Users/colorfy/Downloads/Lumi-4.19.0/Packages/LumiAppKit/Sources/LumiAppKit/Services/ \
          Packages/LumiFactory/Sources/LumiFactory/  # 找缺失逻辑
  ```
- 新 LumiKernel 服务列表：`Packages/LumiKernel/Sources/LumiKernel/LumiKernel.swift` (line 100+)
- 新 LumiPlugin 协议：`Packages/LumiKernel/Sources/LumiKernel/Contracts/LumiPlugin.swift`

---

## 优先级建议

1. **B0-1~B0-4**：必做，否则核心 UI 跑不通
2. **B1-2**：必做，主题功能核心
3. **B2-1**：必做，Finder 集成是基础
4. **B2-2**：必做，快捷键用户立刻感受到
5. **B1-1, B1-3, B1-4**：高价值但工时大
6. **B2-3**：高价值，工时大
7. **B3-x, B4-x**：依赖前面，可后做
8. **B5-1**：可后做，每个 provider 独立
9. **B6**：最后做总验证

---

**创建时间**: 2026-07-20
**总工时估算**: ~80-100h（4-5 个 agent 并行 1 周）
**状态**: 待分发
