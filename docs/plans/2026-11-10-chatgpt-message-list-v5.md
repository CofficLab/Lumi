# ChatGPT Message List V5 Implementation Plan

> **实施提示：** 后续实施时使用 `executing-plans-0.1.0`，按任务逐项执行、验证和评审。本文是技术方案与实施计划，不代表已实施、已提交或已推送。

**Goal:** 在 Lumi 新增与 Brief、Standard、Detailed、ZCode 平级的独立 `PluginMessageListChatGPT` 插件包，以 `ResponseVerbosity.chatGPT` / 持久化值 `"v5"` 提供 ChatGPT 风格的居中阅读列、右侧用户气泡、无气泡助手正文、轮尾操作、流式回复与不抢阅读位置的滚动体验。

**Architecture:** 新包只拥有 V5 的插件生命周期、消息窗口、turn 投影、列表外壳、滚动状态和布局，不依赖任何其他消息列表插件。消息仍通过 `MessageRenderingProviding` 分发，在现有 `PluginMessageRenderer` 内增加 `.chatGPT` 分支和 V5 私有视图；公开 renderer 签名、`preferredRendererID`、第三方 renderer、工具授权和 AgentLoop 均不改变。以当前独立 `PluginMessageListZCode` 包的行为为基线，在其私有基础设施上做一次有测试约束的独立实现，不在本任务同时抽取新的共享 Kit。

**Tech Stack:** Swift 6、SwiftUI、AppKit、Swift Package Manager、SwiftData、Swift Testing / XCTest、XCUITest、现有 `KitMarkdown` 与 `LumiUI`。

---

## 0. 结论摘要

### 0.1 推荐方案

新增：

```text
Packages/PluginMessageListChatGPT
Plugin ID: com.coffic.lumi.plugin.message-list.chatgpt
Verbosity: ResponseVerbosity.chatGPT
Raw value: v5
ChatSection exclusiveGroup: message-list
Order: 82（与现有消息列表一致）
```

首版必须实现的可见特征：

1. 消息内容列居中，常规最大宽度 768pt；宽度由聊天容器决定，而不是窗口决定。
2. 用户消息右对齐、按内容收缩、柔和表面色气泡；附件放在气泡上方，右对齐。
3. 助手正文占满阅读列，无气泡、无头像、无发送者名称、无默认时间戳。
4. reasoning、工具工作和错误保持可见且可访问，但默认收起已完成的长过程，不能为了“简洁”隐藏工具授权。
5. 助手轮尾提供真实复制；错误仅在当前失败回合可重试时提供重试。用户消息提供复制和现有“再次发送”，不把“再次发送”伪装成“编辑”或“重新生成”。
6. 新包启用真实流式尾行，逐帧合并更新，历史 turn 不随每个 token 全量重建。
7. 用户向上阅读后立即停止自动跟随；流式、异步测高、折叠和窗口 resize 不得把用户拉回底部。
8. 使用 SwiftUI `List`、有界分页和 AppKit 几何观察，禁止改成 `ScrollView + LazyVStack` 或 eager `VStack`。

### 0.2 明确不做

本任务不改造 composer、侧边栏、模型选择器、会话数据库 schema、AgentLoop、工具执行协议或 V1–V4 样式；不复制 OpenAI 商标、图标、字体文件或专有资源。

以下 ChatGPT 产品能力在 Lumi 当前缺少对应领域协议，**不属于 V5 首期**：

- 用户消息行内编辑、编辑后截断/重跑；
- 任意成功回复的通用重新生成；
- 对话分支与分支切换；
- 点赞/点踩反馈；
- 朗读、分享、导出对话；
- Canvas、交互式迷你应用；
- LaTeX / KaTeX / MathML 专用渲染。

通用 `updateMessage` / `deleteMessage` 不等于安全的“编辑并重跑”协议；`resendMessage` 不等于“重新生成”。首期不得放置无行为或语义错误的按钮。

### 0.3 调研与源码基线

- Lumi 调研日期：2026-11-10。
- Lumi 当前基线：`91bd5bb50e9442ed59743f2b8f66c68a685a6f21`（`docs: record V4 package extraction`）。
- ZCode V4 已在当前基线中拆为独立包；实施时若基线变化，先复核本文路径，不直接套用旧 `PluginMessageListDetailed` 路径。
- assistant-ui 调研 commit：`b98301dff6542283c4ce616e25ea17b43021e8e4`。
- Vercel Chatbot 调研 commit：`a8989b522fa3672a2ae52f053105e40993b36ca1`。
- OpenAI 帮助页正文抓取返回 403，因此官方条目按公开搜索索引交叉核对；本文不把未经验证的 ChatGPT CSS 数值声称为官方事实。第 2 节的精确数值均标记为 **Lumi 设计值**。

---

## 1. 网络调研结论与可迁移模式

### 1.1 OpenAI 公开资料

| 公开事实 | 对 Lumi 的启示 | 首期处理 |
|---|---|---|
| OpenAI 的 GPT-5.5 使用说明描述了 hover 编辑用户消息、重试回复和从新对话分支继续 | 这些不是纯视觉能力，需要编辑、重生成和分支的数据语义 | 只做视觉风格；不以 CRUD 或 resend 冒充这些能力 |
| OpenAI 的写作/代码块说明将代码块作为独立区域，支持阅读、复制以及按环境提供的编辑/预览 | 代码块应是正文中的独立块级容器，复制是基本操作 | 复用 `KitMarkdown` 的代码块、异步高亮和复制；不新增 Canvas |
| ChatGPT macOS 发布说明提到表格、代码块和数学公式横向滚动、流式性能、滚动性能及无障碍改进 | 宽内容不能撑破阅读列；流式与滚动是核心质量而非附加项 | 代码横滚沿用；接通既有表格横滚 theme 开关；数学渲染另立任务 |
| ChatGPT 发布说明包含行内错误重试 | 错误应在会话上下文中处理，而不是只弹全局提示 | 沿用现有 `RetryTurnButton` 的 `canRetryTurn` 判定 |
| OpenAI 帮助页说明不同设备、计划和 rollout 的可用动作不同 | 不应为了“像 ChatGPT”显示 Lumi 没有的动作 | 操作按钮由真实 capability 决定 |

### 1.2 assistant-ui（MIT，仅研究模式，不引入 React 代码）

调研文件：

- `packages/ui/src/components/react/assistant-ui/elements/thread.aui.tsx`
- `packages/store/src/utils/thread-viewport-auto-scroll.ts`
- `apps/docs/content/docs/(reference)/api-reference/primitives/thread.mdx`

可迁移模式：

- Thread 分为 viewport、messages、viewport footer，composer 不混进消息数据模型。
- 参考实现使用居中阅读列；用户消息位于右侧 grid 列，助手正文没有用户气泡式卡片。
- assistant 操作栏包含复制，并按运行状态、消息位置和 capability 决定可见性。
- reasoning/tool 可按类型分组，工具需要动作时不能被折叠状态吞掉。
- 自动跟随实现区分真实用户输入、内容增长、prepend、会话切换和 programmatic scroll；prepend 要保持原阅读锚点。
- 历史加载与“回到底部”是 thread 的原语，不应由每个消息行自行实现。

