# Provider Observer-Only Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让所有 `*Providing` 的外部状态变化都通过类型化的 `add...Observer` + `ObserverHandle` 通知，禁止消费方直接监听 `ObservableObject.objectWillChange`、裸 Combine Publisher 或 Provider 内部状态。

**Architecture:** Provider 负责发布领域事件和维护观察者句柄；插件或宿主集成层在插件入口/装配入口创建并持有 Observer。Observer 将 Provider 事件转换为插件自己的 ViewModel 状态，视图只绑定注入的 ViewModel。Provider 可以继续在内部使用 `@Published` 保存状态，但该机制不再作为跨模块通知协议。

**Tech Stack:** Swift 6, SwiftUI, Combine（仅用于 Provider 内部实现或 Observer 适配）, `@MainActor`, Swift Package Manager, Xcode/macOS。

---

## 1. 现状与验收边界

当前仓库已经有一批符合目标的实现：Project、Theme、Rail、Chat、ConversationState、Message、MessageStreaming 等 Provider 已提供类型化 Observer API，部分插件也已经使用插件入口持有 Observer 并更新 ViewModel。本计划是在这些实现之上完成剩余统一，而不是重新设计一套并行通知系统。

审计已发现的主要不一致：

- `ConversationManaging` 仍继承 `ObservableObject`，并在协议文档中推荐通过 `objectWillChange` 通知；直接消费点包括：
  - `Packages/ProviderChatSection/Sources/ProviderChatSection/DefaultChatSectionProviding.swift`
  - `Packages/PluginConversationMode/Sources/PluginConversationMode/Observers/ConversationManagerObservationBox.swift`
  - `Packages/PluginConversationInput/Sources/PluginConversationInput/Observers/ConversationInputObserver.swift`
  - `Packages/ProviderConversation/Sources/ProviderConversation/ConversationManaging.swift`
- `ChatSectionProviding` 被 `Packages/ProviderRootView/Sources/ProviderRootView/RootViewProviding.swift` 直接监听 `objectWillChange`。
- `RailViewProviding` 仍暴露 `railVisibilityPublisher`、`railWidthPublisher`；`ChatSectionProviding` 仍暴露 `chatSectionWidthPublisher`，并被以下 Factory 消费：
  - `Packages/FactoryLumi/Sources/FactoryLumi/ViewFactory.swift`
  - `Packages/FactoryAppIconDesigner/Sources/FactoryAppIconDesigner/ViewFactory.swift`
  - `Packages/FactoryBookletMaker/Sources/FactoryBookletMaker/ViewFactory.swift`
- `PromptSuggestionProviding.changes` 仍被 `Packages/PluginMessageList/Sources/PluginMessageList/MessageListPlugin.swift` 直接消费。
- `LLMModelDownloadProviding.downloadStatePublisher` 仍出现在 Provider 协议中，虽然当前已有插件 Observer 适配它。
- `ActivityBarProviding`、`ContentViewProviding`、`DocsViewProviding`、`MenuBarProviding`、`RootViewProviding`、`SettingViewProviding`、`ToolbarProviding`、`MessageRenderingProviding` 等贡献型 Provider 仍主要依赖 `ObservableObject`，需要逐个确认其外部变化是否有类型化事件。

以下内容不自动纳入“Provider 唯一监听通道”迁移：

- `NotificationCenter`、`DistributedNotificationCenter`、`NSEvent` monitor 等对系统事件的底层监听；它们可以继续被插件自己的 `Observers` 封装。
- OSLogStore、文件修改时间、IdleTime、设备/网络/剪贴板/显示器等轮询或系统源实现；只有当它们跨插件暴露为 Provider 状态时，才必须经过 Provider Observer。
- `ScrollViewBottomTracker`、搜索/排序模型、`ShowImageState`、`HTTPExportProgress` 等局部视图或任务状态。

最终原则是：Provider 的跨模块消费者只能订阅类型化 Observer；Provider 内部可以使用 `@Published` 或 Combine 实现状态存储和适配，但不得把它们作为公共监听协议。

## 2. 目标架构

```text
Provider state mutation
        │
        ├── update published/internal state
        └── emit typed ProvidingEvent to registered handles
                         │
                         ▼
              plugin-owned Observer
                         │
                         └── update plugin ViewModel
                                      │
                                      ▼
                         injected @ObservedObject View
```

每个需要对外通知的 Provider 遵循同一组约束：

