# TestPlan — PluginLLMContext

## 包概述

PluginLLMContext 的实现包，包含 14 个主要类型；当前测试覆盖 123 条用例。

平台: macOS 14+, iOS 17+
测试文件: 15 个，用例总数: 123

核心组件（源码目录）:
- `AuxiliaryUsage/`
- `Compression/`
- `Hooks/`
- `Observers/`
- `Providers/`
- `Tools/`
- `UI/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `LLMContextPlugin`
- `AuxiliaryUsageLedger`
- `AuxiliaryUsageModel`
- `AuxiliaryUsageStore`
- `CompressionBlock`
- `CompressionBlockModel`
- `CompressionBlockStore`
- `CompressionEngine`
- `ContextSummaryModel`
- `ContextSummaryRecord`
- `LLMContextTurnFinishedHook`
- `LLMContextConversationDeletionObserver`
- `ContextWindowUsageSnapshot`
- `ContextStatusTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AttachmentContextBudget**（2 条）：由 `estimateIncludesTextAttachment`、`emergencyFallbackTrimsOversizedTextAttachment` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CompactionToolPairing**（4 条）：由 `compactionRepairsOrphanAtFullFitTailStart`、`compactionDropsOrphanWithoutDeclaration`、`compactionDropsAllOrphanedResultsOfMultiToolCall` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CompressionBlockStore**（6 条）：由 `roundTripTier1`、`roundTripTier2`、`upsertDeactivates` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CompressionEngine**（22 条）：由 `ordersBlocksByContentNotCreation`、`watermarkNilWithoutBlocks`、`recentZoneStartProtectsTail` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ContextPopoverConversationIsolation**（6 条）：由 `auxiliaryLedgerIsConversationScoped`、`auxiliaryStoreIsConversationScoped`、`ledgerLoadDoesNotPullOtherConversation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ContextPopoverExport**（5 条）：由 `exportHeightIsNotClampedByPopoverMaxHeight`、`exportRendersFullCompactionTimeline`、`exportWidthMatchesPopoverWidth` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ContextPopoverLayout**（6 条）：由 `trendViewHeightIsConstrained`、`trendViewRendersInTightSpace`、`trendViewHeightStaysStableWithManySamples` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ContextRecoveryTools**（18 条）：由 `decompressTier1RestoresOriginals`、`decompressTier2TransitiveLineage`、`decompressLegacyBlockWithoutLineage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ContextTokenFormatting**（3 条）：由 `smallSizesKeepActualTokens`、`largeSizesUseShortUnits`、`zeroHasNoUnit` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ContextUsageHistory**（9 条）：由 `emptyHistory`、`samplesUseReportedInputTokens`、`assistantOutputExcludedFromInput` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DeterministicFallbackCalibration**（1 条）：由 `emergencyFallbackTrimsWithCalibratedBudget` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DeterministicFallbackToolPairing**（5 条）：由 `deterministicFallbackDropsOrphanedToolResult`、`deterministicFallbackKeepsPairedToolResultWhenAssistantFits`、`deterministicFallbackDropsAllParallelOrphanedToolResults` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LLMContextPlugin**（25 条）：由 `timelineMessagesAreExcludedFromLLMHistory`、`shortConversationUsesFullHistory`、`contextWindowUsageMatchesPreparedRequest` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StalePrewarmSummaryRetry**（1 条）：由 `hardThresholdRetriesAfterDiscardedPrewarm` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UtilityModelAndAuxiliaryUsage**（10 条）：由 `summaryRoutesToUtilityModel`、`summaryFallsBackToMainWithoutDeclaration`、`summaryInputBoundedByUtilityWindow` 等用例锁定；改动该模块时优先跑对应测试文件。

### 回归契约（跨模块不变量）

