# 取消 PluginContext，插件直接操作内核 — 执行计划

> 目标：完全移除 `PluginContext` / `LumiPluginContext`，所有插件方法直接接收 `lumiCore: any LumiCoreAccessing`，原本由上下文承载的布局/视图状态下沉到 `LumiCore.layoutComponent.state`。

---

## 0. 核心设计决策

- `LumiPluginContext` 的三类职责拆分：
  - **内核访问** → 直接传 `lumiCore: any LumiCoreAccessing`
  - **布局/视图状态** → 写入 `LumiCore.layoutComponent.state`
  - **依赖注入** → 走 `LumiCore` 服务表（`registerService` / `resolveService`）
- `LumiCoreAccessing` 增加 `resolveService`，让插件能在运行时解析服务。
- App 层服务（`ChatSectionCoordinator`、`LumiEditorServicing`、`LumiThemeServicing`）必须在 `RootContainer` 注册进 `LumiCore`。
- `LumiPlugin.lifecycle` 增加 `lumiCore` 参数，避免启动期依赖不可靠的 `LumiCore.current`。

---

## Phase 1：内核与协议改造

### 1.1 改造 `LumiCoreAccessing` 协议
**文件**：`Packages/LumiCorePlugin/Sources/LumiCoreAccessing.swift`

- [ ] 在 `LumiCoreAccessing` 中加入 `func resolveService<T>(_ type: T.Type) -> T?`
- [ ] 从 `LumiCoreAccessing` 中删除 `makePluginContext(...)`
- [ ] `LumiCoreBootstrapping` 保留 `registerService`，但 `resolveService` 迁移到 `LumiCoreAccessing` 后，该协议可以只保留注册相关能力
- [ ] 更新文件头注释，移除与 `LumiPluginContext` 相关的描述

### 1.2 把上下文中的布局状态下沉到内核
**文件**：`Packages/LumiCoreLayout/Sources/LayoutState.swift`

在 `LayoutState` 中新增以下 `@Published` 属性：

- [ ] `activeViewContainerTitle: String = "Main"`
- [ ] `currentChatSection: LumiChatSectionLayout = .none`
- [ ] `showsRail: Bool = false`
- [ ] `showsPanelChrome: Bool = false`
- [ ] `isChatSectionVisible: Bool = false`（可与已有 `chatSectionVisible` 对齐命名，避免歧义）

**约束**：这些字段是**当前视图快照**，不持久化、不发通知（或在 `AppLayoutView` 中按需更新），仅作为插件读取的“当前布局上下文”。

### 1.3 更新 `LumiCore` 实现
**文件**：`Packages/LumiCoreKit/Sources/LumiCore.swift`

- [ ] 删除 `makePluginContext(...)` 方法
- [ ] 确保 `LumiCore` 继续实现 `resolveService`（因为已加入 `LumiCoreAccessing`）
- [ ] 保留 `registerService` 在 `LumiCoreBootstrapping` 中，仅启动期使用

### 1.4 清理类型别名
**文件**：`Packages/LumiCoreKit/Sources/LumiCoreTypes.swift`

- [ ] 删除 `public typealias LumiPluginContext = LumiCorePlugin.LumiPluginContext`
- [ ] 删除 `public typealias LumiPluginDependencies = LumiCorePlugin.LumiPluginDependencies`

---

## Phase 2：Plugin 协议与 Registry

### 2.1 重写 `LumiPlugin` 协议
**文件**：`Packages/LumiCorePlugin/Sources/LumiPlugin.swift`

- [ ] 把所有方法参数从 `context: LumiPluginContext` 改为 `lumiCore: any LumiCoreAccessing`
- [ ] `lifecycle(_ event:)` 改为 `lifecycle(_ event: LumiPluginLifecycle, lumiCore: any LumiCoreAccessing)`
- [ ] `onTurnFinished(context:conversationID:reason:)` 改为 `onTurnFinished(lumiCore:conversationID:reason:)`
- [ ] `configureEditorRuntime(_ context: PluginRuntimeContext)` 改为 `configureEditorRuntime(lumiCore: any LumiCoreAccessing)`，或评估后移除
- [ ] 所有默认实现同步更新参数名

### 2.2 删除遗留上下文类型
**文件**：`Packages/LumiCorePlugin/Sources/SuperPluginLegacyTypes.swift`

