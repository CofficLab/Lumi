# TestPlan — PluginConversationTitle

## 包概述

PluginConversationTitle 的实现包，包含 6 个主要类型；当前测试覆盖 78 条用例。

平台: iOS 17+
测试文件: 10 个，用例总数: 78

核心组件（源码目录）:
- `Observers/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationTitlePlugin`
- `ConversationTitleHeaderObserver`
- `TitleService`
- `TitleUpdateTool`
- `ConversationTitleViewModel`
- `HeaderView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AutoTitleRule**（23 条）：由 `appliesWhenNoTitle`、`protectsCustomTitle`、`skipsWhenSameAsCurrent` 等用例锁定；改动该模块时优先跑对应测试文件。`normalizeTitle` 只剥离包裹整个标题的成对符号，标题内部正常的圆括号/方括号（如 `Fix array bounds (off-by-one)`）必须原样保留，不得逐字符 trimming 删掉末尾右括号（**回归 #798**）。
- **ConversationScopedTitleUpdate**（3 条）：由 `writesToCallingConversationInsteadOfSelection`、`doesNotLeakIntoOtherConversation`、`legacyPathStillUsesSelection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HeaderTitleObserver**（7 条）：由 `viewModelSkipsDuplicateTitle`、`viewModelStartsEmpty`、`syncsInitialTitle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（4 条）：由 `normalizeTitle`、`placeholderTitle`、`updateToolUpdatesTitle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TitleServiceBackfill**（8 条）：由 `backfillsUntitledConversation`、`skipsTitledConversation`、`skipsConversationWithoutUserMessage`、`skippedWindowDoesNotBlockValidConversation`、`backfillStopsAtWriteCap`、`backfillDoesNotOverwriteTitleSetDuringMessageRead`、`backfillStillWritesWhenNoTitleSetDuringRead` 等用例锁定；回填取全库无标题 ID 后按「补满 200 条或耗尽列表」推进，永久跳过的条目不得阻塞窗口之外的有效对话（**回归 #799**）。读取首条用户消息的 await 窗口内用户可能已改标题，写前必须再复核一次 `shouldApplyGeneratedTitle`，旧回填不得覆盖新写入的自定义标题（**回归 #466**）。改动该模块时优先跑对应测试文件。
- **PlaceholderTitleCollapsing**（4 条）：由 `shortTextMatchesReference`、`longTextMatchesReference`、`extremelyWhitespaceHeavyMatchesReference`、`resultLengthIsBounded` 锁定；占位标题先取有界前缀再折叠空白，语义必须与「全量折叠再截断」完全一致且结果长度有界（**#1287**）。改动该模块时优先跑对应测试文件。
- **TitleServiceFallback**（4 条）：由 `fallsBackWhenLLMThrows`、`fallsBackWhenLLMReturnsEmptyTitle`、`fallbackDoesNotOverwriteCustomTitle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TitleService**（11 条）：由 `generatesTitleForFirstUserMessage`、`composesPromptWithFence`、`ignoresNonFirstUserMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TitleUpdateTool**（10 条）：由 `updatesSelectedTitle`、`trimsWhitespace`、`reportsMissingProvider`、`executeResultThrowsOnPersistenceFailure`、`executeResultSuccessIsNotError` 等用例锁定；失败分支（服务不可用/未选中/写库失败）统一抛出 `ToolExecutionError`，带 context 的 `executeResult` 同样传播失败由宿主标记 `isError`，不得包成成功结果（**回归 #651**）。改动该模块时优先跑对应测试文件。
- **TitleUtilityRouting**（4 条）：由 `titleRoutesToUtilityModel`、`titleWithoutDeclarationUsesMainModel`、`titleUsageRecordedToLedger` 等用例锁定。声明轻量模型时标题路由到轻量模型、未声明时沿用主模型；用量按 `.title` 用途记入账本并带服务模型，供应商未报用量时记估算值且不为零（**#1158**）。改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AutoTitleRule | shouldApplyGeneratedTitle：无标题时放行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `appliesWhenNoTitle` |
| 2 | AutoTitleRule | shouldApplyGeneratedTitle：保护自定义标题 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `protectsCustomTitle` |
| 3 | AutoTitleRule | shouldApplyGeneratedTitle：生成结果与当前标题相同则跳过 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `skipsWhenSameAsCurrent` |
| 4 | AutoTitleRule | shouldApplyGeneratedTitle：占位标题可被替换 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `replacesPlaceholderTitle` |
| 5 | AutoTitleRule | shouldApplyGeneratedTitle：短消息的占位标题等于原文 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `shortMessagePlaceholderEqualsSource` |
| 6 | AutoTitleRule | shouldApplyGeneratedTitle：生成前预检查不比较生成值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `preflightCheckIgnoresGeneratedTitle` |
| 7 | AutoTitleRule | fencedUserMessage：转义闭合标签，阻断标签注入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fencesClosingTag` |
| 8 | AutoTitleRule | fencedUserMessage：普通消息原样包裹 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fencesPlainMessage` |
| 9 | AutoTitleRule | normalizeTitle：空串与纯空白返回空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeEmpty` |
| 10 | AutoTitleRule | normalizeTitle：跳过前置空行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeSkipsLeadingBlankLines` |
| 11 | AutoTitleRule | normalizeTitle：剥离成对引号与书名号 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeStripsWrappers` |
| 12 | AutoTitleRule | normalizeTitle：折叠内部空白 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeCollapsesWhitespace` |
| 13 | AutoTitleRule | normalizeTitle：40 字符边界不截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizeLengthBoundary` |
| 14 | AutoTitleRule | normalizeTitle：截断后清理尾部空白 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizeTrimsAfterTruncation` |
| 15 | AutoTitleRule | placeholderTitle：折叠换行与连续空白 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderCollapsesWhitespace` |
| 16 | AutoTitleRule | placeholderTitle：恰好 40 字符不追加省略号 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderLengthBoundary` |
| 17 | AutoTitleRule | placeholderTitle：纯空白折叠为空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderEmpty` |
| 18 | AutoTitleRule | placeholderTitle：去掉开头的 system-reminder 注入块 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderStripsLeadingInjectedReminder` |
| 19 | AutoTitleRule | placeholderTitle：保留消息中间的同名标签 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderKeepsInnerReminderTag` |
| 20 | ConversationScopedTitleUpdate | 标题写入工具调用所属会话而非当前选中会话 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `writesToCallingConversationInsteadOfSelection` |
| 21 | ConversationScopedTitleUpdate | 会话 B 的工具调用不会污染会话 A 的标题 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotLeakIntoOtherConversation` |
| 22 | ConversationScopedTitleUpdate | 无 context 的旧路径仍按当前选中会话更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyPathStillUsesSelection` |
| 23 | HeaderTitleObserver | ViewModel 相同标题重复写入短路 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `viewModelSkipsDuplicateTitle` |
| 24 | HeaderTitleObserver | ViewModel 初始标题为空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `viewModelStartsEmpty` |
| 25 | HeaderTitleObserver | Observer 初始化时同步当前标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `syncsInitialTitle` |
| 26 | HeaderTitleObserver | 全部会话事件都触发标题刷新 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `allEventsRefreshTitle` |
| 27 | HeaderTitleObserver | 取消选择后标题回落为空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `clearsTitleOnDeselection` |
| 28 | HeaderTitleObserver | cancel 后不再响应会话事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsAfterCancel` |
| 29 | HeaderTitleObserver | 重复 cancel 幂等 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelIsIdempotent` |
| 30 | 综合 | 标题生成：normalizeTitle 清理引号与换行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeTitle` |
| 31 | 综合 | 占位标题：长消息截断到 40 字符 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `placeholderTitle` |
| 32 | 综合 | 标题更新工具：更新选中会话标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateToolUpdatesTitle` |
| 33 | 综合 | 标题更新工具：缺参数抛错 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateToolMissingArgument` |
| 34 | TitleServiceBackfill | 回填为无标题对话补写占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `backfillsUntitledConversation` |
| 35 | TitleServiceBackfill | 回填跳过已有标题的对话 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `skipsTitledConversation` |
| 36 | TitleServiceBackfill | 回填跳过没有首条用户消息的对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsConversationWithoutUserMessage` |
| 37 | TitleServiceBackfill | 回填把过长的首条消息截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `truncatesLongFirstUserMessage` |
| 38 | TitleServiceFallback | 标题生成抛错时写入占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallsBackWhenLLMThrows` |
| 39 | TitleServiceFallback | 标题生成为空时写入占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallsBackWhenLLMReturnsEmptyTitle` |
| 40 | TitleServiceFallback | 兜底不覆盖用户自定义标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallbackDoesNotOverwriteCustomTitle` |
| 41 | TitleServiceFallback | 占位标题取自首条用户消息并截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `placeholderTitleComesFromFirstUserMessage` |
| 42 | TitleService | 首条用户消息生成标题并写库 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `generatesTitleForFirstUserMessage` |
| 43 | TitleService | 生成标题的请求包含 system 指令与包裹后的用户消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `composesPromptWithFence` |
| 44 | TitleService | 非首条用户消息不触发标题生成 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `ignoresNonFirstUserMessage` |
| 45 | TitleService | 非用户角色的消息被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresNonUserRole` |
| 46 | TitleService | 已有自定义标题时不覆盖 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `doesNotOverwriteCustomTitle` |
| 47 | TitleService | LLM 失败时写入占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `appliesFallbackTitleWhenLLMFails` |
| 48 | TitleService | LLM 返回空标题时写入占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `appliesFallbackTitleWhenLLMReturnsEmptyTitle` |
| 49 | TitleService | 写库失败时不抛出异常 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toleratesPersistenceFailure` |
| 50 | TitleService | 空内容用户消息被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresBlankMessage` |
| 51 | TitleService | stop 后不再响应消息插入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsObserving` |
| 52 | TitleService | 重复 stop 幂等 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stopIsIdempotent` |
| 53 | TitleUpdateTool | 更新选中会话标题返回成功文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updatesSelectedTitle` |
| 54 | TitleUpdateTool | 写入前裁剪标题首尾空白 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `trimsWhitespace` |
| 55 | TitleUpdateTool | Provider 缺失时抛出服务不可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsMissingProvider` |
| 56 | TitleUpdateTool | 未选中会话时抛出未找到 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsNoSelection` |
| 57 | TitleUpdateTool | 写库失败时抛出更新失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsPersistenceFailure` |
| 58 | TitleUpdateTool | 非法 title 参数抛 ToolExecutionError | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidArguments` |
| 59 | TitleUpdateTool | 工具描述与输入 schema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `metadata` |
| 60 | TitleUpdateTool | displayDescription 回退与正常展示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayDescription` |
| 61 | AutoTitleRule | normalizeTitle：保留标题内部的圆括号（回归 #798） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizePreservesInternalParenthetical` |
| 62 | AutoTitleRule | normalizeTitle：保留标题内部的方括号（回归 #798） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizePreservesInternalSquareBrackets` |
| 63 | AutoTitleRule | normalizeTitle：剥离包裹整个标题的成对括号 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeStripsPairedOuterBrackets` |
| 64 | AutoTitleRule | normalizeTitle：逐层剥离嵌套的成对包裹 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeStripsNestedPairedWrappers` |
| 65 | TitleUtilityRouting | 声明轻量模型时标题路由到轻量模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `titleRoutesToUtilityModel` |
| 66 | TitleUtilityRouting | 未声明轻量模型时标题沿用主模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `titleWithoutDeclarationUsesMainModel` |
| 67 | TitleUtilityRouting | 标题用量按用途记入账本并带服务模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `titleUsageRecordedToLedger` |
| 68 | TitleUtilityRouting | 供应商未报用量时标题用量记估算值且不为零 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `titleUsageEstimatedWhenUnreported` |
| 69 | PlaceholderTitleCollapsing | 短文本占位标题与全量折叠参照一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `shortTextMatchesReference` |
| 70 | PlaceholderTitleCollapsing | 长文本占位标题与全量折叠参照一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `longTextMatchesReference` |
| 71 | PlaceholderTitleCollapsing | 极长空白串占位标题仍与参照一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extremelyWhitespaceHeavyMatchesReference` |
| 72 | PlaceholderTitleCollapsing | 占位标题结果长度有界（#1287） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resultLengthIsBounded` |
| 73 | TitleServiceBackfill | 永久跳过的条目不得阻塞窗口之外的有效对话（#799） | 200 条无首条用户消息的无标题对话 + 窗口外 1 条有效对话 | 执行回填两轮 | 有效对话被补写占位标题，跳过条目不写空标题，第二轮不重复补写 | P0 | ✅ 已覆盖 | `skippedWindowDoesNotBlockValidConversation` |
| 74 | TitleServiceBackfill | 单轮回填遵守补写上限 | 201 条可回填的无标题对话 | 执行一轮回填 | 恰好补写 200 条，剩 1 条留到下次启动 | P1 | ✅ 已覆盖 | `backfillStopsAtWriteCap` |
| 75 | TitleUpdateTool | executeResult 写库失败时抛出而非返回成功结果（**回归 #651**） | 有效 context 会话，stub 写库失败 | 调用 `executeResult(context:arguments:)` | 抛出 `ToolExecutionError`，由宿主标记 isError；不得返回 isError == false 的成功结果 | P0 | ✅ 已覆盖 | `executeResultThrowsOnPersistenceFailure` |
| 76 | TitleUpdateTool | executeResult 成功时不带错误标记（**回归 #651**） | 有效 context 会话，写库成功 | 调用 `executeResult(context:arguments:)` | 结果 isError == false 且含成功文案，与失败路径形成对照 | P1 | ✅ 已覆盖 | `executeResultSuccessIsNotError` |
| 77 | TitleServiceBackfill | 回填读取首条消息期间用户改了标题，旧回填不得覆盖新标题（**回归 #466**） | 无标题对话，门闩让 firstUserMessage 读取挂起 | 读取窗口内 `updateConversationTitle` 写新标题后放行读取 | backfilled == 0，标题仍为用户新写入值，不消耗 LLM | P0 | ✅ 已覆盖 | `backfillDoesNotOverwriteTitleSetDuringMessageRead` |
| 78 | TitleServiceBackfill | 回填读取期间无人改标题时仍正常补写占位标题（**回归 #466** 护栏） | 无标题对话，门闩让读取挂起 | 读取窗口内不改标题，直接放行 | backfilled == 1，补写首条消息占位标题，二次复核不过宽 | P1 | ✅ 已覆盖 | `backfillStillWritesWhenNoTitleSetDuringRead` |