不照搬：React 组件结构、DOM live region、Tailwind 数值和 composer 行为。SwiftUI 必须沿用 Lumi 已验证的 `List` 与 AppKit tracker。

### 1.3 Vercel Chatbot（仅研究交互，不引入其代码或许可证不明的资产）

调研文件：

- `components/chat/messages.tsx`
- `components/chat/message.tsx`
- `components/chat/message-actions.tsx`

可迁移模式：

- 消息列表采用居中列、明确的消息间距、独立 thinking 状态和底部回位按钮。
- 用户正文使用受限宽度气泡，助手正文使用更宽的阅读区域。
- 用户操作和助手操作在 hover 时出现，复制只复制真实文本 part。
- reasoning 在正文前合并展示，工具结果和审批是消息内容的一等状态。
- 切换会话时重置滚动状态，避免上一个会话的跟随状态污染新会话。

不照搬：点赞接口、编辑回调、天气/文档专用卡片、`max-w-4xl` 等具体数值。Lumi 只实现已有 Provider 能支撑的动作。

### 1.4 无障碍调研

W3C WCAG 2.2 的 4.1.3 要求状态消息能通过角色或属性被辅助技术识别，且不需要把焦点移到状态消息上。ARIA `log` 的语义适合按顺序追加的聊天历史，但 Web ARIA 不能直接照搬到 SwiftUI。

V5 的本地实现原则：

- 所有图标按钮有本地化 `accessibilityLabel`、稳定 identifier 和键盘焦点。
- 不因流式 token 移动 VoiceOver 焦点，不逐 token 发 announcement。
- “正在生成”“生成完成”“失败”以状态视图的可访问文本表达；完成或失败只做一次语义更新。
- hover 不是显示操作的唯一方式：键盘 focus、latest assistant 常驻和 VoiceOver 聚焦都能到达相同动作。
- Reduced Motion 下关闭 shimmer、淡入和位移动画；信息本身不能依赖动画表达。

---

## 2. V5 视觉与交互合同

> 本节数值是为 Lumi 制定的设计值，不声称是 OpenAI 官方 CSS。CSS px 与 macOS pt 只按逻辑尺寸作设计映射，最终用 SwiftUI 几何断言和截图评审验证，不做跨平台 PNG 字节相等。

### 2.1 页面结构

```text
ChatSection stack
└── ChatGPTListView（占满剩余高度）
    ├── 首屏 loading mask（有超时兜底）
    └── List
        ├── LoadEarlier（仅在 hasEarlier 时出现）
        ├── History turns
        │   └── ChatGPTTurnView（居中，max 768）
        │       ├── 用户附件（右对齐）
        │       ├── 用户气泡（右对齐、按内容收缩）
        │       ├── 用户操作（hover / focus）
        │       ├── Reasoning disclosure（可选）
        │       ├── Assistant Markdown（无气泡、全阅读列）
        │       ├── Tool work group（保留授权和结果）
        │       ├── Inline error（可选，真实 retry）
        │       └── Turn action bar（复制；只在轮尾）
        ├── Live streaming / activity turn
        └── Bottom anchor
    └── BackToBottom overlay（水平居中，脱离跟随时出现）

ChatSection bottomFixed（不属于本包）
├── 现有风险审批 / 用户输入
└── 现有 composer 与停止按钮
```

### 2.2 布局 token

新建 `ChatGPTConversationLayout`，集中管理数值，禁止散落 magic number。

| 项目 | Lumi 设计值 | 说明 |
|---|---:|---|
| 内容列最大宽 | 768 | 常规桌面阅读列，水平居中 |
| 容器水平 padding | `<480` 为 16；否则 24 | 基于聊天容器宽度 |
| 内容列宽 | `min(768, container - 2 * padding)` | 非法/非有限宽度返回 0，不构造负尺寸 |
| 普通 turn 间距 | 32 | 不使用日期分隔线 |
| 用户区与助手区间距 | 16 | 同一 turn 内 |
| reasoning/tool 块间距 | 12 | 连续工作项 |
| 列表顶部/底部空间 | 16 / 24 | bottom anchor 另保留 16 |
| 用户气泡最大宽 | 窄列 `92%`，其余 `80%`，且最多 560 | 永远不超过内容列 |
| 用户气泡圆角 | 四角 18，continuous | 不使用 ZCode 的 12/2，不使用胶囊 |
| 用户气泡内边距 | 水平 16、垂直 10 | 附件在气泡外上方 |
| 用户正文 | `.appBody`，目标行高 24 | 支持多行、长 URL、中文和选区 |
| 助手正文 | `.appBody`，目标行高 24 | 无左右卡片 padding，宽度填满阅读列 |
| 操作按钮 | 28×28，操作栏保留 32 高 | 避免 hover 导致布局跳动 |
| 回到底部按钮 | 32×32，底部偏移 16 | 水平居中，不遮挡右侧正文 |
| 底部跟随容差 | 48 | 与 V4 已验证 reducer 一致，不修改 V3 阈值 |

建议纯函数：

```swift
enum ChatGPTConversationLayout {
    static func horizontalPadding(for container: CGFloat) -> CGFloat
    static func contentWidth(for container: CGFloat) -> CGFloat
    static func userBubbleMaxWidth(contentWidth: CGFloat) -> CGFloat
}
```

### 2.3 颜色与字体

新增 `ChatGPTMessagePalette`，从 `@LumiTheme` 解析：

- 页面与助手正文背景：透明，沿用 ChatSection 背景。
- 用户气泡：`theme.surface`；需要区分时使用主题现有层级色，不写死 ChatGPT 灰或 OpenAI 绿。
- 主文字：`theme.textPrimary`；次要过程与操作：`theme.textSecondary`。
- 分隔/边框：`theme.textSecondary.opacity(0.12...0.16)`；默认无阴影。
- 错误：沿用 `theme.error`，错误详情保留现有隐私与诊断行为，不新增原文日志。
- Markdown 使用 `ChatMarkdownTheme.makeChatGPT(from:)`，不得改动 `make(from:)` 或 `makeZCode(from:)` 的既有输出。

必须评审全部内置主题的 light/dark 对比度，而不是只验证默认主题。字体继续走 `AppTypography`，不引入 OpenAI 字体。

### 2.4 用户消息

- 短消息气泡按内容收缩并右对齐；长消息受最大宽约束。
- 图片、文件附件在气泡上方右对齐；attachment-only 消息不产生空气泡。
- 保留 `CollapsedContentChips` 对粘贴大段文本/编辑器选区的语义，不把附件 base64 或快照路径显示成正文。
- 不采用 ZCode 的 120pt 长文折叠；普通用户正文自然展开，避免把长 prompt 截成另一套交互。
- hover 或键盘 focus 显示“复制”和“再次发送”；复制使用原始 `message.content`，不是截断文本。
- “再次发送”继续调用现有 `resendMessage(content:conversationID:)`，新建一次发送，不修改原消息、不删除后续消息，也不宣称恢复原附件。

### 2.5 助手消息与 turn

