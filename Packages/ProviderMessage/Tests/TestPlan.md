# TestPlan — ProviderMessage

## 包概述

ProviderMessage 的实现包，包含 5 个主要类型；当前测试覆盖 21 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 21

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DefaultMessageManager`
- `MessageChange`
- `MessageRole`
- `MessageTimelineEvent`
- `UserImageAttachment`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（21 条）：由 `lifecycle`、`asyncSnapshot`、`dailyAggregates` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | 消息按创建时间返回并支持更新删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lifecycle` |
| 2 | 综合 | 异步消息快照包含当前会话消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `asyncSnapshot` |
| 3 | 综合 | 消息与 token 可按自然日跨会话聚合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dailyAggregates` |
| 4 | 综合 | 消息插入观察者可接收事件并注销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageInsertionObservation` |
| 5 | 综合 | 结构化消息变化观察者携带消息并支持注销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageChangeObservation` |
| 6 | 综合 | 本地文本文件转换为附件时不污染消息正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsTextFileAsAttachment` |
| 7 | 综合 | 二进制文件保留字节并不伪装成文本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsBinaryFileAsAttachment` |
| 8 | 综合 | 文本文件附件会渲染到发送给 LLM 的用户正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendersTextFileAttachmentForLLM` |
| 9 | 综合 | 二进制文件附件只渲染描述，不把 base64 混入提示词 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendersBinaryFileDescriptionForLLM` |
| 10 | 综合 | no attachments returns original content unchanged | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyAttachmentsReturnContent` |
| 11 | 综合 | attachments to empty content render only the blocks | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `attachmentsWithEmptyContent` |
| 12 | 综合 | special characters in names are attribute-escaped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `escapesAttributeCharacters` |
| 13 | 综合 | multiple attachments are separated by a blank line | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleAttachmentsJoined` |
| 14 | 综合 | file attachment metadata round-trips through encode/decode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileAttachmentCodecRoundTrip` |
| 15 | 综合 | image attachment metadata round-trips | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageAttachmentCodecRoundTrip` |
| 16 | 综合 | extract reads the latest user message carrying file attachments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extractLatestUserFileAttachments` |
| 17 | 综合 | isContextCompaction matches renderKind or metadata marker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isContextCompactionDetection` |
| 18 | 综合 | AgentLoop 重试时间线事件可识别且不误判压缩 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `agentLoopRetryTimelineDetection` |
| 19 | 综合 | isActualContextCompaction requires the actual marker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actualCompactionRequiresMarker` |
| 20 | 综合 | compactionReason maps known values and falls back to legacy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionReasonMapping` |
| 21 | 综合 | integerMetadata parses int strings and tolerates missing or non-numeric | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `integerMetadataParsing` |

> 说明：全部 **21 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 18 / 18
- P2: 已覆盖 2 / 2
- **合计: 21 / 21**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（18 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 21 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderMessage
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