> 说明：全部 **78 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（#799）：把 `backfillUntitledConversations` 的查询改回 `untitledConversationIDs(limit: Self.backfillLimit)`（只取前 200 条窗口），`skippedWindowDoesNotBlockValidConversation` 立即变红（backfilled == 0，窗口外的有效对话永远轮不到）；恢复 `limit: Int.max` 全量取 ID 后重新变绿。`backfillStopsAtWriteCap` 锁定「补满 200 条即停」的有界语义。

> 变异验证（#651）：`TitleUpdateTool` 的失败分支已在 dev 上统一抛出 `ToolExecutionError`（6e948db89 / 4e700b68b），宿主 `DefaultToolManagerProviding` 捕获抛出的 `executeResult` 后置 `isError == true`，GUI/ACP 据此显示失败。本次补锁 issue 直接引用的 `executeResult(context:)` 失败路径：M1 把 `executeResult` 改为 `do/catch` 将失败包成 `ToolCallResult(content: 失败文案)`（isError 默认 false，还原 #651 原始缺陷）→ `executeResultThrowsOnPersistenceFailure` 转红（不再抛出），`executeResultSuccessIsNotError` 仍绿；还原后 76 条全绿。

> 变异验证（#466）：把 `backfillUntitledConversations` 写前的二次复核 `guard await shouldApplyGeneratedTitle(...)` 删除（还原读取后无条件写占位标题的旧缺陷）→ `backfillDoesNotOverwriteTitleSetDuringMessageRead` 转红（backfilled == 1、用户新标题被占位标题覆盖，2 处断言失败），护栏 `backfillStillWritesWhenNoTitleSetDuringRead` 与其余 6 条回填用例仍绿；恢复二次复核后 78 条全绿。门闩 `BackfillReadGate` 让 `firstUserMessage` 读取挂起，测试在窗口内写入新标题后再放行，确定性构造「旧读取晚到」。

## 覆盖率统计

- P0: 已覆盖 17 / 17
- P1: 已覆盖 23 / 23
- P2: 已覆盖 38 / 38
- **合计: 78 / 78**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（17 条）
- **P1**: 其余功能性用例（23 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（38 条）

## 跨平台说明

- Package 声明: iOS 17+
- 78 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationTitle
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