- 无气泡、无头像、无“AI/ChatGPT”名称、无默认模型名和时间戳。
- 正文、标题、列表、引用、表格、代码块以 768 阅读列为边界；代码块内部横滚，表格不得撑破列宽。
- 一轮可有多个 assistant/tool 行，但轮尾操作只出现一次，继续通过 `MessageTurnPresentationContext` 传递，不修改公开 renderer 签名。
- 最新已完成 assistant 的复制操作常驻；历史 turn 在 hover 或键盘 focus 时出现。运行中不显示复制成功态或伪 retry。
- 普通成功回复不显示“重新生成”。失败重试只出现在带有效 `turnID` 且 `canRetryTurn == true` 的错误上。
- 时间、renderer ID 等诊断信息仅在现有开发者模式中显示，不进入默认 ChatGPT 外观。

### 2.6 Reasoning、工具、状态和错误

- Reasoning 标题为“正在思考…”或“已思考”，有真实时长时才显示时长；完成后默认收起。
- 展开内容复用现有可选择文本、最大高 240 和内部滚动行为；不把私有推理转成模型没有提供的摘要。
- 工具组显示真实工具数、运行状态和结果；等待授权的工具必须可见且可交互，不得因默认折叠被隐藏。
- 底部固定风险审批继续只出现一份；V5 不在列表中复制一个审批面板。
- compact、model switch、retry 等 timeline event 使用低强调、居中的小 marker，不渲染成 assistant 正文。
- 错误内联显示在对应 turn，提供现有详情和有效重试；失败不能自动抢焦点或强制滚到底。

### 2.7 流式与滚动

- 新 ViewModel 最终使用 `streamingDisplayEnabled: true`，只影响 V5 实例，不修改其他列表的默认 `false`。
- token 更新按约 16ms 合并；`KitMarkdown` 继续使用稳定前缀增量解析和缓存。
- 历史 projection 只在历史 fingerprint 变化时 O(n) 重建；streaming/activity 只重建 live tail。
- 用户发送新消息可进入跟随并贴底；用户主动上滚超过 48 后立即 detached。
- 流式 delta、异步 Markdown 测高、reasoning/tool 折叠和 resize 均不得改变 detached 状态。
- 用户回到底部 48 内或点击回到底部按钮后恢复 following；prepend 后原首条可见消息保持原位置。
- streaming 不显示无意义的闪烁光标；无内容时显示轻量“正在思考/正在生成”，Reduced Motion 下取消 shimmer。

---

## 3. 当前架构证据与改造边界

### 3.1 现有平级包与选择机制

当前 V4 已是独立 `Packages/PluginMessageListZCode`，其 README 明确：四种列表各自独立 package，共享 `message-list` 槽位，插件之间不得依赖，renderer 通过 `.zcode` 分支共用。见：

- `Packages/PluginMessageListZCode/README.md:7-27`
- `Packages/PluginMessageListZCode/Package.swift:9-64`
- `Packages/PluginMessageListZCode/Sources/PluginMessageListZCode/PluginMessageListZCodePlugin.swift:19-45`

新包必须遵循同一方向，不应把 ChatGPT 做成 ZCode 包内的另一个插件类，也不应依赖 `PluginMessageListZCode`。

`ResponseVerbosity` 当前为 `brief/standard/detailed/zcode` 和 `v1...v4`，默认仍为 `.standard`：

- `Packages/ProviderConversation/Sources/ProviderConversation/ResponseVerbosity.swift:4-35`

Factory 是唯一 Composition Root：

- package 依赖：`Packages/FactoryLumi/Package.swift:92-98`
- target product：`Packages/FactoryLumi/Package.swift:286-292`
- import：`Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift:117-123`
- 实例列表：`Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift:342-348`
- arbitration test product：`Packages/FactoryLumi/Package.swift:453-460`

`SelectedPluginFactory` 按 ID 白名单过滤；使用它的专用宿主若需要 V5，必须显式加入新 ID：

- `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift:432-450`

### 3.2 消息与渲染协议

公开 renderer 签名为 `(Message, ResponseVerbosity) -> AnyView`，`renderer(for:)` 先尊重 `preferredRendererID` 再按 order 选择：

- `Packages/ProviderMessageRendering/Sources/ProviderMessageRendering/MessageRenderingProviding.swift:12-28`
- `Packages/ProviderMessageRendering/Sources/ProviderMessageRendering/MessageRenderingProviding.swift:84-100`

**不得**在 V5 包中另注册一个全局高优先级 renderer 来抢所有消息：`canRender` 没有 verbosity 参数，这会破坏其他列表和第三方 renderer。正确做法是保留现有注册，在 `PluginMessageRenderer` 内按 `.chatGPT` 分支：

- 路由入口：`Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/MessageRendererPlugin.swift:103-308`
- 用户分支：`Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/UserMessageView.swift:17-30`
- 助手分支：`Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/AssistantMessageView.swift:21-34`
- turn environment：`Packages/PluginMessageListZCode/Sources/PluginMessageListZCode/Views/MessageRowView.swift:22-54`

### 3.3 数据、分页、流式和滚动基线

新包参考但不得 import ZCode internal 类型：

- ViewModel、16ms 合并、activationSequence：`Packages/PluginMessageListZCode/Sources/PluginMessageListZCode/ViewModels/ListV4ViewModel.swift:56-72,112-121`
- 分页 pageSize 40、maxRetainedCount 300、输入钳制：`Packages/PluginMessageListZCode/Sources/PluginMessageListZCode/Services/MessageListPaginationService.swift:20-60`
- 历史缓存与 live tail：`Packages/PluginMessageListZCode/Sources/PluginMessageListZCode/Services/ZCodeTurnProjectionStore.swift:4-67`
- 等长正文替换仍失效：`Packages/PluginMessageListZCode/Sources/PluginMessageListZCode/Services/ZCodeTurnProjectionStore.swift:77-116`
- `List` 与 `StateObject` 硬约束：`Packages/PluginMessageListZCode/Sources/PluginMessageListZCode/Views/ListV4View.swift:7-46`
- 48pt 跟随阈值：`Packages/PluginMessageListZCode/Sources/PluginMessageListZCode/Services/ZCodeScrollAnchor.swift:58-71`

V5 自己的 ViewModel 必须遵守仓库异步身份约定：捕获 `activationSequence + conversationID`，每个 `await` 后写回前再次校验，错误分支也一样；翻页还要校验窗口身份，禁止旧请求覆盖新会话。

### 3.4 现有能力和缺口

可直接复用：

- 用户附件 metadata 与视图组件；
- `KitMarkdown` 后台解析、增量前缀、代码复制、异步高亮、Mermaid；
- `ZCodeReasoningView` 的真实时长、折叠和内部滚动逻辑（同 renderer 包内可复用实现，必要时用 V5 wrapper 改外观）；
- `ToolCallRowView` / 自定义 tool renderer 和底部审批；
- `RetryTurnButton` 与 `ResendMessageButton`，两者语义必须保持不同。

需要在 V5 补齐：

- `.chatGPT` 的所有核心 role/renderKind 路由，不能只改 user/assistant；否则 status/error/system/default 会落回旧 chrome。
- `ChatMarkdownTheme.makeChatGPT(from:)`。
- 表格横向滚动：`MarkdownTheme.tableScrollsHorizontally` 已声明，但 `MarkdownBlockRenderer.tableView` 当前尚未消费。只在该 flag 为 true 时包横滚，避免改变其他主题。见 `Packages/KitMarkdown/Views/MarkdownTheme.swift:139-160`、`Packages/KitMarkdown/Views/MarkdownBlockRenderer.swift:232-272`。

