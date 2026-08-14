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
| P8 | 中 | `MarkdownBlockRenderer.swift:50-57,429-435`、`HighlightedCodeView.swift:35-49` | `.task` 继承 View 的 MainActor,"异步解析"实际仍跑主线程(注释与事实不符) |
| P9 | 中 | `MessageStreamingStore.swift:56-70` | 每 token 全串 `content += piece` + 字典整体写回,O(n²)/回合;下游 `blocks(for:)` 再拷贝 |
| P10 | 中 | `MarkdownParser.swift:11-14` + `MarkdownTableNormalizer.swift:24` | 每次 parse 前全文表格归一化(逐行正则),无表格文档纯冗余 |
| P11 | 中 | `ShellKit/ShellExecutor.swift:262`、`GitSection.swift:26-48`、`GitHubCLIDetectService.swift:135-153`、`SubprocessTransport.swift:166-170` | 四处 semaphore.wait "同步壳包异步" 模式,落在 UI 路径即冻结 |
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

### 阶段 1:高收益、低风险(建议先做)

**P1 — fittingSize 缓存失效**
`MarkdownBlockRenderer.swift` 的 `HorizontalScrollView.updateNSView`:比较新旧 content(及宽度分桶),内容未变时保留 `cachedSize`,不清缓存、不重设 rootView。这一个改动直接消除流式后期长代码块的每帧全内容测量。

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
