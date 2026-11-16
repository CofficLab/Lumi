# TestPlan — PluginMessageManager

## 包概述

PluginMessageManager 的实现包，包含 8 个主要类型；当前测试覆盖 78 条用例。

平台: macOS 14+, iOS 17+
测试文件: 16 个，用例总数: 78

核心组件（源码目录）:
- `Errors/`
- `Managers/`
- `Models/`
- `Service/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MessageManagerPlugin`
- `MessageStoreError`
- `MessageManager`
- `MessageModel`
- `MessageStore`
- `PendingMessageBuffer`
- `V4MessageReader`
- `MessageLegacyMigration`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MessageManager**（22 条）：由 `messageChangePublishesBeforePersistence`、`readYourWritesForAssistant`、`asyncSnapshotIncludesPendingMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageManager 读取路径的分流**（3 条）：由 `llmPathOmitsIrrelevantFields`、`uiPathKeepsFullFields`、`llmPathKeepsTimelineMarkers` 锁定——LLM 路径不得携带时间线标记以外的 metadata 与原始事件流，但必须保留 `renderKind` / `lumi.timelineEvent`；UI 路径必须仍拿到完整字段。
- **LLM 回合的消息物化范围**（2 条）：由 `llmReadMustNotMaterializeIrrelevantLargeFields`、`llmReadMustKeepContentAndToolCalls` 锁定——LLM 回合读取时只物化真正需要的内容，不得把无关大字段读进内存。
- **MessageStore 会话查询索引**（2 条）：由 `storeCreatesConversationLookupIndex`、`conversationPageQueryPlanUsesIndex` 锁定——「按会话取消息」必须走 `(ZCONVERSATIONID, ZCREATEDAT)` 复合索引，不得退化成全表扫描。
- **MessageStore 大数据量分页**（2 条）：由 `paginationStaysBoundedAtScale`、`hasEarlierIsBounded` 锁定——大数据量下分页查询耗时有界。
- **MessageStore 日统计聚合**（4 条）：由 `dailyAggregationDoesNotRequireStoreLock`、`dailyAggregationMatchesRowByRowReference`、`dailyAggregationStaysBoundedAtScale` 锁定——日统计聚合只取「创建时间 + token 数」，不得物化整表、不得占用存储层写锁，且口径与逐条读取一致。

- **MessageStore 项目维度日统计**（4 条）：由 `filtersByConversation`、`emptyConversationSetMeansEmpty`、`nilConversationSetMeansUnrestricted`、`chunksLargeConversationSets` 锁定——「本项目近 30 天」这类统计靠一组会话 ID 过滤消息；空集合必须意味着空结果（不得退化成全量），`nil` 意味着不限会话，会话数超过 SQLite 变量上限时按块查询再合并。改动按会话过滤的聚合路径时必须优先跑该文件。
- **MessageStore 全量物化路径基准**（2 条）：由 `fullPathTakesEverythingWhilePagingTakesOnePage`、`fullPathScalesWithConversationLength` 锁定——全量路径的物化量应随会话长度线性增长，作为「分页必须只取一页」的对照基线。
- **MessageManager 会话隔离**（9 条）：由 `snapshotIsConversationScoped`、`llmReadIsConversationScoped`、`syncReadIsConversationScoped`、`pendingWindowIsConversationScoped`、`concurrentInsertsDoNotLeak`、`mismatchedConversationIDIsRebuiltToTarget`、`updateIsConversationScoped`、`deleteIsConversationScoped`、`snapshotReflectsAllStreamsWrittenToSameConversation` 锁定——所有读路径（同步/快照/LLM/落盘前 pending 窗口）与写路径（更新/删除/并发插入）都必须按会话隔离，不得跨会话泄漏；`conversationID` 不一致的消息被重建到目标会话。
- **首条用户消息跳过空白附件**（3 条）：由 `persistedQuerySkipsBlankAttachmentMessage`、`reopenedManagerReadsFirstNonBlankFromDisk`、`persistedQuerySkipsWhitespaceOnlyMessage` 锁定——`fetchFirstUserMessage` / `firstUserMessage` 必须返回第一条**非空白**用户消息（纯附件或纯空白正文的消息要跳过），与默认 Provider 及内存实现口径一致，供自动标题使用（#838）。
- **LLM 窄读取保留附件 metadata**（1 条）：由 `llmReadKeepsAttachmentMetadata` 锁定——LLM 窄读取在跳过无关 metadata 的同时，必须还原图片/文件附件 metadata。
- **工具结果写回不阻塞主线程**（8 条）：由 `toolResultWriteDoesNotBlockOnStoreLock`、`patchIsVisibleOnEveryReadPath`、`readYourWritesAfterToolResult`、`patchesAreScopedToConversation`、`sequentialWritesDoNotClobberEachOther`、`patchWithoutAuthorizationStateKeepsResolvedState`、`deleteClearsPendingPatches`、`clearMessagesClearsPendingPatches` 锁定——助手消息落盘后写回工具结果不得让 MainActor 同步等待存储锁；fetch/编码/save 交给串行落盘队列，主线程只登记内存补丁；补丁在落盘窗口内对所有读路径可见、按会话隔离、多次写回按序不覆盖、不带授权状态时保留磁盘已决定状态，删除/清空会话须清掉未落盘补丁（#1229）。
- **MessageManager 停止排空 write-behind**（3 条）：由 `flushWaitsForBlockedWriteThenDurable`、`flushDrainsToolResultWriteBehind`、`flushConvergesBatchAndEmptiesPending` 锁定——内核停止/插件卸载时 `flushPendingWrites()` 必须排空串行落盘队列，用受控阻塞队列证明「停止调用返回后所有已接受写入（含工具结果写回）都已落盘、pending 清空」，否则正常退出会丢失最后一条消息（#152）。变异验证：把 `flushPendingWrites()` 改成 no-op（空 `sync` 不等待队列），三条用例全部转红——前两条在「flush 提前返回」断言（`!flushReturned.isSet`）失败，第三条在批量落盘断言失败。
- **MessageManager 更新落盘失败保留 pending**（3 条）：由 `updateRetainsPendingWhenNoDiskRecord`、`updateRetainsPendingWhenSaveFails`、`updateDequeuesPendingWhenSaveSucceeds` 锁定——`persistUpdatedMessage` 只有在 `store.updateMessage` 确认落盘成功（返回 true）后才能撤掉 pending；磁盘无记录或 save 失败时必须保留缓冲并暴露可观察错误（`logger.error`），否则消息既不在磁盘也不在内存，从所有读路径静默消失；成功路径仍须 dequeue，避免过度保留堵死 write-behind 窗口（#151）。
> 变异验证（#151）：把 `persistUpdatedMessage` 改回忽略 Bool、无条件 `dequeuePending`，前两条用例转红——pending 不再保留 B、`messages(for:)` 读不到消息（场景 A 彻底消失 / 场景 B 退回旧 A）；成功路径用例仍绿。恢复后 3 条全绿。
- **MessageManager 写回代次门控**（4 条）：由 `writeBackKeepsLatestContentAcrossABCInterleaving`、`toolCallMissStillDrainsPendingGeneration`、`gatedDequeueOnlyRemovesMatchingGeneration`、`duplicateUpdateStillResolvesLatestGeneration` 锁定——pending 按代次（generation）门控 dequeue：insert/更新落盘闭包只能撤掉自己实际写入的那一代，旧写回不得撤掉已更新的新 pending；后续更新在队列里的旧更新完成前必须仍走队列（命中 pending），不得绕过队列同步写磁盘而被旧内容覆盖。用「可挂起队列 + 受控存储锁」确定性复现 A→B→C 交错，断言磁盘最终是 C；工具调用未命中也要把原 toolCalls 原样入队消费掉被 bump 的代次，避免 pending 泄漏；重复同值更新仍推进代次，最新一代写回后 pending 清空（#150）。
> 变异验证（#150）：把 `PendingMessageBuffer.dequeue(id:conversationID:generation:)` 的代次 guard 去掉、改回按 id 无条件移除，A→B→C 用例转红（磁盘最终退回 B）、`gatedDequeueOnlyRemovesMatchingGeneration` 与 `duplicateUpdateStillResolvesLatestGeneration` 转红（旧代次撤掉了新 pending）；`toolCallMissStillDrainsPendingGeneration` 仍绿（它守的是泄漏而非门控）。恢复后 4 条全绿。
- **v4 历史消息迁移**（6 条）：由 `migrationImportsMessagesWithOrderAndContent`、`repeatMigrationDoesNotDuplicate`、`oncePolicySkipsAfterSuccessMarker`、`corruptLegacyDatabaseDoesNotWriteMarker`、`unknownRoleRowsAreSkippedWithoutFailingMigration`、`locatorFindsSiblingV4Directory` 锁定——v4 升级必须把历史消息随会话迁入 v5 消息库：保留会话关联、时间顺序、正文、工具调用（v4 `base64Data` 图片形状须映射成 v5 `data`）、推理内容与用户图片附件；重复迁移不得产生重复数据；marker 只在全部成功后写入（损坏旧库吞错不写 marker，下次启动重试）；未知 role 行跳过不阻塞其余消息（#394）。
> 变异验证（#394）：① 把 `createdAt` 映射改成时间戳取反，顺序/字段断言转红；② 把 toolCallsJSON 直接解码成 v5 `[MessageToolCall]`（v4 图片附件字段不兼容），工具调用断言转红；③ 在迁移开始前预写 marker，损坏旧库用例的「不写 marker」断言转红。恢复后 6 条全绿。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MessageManager | 结构化插入事件在后台落盘前同步发布 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageChangePublishesBeforePersistence` |
| 2 | MessageManager | insert 后立即能读到(assistant 走后台落盘,不等盘) | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readYourWritesForAssistant` |
| 3 | MessageManager | 异步消息快照包含待落盘消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `asyncSnapshotIncludesPendingMessage` |
| 4 | MessageManager | user 消息立即可读并最终后台落盘 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `userMessagePersistedInBackground` |
| 5 | MessageManager | LLM 历史读取包含磁盘与 pending 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmHistoryIncludesPendingMessages` |
| 6 | MessageManager | 响应元数据字段可完整往返数据库 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responseMetadataRoundTrips` |
| 7 | MessageManager | 消息落盘成功后发布结构化持久化事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageChangePublishesAfterPersistence` |
| 8 | MessageManager | assistant 消息最终落盘(等后台队列完成后) | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantEventuallyPersisted` |
| 9 | MessageManager | error 消息也先进入 pending，再由 utility 队列落盘 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorEventuallyPersisted` |
| 10 | MessageManager | store 不可用时,assistant 消息仍可从内存读路径读到(优雅降级) | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readableEvenWhenStoreUnavailable` |
| 11 | MessageManager | 活动聚合包含持久化与待落盘消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dailyActivityAggregates` |
| 12 | MessageManager | 分页:limit 截断 + beforeMessageID 游标 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pagination` |
| 13 | MessageManager | 异步分页包含 pending 消息并遵守游标 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `asyncPagination` |
| 14 | MessageManager | deleteMessage 从磁盘与读路径移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteMessage` |
| 15 | MessageManager | clearMessages 清空磁盘(排空写队列) | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearMessages` |
| 16 | MessageManager | updateToolCallResult 写入展示快照 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateToolCallResult` |
| 17 | MessageManager | 用户允许后重新打开会话，不再显示授权界面 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `approvalIsNotPendingAfterReopen` |
| 18 | MessageManager | 用户拒绝后重新打开会话，不再显示授权界面 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectionIsNotPendingAfterReopen` |
| 19 | MessageManager | 仅覆盖结果不会把已决定的授权状态清回未授权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overwritingResultKeepsResolvedAuthorizationState` |
| 20 | MessageStore 会话查询索引 | 消息库必须建立 (会话, 创建时间) 复合索引 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `storeCreatesConversationLookupIndex` |
| 21 | MessageStore 会话查询索引 | 按会话倒序取消息的查询计划必须使用索引 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `conversationPageQueryPlanUsesIndex` |
| 22 | MessageStore 大数据量分页 | 5000 条消息下分页查询耗时应保持有界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paginationStaysBoundedAtScale` |
| 23 | MessageStore 大数据量分页 | hasEarlierMessages 在大数据量下是常数级查询 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hasEarlierIsBounded` |
| 24 | MessageStore 日统计聚合 | 日统计聚合不得占用存储层全局锁 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `dailyAggregationDoesNotRequireStoreLock` |
| 25 | MessageStore 日统计聚合 | 日统计聚合口径必须与逐条读取一致 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `dailyAggregationMatchesRowByRowReference` |
| 26 | MessageStore 日统计聚合 | 大数据量下日统计聚合必须保持有界 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `dailyAggregationStaysBoundedAtScale` |
| 27 | MessageStore 日统计聚合 | 日统计聚合必须按 id 排除调用方指定的消息 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `dailyAggregateExcludesGivenIdentifiers` |
| 28 | MessageStore 项目维度日统计 | 会话过滤只统计指定会话的消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filtersByConversation` |
| 29 | MessageStore 项目维度日统计 | 空会话集合必须返回空结果而不是退化成全量 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyConversationSetMeansEmpty` |
| 30 | MessageStore 项目维度日统计 | nil 会话集合表示不限会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nilConversationSetMeansUnrestricted` |
| 31 | MessageStore 项目维度日统计 | 会话数超过单块上限时按块合并结果不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chunksLargeConversationSets` |
| 32 | MessageManager 读取路径的分流 | LLM 路径不带 metadata 与原始事件流 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmPathOmitsIrrelevantFields` |
| 33 | MessageManager 读取路径的分流 | UI 路径仍拿到完整字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `uiPathKeepsFullFields` |
| 34 | LLM 回合的消息物化范围 | LLM 回合读取消息时，不得物化与 LLM 无关的大字段 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `llmReadMustNotMaterializeIrrelevantLargeFields` |
| 35 | LLM 回合的消息物化范围 | LLM 回合必须保留真正需要的内容 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `llmReadMustKeepContentAndToolCalls` |
| 36 | MessageStore 全量物化路径基准 | 全量路径取到整个会话，分页路径只取一页 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullPathTakesEverythingWhilePagingTakesOnePage` |
| 37 | MessageStore 全量物化路径基准 | 全量路径的物化量随会话长度增长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullPathScalesWithConversationLength` |
| 38 | MessageManager 读取路径的分流 | LLM 路径保留时间线标记，界面事件仍可被过滤 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmPathKeepsTimelineMarkers` |
| 39 | MessageManager | 最近一页:同 id 的 pending 新版本覆盖磁盘旧版本 | 磁盘已有 A，pending 保留同 id 的 B | 执行该用例 | 最近一页读出 B 的正文、工具结果与授权状态 | P1 | ✅ 已覆盖 | `recentPagePrefersPendingVersion` |
| 40 | MessageManager | 完整快照:同 id 的 pending 新版本覆盖磁盘旧版本 | 磁盘已有 A，pending 保留同 id 的 B | 执行该用例 | 完整快照与 `messages(for:)` 读出 B | P1 | ✅ 已覆盖 | `fullSnapshotPrefersPendingVersion` |
| 41 | MessageManager | LLM 上下文:同 id 的 pending 新版本覆盖磁盘旧版本 | 磁盘已有 A，pending 保留同 id 的 B | 执行该用例 | LLM 上下文读出 B 的正文与工具结果 | P1 | ✅ 已覆盖 | `llmSnapshotPrefersPendingVersion` |
| 42 | MessageManager 会话隔离 | messagesSnapshot 只含目标对话的消息 | 两个对话各有消息 | 执行该用例 | 快照只返回目标对话消息 | P1 | ✅ 已覆盖 | `snapshotIsConversationScoped` |
| 43 | MessageManager 会话隔离 | messagesForLLM 只含目标对话的消息 | 两个对话各有消息 | 执行该用例 | LLM 读取只返回目标对话消息 | P1 | ✅ 已覆盖 | `llmReadIsConversationScoped` |
| 44 | MessageManager 会话隔离 | 同步 messages(for:) 只含目标对话的消息 | 两个对话各有消息 | 执行该用例 | 同步读取只返回目标对话消息 | P1 | ✅ 已覆盖 | `syncReadIsConversationScoped` |
| 45 | MessageManager 会话隔离 | 落盘前的 read-your-writes 窗口仍按对话隔离 | 消息尚在 pending | 执行该用例 | pending 窗口读取不跨对话泄漏 | P1 | ✅ 已覆盖 | `pendingWindowIsConversationScoped` |
| 46 | MessageManager 会话隔离 | 并发交错写入两个对话不互相泄漏 | 两对话并发插入 | 执行该用例 | 各对话只含自身消息，无竞态泄漏 | P0 | ✅ 已覆盖 | `concurrentInsertsDoNotLeak` |
| 47 | MessageManager 会话隔离 | conversationID 不一致的消息被重建到目标对话 | 插入消息 conversationID 与目标不符 | 执行该用例 | 消息被重建到目标对话 | P1 | ✅ 已覆盖 | `mismatchedConversationIDIsRebuiltToTarget` |
| 48 | MessageManager 会话隔离 | 更新只作用于目标对话 | 两个对话各有消息 | 执行该用例 | 更新不影响其他对话 | P1 | ✅ 已覆盖 | `updateIsConversationScoped` |
| 49 | MessageManager 会话隔离 | 删除只作用于目标对话 | 两个对话各有消息 | 执行该用例 | 删除不影响其他对话 | P1 | ✅ 已覆盖 | `deleteIsConversationScoped` |
| 50 | MessageManager 会话隔离 | 写入同一对话的两条流都会如实出现在该对话快照里 | 同一对话两条写入流 | 执行该用例 | 快照如实包含两条流的消息 | P1 | ✅ 已覆盖 | `snapshotReflectsAllStreamsWrittenToSameConversation` |
| 51 | LLM 窄读取保留附件 metadata | 窄读取还原图片/文件附件，仍跳过无关 metadata | 消息带附件与无关 metadata | 执行该用例 | 附件 metadata 还原，无关 metadata 跳过 | P1 | ✅ 已覆盖 | `llmReadKeepsAttachmentMetadata` |
| 52 | 首条用户消息跳过空白附件 | 持久化查询跳过纯附件空白消息，返回其后第一条文本（#838） | 先插纯附件空白消息 U1，后插文本 U2，等待落盘 | 执行该用例 | `fetchFirstUserMessage` 返回 U2 | P1 | ✅ 已覆盖 | `persistedQuerySkipsBlankAttachmentMessage` |
| 53 | 首条用户消息跳过空白附件 | 重启后从磁盘读取首条用户消息仍跳过空白附件消息（#838） | 落盘后重开 manager（纯磁盘路径） | 执行该用例 | `firstUserMessage` 返回 U2 | P1 | ✅ 已覆盖 | `reopenedManagerReadsFirstNonBlankFromDisk` |
| 54 | 首条用户消息跳过空白附件 | 纯空白正文的用户消息也被跳过（#838） | 先插纯空白正文消息，后插文本 | 执行该用例 | 跳过空白正文，返回第一条非空白文本 | P1 | ✅ 已覆盖 | `persistedQuerySkipsWhitespaceOnlyMessage` |
| 55 | 工具结果写回不阻塞主线程 | 助手消息已落盘时，写回工具结果不等待存储锁（#1229） | 助手消息已落盘且离开 pending，后台占住存储锁 | 主线程写回工具结果 | 调用不阻塞（<1s），补丁已登记 | P0 | ✅ 已覆盖 | `toolResultWriteDoesNotBlockOnStoreLock` |
| 56 | 工具结果写回不阻塞主线程 | 落盘窗口内，所有读路径都能看到工具结果补丁（#1229） | 磁盘仍是旧版本，补丁已登记 | 走同步/快照/LLM/分页各读路径 | 全部读到补丁；撤掉补丁后回到磁盘版本 | P0 | ✅ 已覆盖 | `patchIsVisibleOnEveryReadPath` |
| 57 | 工具结果写回不阻塞主线程 | 写回后立刻读到结果，不等后台落盘（#1229） | 助手消息已落盘且离开 pending | 写回工具结果后立即同步读取 | 立即读到结果与授权状态，最终落盘一致 | P1 | ✅ 已覆盖 | `readYourWritesAfterToolResult` |
| 58 | 工具结果写回不阻塞主线程 | 补丁只作用于所属会话（#1229） | 两个会话各有同 toolCallID 的助手消息 | 只写回会话 A | 仅 A 读到结果，B 无补丁 | P0 | ✅ 已覆盖 | `patchesAreScopedToConversation` |
| 59 | 工具结果写回不阻塞主线程 | 同一消息的多次写回按顺序落盘，互不覆盖（#1229） | 助手消息含两个工具调用 | 连续三次写回（含同 id 覆盖） | 各结果按序落盘不互相覆盖，补丁全部撤掉 | P0 | ✅ 已覆盖 | `sequentialWritesDoNotClobberEachOther` |
| 60 | 工具结果写回不阻塞主线程 | 补丁不带授权状态时，保留磁盘上已决定的授权状态（#1229） | 磁盘授权状态为 userApproved | 写回结果但 authorizationState 为 nil | 结果更新，授权状态仍为 userApproved | P1 | ✅ 已覆盖 | `patchWithoutAuthorizationStateKeepsResolvedState` |
| 61 | 工具结果写回不阻塞主线程 | 删除消息会清掉尚未落盘的工具结果补丁（#1229） | 补丁已登记未落盘 | 删除该消息 | 补丁清空，磁盘与读路径均无该消息 | P1 | ✅ 已覆盖 | `deleteClearsPendingPatches` |
| 62 | 工具结果写回不阻塞主线程 | 清空会话会清掉尚未落盘的工具结果补丁（#1229） | 补丁已登记未落盘 | 清空该会话 | 补丁清空，读路径为空 | P1 | ✅ 已覆盖 | `clearMessagesClearsPendingPatches` |
| 63 | MessageManager 停止排空 write-behind | flush 等待被阻塞的落盘收敛后才返回，返回时消息已落盘（#152） | 后台占住存储锁，插入一条消息 | 另一线程调用 flushPendingWrites | flush 在锁释放前不返回；返回时消息已落盘、pending 清空 | P0 | ✅ 已覆盖 | `flushWaitsForBlockedWriteThenDurable` |
| 64 | MessageManager 停止排空 write-behind | flush 同样排空工具结果写回，返回时工具结果已落盘（#152） | 后台占住存储锁，插入助手消息并写回工具结果 | 另一线程调用 flushPendingWrites | flush 在锁释放前不返回；返回时工具结果与授权状态已落盘 | P0 | ✅ 已覆盖 | `flushDrainsToolResultWriteBehind` |
| 65 | MessageManager 停止排空 write-behind | flush 后批量消息全部落盘且 pending 清空（#152） | 连续插入 5 条消息 | 调用 flushPendingWrites | 5 条全部落盘，pending 清空 | P1 | ✅ 已覆盖 | `flushConvergesBatchAndEmptiesPending` |
| 66 | v4 历史消息迁移 | 迁移保留会话关联、顺序、正文与工具调用/附件/推理内容，不得丢失（#394） | 合成 v4 旧库含两个会话、四类 role 消息与图片附件 | 执行迁移后按会话读取 | id/顺序/正文/metadata/工具调用/附件/推理/错误字段全部保留，marker 写入 | P0 | ✅ 已覆盖 | `migrationImportsMessagesWithOrderAndContent` |
| 67 | v4 历史消息迁移 | 重复迁移与已存在消息不得产生重复数据（#394） | 新库已含同 id 消息 | 连续执行两次迁移 | 消息数不变，id 集合无重复 | P0 | ✅ 已覆盖 | `repeatMigrationDoesNotDuplicate` |
| 68 | v4 历史消息迁移 | once 策略成功后写 marker，后续启动跳过（#394） | 首次迁移成功 | 旧库追加新消息后再次迁移 | 新消息不被导入 | P1 | ✅ 已覆盖 | `oncePolicySkipsAfterSuccessMarker` |
| 69 | v4 历史消息迁移 | 旧库损坏时吞错、不得写 marker，保留重试机会（#394） | Core/Lumi.db 为非法字节 | 执行迁移 | 不抛错、无 marker、新库为空 | P0 | ✅ 已覆盖 | `corruptLegacyDatabaseDoesNotWriteMarker` |
| 70 | v4 历史消息迁移 | 未知 role 的行被跳过，不阻塞其余消息与 marker（#394） | 旧库含 bogus role 与有效消息 | 执行迁移 | 仅有效消息导入，marker 写入 | P1 | ✅ 已覆盖 | `unknownRoleRowsAreSkippedWithoutFailingMigration` |
| 71 | v4 历史消息迁移 | v4 根目录定位：兄弟目录存在则返回，缺失返回 nil（#394） | 父目录下有/无 db_production_v4 | 调用 locate | 存在返回该目录，缺失返回 nil | P2 | ✅ 已覆盖 | `locatorFindsSiblingV4Directory` |
| 72 | MessageManager 更新落盘失败保留 pending | insert 失败后 update 找不到磁盘记录时保留 pending，消息不从读路径消失（#151） | 磁盘无记录，pending 持有消息 A | 更新到 B 后排空落盘队列 | pending 仍含 B，磁盘为空，`messages(for:)` 仍读到 B | P0 | ✅ 已覆盖 | `updateRetainsPendingWhenNoDiskRecord` |
| 73 | MessageManager 更新落盘失败保留 pending | update save 失败时保留 pending，磁盘旧内容不被误删（#151） | 磁盘已有 A，触发器使 UPDATE 落盘失败 | 更新到 B 后排空落盘队列 | pending 仍含 B，磁盘仍为 A，`messages(for:)` 读到 B | P0 | ✅ 已覆盖 | `updateRetainsPendingWhenSaveFails` |
| 74 | MessageManager 更新落盘失败保留 pending | update 落盘成功时撤掉 pending，磁盘更新为最新内容（#151） | 磁盘已有 A，pending 持有 A | 更新到 B 后排空落盘队列 | pending 清空，磁盘为 B，`messages(for:)` 读到 B | P1 | ✅ 已覆盖 | `updateDequeuesPendingWhenSaveSucceeds` |
| 75 | MessageManager 写回代次门控 | A→B→C 交错：旧 insert 不得撤掉新 pending，磁盘最终是 C（#150） | 占住存储锁，insert(A)、update(B) 入队后挂起队列再放行锁 | insert(A) 落盘后更新到 C，放行队列排空 | 磁盘最终为 C，pending 清空 | P0 | ✅ 已覆盖 | `writeBackKeepsLatestContentAcrossABCInterleaving` |
| 76 | MessageManager 写回代次门控 | 工具调用未命中也排空被 bump 的代次，pending 不泄漏（#150） | assistant 仍在 pending，写回不存在的 toolCallID | 放行存储锁并排空落盘队列 | pending 清空，磁盘 toolCalls 保持原样、result 为 nil | P0 | ✅ 已覆盖 | `toolCallMissStillDrainsPendingGeneration` |
| 77 | MessageManager 写回代次门控 | 代次门控 dequeue：旧代次不撤新 pending，匹配代次才撤（#150） | enqueue A(gen1) 后 update 到 B(gen2) | 先按 gen1 dequeue，再按 gen2 dequeue | gen1 不撤（pending 仍 B），gen2 撤掉（pending 空） | P0 | ✅ 已覆盖 | `gatedDequeueOnlyRemovesMatchingGeneration` |
| 78 | MessageManager 写回代次门控 | 重复同值更新仍推进代次，最新一代写回后 pending 清空（#150） | enqueue A 后连续两次 update 到同值 B | 按第一代 dequeue，再按最新代 dequeue | 第一代不撤，最新代撤掉后 pending 空 | P1 | ✅ 已覆盖 | `duplicateUpdateStillResolvesLatestGeneration` |

> 说明：全部 **78 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 26 / 26
- P1: 已覆盖 51 / 51
- P2: 已覆盖 1 / 1
- **合计: 78 / 78**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（26 条）
- **P1**: 其余功能性用例（51 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 78 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMessageManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
