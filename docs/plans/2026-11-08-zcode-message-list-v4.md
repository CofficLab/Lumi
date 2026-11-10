# ZCode Message List V4 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Lumi 新增第四套消息列表 V4（`ResponseVerbosity.zcode` / 持久化值 `"v4"`），在不改变 Agent、消息数据与 V1–V3 行为的前提下，尽可能精确复刻 ZCode 3.15.1 的用户气泡、助手正文、turn 组织、Markdown、工作历史与滚动体验。

**Architecture:** 在现有 `PluginMessageListDetailed` target 内新增独立的 `PluginMessageListZCodePlugin`，复用 V3 的分页、消息快照、流式事件、工具组合、`List` cell 复用、初始定位与滚动协调底座；新增 V4 专用的稳定 turn 投影、`ListV4View`、渲染上下文、视觉 token 和滚动所有权 reducer。消息仍经 `MessageRenderingProviding` 分发，核心 renderer 对 `.zcode` 显式分支，第三方 renderer、工具结果补全与授权桥不被绕过。

**Tech Stack:** Swift 6、SwiftUI、AppKit、Swift Package Manager、SwiftData、XCTest / Swift Testing、XCUITest；对照基准为同级 `../ZCode` 的 React 19、Tailwind CSS 4、Vitest 4。

---

## 0. 交付定义与不可突破的边界

### 0.1 “复刻”的验收含义

本计划复刻的是 **ZCode 真实共享桌面聊天 UI 的可见呈现与交互语义**，不是复制 React 实现，也不是把 Lumi 改造成 ZCode：

- 几何、颜色、字号、间距、折叠、hover、流式与滚动行为必须有源码证据和自动化测试。
- 几何和颜色做硬断言；Chromium 与 AppKit 字体栅格化不同，**不使用 PNG 字节相等**作为验收方法。
- 最终用同内容、同逻辑宽度、双主题截图人工对照，允许字体抗锯齿存在平台差异，不允许布局层级、间距、颜色或状态语义漂移。
- ZCode 的“虚拟历史 + live tail”在 Lumi 中由现有 `List` cell 复用、分页窗口和流式尾行承担；首版不另写 AppKit virtualizer。
- V4 只改变呈现。不得借“ZCode 风格”改变提示词、回复长度、AgentLoop、工具执行、消息持久化或会话 schema。

### 0.2 能力真实性

不得为了截图相似而伪造数据或空按钮：

- 不显示 Lumi 没有的 like/dislike、fork、行内编辑、Highspeed 分享、完整文件预览或统一自定义右键菜单。
- 不用 `resendMessage` 冒充 ZCode 的“编辑并回退工作区”。
- 不伪造思考时长、模型名、token、执行状态或工具结果。
- 普通助手不显示无真实行为的 retry；只有现有 `canRetryTurn` 返回 true 的错误/可重试场景才沿用真实能力。
- Permission / UserInput 继续由 `RiskApprovalChatSectionView` 的 `.bottomFixed` 区域承接，不复制成助手气泡。
- context/token 用量继续属于 composer toolbar，不塞进助手消息。

### 0.3 非目标

本任务不改造：composer、sidebar、项目树、状态面板、会话订阅架构、Agent 执行协议、消息数据库、V1/V2/V3 默认样式、`PluginConversationManager` 中旧数据 schema 的 `V4ConversationReader`。后者与消息列表 V4 完全无关。

### 0.4 实施纪律

- 从 Lumi 仓库根目录执行命令；ZCode 仅以同级 `../ZCode` 为只读参考。
- 开始前运行 `git status --short`。实施应在独立的干净 worktree/branch 中进行；若当前工作树已有未提交改动，不 checkout、restore、reset、覆盖或暂存这些改动，先在干净 worktree 实施。
- 每个任务遵循：失败测试 → 确认失败 → 最小实现 → 确认通过 → 独立提交。若目标文件存在非本任务改动，禁止用整文件 `git add` 把它带入 V4 提交。
- 文档中的提交步骤供未来实施 agent 使用，不代表计划编写阶段已获得提交或 push 授权。
- 不连接真实付费供应商，不读取真实凭据。UI 测试必须同时带 `--lumi-ui-testing` 与 `--lumi-ui-testing-isolated-storage`。
- `Scripts/run-all-package-tests.sh` 目前可能失败后仍退出 0，只能作辅助；每个关键 package 必须单独运行并检查真实退出码。

---

## 1. 固定复刻基准与证据地图

### 1.1 基准

```text
ZCode version: 3.15.1
ZCode commit:  aac4755666d09fdcd70272fcf063c077a639015f
Reference root: ../ZCode
```

实施前运行：

```bash
git -C ../ZCode rev-parse HEAD
node -p "require('../ZCode/package.json').version"
```

预期分别为上述 commit 与 `3.15.1`。若不一致，不 pull、不 rebase；在 PR 中记录实际基准并重新核对本计划引用的源码，不可悄悄混用远端新版本。

### 1.2 真实入口，不使用 CLI 或旧通用 Message 组件

```text
WorkspaceShellLayout
  → V4ChatPane / V4WorkspaceChatArea
    → SessionPane
      → ConversationTimeline
        → ConversationTurnGroup
          → ConversationTurnRow
            → ConversationRowView
```

证据：

- `../ZCode/packages/ui/src/app-shell/WorkspaceShellLayout.tsx:14-15,2261,2765`
- `../ZCode/packages/ui/src/v4/V4ChatPane.tsx:82-85,129-175`
- `../ZCode/packages/ui/src/v4/ConversationTimeline.tsx:1998-2008,2029-2039`
- `../ZCode/packages/ui/src/v4/ConversationTurnRow.tsx:43-80`
- `../ZCode/packages/ui/src/v4/ConversationRowView.tsx:2323-2398`

### 1.3 可直接运行的 ZCode 对照测试

```bash
pnpm --dir ../ZCode exec vitest run \
  packages/ui/test/assistantMarkdownTypeScale.test.ts \
  packages/ui/test/v4ConversationUserInputBody.test.ts \
  packages/ui/test/v4ConversationRowViewUserEdit.test.ts \
  packages/ui/test/v4MessageTimeLabel.test.ts \
  packages/ui/test/v4ConversationTurnGroup.test.ts \
  packages/ui/test/executeToolCallBlock.test.tsx \
  packages/ui/test/readToolCallBlock.test.ts \
  packages/ui/test/editToolCallBlock.test.ts
```

这些测试是行为参考，不替代 Lumi 自己的 Swift/XCUITest。`packages/ui/test/browser/manual-review/pending` 中的 ZCode 图是人工评审材料，不是可直接搬来的 pixel golden。

---

## 2. V4 可见规格合同

CSS px 与 macOS pt 按逻辑尺寸 1:1 映射；以下数值均为逻辑点。

### 2.1 内容列与 turn

来源：`../ZCode/packages/ui/src/v4/conversationLayout.ts:3-12`、`ConversationTurnGroup.tsx:1552-1574`。

**必须使用聊天容器宽度，不是窗口宽度。**

| 聊天容器宽度 `c` | 常规内容列宽 |
|---|---|
| `c < 864` | `c` |
| `864 ≤ c < 1280` | `min(c - 96, 896)` |
| `c ≥ 1280` | `min(c - 384, 1152)` |