```swift
enum ChatSectionProvidingEvent {
    case widthChanged(CGFloat)
    case visibilityChanged(Bool)
}

@MainActor
protocol ChatSectionProviding {
    @discardableResult
    func addObserver(
        _ observer: @escaping (ChatSectionProvidingEvent) -> Void
    ) -> ObserverHandle
}
```

实现时必须保证：

1. ObserverHandle 可取消、可释放，且不会让 Provider 强持有插件控制器或 ViewModel。
2. 事件在 Provider 状态真正变化时发送；重复赋值不产生无意义重复事件，除非现有语义明确要求。
3. 观察器注册后能获得必要的初始快照，或由插件入口显式读取一次当前状态；不能因注册时机导致 UI 永久使用默认值。
4. Provider 和 Observer 的 actor 隔离保持一致，UI 状态更新发生在 `@MainActor`。
5. 公共协议不再暴露 `ObservableObjectPublisher`、`AnyPublisher` 或 Provider 内部的 `@Published` 属性作为跨模块通知入口。
6. Observer 只负责把领域事件翻译成插件 ViewModel 状态；View 不直接依赖 Provider 的发布实现。

## 3. 关键架构决策（ADR）

### ADR-001：统一使用类型化 ObserverHandle，而非公共 Publisher

采用 `addObserver` 返回 `ObserverHandle`，事件使用每个 Provider 自己的 enum 或明确类型。这样可以保留编译期事件约束、隐藏 Combine 实现细节并统一生命周期管理。拒绝以 `AnyPublisher` 作为长期公共协议，因为它会继续允许消费方绕过插件 Observer/ViewModel，并使线程、去重和初始快照语义分散在各调用点。

### ADR-002：先保留 Provider 内部 ObservableObject，再逐步移除协议约束

迁移第一阶段只禁止跨模块消费 `objectWillChange`，Provider 内部可继续用 `@Published` 实现状态。确认所有消费者完成替换后，再从不需要 SwiftUI 绑定的协议移除 `ObservableObject` 继承或约束。这样可以降低一次性编译爆炸风险，同时避免把内部实现细节误当成公共架构。

### ADR-003：公共裸 Publisher 必须被替换，不能长期双轨

对布局、提示建议、下载状态等现有裸 Publisher，先新增等价类型化事件并迁移全部消费者，再删除旧属性、适配器和文档。短期双轨只允许存在于同一个迁移提交中，且必须有明确删除点，避免新代码继续依赖旧通道。

## 4. 实施任务

### Task 1：建立静态审计基线

**Files:** `Packages/Provider*/**`, `Packages/Plugin*/**`, 本计划文档。

1. 检查所有 `*Providing` 协议、默认实现及其跨包引用。
2. 搜索以下模式并按“Provider 公共协议 / Provider 内部实现 / 插件 Observer / 局部 UI 状态 / 系统源监听”分类：

```bash
rg -n 'objectWillChange|\.sink\s*\{|AnyPublisher|Publisher|@Published|NotificationCenter|NSEvent|Timer|DispatchSource' Packages
rg -n 'protocol .*Providing|class .*Providing|struct .*Providing|add[A-Za-z]+Observer|ObserverHandle' Packages
```

3. 将每个 Provider 的状态、事件、消费者、生命周期持有点登记到迁移清单。
4. 记录当前基线构建命令和已知测试，后续每个阶段只允许减少公共绕过点。

**验证:** 审计结果能明确列出所有直接 `.objectWillChange` 消费、裸 Provider Publisher 消费以及仍缺少事件协议的 Provider。

### Task 2：统一 ObserverHandle 与事件实现模板

**Files:** 以现有 `ObserverHandle`、`ProjectObservation`、`DefaultProjectProvider` 等实现为参考；必要时修改其公共基础类型和 Provider 测试。

1. 确定仓库中唯一可复用的 handle 生命周期语义：注册、取消、Provider 释放、重复取消都安全。
2. 统一事件命名、`@MainActor` 隔离、初始快照策略和回调存储方式。
3. 不复制出多个功能相同的 handle 实现；若已有基础实现足够，只补文档和测试。
4. 为“发送一次、取消后不再发送、Provider 释放后 Observer 不泄漏、注册后初始状态可用”补单元测试。

**验证:**

```bash
swift test --package-path Packages/ProviderProject
```

预期：测试通过，并能作为后续 Provider 迁移的参考契约。