未找到数学公式专用渲染、通用编辑重跑、分支、点赞和任意回复重生成协议，均不得列入首期“已完成”。

---

## 4. 架构决策记录（ADR）

### ADR-1：新增独立 V5 Package，而不是在 ZCode 中增加皮肤

- **决策：** 新建 `PluginMessageListChatGPT`，新增 `ResponseVerbosity.chatGPT = "v5"`。
- **理由：** 符合当前四种列表的平级装配和独立生命周期；V5 可独立演化、禁用、测试和发布。
- **备选：** 在 ZCode 中加 `style = .chatGPT`；拒绝，因为选择状态、测试夹具和包职责会继续膨胀。
- **代价：** 公共 enum 的穷尽 switch 都要更新；基础设施会再有一份私有实现。
- **兼容性：** 持久化字段已是字符串，无需 SwiftData schema migration。旧版本无法识别 `v5` 时会走该版本的 nil/default 路径；不承诺旧客户端仍显示 V5，需做一次降级实测。

### ADR-2：暂不为第三个列表抽取共享 Kit

- **决策：** 以 ZCode 的私有实现为行为模板，在 V5 内实现必要底座，不依赖 ZCode，不public 化其 ViewModel。
- **理由：** 当前仓库已明确选择“各档位独立实现，避免插件依赖插件”；本任务目标是新呈现，不同时承担 V3/V4 大规模迁移。
- **备选：** 新建 `KitMessageListCore` 并同时迁移 V3/V4/V5；拒绝，回归面和评审成本明显大于本需求。
- **后果：** 近似代码增加；用相同的分页、身份、projection 和滚动不变式测试防止漂移。未来若再增加第六种列表，应先单独评估抽 Kit，而不是继续复制。

### ADR-3：保留统一 Renderer 分发，V5 视图放在 PluginMessageRenderer

- **决策：** V5 列表包通过公开 Provider 渲染；核心 renderer 对 `.chatGPT` 使用 V5 私有组件。
- **理由：** 保持 `preferredRendererID`、第三方 renderer、工具扩展和开发调试徽章；`canRender` 无 verbosity，新包不能安全地全局抢渲染。
- **备选：** V5 自己注册高优先级 renderer；拒绝，因为会跨模式截获消息并形成隐式全局状态。
- **代价：** 视觉代码分布在列表包和 renderer 包，需用路由矩阵测试保证完整性。

### ADR-4：V5 启用流式显示，但不改全局开关

- **决策：** `ChatGPTListViewModel` 实例注入 `streamingDisplayEnabled: true`，保留 16ms 合并和 live-tail projection。
- **理由：** 流式阅读是目标体验的一部分；其他变体保持原默认，降低回归。
- **失败策略：** 无 streaming Provider 时只显示现有活动状态，不用计时器伪造逐字输出；性能验收不通过则不发布 V5，而不是悄悄全量重建历史。

### ADR-5：只呈现真实能力

- **决策：** 复制、再次发送、失败重试沿用现有 capability；编辑、分支、点赞、通用重生成不进首期。
- **理由：** 防止截图相似但行为错误，尤其是删除后续消息、恢复附件和回合身份。
- **后续：** 若产品需要完整 ChatGPT 交互，先另立 Provider 协议、持久化语义和迁移计划，再把按钮加入 V5。

### ADR-6：继续使用 List + AppKit 几何观察

- **决策：** 不使用 `ScrollView + LazyVStack`，不把滚动判断改成 PreferenceKey 反馈环。
- **理由：** 当前源码已记录 AttributeGraph 活锁和 eager materialize 风险，且已有 cell 复用、首屏 gate、滚动来源分类实现。
- **代价：** AppKit 代码和条件编译继续存在；iOS 只复用可共享层，平台特定行为需单独验证。

---

## 5. 目标包结构与文件改造清单

### 5.1 新包

```text
Packages/PluginMessageListChatGPT/
├── Package.swift
├── README.md
├── Resources/Localizable.xcstrings
├── Sources/PluginMessageListChatGPT/
│   ├── PluginMessageListChatGPTPlugin.swift
│   ├── ChatGPTVerbosityObservationBox.swift
│   ├── MessageListChatGPTUITestingSupport.swift
│   ├── Capabilities/
│   │   ├── MessageCapability.swift
│   │   ├── ConversationCapability.swift
│   │   ├── ConversationStateCapability.swift
│   │   ├── RenderingCapability.swift
│   │   ├── StreamingCapability.swift
│   │   ├── ToolManagerCapability.swift
│   │   ├── AgentLoopCapability.swift
│   │   └── ChatSectionCapability.swift
│   ├── Models/
│   │   ├── ChatGPTTurn.swift
│   │   ├── MessageListServices.swift
│   │   └── MessageExtensions.swift
│   ├── Services/
│   │   ├── MessageListPaginationService.swift
│   │   ├── MessageListRowBuilder.swift
│   │   ├── MessageListTailRefreshGate.swift
│   │   ├── ChatGPTTurnProjector.swift
│   │   ├── ChatGPTTurnProjectionStore.swift
│   │   ├── ChatGPTScrollAnchor.swift
│   │   ├── ChatGPTScrollSourceClassifier.swift
│   │   ├── MessageListScrollCoordinator.swift
│   │   ├── InitialPositionGate.swift
│   │   └── PluginLocalization.swift
│   ├── ViewModels/ChatGPTListViewModel.swift
│   └── Views/
│       ├── ChatGPTListView.swift
│       ├── ChatGPTTurnView.swift
│       ├── ChatGPTConversationLayout.swift
│       ├── ChatGPTBackToBottomButton.swift
│       ├── ChatGPTAccessibilityIdentifiers.swift
│       ├── MessageRowView.swift
│       ├── MessageListRuntime.swift
│       ├── ScrollViewBottomTracker.swift
│       └── LiveResizeFrozenView.swift
└── Tests/PluginMessageListChatGPTTests/
    ├── TestCapabilityStubs.swift
    ├── ChatGPTConversationLayoutTests.swift
    ├── ChatGPTListViewModelTests.swift
    ├── ChatGPTTurnProjectorTests.swift
    ├── ChatGPTTurnProjectionStoreTests.swift
    ├── ChatGPTScrollAnchorTests.swift
    ├── MessageListPaginationTests.swift
    └── MessageListChatGPTUITestingSupportTests.swift
```

新包依赖以 `PluginMessageListZCode/Package.swift` 为模板，只声明实际使用的 Provider/Kit；**不得**出现 `.package(path: "../PluginMessageListZCode")`、`.package(path: "../PluginMessageListDetailed")` 或 `.package(path: "../PluginMessageRenderer")`。

### 5.2 Renderer 新增私有组件

```text
Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ChatGPT/
├── ChatGPTUserMessageView.swift
├── ChatGPTAssistantMessageView.swift
├── ChatGPTMessageActionsView.swift
├── ChatGPTToolWorkHistoryView.swift
├── ChatGPTTimelineMarkerView.swift
└── ChatGPTErrorMessageView.swift
```

修改：

- `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/MessageRendererPlugin.swift`
- `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/UserMessageView.swift`
- `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/AssistantMessageView.swift`
- `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Helpers/ChatMarkdownTheme.swift`
- 对应 `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ChatGPT*Tests.swift`

### 5.3 宿主与设置