- 内容列水平居中。
- turn 内水平 padding：容器 `< 448` 为 16，`≥ 448` 为 24。
- 普通含用户气泡 turn：顶部 56、底部 20。
- 没有可见用户气泡的工作/通知型 turn：顶部 0、底部 20，避免与上一 turn 的 20 叠加成 76 的空白。
- turn 一级内容间距 20；连续 reasoning/tool 等工作项之间 16。
- 普通消息无头像、无发送者名称、无按日期分组头。
- `max-w-2xl = 672` 只属于草稿空态，不能误用于常规消息列。
- timeline marker 用于 compact/fork/goal/modelChange 等系统事件，不是日期分隔线。

### 2.2 用户消息

来源：`ConversationUserInputBubble.tsx:23-44` 及对应 body/attachment 组件。

- 右对齐，短消息按内容收缩；长消息不超过可用宽度。
- 容器 `< 624`：气泡最大可用全宽；`≥ 624`：最大 576，同时仍受内容列内宽约束。
- 背景 `surface`，1px `border`，无阴影。
- 圆角 12，右上圆角 2；SwiftUI 用独立四角 radii，不用胶囊或对称圆角代替。
- padding：水平 16、垂直 12；内部间距 8。
- 正文 14/24，普通文本，不走助手 Markdown。
- 空正文且只有附件时不绘制空气泡；附件仍在气泡外右对齐，附件列最大 576，底间距 8。
- 图片/视频缩略图 80×80、圆角 12；非媒体文件 pill 水平 12、垂直 6、全圆角，文件名最大 160、图标 16。
- 长文可见高度 120，overflow tolerance 1：实测 120/121 不折叠，122 折叠。
- 展开/收起 300ms ease-out；`reduceMotion` 下无动画；内容或 row 身份变化后重新收起。
- hover/focus 才显示复制按钮；复制原始 `Message.content`，成功绿色勾 1200ms 后恢复；按钮 24×24、图标 14。

### 2.3 助手正文与轮尾操作

- 无气泡、无卡片背景、无头像、无名称，占满内容列。
- 正文 14，目标行高 `14 × 1.75 = 24.5`，tracking `0.025em ≈ 0.35`，strong 字重 500。
- SwiftUI 的 `.lineSpacing` 是“额外间距”，不能把 24.5 直接传入；必须用实际 `NSFont` 行高计算 `max(0, 24.5 - font.lineHeight)`。
- 操作栏只在 turn 完成且当前行是轮尾助手正文段时出现；hover 范围是整个 assistant turn，不只是按钮区域。
- 整轮复制：所有非空助手正文按原顺序用 `\n\n` 连接；不包含普通工具输出。
- 时间仅属于轮尾操作栏，12、`foreground-subtlest`。
- 流式正文无 cursor、无正文淡入、无 `animate-pulse`。
- streaming 与 complete 使用对应解析状态；完成后才启用高亮/Mermaid。

时间格式来源：`../ZCode/packages/ui/src/v4/messageTimeLabel.ts:52-93`：

| 条件 | 显示 |
|---|---|
| 无效/非正时间戳 | 不显示 |
| 今天 | 本地 locale 的 HH:mm |
| 昨天 | 本地化“昨天 HH:mm” |
| 今年其他日期 | 月、日、HH:mm |
| 非今年 | 年、月、日、HH:mm |

测试必须注入固定 `now`、`Calendar`、locale 与 time zone，不能依赖运行机器当前日期。

### 2.4 Markdown

总容器证据：`../ZCode/packages/ui/src/components/ai-elements/message.tsx:1367-1371`。

| 元素 | V4 规格 |
|---|---|
| 标题通用 | 上 24、下 16；首个子元素去顶部 margin |
| h1 | 18 / 600 |
| h2 | 16 / 600 |
| h3、h4 | 14 / 600 |
| h5 | 14 / 500 |
| h6 | 14 / 400 |
| 无序列表 | 上下 12、左 padding 20、项间距 6、subtlest marker；嵌套上下 6 |
| 有序列表 | inside decimal、左 padding 0、li 左 padding 4 |
| 引用 | 上下 16、左 2 border、左 padding 12、subtle 文本 |
| 链接 | 14/500、icon-blue、默认无 underline、hover dotted underline、offset 4、长 URL 可断行 |
| 行内代码 | 12 mono、圆角 6、左右外边距 2、水平 padding 6、垂直 2、inline-code 50% alpha |
| 普通段落 | 源码无统一自定义 margin；保持解析器默认并用截图校准，不编造数值 |

### 2.5 代码块、表格与图片

代码块：

- 外壳上下 16、1px border、`card` 背景、圆角 12、裁剪溢出。
- Header：左 12、右 8、垂直 8；语言小写 mono，可 truncate；缺省语言 `text`；文件图标 16；操作按钮 28×28、图标 14。
- 内容水平 8、上 0、下 12；字号 12，不采用旧 DESIGN 文档里的 14。
- 默认无行号；流式默认不高亮，完成后异步高亮。
- 默认不 wrap，长行内部横向滚动；允许现有能力切换 wrap；复制反馈 2000ms。
- 不发明固定最大高度。

表格：

- frame 圆角 12、1px border；内部横向滚动，不能撑宽 timeline。
- th/td 水平 12、垂直 8；th 左对齐、字重 400。
- 单元格最小 64、最大 448。

图片：

- 单图最大为容器 50% 宽，最大高 360，圆角 12。
- 连续图片组成 gallery；失败显示错误占位。

### 2.6 Reasoning 与工作历史

Reasoning：

- streaming 和 complete 默认均收起；streaming 且 text 为空不渲染。
- 完成时自动 collapse 不得覆盖用户显式展开/收起选择。
- Brain 图标 16；streaming 文案使用 gradient，动画 4s linear infinite；reduced-motion 禁用。
- 只有真实时长字段语义匹配时才显示完成时长；不得用消息到达间隔伪造。
- streaming 收起时显示最后非空行摘要。
- 内容顶部间距 12、最大高 240、内部纵向滚动；左 margin 8、左 padding 14、左边框。
- 内容是普通文本，不跑 Markdown；默认吸底，用户离底超过 2 后停止跟随。
- turn 级工作历史折叠与单条 reasoning 折叠是两套独立状态。

工具：

- 两个及以上连续 Explore/Execute 才形成父分组；单工具不额外套父层。
- ZCode 默认：Explore=true、Execute/Terminal=true、Changes=false、CUA=true；Lumi 只映射真实存在的工具类型，找不到等价语义时保持独立工具行。
- 共享嵌套容器：左 margin 8、左边框、左 padding 14、子项间距 8。
- 摘要 14，图标通常 16，项间距 8，默认收起；Enter/Space 可展开，暴露 `accessibilityExpanded` 与可见键盘焦点。
- 展开内容与摘要间距 8；收起后 300ms 卸载重内容。
- 工具错误使用失败状态 + dotted underline + tooltip，不默认变成大红卡。
- Execute 摘要 command 用 sans；展开命令 mono 且带 `$`；详情卡圆角 12、1px border、水平 16、垂直 12。
- Execute 输出 mono 14/20，最多 5 行内部滚动；离底超过 8 后停止输出跟随。
- Read 不展开结果；Edit 可展开 inline diff，最大高 240；通用工具预览最大高 240。
- 必须复用 Lumi 现有 `ToolCallRowRenderer`、结果补全、授权状态和 `ToolApprovalBridge`，不得用静态 ZCode 文案替换真实状态。

### 2.7 滚动所有权

来源：`../ZCode/packages/ui/src/v4/timelineScrollAnchor.ts`。