### Task 3：迁移 Conversation 相关的 objectWillChange

**Files:**

- `Packages/ProviderConversation/Sources/ProviderConversation/ConversationManaging.swift`
- `Packages/ProviderConversation/Sources/ProviderConversation/DefaultConversationManager.swift`
- `Packages/ProviderChatSection/Sources/ProviderChatSection/DefaultChatSectionProviding.swift`
- `Packages/PluginConversationMode/Sources/PluginConversationMode/Observers/ConversationManagerObservationBox.swift`
- `Packages/PluginConversationInput/Sources/PluginConversationInput/Observers/ConversationInputObserver.swift`
- `Packages/PluginConversationPendingMessage/Sources/PluginConversationPendingMessage/ObservableMessageSendingBox.swift`

1. 为会话列表、选中会话、输入状态、发送状态等实际跨模块变化定义类型化事件。
2. 在 `DefaultConversationManager` 中集中发送事件；删除协议文档中“普通 UI 使用 `objectWillChange`”的推荐。
3. 把 ConversationMode、ConversationInput 和 PendingMessage 的直接 `objectWillChange.sink` 改为插件 Observer，并让 Observer 更新本插件 ViewModel/状态盒。
4. 保留已有的内部 Combine 适配时，适配层必须位于 Provider 或 Observer 内，不得把 publisher 继续传到 View/Factory。
5. 只有在所有引用迁移后，才移除不再需要的 `ObservableObject` 约束。

**验证:**

```bash
swift build --package-path Packages/ProviderConversation
swift build --package-path Packages/ProviderChatSection
swift build --package-path Packages/PluginConversationMode
swift build --package-path Packages/PluginConversationInput
swift build --package-path Packages/PluginConversationPendingMessage
```

### Task 4：迁移 Root、Rail、Chat 布局 Provider Publisher

**Files:**

- `Packages/ProviderRailView/Sources/ProviderRailView/RailViewProviding.swift`
- `Packages/ProviderRailView/Sources/ProviderRailView/DefaultRailViewProviding.swift`
- `Packages/ProviderRootView/Sources/ProviderRootView/RootViewProviding.swift`
- `Packages/FactoryLumi/Sources/FactoryLumi/ViewFactory.swift`
- `Packages/FactoryAppIconDesigner/Sources/FactoryAppIconDesigner/ViewFactory.swift`
- `Packages/FactoryBookletMaker/Sources/FactoryBookletMaker/ViewFactory.swift`
- `Packages/ProviderChatSection/Sources/ProviderChatSection/ChatSectionProviding.swift`

1. 将 rail 可见性、rail 宽度、chat section 宽度等 Publisher 转换为带值的类型化事件。
2. 将 `RootTrailingPane` 的 `objectWillChange` 监听改为对 `ChatSectionProviding` 注册 Observer。
3. 将三个 Factory 的 `chatSectionWidthPublisher` 订阅改为装配层或插件入口持有 Observer，再把当前值注入 ViewModel/视图参数。
4. 删除旧裸 Publisher 以及仅为兼容旧 Publisher 而存在的 `Just`、`eraseToAnyPublisher` 等代码。
5. 检查 Provider 替换时旧 ObserverHandle 是否取消并重新注册，避免旧实例继续驱动界面。

**验证:** 构建 ProviderRootView、ProviderRailView、ProviderChatSection 及三个 Factory 包，并检查布局初始值和变更值都能更新。

### Task 5：为贡献型 Provider 补齐事件协议

**Files:** 逐一检查并按需修改：

- `Packages/ProviderActivityBar/**`
- `Packages/ProviderContentView/**`
- `Packages/ProviderDocsView/**`
- `Packages/ProviderMenuBar/**`
- `Packages/ProviderRootView/**`
- `Packages/ProviderSettingView/**`
- `Packages/ProviderToolbar/**`
- `Packages/ProviderMessageRendering/**`

1. 对每个 Provider 列出真正会在 Provider 生命周期内变化的字段；静态贡献项不强行增加事件。
2. 为动态字段增加类型化事件和 Observer 注册方法；默认实现集中发送事件。
3. 在宿主或插件入口创建并持有 Observer；Observer 只修改插件 ViewModel，视图改为绑定 ViewModel。
4. 删除消费者对 `ObservableObject`、`objectWillChange` 和内部 `@Published` 字段的依赖；确认无消费者后再精简协议继承。

