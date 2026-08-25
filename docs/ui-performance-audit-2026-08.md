# UI 卡顿排查与流畅度优化报告(2026-08)

> 范围:`LumiApp/`、`Packages/`、`Plugins/`(排除 build 产物)。
> 方法:静态扫描三类风险——主线程阻塞 IO/子进程、SwiftUI 重渲染、聊天 Markdown 渲染链路。
> 结论先行:历史消息滚动路径已经过一轮系统性治理(List 复用、三级缓存、流式增量解析、16ms 帧门禁),整体健康;剩余风险集中在 **流式输出后期掉帧**、**启动主线程同步 IO**、以及 **kernel 高频 objectWillChange 整页重渲染** 三块。

---

## 一、问题总览(按优先级)

| 编号 | 严重度 | 位置 | 问题 |
|---|---|---|---|
| P1 | 高 | `MarkdownBlockRenderer.swift:531-538` | 流式期间 `HorizontalScrollView.updateNSView` 每帧清空 fittingSize 缓存,每 16ms 重跑全内容 `NSHostingView.fittingSize` |
| P2 | 高 | `KernelLumi+Registration.swift:34,57,62,99,109` + `ListView.swift:23` | MessageSending 等高频服务把 objectWillChange 转发到 kernel,`@ObservedObject kernel` 的视图整页重渲染 |
| P3 | 高 | `ProjectsPlugin/Sources/Hooks/OnReady.swift:20-66` | 启动阶段 @MainActor 上做迁移、示例项目整目录复制、同步 JSON 读取 |
| P4 | 高 | `ConversationService.swift:43-73` | @MainActor init 同步读+解码整个会话列表,会话多时启动卡顿 |
| P5 | 高 | `XcodeBuildServerLocator.swift:28-56` | 主线程同步 spawn 子进程 + `waitUntilExit`(经 `XcodeProjectStatusBarViewModel.refreshCapabilityLevel` 调用) |
| P6 | 中 | `MessageManager.swift:247` → `ConversationManager.swift:367-371` → `ListView.swift:62-66` | 每条消息 insert 触发会话列表全量分页 reload,工具密集回合形成查询风暴 |
| P7 | 中 | `MarkdownBlockRenderer.swift:270-303` | streamingSlot 每帧多次 O(n) 全串操作(hasPrefix/count/prefix/dropFirst),边界推进时全前缀重解析 |
| P8 | 中 | `MarkdownBlockRenderer.swift:50-57,429-435`、`HighlightedCodeView.swift:35-49` | `.task` 继承 View 的 MainActor,"异步解析"实际仍跑主线程(注释与事实不符)——**✅ 已修复(2026-08-15)** |
| P9 | 中 | `MessageStreamingStore.swift:56-70` | 每 token 全串 `content += piece` + 字典整体写回,O(n²)/回合;下游 `blocks(for:)` 再拷贝 |
| P10 | 中 | `MarkdownParser.swift:11-14` + `MarkdownTableNormalizer.swift:24` | 每次 parse 前全文表格归一化(逐行正则),无表格文档纯冗余 |
| P11 | 中 | `KitShell/ShellExecutor.swift:262`、`GitSection.swift:26-48`、`GitHubCLIDetectService.swift:135-153`、`SubprocessTransport.swift:166-170` | 四处 semaphore.wait "同步壳包异步" 模式,落在 UI 路径即冻结 |
| P12 | 中 | `XcodeBuildServerStore.swift:62-255` | 主 Actor 状态栏 VM 高频同步读 JSON(manifest 读写) |
| P13 | 低 | `AgentTurnView.swift:53-62`、`ScrollViewBottomTracker.swift:148-157` | item 每变更新建 Task;滚动每事件分配一个 Task |
| P14 | 低 | `TokenLineChartView.swift:270-283`、`ProviderSettingsPageBase.swift:78`、`AssistantMessageView.swift:53,94` 等 | 每次渲染新建 DateFormatter / body 内 filter+map / theme 重建 |
| P15 | 功能 | `MarkdownEnvironment.swift:10-38` | `CodeHighlightProviding` 全仓无实现注入,聊天代码块恒为纯文本降级(高亮体系是死代码;一旦启用还需注意缓存键含全文导致流式缓存抖动) |