- [ ] 删除 `PluginContext`
- [ ] 删除 `PluginRuntimeContext`
- [ ] 删除 `EditorLanguageRuntimeBridge`
- [ ] 如该文件变空，直接删除文件

### 2.3 更新 `LumiPluginRegistry`
**文件**：`Packages/LumiPluginRegistry/Sources/LumiPluginRegistry.swift`

- [ ] 所有聚合方法（`titleToolbarItems`/`statusBarItems`/`viewContainers`/`llmProviders`/`agentTools`/`subAgents`/`sendMiddlewares`/`messageRenderers`/`rootOverlays`/`onboardingPages`/`chatSectionItems`/...）改为接收 `lumiCore: any LumiCoreAccessing`
- [ ] `dispatchLifecycle` 把 `lumiCore` 传给每个插件
- [ ] `restoreLayoutEarly()` 如需调用 `LayoutPlugin.lifecycle`，可传 `LumiCore.current!`

### 2.4 更新 `AgentToolProviding`
**文件**：`Packages/LumiCorePlugin/Sources/AgentToolProviding.swift`

- [ ] `agentTools(context:)` → `agentTools(lumiCore:)`
- [ ] `subAgents(context:)` → `subAgents(lumiCore:)`

---

## Phase 3：Chat 层改造

### 3.1 改造 `ChatServiceDelegate`
**文件**：`Packages/LumiCoreChat/Sources/ChatServiceDelegate.swift`

- [ ] 删除 `makePluginContext(...)` 方法
- [ ] 如需要，增加 `var lumiCore: (any LumiCoreAccessing)? { get }`

### 3.2 改造 `ChatService`
**文件**：`Packages/LumiCoreChat/Sources/ChatService.swift`

- [ ] 删除 `makeChatPluginContext()`
- [ ] `applyPluginContributions(from:toolExecutionHook:)` 直接使用 `delegate?.lumiCore`
- [ ] `onTurnFinished` 回调中构造 lumiCore 传给 `provider`
- [ ] 修复 `makeAssistantMessage` 等位置：当前只传了 `builtInTools`，应改为同时传入 `pluginTools`

### 3.3 改造 `SendPipeline`
**文件**：`Packages/LumiCoreChat/Sources/Managers/SendPipeline.swift`

- [ ] `makePerRequestToolService(for:)` 改为：
  1. 通过 `provider.agentTools(lumiCore:)` 收集插件工具
  2. 调用 `service.agentToolComponent.buildToolSet(builtInTools:..., pluginTools: ...)`
- [ ] 处理插件工具收集异常，软降级（不要阻断发送）

---

## Phase 4：App Shell 改造

### 4.1 改造 `PluginService`
**文件**：`Packages/LumiAppKit/Sources/LumiAppKit/Services/PluginService.swift`

- [ ] 所有方法参数 `context:` → `lumiCore:`
- [ ] `registerPluginContributions(context:)` → `registerPluginContributions(lumiCore:)`
- [ ] `onTurnFinished(context:...)` → `onTurnFinished(lumiCore:...)`
- [ ] 保持 `AgentToolProviding` / `LumiChatContributionProviding` / `LumiLLMProviderSettingsContributing` 协议实现

### 4.2 改造 `AppLayoutView`
**文件**：`Packages/LumiAppKit/Sources/LumiAppKit/Views/Layout/AppLayoutView.swift`

- [ ] 删除 `basePluginContext(...)` 私有方法
- [ ] 在 `body` 计算当前容器后，把信息同步写入 `lumiCore.layoutComponent.state`：
  - `activeViewContainerID`
  - `activeViewContainerTitle`
  - `currentChatSection`
  - `showsRail`
  - `showsPanelChrome`
  - `isChatSectionVisible`
- [ ] 所有 `pluginService.xxx(context:)` 改为 `pluginService.xxx(lumiCore: lumiCore)`
- [ ] 给子视图传 `lumiCore` 而不是 `pluginContext`

### 4.3 改造子视图
**文件**：
- `Packages/LumiAppKit/Sources/LumiAppKit/Views/Layout/Chat/ChatView.swift`
- `Packages/LumiAppKit/Sources/LumiAppKit/Views/Layout/AppTitleToolbar.swift`
- `Packages/LumiAppKit/Sources/LumiAppKit/Views/Layout/StatusBar.swift`
- `Packages/LumiAppKit/Sources/LumiAppKit/Views/Layout/Panel/PanelColumnView.swift`