- `Packages/ProviderConversation/Sources/ProviderConversation/ResponseVerbosity.swift`
- `Packages/ProviderConversation/Tests/ProviderConversationTests/ResponseVerbosityTests.swift`
- `Packages/PluginConversationVerbosity/Sources/PluginConversationVerbosity/Support/VerbosityLocalization.swift`
- `Packages/PluginConversationVerbosity/Resources/Localizable.xcstrings`
- `Packages/PluginConversationManager/Sources/PluginConversationManager/Views/ConversationStoreSettingsView.swift:486-495`
- `Packages/FactoryLumi/Package.swift`
- `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`
- `Packages/FactoryLumi/Tests/FactoryLumiTests/MessageListSlotArbitrationTests.swift`
- 使用 `SelectedPluginFactory` 且需要 V5 的宿主白名单。

### 5.4 Markdown、UI 测试与文档

- `Packages/KitMarkdown/Views/MarkdownBlockRenderer.swift`
- `Packages/KitMarkdown/Tests/KitMarkdownTests/` 中新增 ChatGPT table layout 测试，文件名以现有测试目录为准。
- `LumiUITests/LumiMessageListChatGPTUITests.swift`
- `LumiUITests/LumiMessageListChatGPTScrollUITests.swift`
- `docs/plans/artifacts/chatgpt-message-list-v5/`：实施时生成真实截图和评审索引，不预先伪造。

---

## 6. 分阶段 TDD 实施计划

> 所有命令从仓库根目录运行。每个任务遵循“失败测试 → 确认失败 → 最小实现 → 确认通过 → 按明确路径提交”。中间提交位于功能分支，不作为发布点；本文中的提交命令不代表当前已获得提交或 push 授权。
>
> 每次提交前执行 `git status --short`、`git diff --cached --name-only`，只暂存本任务文件；禁止 `git add .`、`git add -A`、`git commit -a`。若其他会话已修改同文件，先协调，不覆盖、不 reset。

### Task 1：V5 枚举、独立包与互斥接线

**Files:**

- Modify: `Packages/ProviderConversation/Sources/ProviderConversation/ResponseVerbosity.swift`
- Modify: `Packages/ProviderConversation/Tests/ProviderConversationTests/ResponseVerbosityTests.swift`
- Create: `Packages/PluginMessageListChatGPT/Package.swift` 及最小插件入口、资源和测试目录
- Modify: `Packages/FactoryLumi/Package.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`
- Modify: `Packages/FactoryLumi/Tests/FactoryLumiTests/MessageListSlotArbitrationTests.swift`

**Step 1：先改测试。**

将 raw value、alias、allCases、Codable 往返改为五档；未知值测试改用 `"v6"`，保留默认 `.standard`。核心断言：

```swift
#expect(ResponseVerbosity.chatGPT.rawValue == "v5")
#expect(ResponseVerbosity(rawValue: "v5") == .chatGPT)
#expect(ResponseVerbosity(rawValue: "CHATGPT") == .chatGPT)
#expect(ResponseVerbosity.allCases.map(\.rawValue) == ["v1", "v2", "v3", "v4", "v5"])
#expect(ResponseVerbosity.defaultVerbosity == .standard)
#expect(ResponseVerbosity(rawValue: "v6") == nil)
```

把 arbitration 的往返矩阵扩为 `.brief → .standard → .detailed → .zcode → .chatGPT → .brief`，每步断言 active item 至多一个；新增选择 V5 和 shutdown V5 的测试。harness 必须强持有真实 V5 插件。

**Step 2：运行并确认失败。**

```bash
swift test --package-path Packages/ProviderConversation --filter ResponseVerbosityTests
swift test --package-path Packages/FactoryLumi --filter MessageListSlotArbitrationTests
```

预期：编译失败，找不到 `.chatGPT` / `PluginMessageListChatGPTPlugin`，而不是用删除断言获得绿色。

**Step 3：最小实现。**

- 新增 `case chatGPT`，raw value `"v5"`，alias `"v5", "chatgpt"`，图标 `message`。
- 新插件 ID 为 `com.coffic.lumi.plugin.message-list.chatgpt`，order 82，`.alwaysOn`，`.preview`。
- 常驻注册 `exclusiveGroup == "message-list"`、`fillsRemainingHeight == true` 的贡献项，只在当前会话为 `.chatGPT` 时 active。
- 首步可提供编译所需的最小 `ChatGPTListView`，后续任务补齐数据与外观，不在此任务复制完整 V4。
- Factory 添加 dependency、product、import、实例和 test product；插件放在 ZCode 后、MessageRenderer 前。
- shutdown 取消全部 observer、释放 ViewModel 并按插件 ID 移除 item。

**Step 4：确认通过。**

重复 Step 2 命令，并运行：

```bash
swift test --package-path Packages/PluginMessageListChatGPT --filter ChatGPTVerbosityObservationTests
```

预期全部 PASS；V1–V4 原断言不得修改语义。

**Step 5：独立提交。**

```bash
git add Packages/ProviderConversation/Sources/ProviderConversation/ResponseVerbosity.swift Packages/ProviderConversation/Tests/ProviderConversationTests/ResponseVerbosityTests.swift Packages/PluginMessageListChatGPT Packages/FactoryLumi/Package.swift Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift Packages/FactoryLumi/Tests/FactoryLumiTests/MessageListSlotArbitrationTests.swift
git commit -m "feat: add ChatGPT message list plugin shell"
```

### Task 2：设置菜单、持久化与旧版本降级

**Files:**

- Modify: `Packages/PluginConversationVerbosity/Sources/PluginConversationVerbosity/Support/VerbosityLocalization.swift`
- Modify: `Packages/PluginConversationVerbosity/Resources/Localizable.xcstrings`
- Modify: `Packages/PluginConversationManager/Sources/PluginConversationManager/Views/ConversationStoreSettingsView.swift`
- Test: 两个设置插件现有 verbosity/localization 测试
- Test: `Packages/PluginConversationManager/Tests/ConversationManagerPreferenceTests.swift`

**Step 1：** 增加五档 display name/description 测试和 `v5` 持久化往返测试，文案只描述“ChatGPT 风格消息列表”，不描述回复长短。

**Step 2：** 运行相关测试，确认穷尽 switch 或断言失败。

```bash
swift test --package-path Packages/PluginConversationVerbosity
swift test --package-path Packages/PluginConversationManager --filter ConversationManagerPreferenceTests
```

**Step 3：** 补 `.chatGPT` 分支和中英文资源；`ConversationStoreSettingsView` 显示 `ChatGPT`。不修改 `V4ConversationReader`，它与消息列表 V4/V5 无关。

**Step 4：** 验证重进 App 后仍为 V5；用旧版本测试夹具读取 `v5`，记录实际 nil/default 行为，不改数据库、不写回一个不同枚举值。

**Step 5：** 仅提交本任务四个实现/测试范围，提交信息：`feat: expose ChatGPT message list setting`。

### Task 3：布局 token 与用户消息

**Files:**

- Create: `Packages/PluginMessageListChatGPT/Sources/PluginMessageListChatGPT/Views/ChatGPTConversationLayout.swift`
- Create: `Packages/PluginMessageListChatGPT/Tests/PluginMessageListChatGPTTests/ChatGPTConversationLayoutTests.swift`
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ChatGPT/ChatGPTUserMessageView.swift`
- Create: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ChatGPTUserMessageViewTests.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/UserMessageView.swift`