---

## 二、已确认做对的关键点(勿回退)

1. **列表容器**:`ListV3View` / `ListV2View` 用 `List`(NSTableView cell 复用)替代 LazyVStack,规避富文本长列表 AttributeGraph 活锁。
2. **流式行隔离**:流式临时行用进程级常量 `LumiStreamingRowID` 单独渲染;VM 侧 16ms 帧门禁合并逐 token 广播;`MessageStreaming` 注册时 `forwardsObjectWillChange: false`。
3. **重建短路**:`HistoryBuildSignatureV3` 指纹签名跳过 O(rows×content) 数组比较。
4. **底部判定**:`ScrollViewBottomTracker` 用 `NSClipView.boundsDidChangeNotification` 替代 GeometryReader+PreferenceKey,`AtBottomBox` 刻意非 Observable,切断布局反馈环,含迟滞防抖。
5. **Markdown 缓存**:块级有界 LRU(384)+ 流式稳定前缀增量解析 + 行内 AttributedString 缓存(2048)+ 代码高亮缓存(512)。
6. 全仓库 0 处 `DispatchQueue.main.sync`;多数 LocalStore 已用 actor/串行队列保护。

---

## 三、修复方案

> **📎 88 条消息滚动掉帧专项(2026-08-15)**
> 用户反馈 MessageList V2 在 88 条消息下来回滚动持续掉帧(非首滚一次性)。滚动基准 harness(`~/Code/Coffic/streaming-bench` scroll 模式:List + 88 条生产同构消息,程序化往返滚动,按趟统计)+ Time Profiler 归因结论:
> 1. 列表状态隔离良好(无 kernel 订阅、tracker 零失效、流式 16ms 门禁),空闲滚动本身不产生状态更新;
> 2. 持续性成本 = `List` 惰性重物化:**行滚出视口被拆除、滚回重建**,每次物化重跑整行 SwiftUI 视图树构建 + 文本排版(AttributeGraph 更新 + Typesetter 占主),热缓存无济于事(harness 实测第 2 趟与第 1 趟耗时相当);
> 3. 次级成本:P8 主线程解析(首滚)、代码块 fittingSize 无跨物化缓存(P1 修复只覆盖同一视图实例)。
>
> 本轮落地三项修复:① `HorizontalFittingSizeStore` 进程级共享测量缓存(按指纹×宽度桶,LRU 512,跨物化复用);② P8 后台解析(见上);③ `ListV2ViewModel` 后台批量预热。harness 5 次取中位数:
>
> | 指标(热滚趟) | 修复前 | 修复后 | 变化 |
> |---|---|---|---|
> | 每 tick 主线程耗时 | ~4.1ms | ~3.2ms | **-22%** |
> | p95 | ~20ms | ~14.5ms | **-27%** |
> | 超 16ms 预算 tick/趟 | ~40 | ~10 | **-75%** |
> | 最大尖刺 | 34~51ms | 25~37ms | 收窄 |
>
> 已验证无收益而放弃的假设:`.textSelection` 从每行提升到 List 级(SelectionOverlay/trackingArea churn 并非主因,5 次对比在噪声内)。
> **遗留决策点**:剩余成本为 SwiftUI `List` 惰性行物化的结构性开销(AG 视图图重建 + 文本排版,无法在纯 SwiftUI 内跨物化复用)。若真机体感仍不达标,建议启用并完善 `MessageListAppKitPlugin`(已具 `heightOfRow` + `AppKitMessageLayoutCache` + cell 复用骨架,当前 disabled/.dev)——需另行立项评估回归风险。