- 底部容差固定 48：`max(0, contentHeight - viewportHeight - scrollTop) <= 48` 视为底部。
- `following` 表示用户滚动权，不是瞬时几何快照。
- 用户上滚离底：`following=false`；流式增量、测高、resize、终态折叠不得抢回阅读位置。
- 用户滚回 48 内或点击回底按钮：`following=true`。
- 只有真实用户滚动输入可以改变 following；programmatic/layout 事件只更新几何账目。
- following 时内容增长贴底；detached 时保持阅读位置并显示回底按钮。
- 回底按钮 28×28、圆形、outline、图标 16，位于消息列表底部与 composer 交界处；不修改 composer 内部。
- V3 的 `BottomEdgeEvaluator` enter 24 / leave 96 保持不变；V4 使用独立 reducer，不能全局改成 48。

### 2.8 双主题 token

实际基准是 `theme-zai-light` / `theme-zai-dark`，不是只看普通 `.dark` fallback。

| Token | Light | Dark |
|---|---|---|
| background | `#f8f8f8` | `#161616` |
| border | `rgba(13,13,13,0.10)` | `rgba(255,255,255,0.10)` |
| hover | `rgba(13,13,13,0.05)` | `rgba(255,255,255,0.05)` |
| selected | `rgba(13,13,13,0.05)` | `rgba(255,255,255,0.10)` |
| panel/card | panel `#ffffff`, card `#ffffff` | panel `#202020`, card `#2b2b2b` |
| popover/input | `#ffffff` | dark popover `#2b2b2b` |
| surface | `rgba(13,13,13,0.03)` | `rgba(255,255,255,0.05)` |
| foreground | `#262626` | `#d4d4d4` |
| subtle | foreground 60% | foreground 60% |
| subtlest | foreground 40% | foreground 30% |
| destructive | `#e03131` | `#ff5c5c` |
| warning | `#e07b00` | `#ff8a30` |
| inline-code base | `#e6e6e6` | `#363636` |
| icon-blue | `#0066dd` | `#80beff` |

- 字号只允许本规格需要的 18/16/14/13/12/10。
- sans 使用系统栈；mono 使用 `NSFont.monospacedSystemFont` 或系统 mono 栈，不虚构 bundled font。
- collapse 300ms；gradient 4s；reduced-motion 禁用装饰动画。

---

## 3. Lumi 接入与文件设计

### 3.1 为什么不新建 package

`ListV3ViewModel`、分页、工具组合、runtime、gate 等均为 internal 且体量较大。新建 package 会迫使复制或扩大大量 API。V4 与 V3 共用同一 target，但使用独立插件类、ID、observer、ViewModel 实例和 shutdown，不共享可变单例。

生产 `FactoryLumi` 已依赖并 import `PluginMessageListDetailed`，只需追加插件实例，不新增生产 package/product。

### 3.2 渲染上下文

保留现有签名：

```swift
public let render: @MainActor @Sendable (Message, ResponseVerbosity) -> AnyView
```

新增可选 SwiftUI Environment，而不是修改所有第三方 renderer：

```swift
public struct MessageTurnPresentationContext: Equatable, Sendable {
    public let turnKey: String
    public let agentTurnID: UUID?
    public let isTailAssistantText: Bool
    public let isRunning: Bool
    public let assistantCopyText: String
    public let completedAt: Date?

    public init(
        turnKey: String,
        agentTurnID: UUID?,
        isTailAssistantText: Bool,
        isRunning: Bool,
        assistantCopyText: String,
        completedAt: Date?
    ) {
        self.turnKey = turnKey
        self.agentTurnID = agentTurnID
        self.isTailAssistantText = isTailAssistantText
        self.isRunning = isRunning
        self.assistantCopyText = assistantCopyText
        self.completedAt = completedAt
    }
}
```

- `MessageRowView` 新增默认 nil 的 `turnContext` 参数，并只把 context 应用到 renderer 输出。
- V1–V3 不传 context，行为完全不变。
- V4 turn 根视图另传 `messageTurnIsHovered` Environment，默认 false；核心 Assistant renderer 据此控制轮尾操作栏。
- 共享的 V4 颜色 token 也放在 `ProviderMessageRendering`，因为 list 与 renderer 两个 target 都已依赖它；避免新建 package 或制造互相依赖。

### 3.3 Turn 投影与 live tail

新增纯值类型：

```swift
struct ZCodeTurnRow: Identifiable, Equatable {
    enum Origin: Equatable { case history, streaming, activity }
    let id: String
    let message: Message
    let origin: Origin
}

struct ZCodeTurn: Identifiable, Equatable {
    let id: String
    var agentTurnID: UUID?
    var rows: [ZCodeTurnRow]
    var isRunning: Bool
    var tailAssistantRowID: String?
    var assistantCopyText: String
    var completedAt: Date?
}
```

规则：

1. 输入必须是 `ListV3ViewModel.historyRows`，不是重新读数据库；这样独立 `.tool` 过滤和连续 tool-only 合并只有一份事实来源。
2. 用户消息开启新 turn。普通用户消息没有 `turnID`，不能仅按 `turnID` 分桶。
3. 非用户行优先沿用当前 turn；若它和当前 turn 都有非 nil 且不同的 `turnID`，开启新 turn。
4. 当前 turn 尚无 `agentTurnID` 时，可由后续真实消息的非 nil `turnID` 补上。
5. 旧数据全部 nil turnID 时，以用户消息边界和原始顺序确定性分组。
6. 含用户消息的 turn 使用 `"message:<userUUID>"`；助手/工作主导的 turn 优先 `"turn:<turnUUID>"`，否则 `"message:<firstMessageUUID>"`。禁止随机 UUID。
7. history row id 为 `"history:<messageUUID>"`；streaming 固定使用 `LumiStreamingRowID` 语义；activity 固定 `"conversation-activity"`，避免临时行与落库行身份冲突。
8. `assistantCopyText` 只拼接 `role == .assistant`、非 tool-execution-only、去空白后非空的正文，分隔符 `\n\n`。
9. `tailAssistantRowID` 是最后一个符合上述条件的正文行；操作栏只挂在这里。
10. `completedAt` 取该轮尾正文的真实 `createdAt`；运行中不显示完成时间。
11. 保持 V3 尾行规则：streaming 存在时不另显示 activity；history 的 status 隐藏逻辑继续由 ViewModel 负责。投影不得再次插入同一尾行。
12. prepend 只改变数组，不重建所有身份；翻页锚点仍使用 V3 返回的真实 anchor message id。

新增 `ZCodeTurnProjectionStore` 缓存 history 投影：只有 `historyRows` 改变时做 O(n) 重建；streaming/activity 更新只重做 live tail，不能每个 token 扫描整个长会话。

### 3.4 预计文件地图

```text
Packages/ProviderConversation/Sources/ProviderConversation/ResponseVerbosity.swift
Packages/ProviderConversation/Tests/ProviderConversationTests/ResponseVerbosityTests.swift

Packages/ProviderMessageRendering/Sources/ProviderMessageRendering/MessageTurnPresentationContext.swift
Packages/ProviderMessageRendering/Sources/ProviderMessageRendering/ZCodeMessageAppearance.swift
Packages/ProviderMessageRendering/Tests/ProviderMessageRenderingTests/MessageTurnPresentationContextTests.swift
Packages/ProviderMessageRendering/Tests/ProviderMessageRenderingTests/ZCodeMessageAppearanceTests.swift

Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/PluginMessageListZCodePlugin.swift
Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/MessageListZCodeUITestingSupport.swift
Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Models/ZCodeTurn.swift
Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/ZCodeTurnProjector.swift
Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/ZCodeTurnProjectionStore.swift
Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/ZCodeScrollAnchor.swift
Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4/ListV4View.swift
Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4/ZCodeConversationLayout.swift
Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4/ZCodeTurnView.swift
Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4/ZCodeBackToBottomButton.swift

Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeUserMessageView.swift
Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeAssistantMessageView.swift
Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeReasoningView.swift
Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeToolWorkHistoryView.swift
Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeTimelineMarkerView.swift
Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Helpers/ZCodeMessageTimeLabel.swift

Packages/KitMarkdown/Views/MarkdownTheme.swift
Packages/KitMarkdown/Views/MarkdownBlockRenderer.swift
Packages/KitMarkdown/Tests/KitMarkdownTests/ZCodeMarkdownThemeTests.swift

Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift
Packages/FactoryLumi/Tests/FactoryLumiTests/MessageListSlotArbitrationTests.swift
LumiUITests/LumiMessageListZCodeUITests.swift
LumiUITests/LumiMessageListZCodeScrollUITests.swift
```

