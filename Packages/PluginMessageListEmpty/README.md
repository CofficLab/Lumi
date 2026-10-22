# PluginMessageListEmpty

Lumi 聊天区**空态**实现包：未选中会话，或当前会话没有可见消息时接管消息列表槽位。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginMessageListEmpty`
- Plugin id: `com.coffic.lumi.plugin.message-list.empty`
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 提供什么

**两种空态视图**，按是否有选中会话分流：

| 视图 | 触发条件 |
| --- | --- |
| `NoConversationSelectedView` | 没有选中任何会话 |
| `MessageEmptyStateView` | 选中会话，但没有可见消息 |

两种视图的内容结构一致：

1. 氛围背景（`EmptyStateAtmosphere`）
2. 上下文图标 + 标题（按 `ChatContext` 切换：默认聊天 / 具名上下文 / 当前项目）
3. **项目身份行**（`ProjectIdentityLine`，有项目时占据副标题槽位：折叠后的路径 + 技术栈）
4. 提示胶囊流（`PromptSuggestionFlow`，按项目可见性与 launcher scope 过滤）
5. **项目上下文卡**（`ProjectContextCard`，紧跟提示流下方）
6. **近 30 天活动卡**（`ActivityFusionCard`，紧跟项目卡下方，非底部固定栏）

### 项目上下文卡

有项目时，空态要回答用户的三个问题：**我在哪**、**这是个什么项目**、
**现在能不能开工**。项目卡用三行可点击的状态回答后两个：

| 行 | 数据来源 | 点击 |
| --- | --- | --- |
| 已索引 N 个文件 · 多久前 | `ProjectRAGProviding.indexStatus` | 打开文件树 |
| N 个文件有未提交改动 | `GitRepositoryReading.status` | 打开 Git 面板 |
| 上次在这里：<会话标题> · 多久前 | `ConversationManaging.fetchConversationPage(projectPath:)` | 回到该会话 |

展开后另有「本项目会话数」与关键文件标签（`Package.swift` / `README.md` 等）。

**每一行都必须可点**：一行状态如果既不能点、又不表达任何可执行动作，
它就是噪音。因此模型层只产出**带动作**的行，拿不到数据的行直接不渲染。

### 活动卡的统计范围

活动卡把两段数据合成一张卡：

- **热力图**：近 30 个自然日每天的消息条数，按窗口内峰值归一化分 5 级
- **token 曲线**：同窗口的 token 消耗；无消耗时整段隐藏
- 锚点文案：「近 30 天共 N 条消息 · 消耗 M tokens」

统计默认是**当前项目**维度（人在项目里，注意力就在这个项目上），
卡片底部提供「本项目 / 全部项目」切换，而不是并排摆两张卡。
项目维度靠一组会话 ID 过滤消息：会话集合由 `ProviderConversation` 按项目路径
查出，再交给消息存储按会话 ID 过滤（`ProviderMessage` 的
`dailyMessageCountsAsync(since:conversationIDs:)`）。

项目维度没有历史时卡片仍然渲染（一行「本项目还没有任何消息」）——
「这个项目还没人动过」本身就是一条信息，比一块空白热力图有用。

### 与兄弟包的关系

本包**不依赖**任何一个 verbosity 消息列表包。它与
`PluginMessageListBrief` / `Standard` / `Detailed` 同属 `message-list` 互斥组，
靠 `isActive` 决定谁胜出，因此「有空态」与「有消息」不会同时出现。

## 结构

```
Sources/PluginMessageListEmpty/
├── PluginMessageListEmptyPlugin.swift        # 装配入口 + 三态可见性判定
├── MessageListEmptyUITestingSupport.swift    # UI 夹具（仅 DEBUG）
├── Models/                                   # MessageListEmptyServices
├── Observers/                                # GuideObservers、NoConversationSelectedToolbarCoordinator
├── Services/                                 # PluginLocalization
├── Support/                                  # MessageListEmptyAccessibility、ActivityTokenFormat
├── ViewModels/                               # EmptyStateActivityViewModel、ProjectContextViewModel
└── Views/Guide/                              # 两种空态视图、项目卡、活动卡、热力图、提示流
```

## 关键设计约束

- **可见性是三态，不是布尔**
  判定「当前会话是否没有消息」依赖**异步 SwiftData 查询**，必然存在
  「尚未得出结论」的中间态。若把它折叠成 `Bool`，「还不知道」会被当成
  「答案是空」，空态便会在判定窗口内抢占 `message-list` 槽位 ——
  用户会看到**有消息却显示空态引导页**。
  因此 `registrationState` 显式建模为 `evaluating` / `resolved(Bool)`，
  且 `shouldRenderEmptyState` 在 `evaluating` 期间返回 `false`。
  由 `RegistrationEvaluationWindow` 两条 P0 用例锁定。
- **注册状态与可见状态分离**
  `register()` 只做一次（常驻）；可见性完全由 `isActive` 闭包表达。
  若把「按需注册/移除」与「是否渲染」耦合，会出现「已移除 item 却仍需重新注册」
  这类不变量被破坏的路径。`VerbosityObservationBox`（V1/V2/V3）采用同一范式。
- **活动卡不画尾部分隔线**
  `showsTrailingDivider: false`。分隔线由宿主在 stack 与 bottomFixed 之间统一绘制；
  空态内容与活动卡属于同一段画面（同配色、同底色、同宽度基准），
  留着这条线等于亲手把两块内容切成两个区域。
- **判定任务可取消且防过期**
  选择与消息事件在加载/流式期间会成簇触发。`scheduleRegistrationEvaluation`
  先 cancel 上一轮再发起新的；结论返回时同时校验 `Task.isCancelled` 与
  「会话仍是当初那个」，避免旧结果覆盖新状态。
- **零结果不钉死活动卡**
  活动卡首次加载为零时不置为「已加载」，保持可重试 —— 迟到的数据仍能显示。
  由 `zeroResultDoesNotPinTheStrip`（P0）锁定。
- **`EmptyStateActivityViewModel` 由插件入口强持有**
  它是 `@Observable` 且需要跨视图重建保持已加载窗口，不能只在 item 闭包里临时构造。
- **标识符挂在 `ScrollView` 内容而非 `GeometryReader` 上**
  `GeometryReader` 是布局容器、无自身语义，在其上设置 identifier 会让整页子树被
  合并成一个元素，屏幕阅读器将失去内部结构。

## 无障碍标识符

集中定义在 `Support/MessageListEmptyAccessibility.swift`：

| 标识符 | 元素 |
| --- | --- |
| `lumi.message-list.empty.no-conversation-selected` | 未选中会话空态根节点 |
| `lumi.message-list.empty.no-messages` | 无消息空态根节点 |
| `lumi.message-list.empty.activity` | 活动卡 |
| `lumi.message-list.empty.suggestion-flow` | 提示胶囊流 |
| `lumi.message-list.empty.suggestion.<id>` | 单个提示胶囊 |

> **传播陷阱**：`suggestion-flow` 的标识符会传播到**每一个 chip** 上。
> UI 测试要取整条流，必须取「所有匹配元素的并集」，
> 单取第一个匹配元素只会拿到某一个 chip。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginMessageListEmpty"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginMessageListEmpty"]),
]
```