> **📎 滚动专项第二轮:SwiftUI 路径极限优化(2026-08-15)**
> 在不动 AppKit 插件的前提下,清除生产行 chrome 渲染路径上所有"每次 body 求值/每次重物化都重做"的工作:
> - **纯缓存化**:`NSFullUserName()` 目录服务查询、`Color(hex:)` 解析(AvatarView 预构建)、`LumiLocalization.string` 结果级记忆化(原每次调用做 bundle 路径探测,KitLocalization 内修复惠及全部插件)、`ErrorMessageView` 解析器双跑、`MessageViewChrome` token/thinking 双计算、`CollapsiblePlainText` 无守卫整串切分、`ToolCallRowView` 注册表二次查找 + AnyView 闭包、`AppIdentityRow` 逐条 trim。
> - **高影响修复**:① `ToolCallResolutionCache`——工具调用结果按消息 id 进程级缓存(仅全解析完成才缓存,进行中回合不钉死),行重物化不再逐个 await kernel;② `MessageAttachmentDecodeCache` + `AppImageDecodeCache`——用户消息附件 JSON/base64 解码与位图解码各缓存一次;③ `CopyMessageButton` 内容改惰性闭包(空消息的 metadata dump 不再进渲染路径)。
> - **行结构精简(产品已确认 UX 变化)**:操作按钮组(复制/重发/思考/详情/info)仅在行悬停 150ms 后物化,离开即隐藏;防抖刻意防"滚动时光标下行的 hover 风暴"。时间戳/token 文本常驻。
> - **按证据跳过**:状态行 `PulseRipple` 门控——数据模型中 status 行全部为瞬态(turn 结束即清除),不存在"终态 status 行",当前行为已等价于"仅进行中动画"意图。
> - **测量教训**:本轮 harness 复测揭示环境噪声在 ±40% 量级主导(同一二进制在不同时间窗测得 2.3~4.5ms/趟);跨时间窗对比无效,只接受同一时间窗内的交错 A/B。chrome 层收益无法用纯 KitMarkdown harness 量化,以真机体感验收为准。

### 阶段 1:高收益、低风险(建议先做)

**P1 — fittingSize 缓存失效**
`MarkdownBlockRenderer.swift` 的 `HorizontalScrollView.updateNSView`:比较新旧 content(及宽度分桶),内容未变时保留 `cachedSize`,不清缓存、不重设 rootView。这一个改动直接消除流式后期长代码块的每帧全内容测量。

> **✅ P1 已修复并验证(2026-08-15)**
> - 实现:测量缓存决策抽出为可单测的纯值类型 `HorizontalFittingSizeCache`(`Views/HorizontalFittingSizeCache.swift`),按(内容指纹 × 宽度 16pt 分桶)判定命中;`HorizontalScrollView` 泛型化 `Fingerprint`,`updateNSView` 指纹未变时直接跳过 rootView 重设与缓存清空;调用方 `HighlightedCodeView` 传入覆盖全部渲染输入的指纹。契约测试 `HorizontalFittingSizeCacheTests` 8 例全过(含 120 帧不变内容仅 1 次测量的 P1 回归用例)。
> - 基准验证:无头 harness(仓库外 `~/Code/Coffic/streaming-bench`,xctrace Time Profiler + tick 级计时),场景 = 400 行代码块内容恒定、每 16ms 一次无关重渲染(模拟 P2 整页重渲染放大效应),每版本 5 次取中位数:
>   | 指标(中位数) | 修复前 | 修复后 | 变化 |
>   |---|---|---|---|
>   | 每 tick 主线程耗时 | 2.40ms | 0.81ms | **-66%** |
>   | 8s 累计布局耗时 | 865ms | 447ms | **-48%** |
>   | 超 16ms 预算的 tick | 9 次 | 0 次 | 消除 |
>   | 最大尖刺 | 381ms | 41ms | 大幅收窄 |
> - 局限:harness 的纯流式逐 token 场景被全量重解析(P7 领域)主导且运行方差大,不适合作为 P1 的隔离信号;真实 App 端到端确认待 P2/P9 修复后统一验收。

**P2 — kernel 转发豁免**
对 `MessageSending`、`ConversationManaging`、`MessageManaging`、`ToolManaging`、`AgentTurnManaging` 的注册加 `forwardsObjectWillChange: false`(与 `MessageStreaming` 同法),消费方改为窄播观察具体服务;`ListView` 移除对整个 kernel 的 `@ObservedObject`。