---

## 4. 逐任务实施步骤

### Task 0: 固定基线并跑现有回归

**Files:** 不修改文件。

1. 运行 `git status --short`。若并非干净工作树，转到基于同一 Lumi HEAD 的独立干净 worktree/branch；后续每个 commit 只 stage 本任务文件，绝不夹带原工作树改动。
2. 固定 ZCode commit/version，运行第 1.3 节对照测试。
3. 运行现有测试，区分真实失败与既有环境失败：

```bash
swift test --package-path Packages/ProviderConversation
swift test --package-path Packages/ProviderMessageRendering
swift test --package-path Packages/PluginMessageListDetailed
swift test --package-path Packages/PluginMessageRenderer
swift test --package-path Packages/KitMarkdown
swift test --package-path Packages/FactoryLumi --filter MessageListSlotArbitrationTests
```

4. 若基线失败，记录测试名、错误和是否在本任务改动前已存在；不得通过修改 V4 测试掩盖旧失败。

### Task 1: 新增持久化枚举 `.zcode`

**Files:**
- Modify: `Packages/ProviderConversation/Sources/ProviderConversation/ResponseVerbosity.swift`
- Create: `Packages/ProviderConversation/Tests/ProviderConversationTests/ResponseVerbosityTests.swift`

**Step 1: 写失败测试**

覆盖：

```swift
#expect(ResponseVerbosity.zcode.rawValue == "v4")
#expect(ResponseVerbosity(rawValue: "v4") == .zcode)
#expect(ResponseVerbosity(rawValue: "zcode") == .zcode)
#expect(ResponseVerbosity.defaultVerbosity == .standard)
#expect(ResponseVerbosity.allCases.map(\.rawValue) == ["v1", "v2", "v3", "v4"])
#expect(ResponseVerbosity.zcode.displayName == "ZCode")
```

再用 JSONEncoder/Decoder 往返所有 case，防止 `init(rawValue:)` 漏分支但编译仍通过。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/ProviderConversation --filter ResponseVerbosityTests
```

预期：`.zcode` 不存在而编译失败。

**Step 3: 最小实现**

- 在 `detailed` 后加 `case zcode`。
- rawValue `"v4"`；init 接受 `"v4", "zcode"`；displayName `"ZCode"`。
- icon 使用系统 SF Symbol，例如 `"bubble.left.and.bubble.right"`。
- description 写 `"ZCode 风格消息呈现"`，不得写成“回复更详细/更长”。
- 默认仍 `.standard`。
- 全仓搜索 `switch verbosity`、`ResponseVerbosity` 和 `.description` 用途，确保新 case 不进入提示词或回复长度策略。

**Step 4: 确认通过**

重复上述命令，并运行完整 `swift test --package-path Packages/ProviderConversation`。

**Step 5: 提交**

```bash
git add Packages/ProviderConversation/Sources/ProviderConversation/ResponseVerbosity.swift Packages/ProviderConversation/Tests/ProviderConversationTests/ResponseVerbosityTests.swift
git commit -m "feat: add ZCode message list verbosity"
```

### Task 2: 新增 turn Environment 与双主题 token

**Files:**
- Create: `Packages/ProviderMessageRendering/Sources/ProviderMessageRendering/MessageTurnPresentationContext.swift`
- Create: `Packages/ProviderMessageRendering/Sources/ProviderMessageRendering/ZCodeMessageAppearance.swift`
- Create: `Packages/ProviderMessageRendering/Tests/ProviderMessageRenderingTests/MessageTurnPresentationContextTests.swift`
- Create: `Packages/ProviderMessageRendering/Tests/ProviderMessageRenderingTests/ZCodeMessageAppearanceTests.swift`

**Step 1: 写失败测试**

- context 默认 nil、hover 默认 false。
- 环境能无损传递 turnKey、agentTurnID、isTailAssistantText、isRunning、copyText、completedAt。
- 对 light/dark 的 sRGB 分量逐项断言第 2.8 节颜色，alpha 精度 `0.001`。
- subtle/subtlest 必须分别从 foreground 派生，不另写不一致的灰色。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/ProviderMessageRendering --filter MessageTurnPresentationContextTests
swift test --package-path Packages/ProviderMessageRendering --filter ZCodeMessageAppearanceTests
```

**Step 3: 最小实现**

实现第 3.2 节 struct 和 `EnvironmentValues`：

```swift
public extension EnvironmentValues {
    var messageTurnPresentation: MessageTurnPresentationContext? { get set }
    var messageTurnIsHovered: Bool { get set }
}
```

`ZCodeMessageAppearance` 提供 background/border/hover/selected/panel/card/popover/surface/foreground/subtle/subtlest/destructive/warning/inlineCode/iconBlue，并处理 macOS/iOS 颜色转换；不改变现有 LumiTheme。

**Step 4: 确认通过**

```bash
swift test --package-path Packages/ProviderMessageRendering
```

**Step 5: 提交**

```bash
git add Packages/ProviderMessageRendering
git commit -m "feat: add turn presentation context"
```

### Task 3: 实现稳定 turn 投影与增量 tail

**Files:**
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Models/ZCodeTurn.swift`
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/ZCodeTurnProjector.swift`
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/ZCodeTurnProjectionStore.swift`
- Create: `Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/ZCodeTurnProjectorTests.swift`
- Create: `Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/ZCodeTurnProjectionStoreTests.swift`

**Step 1: 写失败测试**

至少覆盖：

1. nil-turn user + assistant + 下一 user 形成两个 turn。
2. 同 turnID 的多段 assistant/tool/status 不拆开；不同非 nil turnID 不混桶。
3. 旧数据全 nil 时顺序稳定。
4. 同一输入重复投影，turn/row id 完全相等；不生成随机 UUID。
5. prepend 后已有 turn/row 身份保持。
6. 整轮 copy 只含助手正文，以 `\n\n` 连接，排除工具输出与 tool-only 行。
7. 只有轮尾正文获得 `isTailAssistantText`；中间正文不显示操作栏。
8. streaming 与 activity 互斥；tail 更新不改变历史 turn 数量或身份。
9. 100 次 streaming 更新只执行一次 history O(n) 重建，tail 只增量更新。
10. 空正文/空数组、status-only、tool-only、assistant-only 均不崩溃。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/PluginMessageListDetailed --filter ZCodeTurnProjectorTests
swift test --package-path Packages/PluginMessageListDetailed --filter ZCodeTurnProjectionStoreTests
```

**Step 3: 最小实现**

严格实现第 3.3 节；不修改 `MessageListRowBuilder` 的相邻工具合并规则，不把跨正文的工具重新合桶。投影只做 UI 值，不写回 Message/SwiftData。

**Step 4: 确认通过**

运行上述测试及既有：