**验证:** 每个新增动态 Provider 至少有一个“注册、触发、取消”的测试或可执行示例；逐包 `swift build` 通过。

### Task 6：迁移 PromptSuggestion 与 LLM 下载状态

**Files:**

- `Packages/ProviderPromptSuggestion/Sources/ProviderPromptSuggestion/PromptSuggestionProviding.swift`
- `Packages/ProviderPromptSuggestion/Sources/ProviderPromptSuggestion/DefaultPromptSuggestionProviding.swift`
- `Packages/PluginMessageList/Sources/PluginMessageList/MessageListPlugin.swift`
- `Packages/KitLLM/Sources/KitLLM/Contracts/LLMModelDownloadProviding.swift`
- `Packages/PluginLLMProviderMLX/**`
- `Packages/PluginLLMProviderSettings/**`

1. 把 `PromptSuggestionProviding.changes` 改为类型化 Observer 事件，并在 `MessageListPlugin` 的插件文件中注册 Observer。
2. 为下载状态定义明确事件（开始、进度、完成、失败、取消或现有状态值的等价表示）。
3. 将 MLX 下载管理器与设置插件中的 `downloadStatePublisher` 适配改为 Observer 驱动的 ViewModel 状态更新。
4. 处理插件初始化顺序：先创建 ViewModel，再注册 Observer，最后构造视图；若 Provider 支持替换，切换时重建 handle。
5. 删除 `changes`、`downloadStatePublisher` 等公共裸 Publisher，避免形成新旧双轨。

**验证:** MessageList 和 LLM 相关包构建通过；下载状态和提示建议的初始值、连续变化、失败状态均有覆盖。

### Task 7：清理剩余 Provider 直接 objectWillChange 消费

**Files:** 以 Task 1 审计结果为准，至少复查：

- `Packages/ProviderChatSection/Sources/ProviderChatSection/DefaultChatSectionProviding.swift`
- `Packages/ProviderRootView/Sources/ProviderRootView/RootViewProviding.swift`
- `Packages/PluginConversationMode/Sources/PluginConversationMode/Observers/ConversationManagerObservationBox.swift`
- `Packages/PluginConversationInput/Sources/PluginConversationInput/Observers/ConversationInputObserver.swift`

1. 再次搜索所有 `.objectWillChange.sink`、`objectWillChange.receive`、对 Provider `.publisher` 的访问。
2. 每个命中点必须归类为“Provider 公共消费”“Provider 内部实现”“局部 UI 状态”或“系统源适配”。
3. Provider 公共消费一律改成 Observer；局部 UI 状态和系统源适配保留，但在代码注释或文档中说明边界。
4. 搜索协议文档和示例，删除会诱导新代码直接订阅 `objectWillChange` 的内容。

**验证:** Provider/Plugin 目录中不存在未解释的 Provider `objectWillChange` 消费点。

### Task 8：审计系统通知、AppKit 监听与轮询边界

**Files:** 重点检查：

- `Packages/PluginInput/**/Observers/InputEventObserver.swift`
- `Packages/PluginCodeEditor/**/Observers/CodeEditorThemeObserver.swift`
- `Packages/PluginFileTree/**`
- `Packages/PluginAppUpdate/**`
- `Packages/PluginProjectRAG/**`
- `Packages/PluginQuickLauncher/**`
- `Packages/PluginScreenRecorder/**`
- `Packages/PluginTextActions/**/Observers/TextSelectionObserver.swift`
- `Packages/PluginQuickFileSearch/**/FileSearchHotkeyManager.swift`
- `Packages/PluginFileLog/**/FileLogCoordinator.swift`

1. 确认 NotificationCenter、NSEvent、计时器和轮询只作为插件 Observer 的底层数据源，而不是另一套 Provider 对外通知方式。
2. 若 FileLog、QuickLauncher 等组件的变化跨越 Provider 边界，补一个插件文件内的 Observer 适配层；若只是内部控制器，保留现状并记录为边界例外。
3. 检查所有系统监听器的取消和释放，避免插件卸载后继续回调。

**验证:** 审计报告能解释每个系统监听点的归属，且没有把 AppKit/系统监听错误地暴露成 Provider 公共 Publisher。

### Task 9：补充跨层行为测试

**Files:** 对应各 Provider 的 `Tests/**`，以及 MessageList、ConversationInput、ConversationMode 的测试目录。

至少覆盖：