- **不可发送角色的预算隔离**：`.error` / `.status` 必须在估算、摘要和 fallback 之前排除，否则尾部错误会挤掉真实用户请求（**#1025**，`nonSendableRolesAreExcludedFromLLMHistory`、`fallbackKeepsUserRequestWhenErrorExceedsBudget`）。
- **确定性降级的量纲与用户请求保留**：裁剪必须按 token 估算（字符数对三字节字符只有约三分之一），且系统消息占满预算时仍要保留最新用户消息（**#1022**，`oversizedChineseUserMessageIsTruncatedInsteadOfDropped`、`largeSystemMessageDoesNotEvictUserRequest`）。
- **用量显示**：小于 1000 的用量必须显示真实 token 数，不能因整数除法塌缩成 `0K`（**#936**，`smallSizesKeepActualTokens`）。
- **过期预热重试**：硬阈值等待的预热摘要若因请求期间产生新消息而被丢弃，必须按最新历史重新生成一次再决定是否降级（**#1118**，`hardThresholdRetriesAfterDiscardedPrewarm`）。
- **确定性降级的工具配对**：降级裁剪丢弃超预算的 assistant tool-call 时，必须连同其 tool 结果一起去掉（并行调用要全部清理），否则 provider 收到孤立 tool 消息会返回 400（**#205**，`deterministicFallbackDropsOrphanedToolResult` 等）。
- **压缩覆盖边界的工具配对**：覆盖水位不得切在工具回合中间——折叠源要保留带 toolCalls 的空正文 assistant、边界原子收缩、预算截断后修剪不完整工具回合；逐字尾部开头的孤儿工具结果无论是否被预算截断都要补上声明或丢弃（**#812**，`tier1MiddleKeepsEmptyToolTurnMessages`、`compactionRepairsOrphanAtFullFitTailStart` 等）。
- **多工具调用的原子协议组**：一个 assistant 的多个 tool-call 及其全部结果必须整组保留或整组丢弃；尾部保护只删第一条孤儿结果会留下同一 assistant 的其余结果，OpenAI 兼容服务直接 400（**#349**，`compactionDropsAllOrphanedResultsOfMultiToolCall`、`compactionKeepsWholeMultiToolGroupWhenAssistantFits`）。
- **工具调用参数不得截成非法 JSON**：协议降级路径（compactedHistory 尾部、deterministicFallback）一律走按 token 的 `boundedMessage`，只裁剪正文、绝不裁剪 `toolCalls.arguments`；装得下就原样保留合法 JSON，装不下就整组丢弃。截断参数会让 adapter 构造请求时校验失败（**#562**，`fallbackKeepsFittingArgumentsAsValidJSON`、`fallbackDropsOversizedArgumentsAtomically`）。
- **降级预算必须折算校准倍率**：`reportContextLimitExceeded` 学到倍率 ≥1.25 后，确定性降级要把可用预算折算回未校准量纲（`inputTokenLimit / factor`）再裁剪，否则估算落在 `limit/factor … limit` 的历史会被原样选中，紧急重试把已确认超限的请求再发一次（**#813**，`emergencyFallbackTrimsWithCalibratedBudget`）。
- **文本附件必须计入预算并可被降级裁剪**：附件正文存在 metadata、转换阶段才拼进真实请求；估算要覆盖渲染后的附件正文，降级要把文本附件折进正文裁剪并从 metadata 移除，否则超大附件让首次请求与紧急重试都原样超限（**#814**，`estimateIncludesTextAttachment`、`emergencyFallbackTrimsOversizedTextAttachment`）。
- **压缩去重守卫不得在 MainActor 同步全量读取**：复用压缩上下文的合格请求会反复进入去重守卫；已记录的 sourceLastMessageID 必须 O(1) 内存命中即返回，首次核对走异步快照，既保住跨重启去重保护，又不让每个请求都同步 fetch/解码/排序整段会话（**#1256**，`duplicateGuardAvoidsSynchronousFullRead`）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AttachmentContextBudget | 估算必须覆盖文本附件正文，而不是只算短正文（#814） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `estimateIncludesTextAttachment` |
| 2 | AttachmentContextBudget | 超大文本附件的紧急重试必须真正裁剪附件正文，不再原样超限（#814） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emergencyFallbackTrimsOversizedTextAttachment` |
| 3 | CompactionToolPairing | 水位停在 assistant 声明上、尾部完整装下时，孤儿工具结果要补上声明（#812） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionRepairsOrphanAtFullFitTailStart` |
| 4 | CompactionToolPairing | 水位后的孤儿工具结果找不到声明时直接丢弃，不得发出（#812） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `compactionDropsOrphanWithoutDeclaration` |
| 5 | CompactionToolPairing | 多工具调用的 assistant 超预算时，其全部工具结果一起丢弃，不留孤儿（#349） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionDropsAllOrphanedResultsOfMultiToolCall` |
| 6 | CompactionToolPairing | 多工具调用整组装得下时，声明与全部结果完整保留（#349） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionKeepsWholeMultiToolGroupWhenAssistantFits` |
| 7 | CompressionBlockStore | tier-1 块连同源消息 ID 列表往返一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripTier1` |
| 8 | CompressionBlockStore | tier-2 块连同源块 ID 列表往返一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripTier2` |
| 9 | CompressionBlockStore | 同 id 再次保存是更新而非重复插入（折叠停用） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `upsertDeactivates` |
| 10 | CompressionBlockStore | 读取包含停用块，供血缘回溯 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadIncludesInactive` |
| 11 | CompressionBlockStore | remove 只清理目标会话的块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeScopedToConversation` |
| 12 | CompressionBlockStore | 重建 store 后从磁盘恢复块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `survivesRecreation` |
| 13 | CompressionEngine | resident 块按内容顺序排列，晚创建的高层块仍排在旧内容处 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ordersBlocksByContentNotCreation` |
| 14 | CompressionEngine | 没有块时水位为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `watermarkNilWithoutBlocks` |
| 15 | CompressionEngine | 最近区间起点保留末尾 recentZone 条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recentZoneStartProtectsTail` |
| 16 | CompressionEngine | 没有块时中间段是最近区间之前的全部历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tier1MiddleWithoutBlocks` |
| 17 | CompressionEngine | 中间段从水位之后开始，到最近区间之前结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tier1MiddleAfterWatermark` |
| 18 | CompressionEngine | 增长门控：中间段不足阈值时不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tier1MiddleGrowthGate` |
| 19 | CompressionEngine | 中间段跳过空内容消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `tier1MiddleSkipsEmptyContent` |
| 20 | CompressionEngine | 空正文但带工具声明/配对的消息不得被跳过（#812） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `tier1MiddleKeepsEmptyToolTurnMessages` |
| 21 | CompressionEngine | 末尾 assistant 的工具结果在最近区间时，该 assistant 不进折叠源（#812） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tier1MiddleExcludesAssistantWithResultsInRecentZone` |
| 22 | CompressionEngine | 工具回合完整落在中间段时保持完整折叠（#812） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tier1MiddleKeepsCompleteToolTurn` |
| 23 | CompressionEngine | 水位消息已不在历史中时放弃折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tier1MiddleMissingWatermark` |
| 24 | CompressionEngine | 某层攒够 fanout 时取最旧一批折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foldBatchTakesOldest` |
| 25 | CompressionEngine | 未攒够 fanout 时不折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foldBatchBelowFanout` |
| 26 | CompressionEngine | 折叠批次只取指定层，且忽略停用块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foldBatchOnlySameTierActive` |
| 27 | CompressionEngine | tier-1 血缘直接返回源消息 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineageTier1` |
| 28 | CompressionEngine | tier-2 血缘逐层回溯到原始消息并保持顺序去重 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineageTier2Transitive` |
| 29 | CompressionEngine | 血缘环不会导致无限递归 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineageCycleSafe` |
| 30 | CompressionEngine | 缺失块 ID 的血缘静默跳过 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineageMissingBlock` |
| 31 | CompressionEngine | system 前缀只取最前面连续的 system 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `systemPrefixLeadingRunOnly` |
| 32 | CompressionEngine | 块消息内容与元数据完全由块决定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `blockMessageIsImmutable` |
| 33 | CompressionEngine | 追加新块不改写已渲染前缀的字节（前缀缓存命中） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendingBlockPreservesPrefixBytes` |
| 34 | CompressionEngine | 折叠停用旧块后，前缀以高层块替换被折叠范围 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `foldingDeactivatesLowerBlocks` |
| 35 | ContextPopoverConversationIsolation | 内存账本只返回目标对话的幕后用量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `auxiliaryLedgerIsConversationScoped` |
| 36 | ContextPopoverConversationIsolation | 磁盘账本只返回目标对话的幕后用量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `auxiliaryStoreIsConversationScoped` |
| 37 | ContextPopoverConversationIsolation | 账本首次加载只并入目标对话的磁盘记录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ledgerLoadDoesNotPullOtherConversation` |
| 38 | ContextPopoverConversationIsolation | 趋势曲线只绘制传入快照里的采样 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usageHistoryPlotsOnlyProvidedSnapshot` |
| 39 | ContextPopoverConversationIsolation | 用量估算只反映目标对话自己的历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextWindowUsageEstimateIsConversationScoped` |
| 40 | ContextPopoverConversationIsolation | 模型级校准倍率跨对话共享（设计如此，非数据混入） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `calibrationFactorIsSharedPerModelNotPerConversation` |
| 41 | ContextPopoverExport | 导出图片的高度不被弹窗的最大高度约束裁剪 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportHeightIsNotClampedByPopoverMaxHeight` |
| 42 | ContextPopoverExport | 导出图片包含完整的压缩时间线，不止可视区域 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportRendersFullCompactionTimeline` |
| 43 | ContextPopoverExport | 导出图片宽度与弹窗一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportWidthMatchesPopoverWidth` |
| 44 | ContextPopoverExport | 无压缩历史时导出仍然成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportWorksWithoutCompactionEvents` |
| 45 | ContextPopoverExport | 导出内容可以写成 PNG 文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportProducesWritablePNG` |
| 46 | ContextPopoverLayout | 趋势图在宽松空间下不应超过图表高度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trendViewHeightIsConstrained` |
| 47 | ContextPopoverLayout | 趋势图在极小空间下仍能渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trendViewRendersInTightSpace` |
| 48 | ContextPopoverLayout | 请求数极多时趋势图高度不变 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `trendViewHeightStaysStableWithManySamples` |
| 49 | ContextPopoverLayout | ContextPopover 在内容很多时不应超出最大高度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `popoverHeightIsConstrainedWithManyEvents` |
| 50 | ContextPopoverLayout | ContextPopover 在内容很少时不超过最大高度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `popoverHeightRespectsMaxHeightWithMinimalContent` |
| 51 | ContextPopoverLayout | ContextPopover 无压缩事件时只显示窗口信息和趋势 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `popoverWithoutCompactionEvents` |
| 52 | ContextRecoveryTools | tier-1 块沿血缘还原原始消息并写入文件，不改对话历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decompressTier1RestoresOriginals` |
| 53 | ContextRecoveryTools | tier-2 块逐层回溯到全部原始消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decompressTier2TransitiveLineage` |
| 54 | ContextRecoveryTools | 迁移块无血缘时返回说明而非报错，也不写文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decompressLegacyBlockWithoutLineage` |
| 55 | ContextRecoveryTools | 非法 blockID 抛出工具执行错误 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `decompressInvalidBlockIDThrows` |
| 56 | ContextRecoveryTools | 未知 blockID 抛出工具执行错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decompressUnknownBlockThrows` |
| 57 | ContextRecoveryTools | 缺少存储目录时解压明确报错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decompressWithoutDirectoryThrows` |
| 58 | ContextRecoveryTools | 搜索同时命中块摘要与原始消息并返回 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchFindsSummariesAndMessages` |
| 59 | ContextRecoveryTools | scope 限定只搜摘要或只搜消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchScopeFilters` |
| 60 | ContextRecoveryTools | limit 钳制命中数量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchLimitClamps` |
| 61 | ContextRecoveryTools | 空查询抛出工具执行错误 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `searchEmptyQueryThrows` |
| 62 | ContextRecoveryTools | 无命中时返回友好提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchNoMatches` |
| 63 | ContextRecoveryTools | 组成报告含分层块数、覆盖水位与幕后压缩开销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusReportsComposition` |
| 64 | ContextRecoveryTools | 无块时报告说明尚未折叠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusWithoutBlocks` |
| 65 | ContextRecoveryTools | purgeConversation 清空内存与磁盘块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `purgeRemovesBlocks` |
| 66 | ContextRecoveryTools | 账本 remove 清空某会话幕后用量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ledgerRemoveClearsEntries` |
| 67 | ContextRecoveryTools | 会话删除事件触发压缩数据清理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deletionObserverCleansUp` |
| 68 | ContextRecoveryTools | 摘要模型拒绝折叠时不产出块，历史走确定性降级 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doctrineRefusalSkipsBlock` |
| 69 | ContextRecoveryTools | 教义包含中途拒绝条款与防注入措辞 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doctrineContainsRefusalClause` |
| 70 | ContextTokenFormatting | 小于 1000 的用量显示真实 token 数而不是 0K | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `smallSizesKeepActualTokens` |
| 71 | ContextTokenFormatting | 千级与百万级仍使用 K/M 简写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `largeSizesUseShortUnits` |
| 72 | ContextTokenFormatting | 零值不再显示为 0K | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroHasNoUnit` |
| 73 | ContextUsageHistory | 没有请求时历史为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyHistory` |
| 74 | ContextUsageHistory | 采样点取服务端上报的 inputTokenCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `samplesUseReportedInputTokens` |
| 75 | ContextUsageHistory | assistant 自身的输出不计入下一轮输入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantOutputExcludedFromInput` |
| 76 | ContextUsageHistory | 供应商未上报 usage 时用本地累计估算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToLocalEstimate` |
| 77 | ContextUsageHistory | 无累计内容时不产生估算采样，避免零值点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noSampleWhenNothingAccumulated` |
| 78 | ContextUsageHistory | 真实的压缩事件只作为标记，不计入采样 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actualCompactionBecomesMarker` |
| 79 | ContextUsageHistory | 后台预热事件不显示为压缩标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prewarmEventIsNotAMarker` |
| 80 | ContextUsageHistory | 错误与状态消息不计入累计 token | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonLLMRolesExcluded` |
| 81 | ContextUsageHistory | 采样点按时间排序，与消息插入顺序无关 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `samplesAreChronologicallyOrdered` |
| 82 | DeterministicFallbackCalibration | 超限学习校准倍率后，紧急降级必须按折算预算真正裁剪历史（#813） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emergencyFallbackTrimsWithCalibratedBudget` |
| 83 | DeterministicFallbackToolPairing | 降级裁剪丢弃超预算 assistant 调用时，不能留下孤立的 tool 结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deterministicFallbackDropsOrphanedToolResult` |
| 84 | DeterministicFallbackToolPairing | 降级裁剪保留装得下的 assistant 调用与配对的 tool 结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deterministicFallbackKeepsPairedToolResultWhenAssistantFits` |
| 85 | DeterministicFallbackToolPairing | 并行工具调用超预算时，所有孤立 tool 结果都要丢弃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deterministicFallbackDropsAllParallelOrphanedToolResults` |
| 86 | DeterministicFallbackToolPairing | 降级保留装得下的工具调用时，参数必须原样保持合法 JSON（#562） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fallbackKeepsFittingArgumentsAsValidJSON` |
| 87 | DeterministicFallbackToolPairing | 降级装不下超大参数时整组丢弃，绝不保留被截断的非法 JSON（#562） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fallbackDropsOversizedArgumentsAtomically` |
| 88 | LLMContextPlugin | 时间线消息只展示给用户，不进入 LLM 历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `timelineMessagesAreExcludedFromLLMHistory` |
| 89 | LLMContextPlugin | 短会话透传完整历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shortConversationUsesFullHistory` |
| 90 | LLMContextPlugin | 工具栏统计复用 LLMContext 请求的估算和预算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextWindowUsageMatchesPreparedRequest` |
| 91 | LLMContextPlugin | 摘要生成失败时不阻塞，继续返回完整历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryFailureFallsBackToFullHistory` |
| 92 | LLMContextPlugin | 生成摘要时使用防提示注入的摘要指令 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryPromptTreatsConversationAsData` |
| 93 | LLMContextPlugin | 后台生成摘要后返回摘要和最近消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `backgroundSummaryCompactsHistory` |
| 94 | LLMContextPlugin | 后台摘要沿用对话模型 ID，不会误路由到同名全局模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `backgroundSummaryUsesConversationModelID` |
| 95 | LLMContextPlugin | 硬阈值请求会在发送前等待摘要 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hardBudgetWaitsForCompaction` |
| 96 | LLMContextPlugin | 软阈值只预热，不记录实际压缩 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `softThresholdOnlyPrewarms` |
| 97 | LLMContextPlugin | 工具 schema usage 不会放大后续消息上下文估算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolSchemaUsageDoesNotInflateMessageCalibration` |
| 98 | LLMContextPlugin | 成功请求会逐步修正过高的历史校准倍率 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `successfulUsageReducesInflatedCalibration` |
| 99 | LLMContextPlugin | 超过原先消息上限后仍能滚动生成摘要 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rollingSummaryContinuesPastLegacyMessageLimit` |
| 100 | LLMContextPlugin | 重新创建 Provider 后复用磁盘压缩块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistedSummarySurvivesProviderRecreation` |
| 101 | LLMContextPlugin | 旧单摘要记录迁移为 tier-1 压缩块后复用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacySummaryMigratesToCompressionBlock` |
| 102 | LLMContextPlugin | 压缩结果落在目标水位内，不会把预算填满 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionResultStaysUnderTargetWatermark` |
| 103 | LLMContextPlugin | 摘要仍然覆盖得住最近区间时不会重新生成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validSnapshotIsReusedWithoutNewSummary` |
| 104 | LLMContextPlugin | 压缩上下文会裁剪超大的旧工具输出 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oversizedToolOutputIsTruncatedInCompactedContext` |
| 105 | LLMContextPlugin | 保留窗口本身就超预算时仍然产出不超过预算的上下文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `irreducibleProtectedWindowStillProducesValidContext` |
| 106 | LLMContextPlugin | 不可发送的错误与状态消息不进入 LLM 历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonSendableRolesAreExcludedFromLLMHistory` |
| 107 | LLMContextPlugin | 降级裁剪不会让尾部错误消息挤掉真实用户请求 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fallbackKeepsUserRequestWhenErrorExceedsBudget` |
| 108 | LLMContextPlugin | 超长中文用户消息按 token 裁剪后保留，而不是整条丢弃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oversizedChineseUserMessageIsTruncatedInsteadOfDropped` |
| 109 | LLMContextPlugin | 系统消息占满预算时仍保留本轮用户请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `largeSystemMessageDoesNotEvictUserRequest` |
| 110 | LLMContextPlugin | 复用压缩上下文的重复请求不再同步全量读取会话（#1256） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `duplicateGuardAvoidsSynchronousFullRead` |
| 111 | LLMContextPlugin | 并发调用时两个调用者都读到迁移后的块 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `concurrentLoadersSeeTheSameMigratedBlock` |
| 112 | LLMContextPlugin | 并发调用不因重复加载而产生重复的迁移块 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `concurrentLoadersDoNotProduceDuplicateMigratedBlocks` |
| 113 | StalePrewarmSummaryRetry | 等待过期预热摘要后按最新历史重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `hardThresholdRetriesAfterDiscardedPrewarm` |
| 114 | UtilityModelAndAuxiliaryUsage | 摘要路由到供应商声明的轻量模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryRoutesToUtilityModel` |
| 115 | UtilityModelAndAuxiliaryUsage | 未声明轻量模型时摘要仍走主模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryFallsBackToMainWithoutDeclaration` |
| 116 | UtilityModelAndAuxiliaryUsage | 摘要输入受轻量模型窗口约束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryInputBoundedByUtilityWindow` |
| 117 | UtilityModelAndAuxiliaryUsage | 切换对话主模型不作废轻量模型摘要 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summarySurvivesMainModelSwitch` |
| 118 | UtilityModelAndAuxiliaryUsage | 轻量模型下线后摘要路由变化并重新生成 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `summaryRouteChangeInvalidatesSnapshot` |
| 119 | UtilityModelAndAuxiliaryUsage | 轻量模型摘要失败时回退主模型重试一次 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `utilityFailureFallsBackToMain` |
| 120 | UtilityModelAndAuxiliaryUsage | 压缩用量按用途记入账本并带服务模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionUsageRecordedWithServingModel` |
| 121 | UtilityModelAndAuxiliaryUsage | 供应商未报用量时记估算值且不为零 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `missingUsageRecordedAsEstimatedNeverZero` |
| 122 | UtilityModelAndAuxiliaryUsage | 压缩事件净收益 = 节省估算 − 摘要消耗 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionNetTokensEqualsSavedMinusSpent` |
| 123 | UtilityModelAndAuxiliaryUsage | 账本按用途聚合开销并标注估算/不可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overheadSummarizesByPurpose` |

> 说明：全部 **123 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 21 / 21
- P1: 已覆盖 97 / 97
- P2: 已覆盖 5 / 5
- **合计: 123 / 123**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（21 条）
- **P1**: 其余功能性用例（97 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 123 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMContext
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