```bash
swift test --package-path Packages/PluginMessageListDetailed --filter ListV3ViewModelTests
swift test --package-path Packages/PluginMessageListDetailed --filter MessageListSyntheticRowOrderingTests
```

**Step 5: 提交**

```bash
git add Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Models/ZCodeTurn.swift Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/ZCodeTurnProjector.swift Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/ZCodeTurnProjectionStore.swift Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/ZCodeTurnProjectorTests.swift Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/ZCodeTurnProjectionStoreTests.swift
git commit -m "feat: project messages into ZCode turns"
```

### Task 4: 实现 V4 独立滚动 reducer

**Files:**
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/ZCodeScrollAnchor.swift`
- Create: `Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/ZCodeScrollAnchorTests.swift`

**Step 1: 写失败测试**

```swift
enum ZCodeScrollEventSource { case user, programmatic, layout }

struct ZCodeScrollMetrics: Equatable {
    var offsetY: CGFloat
    var visibleHeight: CGFloat
    var documentHeight: CGFloat
}

struct ZCodeScrollAnchor: Equatable {
    static let bottomTolerance: CGFloat = 48
    var following = true
}
```

覆盖：距离 48/48.01、不足一屏、user 离底/回底、programmatic/layout 不改 following、following 内容增长 stick、detached 内容增长 hold、回底按钮恢复、resize/终态折叠不抢滚动、非有限几何不崩溃。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/PluginMessageListDetailed --filter ZCodeScrollAnchorTests
```

**Step 3: 最小实现**

核心语义必须是：

```swift
mutating func handleScroll(metrics: ZCodeScrollMetrics, source: ZCodeScrollEventSource) {
    guard source == .user, metrics.areFiniteAndUsable else { return }
    following = distanceToBottom(metrics) <= Self.bottomTolerance
}

func contentChangeAction() -> ZCodeAnchorAction {
    following ? .stickToBottom : .hold
}
```

不修改 `BottomEdgeEvaluator` 的 24/96，也不把 `AtBottomBox` 改成 ObservableObject。

**Step 4: 确认通过**

运行新测试和 `BottomEdgeEvaluatorTests`、`BottomStickyPinTests`。

**Step 5: 提交**

```bash
git add Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/ZCodeScrollAnchor.swift Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/ZCodeScrollAnchorTests.swift
git commit -m "feat: add ZCode scroll ownership reducer"
```

### Task 5: 新增 ListV4View 与响应式 turn 外壳

**Files:**
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4/ZCodeConversationLayout.swift`
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4/ZCodeTurnView.swift`
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4/ListV4View.swift`
- Create: `Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/ZCodeConversationLayoutTests.swift`

**Step 1: 写失败测试**

宽度断言：390→390、863→863、864→768、900→804、1279→896、1280→896、1440→1056、1600→1152；padding 447→16、448→24；用户气泡阈值 623/624；turn padding 56/0/20、一级间距 20、工作项间距 16。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/PluginMessageListDetailed --filter ZCodeConversationLayoutTests
```

**Step 3: 最小实现**

```swift
static func contentWidth(for container: CGFloat) -> CGFloat {
    switch container {
    case ..<864: return container
    case ..<1280: return min(container - 96, 896)
    default: return min(container - 384, 1152)
    }
}
```

`ListV4View` 必须镜像 `Views/V3/ListV3View.swift` 的可靠底座：

- 使用 SwiftUI `List`，禁止改成 `ScrollView + LazyVStack` 或 eager `VStack`。
- `MessageListRuntime` 与 `InitialPositionGate` 必须 `@StateObject`。
- 复用 `ListV3ViewModel` 的 activate、分页、pinToAnchor、history/streaming/activity、latestUserMessageID、isLoading。
- 保留 `.environment(\.preferOuterScroll, true)`、首屏 gate、底部锚点、cancelPendingTasks。
- 每行是 `ZCodeTurnView`，内部按 turn.rows 调 `MessageRowView` 并传 turn context。
- 去掉 List separator、默认背景与默认 row insets，避免双重 padding。
- 外层 GeometryReader 只读聊天容器宽度，不读取底部锚点 preference。
- hover 状态属于每个 turn；通过 Environment 传给轮尾正文。

**Step 4: 确认通过**

运行布局测试及 `InitialPositionGateTests`、`MessageListStateLifetimeTests`、`StuckLoadingMaskTests`。

**Step 5: 提交**

```bash
git add Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4 Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/ZCodeConversationLayoutTests.swift
git commit -m "feat: add ZCode turn timeline shell"
```

### Task 6: 装配独立 V4 插件并验证互斥槽位

**Files:**
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/PluginMessageListZCodePlugin.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`
- Modify: `Packages/FactoryLumi/Package.swift`（仅测试 target 增加已有 `PluginMessageListDetailed` product，不调整其他依赖）
- Modify: `Packages/FactoryLumi/Tests/FactoryLumiTests/MessageListSlotArbitrationTests.swift`

**Step 1: 写失败测试**

用真实 SwiftData store + 真实 Empty/V2/V3/V4 插件，分别设置 `.brief/.standard/.detailed/.zcode`，断言：

- active message-list item 集合始终最多一个；非空会话选择正确版本，空会话 Empty 获胜。
- 不只断言排序 winner，还要断言 active IDs，防止两个插件同时 active。
- harness 强持有所有插件，避免 weak closure 假通过。
- shutdown 后 observer 全部 cancel、ChatSection item 移除。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/FactoryLumi --filter MessageListSlotArbitrationTests
```

预期：V4 插件类型不存在或 `.zcode` 无 active item。

**Step 3: 最小实现**

- 镜像 `PluginMessageListDetailedPlugin` 的 provider 解析、services、observer 生命周期。
- 新 ID：`com.coffic.lumi.plugin.message-list.zcode`。
- metadata name `消息列表（ZCode）`、description `V4 ZCode 风格消息列表`、policy `.alwaysOn`。
- `VerbosityObservationBox(expectedVerbosity: .zcode)`，order 82、exclusiveGroup `message-list`。
- 创建自己的 `ListV3ViewModel`，不共享 V3 的可变实例；生产 `streamingDisplayEnabled` 保持默认 false。
- `FactoryLumi` 在 `PluginMessageListDetailedPlugin()` 后追加 `PluginMessageListZCodePlugin()`。
- 若宿主使用 `SelectedPluginFactory` 白名单，同时加入 V4 ID；`.alwaysOn` 不替代白名单。
- shutdown 完整镜像 V3，绝不漏 observer。

**Step 4: 确认通过**

运行 arbitration 与 Factory 编译测试；再运行 V1–V3 switch UI 测试，确认菜单新增第四项没有导致空白：

```bash
xcodebuild test -scheme Lumi -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListSwitchUITests \
  -only-testing:LumiUITests/LumiMessageListDetailedSwitchUITests
```

**Step 5: 提交**

```bash
git add Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/PluginMessageListZCodePlugin.swift Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift Packages/FactoryLumi/Package.swift Packages/FactoryLumi/Tests/FactoryLumiTests/MessageListSlotArbitrationTests.swift
git commit -m "feat: assemble ZCode message list plugin"
```

### Task 7: 复刻用户气泡、附件与长文折叠

**Files:**
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeUserMessageView.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/UserMessageView.swift`
- Create: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeUserMessageViewTests.swift`

**Step 1: 写失败测试**

