# PluginMessageListStandardNoHeader

Lumi 消息列表 **V6（standardNoHeader / 标准·无消息头）** 实现包。工具栏 **消息列表风格**
处于 `无消息头` 时，聊天区由本包接管。

布局、分页、滚动、折叠行为与 **V2（标准）完全一致**，唯一差异是**每条消息不再渲染消息头**
（头像 / 标题 / 时间那一行）。消息头的隐藏由渲染层统一判定
（`PluginMessageRenderer` 的 `MessageHeaderVisibility`），本包不做局部特判。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。
> 本包因此**复制**了 V2 的列表基础设施，而不是引用 `PluginMessageListStandard`。

## Package

- Product: `PluginMessageListStandardNoHeader`
- Plugin id: `com.coffic.lumi.plugin.message-list.standard-no-header`
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 提供什么

与 V2 相同：

- 分页消息列表：首屏取最近一页、向上翻页、尾部刷新、窗口回收
  （`pageSize = 40`、`maxRetainedCount = 300`，见 `MessageListPaginationService`）
- 「加载更早消息」入口：加载中显示 spinner，prepend 后按锚点 id 钉回视口顶部
- 独立的流式尾行：LLM 回复期间逐字增长，稳定 id `LumiStreamingRowID`
- 活动消息行：sending / thinking / executingTool / waitingForUser 各阶段文案
- turn 工具调用汇总（`LumiTurnActivity`）与多工具调用折叠为一行摘要
- 开发者模式徽章、首屏遮罩与首屏定位编排（`InitialPositionGate`，含超时兜底）

与 V2 的差异：

- **不显示消息头**：`MessageViewChrome` 经 `MessageHeaderVisibility.isVisible` 判定，
  `standardNoHeader` 恒为不显示（与 `brief` 同列）
- 无 UI 测试夹具（`MessageListStandardUITestingSupport` 仅供 V2 使用）

## 结构

```
Sources/PluginMessageListStandardNoHeader/
├── PluginMessageListStandardNoHeaderPlugin.swift  # 装配入口：解析 Provider、注册 ChatSection 项
├── VerbosityObservationBox.swift                  # 常驻注册 + verbosity 切换时刷新可见性
├── Capabilities/                                  # 收窄后的能力协议 + Adapter
├── Models/                                        # MessageListServices、MessageExtensions、LumiTurnActivity
├── Observers/                                     # DeveloperModeStateObserver
├── Services/                                      # 分页、滚动协调、行合并、底部几何
├── ViewModels/                                    # ListV6ViewModel、DeveloperModeStateViewModel
└── Views/                                         # ListV6View、MessageRowView、ScrollViewBottomTracker…
```

## 关键设计约束

与 V2 同一组约束，改动前请先读源码注释：

- **用 SwiftUI `List` 而不是 `ScrollView + LazyVStack`**（避免 AttributeGraph 活锁）
- **有状态运行时对象必须是 `@StateObject`，不能用 `let`**（宿主每次重绘都会重新 `init` 视图）
- **`AtBottomBox` 刻意不实现 `ObservableObject`**（切断底部锚点 Preference 反馈环）
- **历史行快照驱动 + 流式行独立**（token 增长不触发全量 rebuild）

## 无障碍标识符

| 标识符 | 位置 |
| --- | --- |
| `lumi.message-list.loading-mask` | 首屏遮罩 `MessageLoadingView` |
| `lumi.message-list.v6.load-earlier` | 「加载更早消息」按钮 |

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginMessageListStandardNoHeader"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginMessageListStandardNoHeader"]),
]
```

注册（宿主 `FactoryLumi` 已默认注册）：

```swift
kernel.registerPlugin(PluginMessageListStandardNoHeaderPlugin())
```

## Testing

```sh
cd Packages/PluginMessageListStandardNoHeader
swift test
```
