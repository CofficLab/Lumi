# TestPlan — ProviderMessage

## 包概述

ProviderMessage 的实现包，包含 6 个主要类型；当前测试覆盖 42 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 42

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `CollapsedContentBlock`
- `DefaultMessageManager`
- `MessageChange`
- `MessageRole`
- `MessageTimelineEvent`
- `UserImageAttachment`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CollapsedContentBlock**（7 条）：由 `encodesAndDecodesBlocks`、`decodesEmptyForLegacyData`、`encodesNothingForEmptyBlocks` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CollapsedContentChipStyle**（5 条）：由 `keepsTypographyScale`、`splitsTitleAndDetail`、`dropsEmptyDetail` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（26 条）：由 `lifecycle`、`asyncSnapshot`、`dailyAggregates` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CollapsedContentBlock | 折叠块可编码进 metadata 并原样解码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodesAndDecodesBlocks` |
| 2 | CollapsedContentBlock | 旧数据没有该 key 时解码为空数组 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `decodesEmptyForLegacyData` |
| 3 | CollapsedContentBlock | 空数组不写入 metadata，避免留下无意义的空 JSON | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `encodesNothingForEmptyBlocks` |
| 4 | CollapsedContentBlock | 越界区间被丢弃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dropsOutOfRangeBlocks` |
| 5 | CollapsedContentBlock | 重叠区间只保留靠前的一个 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dropsOverlappingBlocks` |
| 6 | CollapsedContentBlock | 正文裁掉开头空白后，区间同步平移 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rebasesBlocksAfterLeadingWhitespaceDrop` |
| 7 | CollapsedContentBlock | 正文没有前导空白时区间保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsBlocksWhenNoLeadingWhitespace` |
| 8 | 综合 | 消息按创建时间返回并支持更新删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lifecycle` |
| 9 | 综合 | 异步消息快照包含当前会话消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `asyncSnapshot` |
| 10 | 综合 | 消息与 token 可按自然日跨会话聚合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dailyAggregates` |
| 11 | 综合 | 消息插入观察者可接收事件并注销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageInsertionObservation` |
| 12 | 综合 | 结构化消息变化观察者携带消息并支持注销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageChangeObservation` |
| 13 | 综合 | 本地文本文件转换为附件时不污染消息正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsTextFileAsAttachment` |
| 14 | 综合 | 二进制文件保留字节并不伪装成文本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsBinaryFileAsAttachment` |
| 15 | 综合 | 文本文件附件会渲染到发送给 LLM 的用户正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendersTextFileAttachmentForLLM` |
| 16 | 综合 | 二进制文件附件只渲染描述，不把 base64 混入提示词 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendersBinaryFileDescriptionForLLM` |
| 17 | 综合 | no attachments returns original content unchanged | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyAttachmentsReturnContent` |
| 18 | 综合 | attachments to empty content render only the blocks | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `attachmentsWithEmptyContent` |
| 19 | 综合 | special characters in names are attribute-escaped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `escapesAttributeCharacters` |
| 20 | 综合 | multiple attachments are separated by a blank line | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleAttachmentsJoined` |
| 21 | 综合 | file attachment metadata round-trips through encode/decode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileAttachmentCodecRoundTrip` |
| 22 | 综合 | image attachment metadata round-trips | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageAttachmentCodecRoundTrip` |
| 23 | 综合 | extract reads the latest user message carrying file attachments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extractLatestUserFileAttachments` |
| 24 | 综合 | isContextCompaction matches renderKind or metadata marker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isContextCompactionDetection` |
| 25 | 综合 | AgentLoop 重试时间线事件可识别且不误判压缩 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `agentLoopRetryTimelineDetection` |
| 26 | 综合 | App Store Connect 提交时间线事件可识别且不回流 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appStoreSubmissionTimelineDetection` |
| 27 | 综合 | isActualContextCompaction requires the actual marker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actualCompactionRequiresMarker` |
| 28 | 综合 | compactionReason maps known values and falls back to legacy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionReasonMapping` |
| 29 | 综合 | integerMetadata parses int strings and tolerates missing or non-numeric | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `integerMetadataParsing` |
| 30 | 综合 | 二进制附件在源文件被替换后仍指向发送时的字节快照 | 发送后替换原文件字节 | 渲染附件正文 | 引用受管快照路径，内容等于发送时字节 | P1 | ✅ 已覆盖 | `binaryAttachmentUsesStableSnapshotAfterSourceChanges` |
| 31 | 综合 | 没有字节快照的旧二进制附件回退到原始路径 | 仅有 `localPath` 的旧附件 | 渲染附件正文 | 正文包含原始路径 | P2 | ✅ 已覆盖 | `legacyBinaryAttachmentFallsBackToLocalPath` |
| 32 | CollapsedContentChipStyle | 字号与消息列表的排版规格一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsTypographyScale` |
| 33 | CollapsedContentChipStyle | 标题串按第一个分隔符拆成标题与统计信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `splitsTitleAndDetail` |
| 34 | CollapsedContentChipStyle | 分隔符后为空时没有统计信息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `dropsEmptyDetail` |
| 35 | CollapsedContentChipStyle | 空标题原样返回 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `handlesEmptyTitle` |
| 36 | CollapsedContentChipStyle | 没有分隔符时整串都是标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `keepsWholeTitleWhenNoSeparator` |
| 37 | 综合 | 模型切换时间线事件可识别且不回流 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelSwitchedTimelineDetection` |
| 38 | 综合 | 模型切换事件仅凭 renderKind 也可识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelSwitchedDetectionByRenderKind` |
| 39 | CollapsedContentBlock | 折叠块包含首尾空白时裁掉碰到的空白并保留其余区间 | 区间覆盖整段含首尾空白的正文 | 按 trim 后正文重算区间 | 区间裁短为正文长度，块不丢失 | P0 | ✅ 已覆盖 | `clipsSurroundingWhitespaceInsteadOfDroppingBlock` |
| 40 | CollapsedContentBlock | 只含尾随空白时同样裁短保留 | 区间延伸到换行之后 | 按 trim 后正文重算区间 | 区间裁短到正文末尾 | P1 | ✅ 已覆盖 | `clipsTrailingWhitespaceOnly` |
| 41 | CollapsedContentBlock | 部分与空白重叠的块裁短，完全落在空白里的块删除 | 块分别覆盖全空白与部分正文 | 按 trim 后正文重算区间 | 全空白块删除，部分重叠块裁短 | P1 | ✅ 已覆盖 | `dropsOnlyFullyTrimmedBlocks` |
| 42 | UserAttachment | 文本附件正文中的结构标签被转义，不能伪造额外附件 | 正文含 `</attached_file>` 与伪开始标签 | 序列化到 LLM 正文 | 结构标签只来自真实附件，正文标签被转义 | P0 | ✅ 已覆盖 | `escapesStructureTagsInTextAttachmentBody` |

> 说明：全部 **38 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 31 / 31
- P2: 已覆盖 8 / 8
- **合计: 42 / 42**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（29 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（8 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 38 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