- 四角 radii `(12, 2, 12, 12)`、padding、14/24、宽度阈值、右对齐。
- 空白正文 + 附件不生成气泡；附件仍显示。
- collapse 纯函数：`shouldCollapse(contentHeight: 120) == false`、121 false、122 true。
- row/content 改变重置为收起；reduceMotion 无动画。
- copy 使用原始 content，1200ms 状态恢复用注入 clock/scheduler 测试，不 sleep 1.2 秒。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/PluginMessageRenderer --filter ZCodeUserMessageViewTests
```

**Step 3: 最小实现**

- `.zcode` 显式路由到 `ZCodeUserMessageView`，V1–V3 继续旧 body。
- 复用 `cachedDecodedAttachments`、`MessageFileAttachmentChips`/可复用内部解析与 capability，不复制附件解码逻辑。
- 必要时把附件子视图拆成 internal 可复用组件，但默认参数保持旧外观。
- 长文测量只用于气泡内部裁剪，不参与列表底部 PreferenceKey。
- 支持 hover 与 keyboard focus；按钮 accessibility label 明确。

**Step 4: 确认通过**

运行新测试和完整 `swift test --package-path Packages/PluginMessageRenderer`。

**Step 5: 提交**

```bash
git add Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeUserMessageView.swift Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/UserMessageView.swift Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeUserMessageViewTests.swift
git commit -m "feat: match ZCode user message bubbles"
```

### Task 8: 复刻助手正文、轮尾复制与时间

**Files:**
- Modify: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/MessageRowView.swift`
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeAssistantMessageView.swift`
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Helpers/ZCodeMessageTimeLabel.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/AssistantMessageView.swift`
- Create: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeAssistantMessageViewTests.swift`
- Create: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeMessageTimeLabelTests.swift`

**Step 1: 写失败测试**

- `.zcode` 不被升格为 `.standard`，不进入旧 `MessageViewChrome` 的 detailed/header/actions 规则。
- 无头像/名称/气泡；正文 metrics 为 14、tracking 0.35、目标行高 24.5、strong 500。
- context 为 nil 时 V1–V3 完全旧行为。
- 仅 `isTailAssistantText && !isRunning && messageTurnIsHovered` 显示操作栏。
- copyText 为空不显示复制；复制内容恰好等于投影 copyText。
- 固定 locale/timezone/now 覆盖今天、昨天、今年、跨年、无效时间。
- streaming 无 cursor/淡入。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/PluginMessageRenderer --filter ZCodeAssistantMessageViewTests
swift test --package-path Packages/PluginMessageRenderer --filter ZCodeMessageTimeLabelTests
```

**Step 3: 最小实现**

- `MessageRowView` 增加默认 nil context 并应用 Environment，保持现有 init 调用源兼容。
- `AssistantMessageView` 在 `.zcode` 走专用视图；普通助手与 tool-step-group 都必须最终进入一致 V4 呈现，不遗漏 `turn-activity`。
- 不显示旧 header、info popover、模型名或每行操作。
- 复用真实复制能力；不新增 fake retry/like/fork。
- 时间格式严格按第 2.3 节，不实现与可见行为无关的缓存系统。

**Step 4: 确认通过**

运行新测试、PluginMessageRenderer 全包测试和 Detailed 全包测试，检查签名默认参数未破坏调用方。

**Step 5: 提交**

```bash
git add Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/MessageRowView.swift Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeAssistantMessageView.swift Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/AssistantMessageView.swift Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Helpers/ZCodeMessageTimeLabel.swift Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeAssistantMessageViewTests.swift Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeMessageTimeLabelTests.swift
git commit -m "feat: match ZCode assistant presentation"
```

### Task 9: 主题化 Markdown，保持 V1–V3 默认值不变

**Files:**
- Modify: `Packages/KitMarkdown/Views/MarkdownTheme.swift`
- Modify: `Packages/KitMarkdown/Views/MarkdownBlockRenderer.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Helpers/ChatMarkdownTheme.swift`
- Create: `Packages/KitMarkdown/Tests/KitMarkdownTests/ZCodeMarkdownThemeTests.swift`
- Create: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeChatMarkdownThemeTests.swift`

**Step 1: 写失败测试**

- `ChatMarkdownTheme.make(..., verbosity: .zcode)` 输出第 2.4 节全部字号/字重/间距。
- 正文 lineSpacing 由 NSFont 实际 lineHeight 换算，不直接等于 24.5。
- 首标题无顶部 24，后续标题有。
- 列表、引用、链接、inline code 样式符合合同。
- 旧 `ChatMarkdownTheme.make(from:)` 与 `MarkdownTheme.standard` 的每个旧字段逐值相等。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/KitMarkdown --filter ZCodeMarkdownThemeTests
swift test --package-path Packages/PluginMessageRenderer --filter ZCodeChatMarkdownThemeTests
```

**Step 3: 最小实现**

- `MarkdownTheme` 新参数全部放在 init 尾部并提供旧默认值；不为 V4 直接改旧硬编码。
- 将 `MarkdownBlockRenderer` 中现有 lineSpacing、heading margin、列表 padding、引用、链接、inline-code 的硬编码改为读取 theme。
- `ChatMarkdownTheme.make(from:)` 保留旧签名并转发 `verbosity: .standard` 语义；新增可选 verbosity 参数或独立 `makeZCode`，调用方只能选择其一，避免歧义。
- 普通段落没有源码证据的 margin 不新增统一数值。

**Step 4: 确认通过**

运行新测试及 KitMarkdown 全包、PluginMessageRenderer 全包；特别跑 `MarkdownChatListLayoutTests`、`MarkdownQuoteLayoutTests`、`MarkdownInlineParserTests`。

**Step 5: 提交**

```bash
git add Packages/KitMarkdown/Views/MarkdownTheme.swift Packages/KitMarkdown/Views/MarkdownBlockRenderer.swift Packages/KitMarkdown/Tests/KitMarkdownTests/ZCodeMarkdownThemeTests.swift Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Helpers/ChatMarkdownTheme.swift Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeChatMarkdownThemeTests.swift
git commit -m "feat: add ZCode Markdown typography"
```

### Task 10: 复刻代码块、表格和图片几何

**Files:**
- Modify: `Packages/KitMarkdown/Views/MarkdownTheme.swift`
- Modify: `Packages/KitMarkdown/Views/MarkdownBlockRenderer.swift`
- Modify: `Packages/KitMarkdown/Views/CodeBlockCopyButton.swift`
- Modify: `Packages/KitMarkdown/Views/HighlightedCodeView.swift`
- Modify: `Packages/KitMarkdown/Views/MarkdownInlineParser.swift`（仅图片/inline 呈现确有需要时）
- Modify: `Packages/KitMarkdown/Views/MarkdownEnvironment.swift`（仅需要传递 V4 测高/滚动环境时）
- Create: `Packages/KitMarkdown/Tests/KitMarkdownTests/ZCodeCodeBlockLayoutTests.swift`
- Create: `Packages/KitMarkdown/Tests/KitMarkdownTests/ZCodeTableMediaLayoutTests.swift`

**Step 1: 写失败测试**

- 代码块外壳/header/content 全部数值、默认语言 text、12 mono、无行号、默认不 wrap、复制 2000ms。
- streaming 不高亮，complete 才请求高亮/Mermaid。
- 长代码行只让代码块内部横滚，不改变消息列宽。
- 表格单元格 padding/min/max、header 字重、内部横滚。
- 图片 50% 容器宽、maxHeight 360、圆角 12、失败占位。
- 默认旧主题快照不变。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/KitMarkdown --filter ZCodeCodeBlockLayoutTests
swift test --package-path Packages/KitMarkdown --filter ZCodeTableMediaLayoutTests
```

**Step 3: 最小实现**

