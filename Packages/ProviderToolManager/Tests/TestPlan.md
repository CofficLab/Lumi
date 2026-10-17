# TestPlan — ProviderToolManager

## 包概述

ProviderToolManager 的实现包，包含 14 个主要类型；当前测试覆盖 34 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 34

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DefaultToolManagerObserverHandle`
- `DefaultToolInteractionPayload`
- `ToolArgumentCoding`
- `ToolAuthorizationDecision`
- `ToolCallRecord`
- `ToolCallRecordModel`
- `ToolCallRecordStore`
- `ToolExecutionPolicy`
- `ToolJobStatus`
- `ToolOutputStream`
- `ToolJobObserverHandle`
- `ToolJobRecord`
- `ToolJobRecordModel`
- `ToolJobRecordStore`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DefaultToolManagerProviding**（13 条）：由 `executeSuccess`、`executePassesConversationContext`、`executeNotifiesObservers` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolCallRecordStore**（3 条）：由 `recordAndFetch`、`deleteAll`、`count` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolJobRecordStore**（3 条）：由 `upsertAndFetchLifecycle`、`queryAndDeleteByScope`、`outputIsBounded` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolJob**（4 条）：由 `terminalStatuses`、`validTransitions`、`codableRoundTrip` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolManagerProviding**（11 条）：由 `addAndOrder`、`addMigratesOwnership`、`groupedByPlugin` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DefaultToolManagerProviding | execute 成功返回内容并缓存结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeSuccess` |
| 2 | DefaultToolManagerProviding | execute 将回合会话 ID 传给 Context-aware 工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executePassesConversationContext` |
| 3 | DefaultToolManagerProviding | execute 通过观察者发出 started 和 completed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeNotifiesObservers` |
| 4 | DefaultToolManagerProviding | 工具注册表变化通过 typed 事件发布 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolRegistrationPublishesTypedEvent` |
| 5 | DefaultToolManagerProviding | execute 工具不存在返回错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeToolNotFound` |
| 6 | DefaultToolManagerProviding | execute 工具抛错返回错误结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeToolThrows` |
| 7 | DefaultToolManagerProviding | 授权执行事件携带最终授权状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizedCompletionCarriesDecision` |
| 8 | DefaultToolManagerProviding | 拒绝授权事件携带最终授权状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectedCompletionCarriesDecision` |
| 9 | DefaultToolManagerProviding | 批次遇到高风险工具后立即暂停，不执行后续调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeBatchStopsAtApproval` |
| 10 | DefaultToolManagerProviding | execute 参数非 JSON 对象返回错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeBadArguments` |
| 11 | DefaultToolManagerProviding | 删除会话后执行被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `executeAfterConversationDeleted` |
| 12 | DefaultToolManagerProviding | toolCalls(for:) 无存储时返回空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallsWithoutStore` |
| 13 | DefaultToolManagerProviding | toolCallResult 无存储且无缓存时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallResultNil` |
| 14 | ToolCallRecordStore | record 后按 turnID / conversationID 可查询 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recordAndFetch` |
| 15 | ToolCallRecordStore | deleteAll 删除记录并阻止后续写入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteAll` |
| 16 | ToolCallRecordStore | count 反映持久化记录数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `count` |
| 17 | ToolJobRecordStore | Job Store 支持创建、更新、终态查询和结果持久化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upsertAndFetchLifecycle` |
| 18 | ToolJobRecordStore | Job Store 支持按会话/回合查询和删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `queryAndDeleteByScope` |
| 19 | ToolJobRecordStore | Job Store 输出尾部保持在 64 KiB 以内 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `outputIsBounded` |
| 20 | ToolJob | 终态可以识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalStatuses` |
| 21 | ToolJob | Job 状态只能按执行生命周期向前转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validTransitions` |
| 22 | ToolJob | ToolJob 可以 Codable 往返并保留工具调用身份 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTrip` |
| 23 | ToolJob | Job ID 始终复用 ToolCall ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `jobIDUsesToolCallID` |
| 24 | ToolManagerProviding | add 与 allTools 保持注册顺序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addAndOrder` |
| 25 | ToolManagerProviding | add 相同名称工具迁移归属且不重复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `addMigratesOwnership` |
| 26 | ToolManagerProviding | toolsGroupedByPlugin 按插件分组、组内保持顺序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `groupedByPlugin` |
| 27 | ToolManagerProviding | remove 与 removeAll 清理分组索引 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeAndRemoveAll` |
| 28 | ToolManagerProviding | displayDescription 使用工具展示名与参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayDescription` |
| 29 | ToolManagerProviding | displayDescription 无法解析时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayDescriptionNil` |
| 30 | ToolManagerProviding | riskLevel 解析工具自身风险 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `riskLevel` |
| 31 | ToolManagerProviding | decode 空字符串得到空字典 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `decodeEmpty` |
| 32 | ToolManagerProviding | decode 保留 JSON 原始类型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodeTypes` |
| 33 | ToolManagerProviding | decode 非对象 JSON 抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodeNonObjectThrows` |
| 34 | ToolManagerProviding | encode 往返一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodeRoundTrip` |

> 说明：全部 **34 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 30 / 30
- P2: 已覆盖 1 / 1
- **合计: 34 / 34**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（30 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 34 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderToolManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
