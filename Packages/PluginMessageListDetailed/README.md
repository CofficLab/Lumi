# PluginMessageListDetailed

Lumi 消息列表 **V3（详细）** 实现包。工具栏 **Response Detail** 处于 `V3 (详细)` 时，
聊天区由本包接管；`V1` / `V2` 分别由 `PluginMessageListBrief` / `PluginMessageListStandard` 接管。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginMessageListDetailed`
- Plugin id: `com.coffic.lumi.plugin.message-list.detailed`
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 提供什么

- 分页消息列表：首屏取最近一页、向上翻页、尾部刷新、窗口回收
  （`pageSize = 40`、`maxRetainedCount = 300`，见 `MessageListPaginationService`）
- 「加载更早消息」入口：加载中显示 spinner，prepend 后按锚点 id 钉回视口顶部
- 独立的流式尾行：LLM 回复期间逐字增长，稳定 id `LumiStreamingRowID`；
  **thinking 阶段额外渲染 `reasoningContent`**
- 活动消息行：sending / thinking / executingTool / waitingForUser 各阶段文案
- turn 工具调用汇总（`LumiTurnActivity`）
- 开发者模式：消息行右上角叠加当前 `renderer.id` 徽章 + 同色细边框
- 首屏遮罩（`MessageLoadingView`）与首屏定位编排（`InitialPositionGate`，含超时兜底）

### 与兄弟包的差异

| 包 | verbosity | 布局单元 | 特有能力 |
| --- | --- | --- | --- |
| `PluginMessageListBrief` | `brief` | Agent Turn 分组 | 折叠过程区段、底部状态卡 |
| `PluginMessageListStandard` | `standard` | 逐条消息行 | 工具执行合并为 `tool-step-group` |
| **本包** | `detailed` | 逐条消息行 | 显示思考内容 `reasoningContent` |

> 差异说明见 `ListV3ViewModel` / `ListV3View` 的类型注释：V3 的思考内容渲染
> **当前与 V2 行为一致**，保留独立类型以便后续差异演化。本包**刻意没有**
> `MessageListStandardUITestingSupport` 夹具 —— UI 测试统一从 V2 的
> `LumiMessageListScaleUITests` / `LumiMessageListSwitchUITests` 走遮罩与切换场景。

三个包**各自独立**、各自注册 `exclusiveGroup: "message-list"` 的常驻
`ChatSectionItem`，由 `isActive` 闭包按当前会话 verbosity 决定谁真正渲染；
同一时刻只有一个胜出。三包之间没有任何源码依赖。

## 结构

```
Sources/PluginMessageListDetailed/
├── PluginMessageListDetailedPlugin.swift   # 装配入口：解析 Provider、注册 ChatSection 项
├── VerbosityObservationBox.swift           # 常驻注册 + verbosity 切换时刷新可见性
├── Capabilities/                           # 收窄后的能力协议 + Adapter
├── Models/                                 # MessageListServices、MessageExtensions、LumiTurnActivity
├── Observers/                              # DeveloperModeStateObserver
├── Services/                               # 分页、滚动协调、行合并、底部边缘判定
├── ViewModels/                             # ListV3ViewModel、DeveloperModeStateViewModel
└── Views/                                  # ListV3View、MessageRowView、ScrollViewBottomTracker…
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
- **底部判定用 `BottomEdgeEvaluator`，不用 V2 的 `MessageListBottomGeometry`**
  V2 直接操作 `NSScrollView` 的 `contentOffset`；V3 把「是否在底部」抽成可单测的
  纯函数（迟滞：上次在底部时用宽容的离开阈值），避免在 View 层散落几何判断。
- **历史行快照驱动 + 流式行独立**
  token 增长只让 `streamingRow` 这一行 diff，不触发 `historyRows` 全量 rebuild。
- **`MessageListScrollingTarget` 是抽象而非直接用 `ScrollViewProxy`**
  滚动协调器因此不依赖 SwiftUI 的 `ScrollViewProxy`，可直接在单元测试中替换。

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

本包**刻意不声明** `lumi.message-list.loading-mask` /
`lumi.message-list.v2.load-earlier` 等标识符 —— 它们属于 V2 夹具与 V2 视图的契约。
本包 UI 层只复用 renderer 自身的标识符，UI 测试针对 V3 走人工验收。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginMessageListDetailed"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginMessageListDetailed"]),
]
```

注册（宿主 `FactoryLumi` 已默认注册）：

```swift
kernel.registerPlugin(PluginMessageListDetailedPlugin())
```

## Testing

```sh
cd Packages/PluginMessageListDetailed
swift test
```

用例清单见 [`Tests/TestPlan.md`](Tests/TestPlan.md)（`BottomEdgeEvaluator` /
`ListV3ViewModel` / `MessageListScrollCoordinator` / `MessageListService`）。

> 用例表由 `Scripts/generate-testplan.py` 生成、`Scripts/verify-testplan.py` 校验。
> 新增或改名 `@Test` 后须重新生成，否则校验脚本会报「登记方法在源码不存在」。

本包无独立 UI 夹具；首屏遮罩、大数据量与会话切换的 UI 验证共用 V2 的夹具
（`--lumi-ui-testing-message-list-standard`），见
`LumiUITests/LumiMessageListScaleUITests` 与 `LumiMessageListSwitchUITests`。