把代码块和表格差异纳入 theme，不全局替换旧值。保留现有异步高亮、缓存和横向滚动性能策略；不增加固定代码块最大高度。

**Step 4: 确认通过**

运行新测试及 `CodeBlockLayoutTests`、`CodeBlockCopyButtonTests`、`CodeHighlightRenderingTests`、`MarkdownAsyncLayoutTests`、`HorizontalFittingSizeCacheTests`。

**Step 5: 提交**

```bash
git add Packages/KitMarkdown
git commit -m "feat: match ZCode rich Markdown blocks"
```

### Task 11: 复刻 reasoning 与工作工具历史

**Files:**
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeReasoningView.swift`
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeToolWorkHistoryView.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/AssistantMessageView.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ToolStepGroupMessageView.swift`
- Create: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeReasoningViewTests.swift`
- Create: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeToolWorkHistoryViewTests.swift`

**Step 1: 写失败测试**

- 空 streaming reasoning 不渲染；streaming/complete 默认收起。
- 用户显式选择优先于完成自动 collapse；turn 折叠和 reasoning 折叠状态键不同。
- 最后非空行摘要、240 maxHeight、2pt 离底规则。
- 两个以上连续 Explore/Execute 才父分组；单工具不套层；跨正文工具不合并。
- Enter/Space、accessibilityExpanded、focus、300ms 卸载。
- Execute 5 行输出、8pt 输出离底规则；Read/Edit/通用预览规则。
- 工具授权仍走 `ToolApprovalBridge`；pending/approved/rejected/result 补全状态不丢失。
- 无真实 duration 不显示时长。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/PluginMessageRenderer --filter ZCodeReasoningViewTests
swift test --package-path Packages/PluginMessageRenderer --filter ZCodeToolWorkHistoryViewTests
```

**Step 3: 最小实现**

- V4 使用专用外壳和折叠状态；工具行内容继续由真实 `ToolCallRowRenderer` 与 capability 提供。
- 分组只依据真实工具名称/类别的显式映射；映射不确定就独立展示，不按数组下标猜类型。
- 复用 `turnActivitySummaries` / `turnActivity(for:)` 的真实计数和时长；不重复查询每个 token。
- 默认收起不能影响底部固定授权卡的可操作性。

**Step 4: 确认通过**

运行新测试、PluginMessageRenderer 全包和 Detailed 的授权/工具身份测试：

```bash
swift test --package-path Packages/PluginMessageListDetailed --filter ListV3AuthorizationAfterSwitchTests
swift test --package-path Packages/PluginMessageListDetailed --filter MessageListSuspendedToolRowIdentityTests
```

**Step 5: 提交**

```bash
git add Packages/PluginMessageRenderer
git commit -m "feat: match ZCode reasoning and tool history"
```

### Task 12: 统一特殊事件、错误与系统标记

**Files:**
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ZCodeTimelineMarkerView.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/MessageRendererPlugin.swift`
- Modify: status/error/system/default 对应 renderer（只增加 `.zcode` 显式分支）
- Create: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ZCodeTimelineMarkerTests.swift`

**Step 1: 写失败测试**

逐一覆盖当前忽略 verbosity 的 renderer：

- `turn-completed`：不留下多余空气泡或大间距；按 turn 终态处理。
- `context-compaction`：紧凑 timeline marker，不是助手 Markdown 气泡。
- `agent-loop-retry`：显示真实重试状态；只有 capability 允许时显示真实 retry。
- `goal-task-continuation`：真实 goal 信息 marker，不伪造进度。
- `model-switched`：有真实模型字段才显示模型名。
- status/error/system/default：无头像、无旧 V3 chrome；错误可读但不冒充工具错误样式。
- preferredRendererID 与第三方 renderer 分发顺序不变。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/PluginMessageRenderer --filter ZCodeTimelineMarkerTests
```

**Step 3: 最小实现**

为五类特殊 renderer 增加 `.zcode` 分支并共用紧凑 marker 外壳；普通用户/助手不添加统一全行右键菜单。审批仍在 `.bottomFixed`，列表内不得再画一份。

**Step 4: 确认通过**

运行 PluginMessageRenderer 全包及 V1–V3 消息 switch UI 回归。

**Step 5: 提交**

```bash
git add Packages/PluginMessageRenderer
git commit -m "feat: align ZCode timeline events"
```

### Task 13: 接入 user/programmatic/layout 滚动来源

**Files:**
- Modify: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/ScrollViewBottomTracker.swift`
- Modify: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Services/MessageListScrollCoordinator.swift`
- Modify: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4/ListV4View.swift`
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/Views/V4/ZCodeBackToBottomButton.swift`
- Create: `Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/ZCodeScrollSourceClassifierTests.swift`

**Step 1: 写失败测试**

- wheel/touch 等效 scrollWheel、键盘滚动、scrollbar 拖动被分类为 user；输入框内光标键不算 timeline 滚动。
- `pinToBottom` / `scrollToBottom` 包裹范围为 programmatic。
- document frame 增长、Markdown 异步测高、终端折叠、live resize 为 layout。
- 事件优先级：显式 programmatic > 当前滚动视图上的真实用户输入 > layout。
- 用户输入监测只接受同 window、同 enclosingScrollView，不能误收 Rail 的滚动。
- stopObserving/dismantle 后 event monitor 与 document observer 都移除。
- detached 时 streaming、append、resize、complete collapse 均 hold；回到底部 48 内恢复；按钮点击恢复并钉底。
- V3 默认 initializer 与 24/96 行为不变。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/PluginMessageListDetailed --filter ZCodeScrollSourceClassifierTests
```

**Step 3: 最小实现**

- 为 tracker 增加默认 `.legacy` 的模式和 V4 source callback；旧调用方无需修改。
- 分类器是纯逻辑 + AppKit 适配层。不要把所有 boundsDidChange 都当 user。
- 用户事件 monitor 必须按 window/scrollView 过滤，并在 `stopObserving()` 释放。
- 程序化写 clip bounds 使用显式作用域 token，不靠任意毫秒猜测。
- 保持 `AtBottomBox` 非 ObservableObject；V4 following box 同样非 Observable。只有 following 真正翻转时更新用于按钮显隐的 `@State`，避免每帧 invalidation。
- 保留 document frame 观察和现有钉底修复，不重新引入 PreferenceKey 底部锚点。
- 新按钮只 overlay 在列表底部，不修改 composer。

**Step 4: 确认通过**

运行：

```bash
swift test --package-path Packages/PluginMessageListDetailed --filter ZCodeScrollAnchorTests
swift test --package-path Packages/PluginMessageListDetailed --filter ZCodeScrollSourceClassifierTests
swift test --package-path Packages/PluginMessageListDetailed --filter ScrollViewBottomControllerTests
swift test --package-path Packages/PluginMessageListDetailed --filter BottomStickyPinTests
swift test --package-path Packages/PluginMessageListDetailed --filter MessageListScrollCoordinatorTests
```

**Step 5: 提交**

```bash
git add Packages/PluginMessageListDetailed
git commit -m "feat: preserve ZCode timeline scroll ownership"
```

### Task 14: 新增隔离、确定性的 V4 UI 夹具

**Files:**
- Create: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/MessageListZCodeUITestingSupport.swift`
- Modify: `Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/PluginMessageListZCodePlugin.swift`
- Create: `Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/MessageListZCodeUITestingSupportTests.swift`
- Create: `LumiUITests/LumiMessageListZCodeUITests.swift`

**Step 1: 写失败测试**

