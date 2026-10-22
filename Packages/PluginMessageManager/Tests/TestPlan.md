# TestPlan — PluginMessageManager

## 包概述

PluginMessageManager 的实现包，包含 6 个主要类型；当前测试覆盖 26 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 26

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

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MessageManager**（19 条）：由 `messageChangePublishesBeforePersistence`、`readYourWritesForAssistant`、`asyncSnapshotIncludesPendingMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageStore 会话查询索引**（2 条）：由 `storeCreatesConversationLookupIndex`、`conversationPageQueryPlanUsesIndex` 锁定——「按会话取消息」必须走 `(ZCONVERSATIONID, ZCREATEDAT)` 复合索引，不得退化成全表扫描。
- **MessageStore 大数据量分页**（2 条）：由 `paginationStaysBoundedAtScale`、`hasEarlierIsBounded` 锁定——大数据量下分页查询耗时有界。
- **MessageStore 日统计聚合**（3 条）：由 `dailyAggregationDoesNotRequireStoreLock`、`dailyAggregationMatchesRowByRowReference`、`dailyAggregationStaysBoundedAtScale` 锁定——日统计聚合只取「创建时间 + token 数」，不得物化整表、不得占用存储层写锁，且口径与逐条读取一致。

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

> 说明：全部 **26 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 19 / 19
- P2: 已覆盖 0 / 0
- **合计: 26 / 26**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（19 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 26 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