- [ ] 删除 `pluginContext` 参数，改为 `lumiCore: LumiCore`
- [ ] 内部读布局状态时从 `lumiCore.layoutComponent.state` 获取

### 4.4 改造其他调用点
**文件**：
- `Packages/LumiAppKit/Sources/LumiAppKit/Bootstrap/RootView.swift`
- `Packages/LumiAppKit/Sources/LumiAppKit/Views/Settings/SettingsView.swift`
- `Packages/LumiAppKit/Sources/LumiAppKit/Views/Settings/PluginSettingsPage.swift`

- [ ] 删除 `makePluginContext` 调用
- [ ] 直接传 `lumiCore` 给插件服务或视图

### 4.5 补全 App 层服务注册
**文件**：`Packages/LumiAppKit/Sources/LumiAppKit/Bootstrap/RootContainer.swift`

- [ ] 注册 `(any LumiEditorServicing).self` → `editorCoreService`（当前只注册了具体类型 `EditorCoreService.self`）
- [ ] 确认 `ChatSectionCoordinator.self` 已注册
- [ ] 确认 `LumiThemeServicing.self` 已注册
- [ ] 确认 `(any LumiLLMProviderSettingsContributing).self` 已注册

---

## Phase 5：批量迁移插件

> 所有插件统一替换模式见「附录：典型代码替换模式」。以下按依赖分组列出关键文件，执行时应一组一组改。

### 5.1 编辑器相关插件（依赖 `LumiEditorServicing`）
- [ ] `Plugins/EditorStickySymbolBarPlugin/Sources/EditorStickySymbolBarPlugin.swift`
- [ ] `Plugins/EditorProblemsPlugin/Sources/EditorProblemsPlugin.swift`
- [ ] `Plugins/EditorOutlinePlugin/Sources/EditorOutlinePlugin.swift`
- [ ] `Plugins/EditorCallHierarchyPlugin/Sources/EditorCallHierarchyPlugin.swift`
- [ ] `Plugins/EditorTabStripPlugin/Sources/StripPlugin.swift`
- [ ] `Plugins/EditorBreadcrumbNavPlugin/Sources/EditorBreadcrumbNavPlugin.swift`
- [ ] `Plugins/EditorSearchPlugin/Sources/EditorSearchPlugin.swift`
- [ ] `Plugins/EditorReferencesPlugin/Sources/EditorReferencesPlugin.swift`
- [ ] `Plugins/EditorSwiftPlugin/Sources/EditorSwiftPlugin.swift`
- [ ] `Plugins/QuickFileSearchPlugin/Sources/QuickFileSearchPlugin.swift`

### 5.2 Chat 相关插件（依赖 `LumiChatServicing` / `ChatSectionCoordinator`）
- [ ] `Plugins/GoalTaskPlugin/Sources/Plugin.swift`
- [ ] `Plugins/AutoTaskPlugin/Sources/Plugin.swift`
- [ ] `Plugins/AskUserPlugin/Sources/Hooks/AskUserResumeHook.swift`
- [ ] `Plugins/ChatPanelPlugin/Sources/ChatPanelPlugin.swift`
- [ ] `Plugins/ChatPanelPlugin/Sources/ChatSectionPlugins.swift`
- [ ] `Plugins/ChatModePlugin/Sources/ChatModePlugin.swift`
- [ ] `Plugins/ModelSelectorPlugin/Sources/ModelSelectorPlugin.swift`
- [ ] `Plugins/MessageRendererPlugin/Sources/MessageRendererPlugin.swift`

### 5.3 LLM Provider 插件
- [ ] `Plugins/LLMProviderOpenAIPlugin/Sources/OpenAIPlugin.swift`
- [ ] `Plugins/LLMProviderAnthropicPlugin/Sources/AnthropicPlugin.swift`
- [ ] `Plugins/LLMProviderDeepSeekPlugin/Sources/DeepSeekPlugin.swift`
- [ ] `Plugins/LLMProviderKimiCodePlugin/Sources/KimiCodePlugin.swift`
- [ ] `Plugins/LLMProviderZhipuPlugin/Sources/ZhipuPlugin.swift`
- [ ] `Plugins/LLMProviderMLXPlugin/Sources/LLMProviderMLXPluginBootstrap.swift`
- [ ] 其余所有 `Plugins/LLMProvider*/Sources/*.swift`

