# PluginMessageListStandard

Lumi 消息列表 **V2（标准）** 实现包。工具栏 **Response Detail** 处于 `V2 (标准)` 时，
聊天区由本包接管；`V1` / `V3` 分别由 `PluginMessageListBrief` / `PluginMessageListDetailed` 接管。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginMessageListStandard`
- Plugin id: `com.coffic.lumi.plugin.message-list.standard`
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 提供什么

- 分页消息列表：首屏取最近一页、向上翻页、尾部刷新、窗口回收
  （`pageSize = 40`、`maxRetainedCount = 300`，见 `MessageListPaginationService`）
- 「加载更早消息」入口：加载中显示 spinner，prepend 后按锚点 id 钉回视口顶部
- 独立的流式尾行：LLM 回复期间逐字增长，稳定 id `LumiStreamingRowID`
- 活动消息行：sending / thinking / executingTool / waitingForUser 各阶段文案
- turn 工具调用汇总（`LumiTurnActivity`）
- 开发者模式：消息行右上角叠加当前 `renderer.id` 徽章 + 同色细边框
- 首屏遮罩（`MessageLoadingView`）与首屏定位编排（`InitialPositionGate`，含超时兜底）

### 与兄弟包的差异

| 包 | verbosity | 布局单元 | 特有能力 |
| --- | --- | --- | --- |
| `PluginMessageListBrief` | `brief` | Agent Turn 分组 | 折叠过程区段、底部状态卡 |
| **本包** | `standard` | 逐条消息行 | 工具执行合并为 `tool-step-group` |
| `PluginMessageListDetailed` | `detailed` | 逐条消息行 | 显示 `reasoningContent` |

三个包**各自独立**、各自注册 `exclusiveGroup: "message-list"` 的常驻
`ChatSectionItem`，由 `isActive` 闭包按当前会话 verbosity 决定谁真正渲染；
同一时刻只有一个胜出。三包之间没有任何源码依赖。

## 结构

```
Sources/PluginMessageListStandard/
├── PluginMessageListStandardPlugin.swift   # 装配入口：解析 Provider、注册 ChatSection 项
├── VerbosityObservationBox.swift           # 常驻注册 + verbosity 切换时刷新可见性
├── MessageListStandardUITestingSupport.swift  # UI 夹具（仅 DEBUG）
├── Capabilities/                           # 收窄后的能力协议 + Adapter
├── Models/                                 # MessageListServices、MessageExtensions、LumiTurnActivity
├── Observers/                              # DeveloperModeStateObserver
├── Services/                               # 分页、滚动协调、行合并、底部几何
├── ViewModels/                             # ListV2ViewModel、DeveloperModeStateViewModel
└── Views/                                  # ListV2View、MessageRowView、ScrollViewBottomTracker…
```

## 关键设计约束

改动下列模块前请先读源码注释，它们记录的是**踩过坑后的结论**而非风格偏好：

- **用 SwiftUI `List` 而不是 `ScrollView + LazyVStack`**
  `LazyVStack` 在富文本长列表下会反复触发 AttributeGraph 活锁（主线程 100% CPU 卡死）；
  普通 `VStack` 则 eager materialize 全部行。macOS 上 `List` 底层是 `NSTableView`，
  自带 cell 复用，既懒加载又不走 LazyStack 的尺寸协商。
- **有状态运行时对象必须是 `@StateObject`，不能用 `let`**
  宿主 `ChatStackView.body` 每次重绘都会重新 `init` 本视图；`let` 持有的
  `MessageListRuntime`（`AtBottomBox` / 滚动协调器 / 底部控制器）会被重建，
  导致新旧两个协调器同时驱动同一个 scroll view、首屏遮罩永久挂起。
  详见 `MessageListRuntime` 与 `InitialPositionGate` 的类型注释。
- **`AtBottomBox` 刻意不实现 `ObservableObject`**
  用于切断底部锚点 Preference 反馈环（`@State` → body 重建 → 偏好重报 → 活锁）。
- **历史行快照驱动 + 流式行独立**
  token 增长只让 `streamingRow` 这一行 diff，不触发 `historyRows` 全量 rebuild；
  `HistoryBuildSignature`（含 contentLength、工具授权状态指纹）短路无变化的重建。
- **`#if DEBUG` 守卫必须覆盖整个函数体**
  `MessageListStandardUITestingSupport` 只在 DEBUG 存在，`onBoot` 与 `onShutdown`
  中的引用点（含句柄释放）都必须同等包裹，否则 Release 构建失败。

## 能力边界

View / ViewModel 只依赖 `Sources/.../Capabilities/` 下的窄协议，
不直接持有 `any *Providing`：

| 能力协议 | 收窄自 |
| --- | --- |
| `MessageListConversationCapability` | `ConversationManaging` |
| `MessageListConversationStateCapability` | `ConversationStateProviding` |
| `MessageListMessageCapability` | `MessageManaging` |
| `MessageListRenderingCapability` | `MessageRenderingProviding` |
| `MessageListStreamingCapability` | `MessageStreamingProviding` |
| `MessageListToolManagerCapability` | `ToolManagerProviding` |
| `MessageListAgentLoopCapability` | `AgentLoopProviding` |
| `MessageListPromptSuggestionCapability` | `PromptSuggestionProviding` |
| `MessageListPromptSuggestionExecutorCapability` | `PromptSuggestionExecuting` |
| `MessageListProjectCapability` | `ProjectProviding` |
| `MessageListToolbarCapability` | `ToolbarProviding` |
| `MessageListChatSectionCapability` | `ChatSectionProviding` |

Adapter 一律在插件入口 `onBoot(kernel:)` 中构造并注入，View 层不感知 Provider 类型。
Observer 仍使用完整 Provider 类型（需要完整事件面）。

## 无障碍标识符

| 标识符 | 位置 |
| --- | --- |
| `lumi.message-list.loading-mask` | 首屏遮罩 `MessageLoadingView` |
| `lumi.message-list.v2.load-earlier` | 「加载更早消息」按钮 |

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginMessageListStandard"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginMessageListStandard"]),
]
```

注册（宿主 `FactoryLumi` 已默认注册）：

```swift
kernel.registerPlugin(PluginMessageListStandardPlugin())
```

## Testing

```sh
cd Packages/PluginMessageListStandard
swift test
```

用例清单见 [`Tests/TestPlan.md`](Tests/TestPlan.md)（`BottomDecision` /
`InitialPositionGate` / `ListV2ViewModel` / `MessageListBottomSettle` /
`MessageListService` / `MessageListServices` / `MessageListTurnActivity` /
`ScrollViewBottomController`）。

> 用例表由 `Scripts/generate-testplan.py` 生成、`Scripts/verify-testplan.py` 校验。
> 新增或改名 `@Test` 后须重新生成，否则校验脚本会报「登记方法在源码不存在」。

UI 测试（首屏遮罩 / 大数据量 / 会话切换）位于 `LumiUITests/`：

```sh
xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListScaleUITests \
  -only-testing:LumiUITests/LumiMessageListSwitchUITests
```

夹具由 `MessageListStandardUITestingSupport` 提供（仅 `DEBUG` 编译），
通过 `--lumi-ui-testing-message-list-standard` 开启；
建议同时开启 `--lumi-ui-testing-isolated-storage` 避免污染用户数据库。