**Step 1：写几何和行为失败测试。**

至少覆盖：

- container 390、479、480、900、1440；0、负数、NaN、infinity 不产生负宽或 trap。
- 内容列最多 768；气泡不超过内容列，宽列最多 560。
- 圆角 18、padding 16/10、目标行高 24。
- 短文本收缩、长 URL 换行、attachment-only 无空气泡。
- 普通长正文不使用 120pt 折叠；collapsed content metadata 仍生成 chip。
- 复制原文；再次发送只调用一次现有 capability。

**Step 2：运行并确认失败。**

```bash
swift test --package-path Packages/PluginMessageListChatGPT --filter ChatGPTConversationLayoutTests
swift test --package-path Packages/PluginMessageRenderer --filter ChatGPTUserMessageViewTests
```

**Step 3：最小实现并接路由。**

实现第 2 节纯函数和 `ChatGPTUserMessageView`；`UserMessageView` 仅在 `.chatGPT` 时进入新视图，`.zcode` 与 legacy 分支保持原样。复用现有附件解码和组件，不复制 base64 解码逻辑。

**Step 4：重复测试并跑完整 renderer 测试。**

```bash
swift test --package-path Packages/PluginMessageRenderer
```

**Step 5：** 按明确路径提交：`feat: add ChatGPT user message presentation`。

### Task 4：助手、reasoning、工具、错误与 Markdown 路由矩阵

**Files:**

- Create: 第 5.2 节其余 ChatGPT renderer 组件
- Modify: `MessageRendererPlugin.swift`、`AssistantMessageView.swift`、`ChatMarkdownTheme.swift`
- Modify: `Packages/KitMarkdown/Views/MarkdownBlockRenderer.swift`
- Test: `ChatGPTAssistantMessageViewTests.swift`、`ChatGPTMessageRoutingTests.swift`、`ChatGPTReasoningViewTests.swift`、`ChatGPTToolWorkHistoryViewTests.swift`、`ChatGPTMarkdownThemeTests.swift`、表格布局测试

**Step 1：先写路由矩阵和状态测试。**

| 输入 | 必须得到 |
|---|---|
| user | ChatGPT 右侧气泡 |
| 普通 assistant | 无气泡正文 |
| tool-step-group / turn-activity | ChatGPT 工具工作组 |
| error / isError | 内联错误；只有有效 failed turn 有 retry |
| status / system / compact / retry / model switch | 低强调 timeline marker |
| 独立 tool | 安全工具呈现；正常分页仍过滤 |
| default / 未知 renderKind | 无旧 chrome 的 Markdown 兜底 |
| `preferredRendererID` | 仍选指定 renderer，不被 V5 截获 |

另测：reasoning 完成默认收起、无真实时长不显示、工具授权不被折叠、成功 assistant 无 retry、无 fake like/edit/branch。

**Step 2：运行并确认失败。**

```bash
swift test --package-path Packages/PluginMessageRenderer --filter ChatGPT
swift test --package-path Packages/KitMarkdown --filter ChatGPTTableLayoutTests
```

**Step 3：最小实现。**

- 所有核心注册项都处理 `.chatGPT`，不能只改 user/assistant。
- 复用同包 reasoning/tool 行为组件；只在 V5 wrapper 改布局和文案，不复制状态机。
- 新增 `makeChatGPT(from:)`；V1–V4 theme 输出不变。
- `tableScrollsHorizontally == true` 时才给 table 内容加横向 ScrollView；对 false 保持当前布局。代码块继续内部横滚。
- 不新增数学依赖；现有公式文本如何显示就如何显示，并在非目标中保留。

**Step 4：运行完整相关包测试。**

```bash
swift test --package-path Packages/PluginMessageRenderer
swift test --package-path Packages/KitMarkdown
swift test --package-path Packages/ProviderMessageRendering
```

**Step 5：** 将 renderer 路由与 KitMarkdown 横滚分成两个独立提交，便于回归定位：`feat: add ChatGPT assistant message rendering`、`fix: honor horizontal table scrolling theme`。

### Task 5：消息窗口、turn 投影和异步身份

**Files:**

- Create: 新包 Capabilities、Models、Services、`ChatGPTListViewModel.swift`
- Create: `TestCapabilityStubs.swift`、pagination、projector、projection store、ViewModel 测试

**Step 1：先写五类失败测试。**

1. **旧请求晚到：** A 快照被 gate 挂住，激活 B 并完成后再释放 A；最终只能显示 B。A 的错误晚到也不能写 B 的错误状态。
2. **分页有界：** pageSize 40、retained 300；连续 prepend 不超过上限，tail eviction 后空档能回填，不出现永久缺段。
3. **工具分组：** 不跨普通正文合并 tool-only assistant；合成 ID 随成员变化；新增等待授权工具会重新物化。
4. **projection 失效：** 100 行历史 + 50 次 streaming snapshot，history rebuild 为 1；等长正文 `AAAA → BBBB` 后重建且复制文本更新。
5. **删除/清空/切换：** 清空不残留旧行，切换会话重置 projection、分页和滚动身份。

异步测试使用 gate/continuation，禁止用任意 `sleep` 猜时序；`isLoading` 与 `isLoadingEarlier` 分离，重叠加载用计数或既有 gate，不能由旧任务收尾关掉新任务 loading。

**Step 2：运行并确认失败。**

```bash
swift test --package-path Packages/PluginMessageListChatGPT --filter ChatGPTListViewModelTests
swift test --package-path Packages/PluginMessageListChatGPT --filter ChatGPTTurnProjectionStoreTests
swift test --package-path Packages/PluginMessageListChatGPT --filter MessageListPaginationTests
```

**Step 3：最小实现。**

- View 不直接访问 Kernel；插件入口解析 Provider 并收窄成 internal capabilities。
- inserted 可应用内存插入；persisted/updated/deleted/cleared 走受身份保护的 tail refresh。
- 每个 await 后比较 `activationSequence` 与 `conversationID`，失败直接 return，不写状态或错误。
- 保留独立 `.tool` 过滤、稳定排序和 turn 边界。
- 此任务先保留 `streamingDisplayEnabled == false`，Task 7 在性能测试就位后开启。

**Step 4：重复测试并运行整个新包测试。**

```bash
swift test --package-path Packages/PluginMessageListChatGPT
```

**Step 5：** 提交：`feat: add bounded ChatGPT conversation projection`。

### Task 6：List、首屏定位和滚动所有权

**Files:**

- Create: 新包 Views、scroll reducer、source classifier、coordinator、gate
- Create: `ChatGPTScrollAnchorTests.swift`、source、coordinator、gate 测试

**Step 1：先写 reducer 与协调器失败测试。**

- 47/48 视为底部，49 脱离；只有 `.user` 来源能改变 following。
- 用户上滚立即 detached；delta、文档变高、终端折叠、resize 不抢回。
- 点击回到底部恢复；用户回到 48 内恢复。
- prepend 保持锚点；延迟任务可取消；会话切换使旧任务失效。
- 首屏 gate 超时能解除 mask，失效 generation 不写回。
- 回到底部按钮 identifier 和居中几何稳定。