### 5.4 工具类插件（使用 `currentProject` / `currentProjectPath`）
- [ ] `Plugins/OpenRemotePlugin/Sources/AgentOpenRemotePlugin.swift`
- [ ] `Plugins/GitHubPlugin/Sources/GitHubPlugin.swift`
- [ ] `Plugins/GitHubPlugin/Sources/Middleware/GitHubKBChatMiddleware.swift`
- [ ] `Plugins/EditorTabStripPlugin/Sources/Tools/GetCurrentFileTool.swift`
- [ ] `Plugins/EditorTabStripPlugin/Sources/Tools/SetCurrentFileTool.swift`
- [ ] `Plugins/IdleTimePlugin/Sources/IdleTimePlugin.swift`

### 5.5 Bootstrap 类插件
- [ ] `Plugins/LayoutPlugin/Sources/LayoutPluginBootstrap.swift`
- [ ] `Plugins/RClickPlugin/Sources/RClickPluginBootstrap.swift`
- [ ] `Plugins/EditorFileTreePlugin/Sources/EditorFileTreePluginBootstrap.swift`
- [ ] `Plugins/EditorFileTreeV2Plugin/Sources/EditorFileTreeV2PluginBootstrap.swift`
- [ ] `Plugins/EditorTabStripPlugin/Sources/StripPluginBootstrap.swift`
- [ ] `Plugins/MenuBarManagerPlugin/Sources/MenuBarManagerPluginBootstrap.swift`
- [ ] `Plugins/ProjectIssueScannerPlugin/Sources/ProjectIssueScannerPluginBootstrap.swift`
- [ ] `Plugins/GitHubPlugin/Sources/GitHubInsightPluginBootstrap.swift`
- [ ] `Plugins/AgentTempStoragePlugin/Sources/AgentTempStoragePluginBootstrap.swift`
- [ ] `Plugins/MemoryPlugin/Sources/MemoryPluginBootstrap.swift`
- [ ] `Plugins/LLMProviderMLXPlugin/Sources/LLMProviderMLXPluginBootstrap.swift`
- [ ] `Plugins/AppStoreConnectPlugin/Sources/AppStoreConnectPluginBootstrap.swift`

### 5.6 使用 `LumiCore.current` 的插件
- [ ] `Plugins/ProjectsPlugin/Sources/ProjectsPlugin.swift`
- [ ] `Plugins/FileLogPlugin/Sources/FileLogPlugin.swift`
- [ ] `Plugins/GoalTaskPlugin/Sources/Plugin.swift`
- [ ] `Plugins/AutoTaskPlugin/Sources/Plugin.swift`

### 5.7 其他插件
- [ ] 运行 `grep -R "context: LumiPluginContext\|context\.lumiCore\|context\.resolve\|context\.activeSectionID\|context\.showsRail\|context\.showsPanelChrome\|context\.showsChatSection\|context\.isChatSectionVisible\|context\.currentProject\|LumiPluginContext(" Plugins/` 找出遗漏文件并逐一修复

---

## Phase 6：删除文件与全局清理

### 6.1 删除文件
- [ ] `Packages/LumiCorePlugin/Sources/LumiPluginContext.swift`
- [ ] `Packages/LumiCorePlugin/Sources/SuperPluginLegacyTypes.swift`

### 6.2 清理引用
- [ ] 搜索 `LumiPluginContext`、`PluginContext`、`LumiPluginDependencies`、`PluginRuntimeContext`，确保没有残留引用
- [ ] 搜索 `makePluginContext`，确保没有残留调用
- [ ] 搜索 `context\.lumiCore`，确保没有残留

### 6.3 Package.swift 检查
- [ ] 确认没有因删除文件导致的编译目标缺失

---

## Phase 7：Preview Support & Tests

### 7.1 Preview Support
- [ ] `Plugins/GitPlugin/Sources/Support/PreviewGitSupport.swift`
- [ ] `Plugins/EditorFileTreePlugin/Sources/Support/PreviewEditorFileTreeSupport.swift`
- [ ] `Plugins/EditorSwiftPlugin/Sources/Support/PreviewEditorSwiftSupport.swift`

改为构造 mock `LumiCoreAccessing` 或注册服务到真实 `LumiCore`。

### 7.2 Plugin Tests
大量测试使用 `LumiPluginContext(...)` + `dependencies.register(...)`。统一改为：
- [ ] 构造实现 `LumiCoreAccessing` 的 mock，或
- [ ] 使用真实 `LumiCore` 并注册所需服务

