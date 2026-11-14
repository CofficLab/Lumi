# TestPlan — ProviderMessageStreaming

## 包概述

ProviderMessageStreaming 的实现包：流式输出瞬态 store（KernelCore 体系），逐 chunk 累积正文/思考内容并窄播变更；持久落库由 AgentLoop 在回合结束时一次性完成，不属于本包。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 14

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MessageStreamingStage`
- `MessageStreamingChange`
- `MessageStreamingObserverHandle`
- `MessageStreamingProviding`
- `DefaultMessageStreamingProviding`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **流式行生命周期**（5 条）：由 `streamingLifecycleAccumulatesContentAndReasoningAndNotifiesChanges`、`startAfterEndCreatesAFreshEmptyMessage`、`startOverwritesAnInProgressMessage` 等用例锁定；start 建行、end 清行、重复 start 重置。
- **追加与快照值语义**（4 条）：由 `appendingChunksDoesNotMutateAPreviouslyReadSnapshot`、`thousandsOfChunksAccumulateExactly`、`appendThinkingOnAFreshMessageInitializesReasoningFromNil` 等用例锁定；追加必须原地进行（拷出结构体会触发逐 chunk 整段 COW 复制），已读出的快照不得被后续追加污染。
- **观察者**（4 条）：由 `multipleObserversAllReceiveTheSameChange`、`observerChangeCarriesTheAffectedConversationID`、`doubleCancelIsSafeAndDoesNotAffectOtherObservers` 等用例锁定；变更携带会话 ID，注销后不再投递。
- **边界与常量**（1 条）：由 `streamingStageRawValuesMatchExpectedStrings` 等用例锁定。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 生命周期 | 流式生命周期累积正文与思考并逐次通知变更 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingLifecycleAccumulatesContentAndReasoningAndNotifiesChanges` |
| 2 | 会话隔离 | 不同会话的流式状态互相隔离 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingStateIsIsolatedByConversation` |
| 3 | 追加 | 没有活动流式行时追加正文/思考不做任何事 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendingChunksWithoutAnActiveMessageDoesNothing` |
| 4 | 常量 | stage 原始值与约定字符串一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `streamingStageRawValuesMatchExpectedStrings` |
| 5 | 常量 | 变更相等性只取决于会话 ID | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `streamingChangeEqualityIsBasedOnConversationID` |
| 6 | 生命周期 | end 之后 start 建出全新空行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startAfterEndCreatesAFreshEmptyMessage` |
| 7 | 生命周期 | 流式进行中重复 start 重置为空行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startOverwritesAnInProgressMessage` |
| 8 | 边界 | 未知会话 end 仍通知但状态保持 idle | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `endOnAnUnknownConversationNotifiesButLeavesStateIdle` |
| 9 | 观察者 | 多个观察者收到同一变更 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleObserversAllReceiveTheSameChange` |
| 10 | 观察者 | 变更携带受影响的会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerChangeCarriesTheAffectedConversationID` |
| 11 | 观察者 | 重复注销安全且不影响其他观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doubleCancelIsSafeAndDoesNotAffectOtherObservers` |
| 12 | 追加 | 新行首次追加思考时 reasoning 从 nil 初始化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendThinkingOnAFreshMessageInitializesReasoningFromNil` |
| 13 | 追加 | 追加不得污染此前已读出的快照（值语义） | UI 按帧读取快照后继续追加 | 读取快照后再追加正文与思考 | 快照内容不变，store 累积到新值 | P0 | ✅ 已覆盖 | `appendingChunksDoesNotMutateAPreviouslyReadSnapshot` |
| 14 | 追加 | 数千 chunk 正文与思考交错累积精确无误 | — | 5000 次正文追加并交错思考追加 | 最终字符串逐字相等，stage 正确 | P1 | ✅ 已覆盖 | `thousandsOfChunksAccumulateExactly` |

> 说明：全部 **14 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 10 / 10
- P2: 已覆盖 3 / 3
- **合计: 14 / 14**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（10 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 14 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderMessageStreaming
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