1. Provider 状态变化发送正确事件和值。
2. 无变化赋值不会产生意外重复事件。
3. ObserverHandle 取消后不再更新 ViewModel。
4. Provider 或插件释放后无回调、无 retain cycle。
5. 插件启动时能得到初始快照，Provider 后续替换时不会继续接收旧 Provider 事件。
6. MessageList 的提示建议变化、会话输入变化、LLM 下载进度变化能驱动 ViewModel 并刷新视图。

建议优先执行：

```bash
swift test --package-path Packages/ProviderConversation
swift test --package-path Packages/ProviderChatSection
swift test --package-path Packages/ProviderPromptSuggestion
swift test --package-path Packages/PluginMessageList
swift test --package-path Packages/PluginConversationInput
```

### Task 10：最终静态审计、全量构建与提交

1. 执行最终审计，确认公共 Provider 不再暴露或消费裸通知通道：

```bash
rg -n 'objectWillChange|\.publisher|AnyPublisher|Publisher|changes|downloadStatePublisher|chatSectionWidthPublisher|railVisibilityPublisher|railWidthPublisher' Packages/Provider* Packages/Plugin*
```

每个命中都必须属于内部实现或已记录的系统/局部状态；不能存在未迁移的跨模块 Provider 消费。

2. 对 Task 1 记录的所有受影响包执行 `swift build`/`swift test`。
3. 构建主 App，使用独立派生数据目录避免污染既有构建缓存：

```bash
xcodebuild -workspace Lumi.xcworkspace -scheme Lumi -configuration Debug -derivedDataPath /tmp/lumi-provider-observer-derived build
```

预期：命令退出码为 0，并生成可启动的 Debug App。

4. 执行 `git diff --check`，检查无未预期生成物、日志、用户数据或临时文件。
5. 提交单一主题变更，建议提交信息：`refactor: make provider observation observer-only`。

## 5. 风险与缓解

| 风险 | 缓解措施 |
| --- | --- |
| 漏发事件导致 UI 不更新 | 每个动态字段建立事件覆盖；测试初始快照、连续变化和失败路径 |
| 注册时错过初始状态 | Observer 注册时发送快照，或插件入口显式同步当前值并记录约定 |
| Provider 替换后旧 Observer 仍回调 | 把 handle 存在插件生命周期对象中，替换前取消，增加替换测试 |
| 新旧通知通道长期并存 | 先迁移全部消费者，再在同一阶段删除旧 Publisher 和文档引用 |
| 为静态贡献项过度抽象 | 只有运行时会变化且存在跨模块消费者的字段才增加事件 |
| 大规模协议变更造成编译级联失败 | 按 Conversation、布局、贡献 Provider、LLM 四个边界分批构建，保持小提交 |
| 把系统监听误判为违规 | 区分“系统源到插件 Observer”和“Provider 到跨模块消费者”，只约束后者 |

## 6. 完成标准

- 所有跨模块 `*Providing` 状态变化都有类型化 Observer API 和明确生命周期。
- 插件感知外部变化时，在插件文件/插件 `Observers` 目录注册 Observer；Observer 更新插件 ViewModel，视图不直接监听 Provider。
- 不再有未解释的 Provider `objectWillChange`、裸 `AnyPublisher` 或 Provider 内部 `@Published` 跨模块消费。
- `PromptSuggestionProviding`、LLM 下载、Conversation、Chat/Rail/Root 布局和动态贡献 Provider 均完成迁移。
- 系统 NotificationCenter、NSEvent、Timer、轮询等底层监听均有清晰归属，插件卸载时可取消。
- 相关单元测试、包构建和主 App 构建全部成功；`git diff --check` 通过。
- 计划执行完成后只提交本次架构迁移相关文件，提交信息清晰可追踪。

## 7. Execution Handoff

执行时使用 `@executing-plans`，按 Task 1 到 Task 10 顺序推进，并在 Task 3、Task 6、Task 10 设置检查点：

1. **Subagent-driven（当前会话）**：逐任务实施，每个边界完成后运行对应包构建和测试，再继续下一阶段。
2. **Parallel Session（独立执行会话）**：将本计划交给新的执行会话，按检查点回报审计结果、编译结果和剩余命中点。

每个阶段都应先审计当前代码，再修改最小范围，并在提交前重新执行全量静态审计，确保“Observer + Providing 事件”是唯一的 Provider 外部通知方式。

References: @writing-plans, @architecture-designer, @executing-plans, @Code