重点文件：
- [ ] `Plugins/ProjectsPlugin/Tests/ProjectsPluginTests/ProjectsPluginTests.swift`
- [ ] `Plugins/EditorSwiftPlugin/Tests/EditorSwiftPluginTests.swift`
- [ ] `Plugins/EditorPanelPlugin/Tests/PluginEditorPanelTests.swift`
- [ ] `Plugins/LLMProviderMLXPlugin/Tests/PluginLLMProviderMLXTests.swift`
- [ ] `Plugins/ThemeStatusBarPlugin/Tests/ThemeStatusBarPluginTests.swift`
- [ ] 其余 `Plugins/*/Tests/*.swift`

### 7.3 LumiCoreKit Tests
- [ ] `Packages/LumiCoreKit/Tests/LumiCoreKitTests/LumiCoreTests.swift`
- [ ] `Packages/LumiCoreKit/Tests/LumiCoreKitTests/LayoutStateTests.swift`

---

## Phase 8：编译与验证

### 8.1 编译顺序
按依赖顺序执行：
1. `LumiCorePlugin`
2. `LumiCoreKit`
3. `LumiCoreChat`
4. `LumiAppKit`
5. `LumiPluginRegistry`
6. 各 `Plugins/*`
7. `LumiApp`
8. Tests

### 8.2 关键验证点
- [ ] 应用启动不 crash
- [ ] `RootContainer` 初始化成功
- [ ] 切换 view container 时插件 UI 正确过滤（rail / panel chrome / chat section）
- [ ] Chat 发送消息时插件工具被正确收集并传入 LLM
- [ ] LLM Provider 插件正常注册、可切换
- [ ] 设置页「插件」列表与详情正常
- [ ] 编辑器相关插件（file tree、outline、problems、tab strip 等）正常显示
- [ ] 插件启用/禁用后 Chat 贡献（middleware / provider / renderer）重载正常
- [ ] 关闭并重新打开应用后布局状态正确恢复

---

## 附录：典型代码替换模式

### A. 插件方法签名
```swift
// 旧
static func agentTools(context: LumiPluginContext) throws -> [any LumiAgentTool]

// 新
static func agentTools(lumiCore: any LumiCoreAccessing) throws -> [any LumiAgentTool]
```

### B. 读取当前项目
```swift
// 旧
context.currentProject?.path
context.lumiCore?.projectComponent.currentProject?.path

// 新
lumiCore.projectComponent.currentProject?.path
```

### C. 解析服务
```swift
// 旧
context.resolve(LumiChatServicing.self)
context.resolve(LumiEditorServicing.self)?.editorService

// 新
lumiCore.resolveService((any LumiChatServicing).self)
lumiCore.resolveService((any LumiEditorServicing).self)?.editorService
```

### D. 布局状态
```swift
// 旧
context.activeSectionID
context.showsRail
context.showsPanelChrome
context.isChatSectionVisible
context.activeSectionTitle

// 新
lumiCore.layoutComponent.state.activeViewContainerID
lumiCore.layoutComponent.state.showsRail
lumiCore.layoutComponent.state.showsPanelChrome
lumiCore.layoutComponent.state.isChatSectionVisible
lumiCore.layoutComponent.state.activeViewContainerTitle
```

### E. 生命周期
```swift
// 旧
static func lifecycle(_ event: LumiPluginLifecycle) throws {
    let dir = LumiCore.current?.storage.pluginDataDirectory(for: "Foo")
}

// 新
static func lifecycle(_ event: LumiPluginLifecycle, lumiCore: any LumiCoreAccessing) throws {
    let dir = lumiCore.storage.pluginDataDirectory(for: "Foo")
}
```

### F. 创建插件工具（工具内部）
```swift
// 旧
let projectPath = context.currentProjectPath

// 新
let projectPath = lumiCore.projectComponent.currentProject?.path ?? ""
```

---

## 执行建议

1. **不要一次性全改**：先完成 Phase 1-4 让内核/App 层编译通过，再批量迁移插件。
2. **保持默认实现**：`LumiPlugin` 的 extension 默认实现要同步改签名，否则旧插件会编译失败。
3. **优先处理高频插件**：EditorFileTree、ChatPanel、Projects、ModelSelector、GitPlugin 先改，便于早验证。
4. **善用全局搜索**：每完成一组，用 `grep` 确认对应关键词归零。
5. **测试跟随**：改一个插件就改对应测试，不要留到最后统一修测试。