注册（宿主 `FactoryLumi` 已默认注册）：

```swift
kernel.registerPlugin(PluginMessageListEmptyPlugin())
```

## Testing

```sh
cd Packages/PluginMessageListEmpty
swift test
```

用例清单见 [`Tests/TestPlan.md`](Tests/TestPlan.md)。覆盖面集中在几何与竞态：
`ActivitySparklineGeometry`（画布内不越界）、`ActivityCardLayout`（并排阈值）、
`EmptyStateActivityWindow`（窗口填充与归一化）、`EmptyStateActivityLoading`（加载竞态）、
`RegistrationEvaluationWindow`（三态不变量）。

> 用例表由 `Scripts/generate-testplan.py` 生成、`Scripts/verify-testplan.py` 校验。
> 新增或改名 `@Test` 后须重新生成，否则校验脚本会报「登记方法在源码不存在」。

### UI 测试

```sh
xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListEmptyUITests
```

夹具 `MessageListEmptyUITestingSupport`（仅 `DEBUG`）植入三个会话：
空会话（默认选中）、带 8 条跨 30 天历史消息的会话、仅含 1 条 tool 消息的会话。
历史消息**刻意放在另一个会话** —— 活动条统计是跨会话的，
放进当前空会话会让「空态 + 活动条」永不共存。

启动参数：`--lumi-ui-testing-message-list-empty`
+ 建议同时开启 `--lumi-ui-testing-isolated-storage`。