- 仅 DEBUG 且参数 `--lumi-ui-testing-message-list-zcode` 才 seed。
- 未同时带 `--lumi-ui-testing` 时 UI 测试拒绝启动，防止残留真实 provider。
- 所有 fixture 会话 verbosity 为 `.zcode`。
- seed 期间抑制自动回复，seed 结束恢复；不触发真实网络。
- V3 fixture 不同时 seed，不重复插入消息。
- 固定 IDs/createdAt/内容；重复启动隔离存储结果一致。

**Step 2: 确认失败**

```bash
swift test --package-path Packages/PluginMessageListDetailed --filter MessageListZCodeUITestingSupportTests
```

**Step 3: 最小实现**

启动参数固定为：

```text
--lumi-ui-testing
--lumi-ui-testing-isolated-storage
--lumi-ui-testing-message-list-zcode
```

至少建立以下会话：

- `ZCode Visual Target`：短用户/助手、标题、列表、引用、链接、inline code、长代码、表格、图片。
- `ZCode Long User Target`：120/121/122 临界内容、展开/收起、附件-only。
- `ZCode Tool Target`：reasoning、连续 Explore/Execute、单工具、Read/Edit、失败工具、真实 pending approval 的安全测试替身。
- `ZCode Scroll Target`：至少 40 轮且含富文本，用于离底、prepend、resize。
- `ZCode Streaming Target`：由确定性 UITest provider 按脚本产生 reasoning/text/code delta，不使用真实供应商。

**Step 4: 确认通过**

运行 fixture 单测，再运行一个只检查 V4 首屏的 XCUITest：

```bash
xcodebuild test -scheme Lumi -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListZCodeUITests/testVisualFixtureOpensInV4
```

**Step 5: 提交**

```bash
git add Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/MessageListZCodeUITestingSupport.swift Packages/PluginMessageListDetailed/Sources/PluginMessageListDetailed/PluginMessageListZCodePlugin.swift Packages/PluginMessageListDetailed/Tests/PluginMessageListDetailedTests/MessageListZCodeUITestingSupportTests.swift LumiUITests/LumiMessageListZCodeUITests.swift
git commit -m "test: add isolated ZCode timeline fixtures"
```

### Task 15: 完整 XCUITest、截图矩阵与性能验收

**Files:**
- Modify: `LumiUITests/LumiMessageListZCodeUITests.swift`
- Create: `LumiUITests/LumiMessageListZCodeScrollUITests.swift`
- Create: `docs/plans/artifacts/zcode-message-list-v4/` 下的评审截图与简短索引（由真实测试生成，不伪造）

**Step 1: 先写会失败的 UI 用例**

功能：

- 四档切换 V1→V2→V3→V4→V1，无空白、无双列表。
- 用户气泡右对齐、复制、长文展开/收起、附件-only 无空气泡。
- 助手无气泡；hover 整个 turn 显示一次轮尾操作，中间正文无操作。
- Markdown、代码横滚、表格不撑宽、reasoning/tool 默认折叠、键盘展开。
- 无 fake like/edit/fork/retry 按钮。
- streaming 无 cursor，用户离底后不被 delta 拉回。
- pending approval 只出现 bottomFixed 一份。

滚动：

- 用户上滚 >48 后 detached；流式/测高/resize/终态折叠保持阅读位置。
- 用户回到 48 内恢复 following；按钮恢复并钉底。
- prepend 后原锚点不跳；40+ 轮长列表首屏 gate 能结束。
- V3 原 `LumiMessageListBottomScrollUITests` 行为不变。

**Step 2: 运行并确认新断言在实现前失败**

```bash
xcodebuild test -scheme Lumi -destination 'platform=macOS' \
  -only-testing:LumiUITests/LumiMessageListZCodeUITests \
  -only-testing:LumiUITests/LumiMessageListZCodeScrollUITests
```

**Step 3: 完成最小修正并生成截图**

逻辑宽度矩阵：390、600、700、900、1440；几何边界另测 447/448、623/624、863/864、1279/1280。

每个关键宽度覆盖：

- light/dark；中文/英文。
- complete/streaming/hover/keyboard focus/reduced-motion。
- 短消息、长用户、附件、全 Markdown、长代码、表格、图片、reasoning、工具组、错误、审批、长列表、滚动离底。

将 ZCode 同内容 fixture 与 Lumi 截图按相同逻辑宽度并排评审。记录每项几何断言、截图文件名、评审结果；不得用“看起来差不多”替代清单。PNG 只做人工对照，不做字节相等。

**Step 4: 性能与回归**

- 40+ 轮富文本、连续 streaming 5 秒以上：主线程无持续 100% CPU、无 AttributeGraph 活锁、无无限 loading mask。
- Instruments/样例采样确认 streaming tail 更新没有对全部 history 做 O(n) 投影。
- 运行相关 package 全测试和下列真实 UI 回归：

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
  -only-testing:LumiUITests/LumiMessageListZCodeScrollUITests
```

若 Xcode 出现既有 package identity conflict 或 invalid exclude 警告，单独记录为环境问题；不能把它描述为干净环境，也不能借此跳过实际成功路径验证。

**Step 5: 提交**

```bash
git add LumiUITests/LumiMessageListZCodeUITests.swift LumiUITests/LumiMessageListZCodeScrollUITests.swift docs/plans/artifacts/zcode-message-list-v4
git commit -m "test: verify ZCode timeline experience"
```

### Task 16: 最终审计与交付

**Files:** 只修审计发现的问题；每个独立根因单独提交。

1. 全仓搜索并审查：

```bash
git diff --check
git status --short
```

再搜索 `.zcode`、`"v4"`、`message-list.zcode`，确认 enum、插件、factory、renderer、fixture 和测试形成闭环。
2. 确认 `ConversationModel.verbosityRaw` 仍是字符串，无数据库迁移。
3. 确认 `ResponseVerbosity.defaultVerbosity == .standard`，V1–V3 默认主题与滚动阈值未改。
4. 确认没有 `LazyVStack` 替换 List、没有随机 turn UUID、没有每 token 全量历史投影、没有 fake 控件或真实 provider 调用。
5. 确认每个关键 package 单独测试成功；不能仅引用 `run-all-package-tests.sh` 的退出 0。
6. PR 说明必须列出：固定 ZCode commit、真实 App 测试矩阵、截图差异、未实现的 ZCode 能力及原因、任何既有测试/环境失败。

---

## 5. 完成定义（Definition of Done）

只有全部满足才可交付：

- [ ] 设置中出现 ZCode V4，持久化 `"v4"` 重启后仍正确，默认 V2 不变。
- [ ] 任一非空会话只激活一个 message-list 插件；V1–V4 往返无空白。
- [ ] 用户气泡、助手无气泡、turn 间距、响应式列宽、Markdown、代码、表格、图片符合第 2 节。
- [ ] 操作栏按 turn 而非按 message 出现，复制文本和时间真实。
- [ ] reasoning/tool 分组、折叠、授权、错误与特殊事件不丢失真实数据。
- [ ] 48px following 语义通过纯测试与真实 UI；离底后任何异步变化都不抢滚动。
- [ ] 长富文本列表无活锁，首屏遮罩可结束，prepend 不跳，streaming 不做全历史 O(n) 重建。
- [ ] V1–V3 package/UI 回归通过，第三方 renderer 签名和分发不变。
- [ ] 所有 UI 测试使用确定性供应商和隔离存储，无真实凭据/付费请求。
- [ ] 双主题、多宽度、中英文截图已人工对照；平台字体差异已记录，几何/颜色无未解释偏差。
- [ ] 未伪造 Lumi 不存在的 ZCode 能力；非目标和已知差异在 PR 中明确列出。