**Step 2：运行并确认失败。**

```bash
swift test --package-path Packages/PluginMessageListChatGPT --filter ChatGPTScrollAnchorTests
swift test --package-path Packages/PluginMessageListChatGPT --filter MessageListScrollCoordinatorTests
swift test --package-path Packages/PluginMessageListChatGPT --filter InitialPositionGateTests
```

**Step 3：最小实现。**

- 使用 `List`，隐藏系统分隔和默认 row inset；runtime/gate/projection/scrollAnchor 为 `@StateObject`。
- `.id(selectedConversationID)` 只作用于列表数据身份，observer 按 ZCode 当前结构放在正确作用域。
- 使用 `NSScrollView`/`NSClipView` 几何观察，不用 PreferenceKey 形成布局反馈环。
- streaming scroll 不动画；用户点击回到底部可使用短动画，Reduced Motion 下关闭。
- live resize 复用位图冻结策略，结束后恢复真实内容。

**Step 4：重复测试并运行新包全测试。**

**Step 5：** 提交：`feat: preserve ChatGPT message reading position`。

### Task 7：开启真实流式并锁定性能

**Files:**

- Modify: `PluginMessageListChatGPTPlugin.swift`
- Modify: `ChatGPTListViewModel.swift`、live-tail view（仅在测试揭示问题时）
- Test: `ChatGPTStreamingTests.swift`、`ChatGPTTurnProjectionStoreTests.swift`

**Step 1：先写失败测试。**

- `start → appendThinking → appendContent → end` 只影响 live tail，历史 rebuild 次数不随 token 增长。
- 16ms 窗口内多次 delta 合并为一次 UI 刷新；end 能及时 flush，不丢最后一段。
- 新会话激活后，旧 streaming task 不写回；detached 时 delta 不触发贴底。
- 无 streaming Provider 时只显示真实 activity，不产生伪逐字文本。

**Step 2：运行并确认流式断言在开关关闭时失败。**

```bash
swift test --package-path Packages/PluginMessageListChatGPT --filter ChatGPTStreamingTests
```

**Step 3：仅对 V5 注入 `streamingDisplayEnabled: true`，做最小修正；不得改 V1–V4 默认。**

**Step 4：验证性能与正确性。**

```bash
swift test --package-path Packages/PluginMessageListChatGPT
swift test --package-path Packages/KitMarkdown
```

再用 40+ 轮富文本连续 streaming 至少 5 秒，采样确认没有持续主线程 100% CPU、AttributeGraph 活锁或全历史 O(n) 重建。600 轮/1200 条消息首屏 mask 沿用现有 6 秒 UI 预算；时间指标在同一台机器记录前后对比，不把不同硬件的绝对耗时当稳定单测。

**Step 5：** 提交：`feat: stream ChatGPT assistant responses efficiently`。

### Task 8：无障碍、本地化和 Reduced Motion

**Files:**

- Modify: 新包 Views、Resources、Renderer ChatGPT 组件与资源
- Create: `ChatGPTAccessibilityTests.swift`
- Modify: `LumiUITests/LumiMessageListChatGPTUITests.swift`

**Step 1：先写标识符、label 和可见性测试。**

稳定 identifier 建议：

```text
lumi.message-list.chatgpt.container
lumi.message-list.chatgpt.back-to-bottom
lumi.message-list.chatgpt.user-copy
lumi.message-list.chatgpt.user-resend
lumi.message-list.chatgpt.assistant-copy
lumi.message-list.chatgpt.reasoning-disclosure
lumi.message-list.chatgpt.tool-group
lumi.message-list.chatgpt.error-retry
```

断言无图标按钮只有 symbol 没有 label；历史操作可通过 focus 到达；latest assistant 复制常驻；Reduced Motion 下无 shimmer/位移动画；中英文资源 key 完整。

**Step 2：运行并确认失败。**

```bash
swift test --package-path Packages/PluginMessageListChatGPT --filter ChatGPTAccessibilityTests
swift test --package-path Packages/PluginMessageRenderer --filter ChatGPTAccessibilityTests
```

**Step 3：最小实现，不添加逐 token announcement，不因状态更新移动焦点。**

**Step 4：运行时验证。**

用 XCUITest 验证键盘 focus 和标识符；再用 System Events dump AX 树，确认 VoiceOver 能到达列表、disclosure、复制、重试和回到底部。若系统截图被 TCC 拦截，记录限制并使用 AX 树与测试截图，不宣称做过未执行的 VoiceOver 验证。

**Step 5：** 提交：`fix: make ChatGPT message actions accessible`。

### Task 9：隔离 UI 夹具、XCUITest 和截图矩阵

**Files:**

- Create: `MessageListChatGPTUITestingSupport.swift` 及测试
- Create: `LumiUITests/LumiMessageListChatGPTUITests.swift`
- Create: `LumiUITests/LumiMessageListChatGPTScrollUITests.swift`
- Create: `docs/plans/artifacts/chatgpt-message-list-v5/` 的真实输出

**Step 1：先写启动守卫和 UI 失败用例。**

启动参数必须同时包含：

```text
--lumi-ui-testing
--lumi-ui-testing-message-list-chatgpt
--lumi-ui-testing-isolated-storage
```

夹具固定覆盖：视觉全量、长用户/附件、reasoning、工具与授权、错误、30+ 轮滚动、流式。seed 时抑制自动回复，完成后解除，再设置 `.chatGPT` 并选中固定会话；不包含凭据、不触发真实供应商。

功能用例：V1→V2→V3→V4→V5→V1 无空白/双列表；用户气泡、附件、复制、再次发送；助手无气泡且只有轮尾复制；无 fake 按钮；Markdown/代码/表格；reasoning/tool 展开；有效错误 retry；bottomFixed 审批只有一份。

滚动用例：streaming、异步测高、折叠、resize 不抢位置；回到底部恢复；prepend 不跳；首屏 mask 在 6 秒内消失。

**Step 2：运行并确认新用例失败。**

```bash
xcodebuild test -scheme Lumi -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListChatGPTUITests \
  -only-testing:LumiUITests/LumiMessageListChatGPTScrollUITests
```

**Step 3：最小修正并生成真实截图。**

逻辑宽度矩阵：390、479、480、600、768、900、1440；覆盖 light/dark、中文/英文、complete/streaming/hover/keyboard focus/reduced-motion。保留同内容 V4/V5 对照，评审布局层级、间距、颜色和状态语义；PNG 不做字节相等。

**Step 4：运行真实 UI 回归。**

```bash
xcodebuild test -scheme Lumi -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListBriefUITests \
  -only-testing:LumiUITests/LumiMessageListSwitchUITests \
  -only-testing:LumiUITests/LumiMessageListDetailedSwitchUITests \
  -only-testing:LumiUITests/LumiMessageListBottomScrollUITests \
  -only-testing:LumiUITests/LumiMessageListScaleUITests \
  -only-testing:LumiUITests/LumiToolCallGroupCollapseUITests \
  -only-testing:LumiUITests/LumiToolCallGroupDetailedUITests \
  -only-testing:LumiUITests/LumiMessageListZCodeUITests \
  -only-testing:LumiUITests/LumiMessageListZCodeScrollUITests \
  -only-testing:LumiUITests/LumiMessageListChatGPTUITests \
  -only-testing:LumiUITests/LumiMessageListChatGPTScrollUITests
```