**P3/P4 — 启动主线程 IO 下放**
- `ProjectsOnReadyHook.execute` 的迁移/示例安装/loadProjects 移入 `Task.detached`,完成后回 MainActor 赋值。
- `ConversationService.loadConversations` 改后台解码、主 Actor 仅接收结果。

**P5 — preflight 异步化**
`XcodeBuildServerLocator.runPreflight` 移出主线程(`waitUntilExit` 改 async 包装),`refreshCapabilityLevel` 改 async 调用;`exportDiagnostics` 的 forceRefresh 走后台。

### 阶段 2:流式链路优化

**P6 — markConversationActive 去抖**:1s 窗口合并广播,或 reload 只取首页增量。

**P7 — streamingSlot 字符串开销**:
- 维护 `(stableUTF8Offset, stableBlocks)` 增量状态,避免每帧 `hasPrefix`/`prefix`/`dropFirst` 全串拷贝(基于 UTF-8 视图切片)。
- 稳定边界识别扩展到代码块围栏 ``` 和表格行,大代码块流式时 tail 不再持续为整块。

**P8 — 解析真正下放后台**:`.task` 内用 `Task.detached`(或 `nonisolated` 函数 + `@Sendable` 数据)执行 `MarkdownParser.parse` 与 `AttributedString(markdown:)`,注意 MarkdownBlock 传回时的隔离标注;顺带修正"后台线程"的错误注释。

> **✅ P8 已修复并验证(2026-08-15,随 88 条消息滚动卡顿治理一并落地)**
> - `MarkdownBlockRenderer` 与 `CachedMarkdownInlineText` 的 `.task` 改为 `Task.detached` 后台解析,主线程只接收结果;`markdown`/`text` 变化时 SwiftUI 取消旧任务,await 返回后丢弃过期结果(防流式行旧内容回写)。
> - 注意事项:无窗口的 headless 宿主会取消 `.task`,"首帧同步可用"的契约改由缓存预热保证——新增 `MarkdownRenderCache.warm(markdown:)` 公开 API,`ListV2ViewModel` 在 `persistedMessages` 变化后以 utility 优先级后台批量预热(滚动到未物化行时同步命中,无两阶段高度跳变)。
> - 契约测试同步更新(4 个布局测试改为先预热)。

**P9 — append 合并**:在 `MessageStreamingStore` 内缓冲 piece,随帧门禁节奏统一拼接,或改用增量 buffer,消除逐 token O(n) 拷贝。

### 阶段 3:清理与低风险打磨

- **P10**:parse 前先快速探测含 `|` 或 `---` 行才做表格归一化。
- **P11**:四处 semaphore.wait 同步桥接改纯 async API。
- **P12**:manifest 读写移出主 Actor。
- **P13**:AgentTurnView update 防抖;ScrollViewBottomTracker 回调直接 `MainActor.assumeIsolated`。
- **P14**:DateFormatter 静态化;`filteredProviders.map(\.id)` 挪出 onChange;theme 缓存。
- **P15**(产品决策):实现并注入 `CodeHighlightProviding`(如 Highlightr),启用时缓存键改用内容哈希避免流式缓存抖动;或删除死代码路径。

### 编辑器侧(另见既有文档)

`docs/editor-performance-analysis.md` 与 `docs/editor-virtualization-design.md` 分别覆盖插件 teardown 缺失、undo 无上限、大文件虚拟化(LightweightLineIndex/LineObjectCache **尚未实施**)——属编辑器文本栈,与聊天渲染独立,实施状态均为"建议稿/设计中",可按原计划推进。

---

## 四、验证建议

1. Instruments:Time Profiler 抓"流式输出长代码块回复"场景,确认 P1/P7 修复前后主线程每帧耗时。
2. XCTest 基准:streamingSlot 对 50KB 文本逐 chunk 的累计 CPU。
3. 启动:Instruments App Launch 或 os_signpost 度量 ProjectsPlugin onReady、ConversationService init 的主线程占用。
4. 回归重点:修复 P2 后确认会话列表在回合中的 UI 仍能及时更新(需要新的窄播通路覆盖所有原 kernel 订阅方)。