若某测试类在当前 scheme 中不存在或既有失败，先核实并单独记录；不能通过删除既有测试或扩大超时掩盖回归。

**Step 5：** 提交：`test: verify ChatGPT message list experience`。

### Task 10：全量回归与交付审计

**Step 1：检查改动和格式。**

```bash
git diff --check
git status --short
python3 Scripts/verify-testplan.py
```

TestPlan 校验以当前项目既有基线为准：固定既有告警不视为本任务新增，但任何新增告警都必须处理或明确记录，不能把基线称为全绿。

**Step 2：逐包运行，不依赖可能吞退出码的汇总脚本。**

```bash
swift test --package-path Packages/ProviderConversation
swift test --package-path Packages/ProviderMessageRendering
swift test --package-path Packages/KitMarkdown
swift test --package-path Packages/PluginMessageRenderer
swift test --package-path Packages/PluginMessageListChatGPT
swift test --package-path Packages/PluginConversationVerbosity
swift test --package-path Packages/PluginConversationManager
swift test --package-path Packages/FactoryLumi --filter MessageListSlotArbitrationTests
```

**Step 3：全仓搜索遗漏。**

- `ResponseVerbosity` 穷尽 switch 均已处理 `.chatGPT`。
- 新包没有 import 其他 Plugin。
- renderer 公开签名未变，`preferredRendererID` 测试仍通过。
- 无硬编码 OpenAI 颜色、商标、假数据按钮、真实凭据或非隔离 UI seed。
- 无 `ScrollView + LazyVStack` 替代、无无限消息窗口、无未校验的 async 写回。
- `git diff --cached --name-only` 只包含当前提交范围；不 push，除非用户另行明确授权。

**Step 4：更新新包 README 和 artifacts 索引，记录实际命令、成功/失败、未验证项、性能环境和截图。独立文档根因单独提交。**

---

## 7. 验收标准

### 7.1 功能验收

- [ ] 设置中出现 ChatGPT V5，默认仍 Standard；`v5` 持久化往返稳定。
- [ ] 任一时刻最多一个 active message-list；Empty 不错误抢占，V1–V5 往返无空白和双列表。
- [ ] 内容列、用户气泡、助手正文、轮尾操作符合第 2 节几何合同。
- [ ] 附件、Markdown、代码、表格、reasoning、工具、错误都有真实数据路径。
- [ ] 复制、再次发送和失败重试语义不混淆；没有编辑、分支、点赞或通用重生成的假按钮。
- [ ] V5 真实流式可见，最终 delta 不丢失；无 Provider 时不伪造流式。
- [ ] V1–V4 视觉、交互和持久化行为不变。

### 7.2 性能与滚动验收

- [ ] List cell 复用、有界分页、tail backfill 和首屏 gate 均有效。
- [ ] streaming 不导致历史 O(n) 重建；等长正文替换仍刷新。
- [ ] 40+ 轮富文本连续 streaming 无持续主线程 100% CPU 和 AttributeGraph 活锁。
- [ ] 600 轮/1200 条消息在既有 6 秒 mask 预算内完成首屏；实际环境数据写入 artifacts。
- [ ] 用户离底后不被 streaming、测高、折叠或 resize 抢回；prepend 保持锚点。

### 7.3 可访问性与安全验收

- [ ] 所有动作可用键盘和 VoiceOver 到达，不依赖 hover。
- [ ] 不逐 token announcement、不抢焦点；Reduced Motion 下信息完整。
- [ ] 工具授权可见且只有一份 bottomFixed 审批，取消后不会永久等待。
- [ ] UI 测试使用双重启动守卫和隔离存储，无真实供应商、凭据或付费请求。
- [ ] 不新增原始错误/附件内容日志，不复制 OpenAI 专有资源。

---

## 8. 风险、失败模式与缓解

| 风险 | 早期信号 | 缓解 |
|---|---|---|
| 漏改某个 enum switch 或 renderer 路由 | 编译失败，或 error/status 落回旧气泡 | 五档 allCases 测试 + role/renderKind 路由矩阵 |
| 新包依赖 ZCode/Detailed | 插件间 import、internal 被迫 public | Package.swift 审计和依赖方向检查 |
| V5 renderer 截获其他模式 | V1–V4 外观变化、preferred renderer 失效 | 不新增全局高优先级 renderer；完整分发回归 |
| 旧异步快照覆盖新会话 | 切会话后短暂显示上一会话 | activationSequence + conversationID，gate 构造晚到测试 |
| streaming 全量重建历史 | CPU 随历史长度上升、长列表掉帧 | rebuildCount 断言 + live tail + 16ms 合并 |
| 表格/代码撑破 768 列 | 整个列表出现横向滚动 | 只让代码/表格内部横滚，增加窄宽 UI 测试 |
| hover 操作无法键盘到达 | AX 树没有按钮、focus 不出现 | focus/latest 常驻策略 + XCUITest/AX 验证 |
| 工具授权被简化外观隐藏 | pending 卡片消失或永久等待 | 保留真实 ToolCallRow 和 bottomFixed，覆盖取消/切换测试 |
| 复制/重试语义错误 | 再次发送被当编辑，旧失败回合可重试 | 分别使用现有 capability；`canRetryTurn` 纯函数测试 |
| 复制第三份滚动代码后漂移 | V3/V4/V5 同类 bug 重复出现 | 共用不变式测试；下一次新增列表前先评估独立抽 Kit |
| 旧版本读到 v5 | 设置回退或显示不一致 | 保留字符串字段、无 schema migration；实测旧版 nil/default，不承诺向前兼容 |
| 测试污染真实数据 | 无隔离参数也 seed、触发真实 Agent | DEBUG + 双 launch argument + isolated storage + 抑制自动回复 |

---

## 9. 参考资料

### OpenAI / 标准

1. [GPT-5.5 in ChatGPT — 编辑、重试与分支的官方说明](https://help.openai.com/en/articles/11909943-gpt-55-in-chatgpt)
2. [Working with writing blocks and code blocks in ChatGPT](https://help.openai.com/en/articles/20001246-working-with-writing-blocks-and-code-blocks-in-chatgpt)
3. [ChatGPT release notes](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)
4. [ChatGPT macOS app release notes](https://help.openai.com/en/articles/9703738-chatgpt-macos-app-release-notes)
5. [W3C WCAG 2.2 — Understanding Status Messages (4.1.3)](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html)
6. [W3C ARIA23 — Using role=log to identify sequential information updates](https://www.w3.org/WAI/WCAG21/Techniques/aria/ARIA23)

### 开源实现（只作行为参考）

7. [assistant-ui/assistant-ui](https://github.com/assistant-ui/assistant-ui)，MIT；调研 commit `b98301dff6542283c4ce616e25ea17b43021e8e4`。
8. [vercel/chatbot](https://github.com/vercel/chatbot)；调研 commit `a8989b522fa3672a2ae52f053105e40993b36ca1`。

### 仓库内

9. `Packages/PluginMessageListZCode/README.md`
10. `docs/plans/2026-11-08-zcode-message-list-v4.md`
11. `docs/plugin-first-architecture-sharing.md`
12. `AGENTS.md`：工具参数范围、工具失败抛出、异步身份、并发提交约定。
