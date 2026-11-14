# TestPlan — ProviderMessage

## 包概述

ProviderMessage 的实现包，包含 8 个主要类型；当前测试覆盖 62 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 62

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `CollapsedContentBlock`
- `CollapsedContentChipStyle`
- `DefaultMessageManager`
- `ImageBase64Decoder`
- `MessageChange`
- `MessageRole`
- `MessageTimelineEvent`
- `UserImageAttachment`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CollapsedContentBlock**（10 条）：由 `encodesAndDecodesBlocks`、`decodesEmptyForLegacyData`、`encodesNothingForEmptyBlocks` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CollapsedContentChipStyle**（5 条）：由 `splitsTitleAndDetail`、`keepsWholeTitleWhenNoSeparator`、`dropsEmptyDetail` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ImageBase64Decoder**（13 条）：由 `decodedResultMatchesDirectDecoding`、`cachedDecodeReturnsSameResult`、`distinctInstancesWithSameContentReuseEntry` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageTimelineCompactionAccounting**（5 条）：由 `savedTokensIsOriginalMinusCompacted`、`netTokensIsSavedMinusSpent`、`netTokensNilWhenSpentMissing` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（29 条）：由 `lifecycle`、`asyncSnapshot`、`dailyAggregates` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 8 | CollapsedContentBlock | 折叠块包含首尾空白时，裁掉碰到的空白并保留其余区间 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clipsSurroundingWhitespaceInsteadOfDroppingBlock` |
| 9 | CollapsedContentBlock | 只含尾随空白时同样裁短保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clipsTrailingWhitespaceOnly` |
| 10 | CollapsedContentBlock | 部分与空白重叠的块裁短，完全落在空白里的块删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dropsOnlyFullyTrimmedBlocks` |
| 11 | CollapsedContentChipStyle | 标题串按第一个分隔符拆成标题与统计信息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `splitsTitleAndDetail` |
| 12 | CollapsedContentChipStyle | 没有分隔符时整串都是标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `keepsWholeTitleWhenNoSeparator` |
| 13 | CollapsedContentChipStyle | 分隔符后为空时没有统计信息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `dropsEmptyDetail` |
| 14 | CollapsedContentChipStyle | 空标题原样返回 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `handlesEmptyTitle` |
| 15 | CollapsedContentChipStyle | 字号与消息列表的排版规格一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsTypographyScale` |
| 16 | ImageBase64Decoder | 解码结果与 Data(base64Encoded:) 完全一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodedResultMatchesDirectDecoding` |
| 17 | ImageBase64Decoder | 缓存命中返回与首次一致的结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cachedDecodeReturnsSameResult` |
| 18 | ImageBase64Decoder | 内容相同的不同字符串实例命中同一条缓存 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `distinctInstancesWithSameContentReuseEntry` |
| 19 | ImageBase64Decoder | 不同内容的图片不会互相污染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `differentContentDoesNotCollide` |
| 20 | ImageBase64Decoder | 非法 base64 返回 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidBase64` |
| 21 | ImageBase64Decoder | 空字符串返回 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyString` |
| 22 | ImageBase64Decoder | 非法 base64 不占用缓存条目 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidInputDoesNotCreateEntry` |
| 23 | ImageBase64Decoder | 空字符串不占用缓存条目 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyStringDoesNotCreateEntry` |
| 24 | ImageBase64Decoder | 条目数超过上限时被淘汰 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `evictsWhenEntryLimitExceeded` |
| 25 | ImageBase64Decoder | 累计字节数超过上限时被淘汰 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `evictsWhenByteLimitExceeded` |
| 26 | ImageBase64Decoder | 淘汰后重新解码仍得到正确结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `evictedEntriesStillDecodeCorrectly` |
| 27 | ImageBase64Decoder | 清空缓存后统计归零 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeAllResetsStatistics` |
| 28 | ImageBase64Decoder | 重复解码同一张图片的耗时显著低于首次解码 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedDecodeIsCheaperThanFirstDecode` |
| 29 | MessageTimelineCompactionAccounting | 节省 = 压缩前 − 压缩后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `savedTokensIsOriginalMinusCompacted` |
| 30 | MessageTimelineCompactionAccounting | 净收益 = 节省 − 摘要消耗 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `netTokensIsSavedMinusSpent` |
| 31 | MessageTimelineCompactionAccounting | 消耗缺失时净收益为 nil，而不是把消耗当零 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `netTokensNilWhenSpentMissing` |
| 32 | MessageTimelineCompactionAccounting | 估算口径标记被正确读取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimatedFlagReadFromMetadata` |
| 33 | MessageTimelineCompactionAccounting | 节省任一端缺失时为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `savedTokensNilWhenEitherEndMissing` |
| 34 | 综合 | 消息按创建时间返回并支持更新删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lifecycle` |
| 35 | 综合 | 异步消息快照包含当前会话消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `asyncSnapshot` |
| 36 | 综合 | 消息与 token 可按自然日跨会话聚合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dailyAggregates` |
| 37 | 综合 | 消息插入观察者可接收事件并注销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageInsertionObservation` |
| 38 | 综合 | 结构化消息变化观察者携带消息并支持注销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageChangeObservation` |
| 39 | 综合 | 本地文本文件转换为附件时不污染消息正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsTextFileAsAttachment` |
| 40 | 综合 | 二进制文件保留字节并不伪装成文本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsBinaryFileAsAttachment` |
| 41 | 综合 | 文本文件附件会渲染到发送给 LLM 的用户正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendersTextFileAttachmentForLLM` |
| 42 | 综合 | 文本附件正文中的结构标签被转义，不能伪造额外附件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `escapesStructureTagsInTextAttachmentBody` |
| 43 | 综合 | 二进制文件附件只渲染描述，不把 base64 混入提示词 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendersBinaryFileDescriptionForLLM` |
| 44 | 综合 | 二进制附件在源文件被替换后仍指向发送时的字节快照 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `binaryAttachmentUsesStableSnapshotAfterSourceChanges` |
| 45 | 综合 | 没有字节快照的旧二进制附件回退到原始路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyBinaryAttachmentFallsBackToLocalPath` |
| 46 | 综合 | no attachments returns original content unchanged | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyAttachmentsReturnContent` |
| 47 | 综合 | attachments to empty content render only the blocks | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `attachmentsWithEmptyContent` |
| 48 | 综合 | special characters in names are attribute-escaped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `escapesAttributeCharacters` |
| 49 | 综合 | multiple attachments are separated by a blank line | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleAttachmentsJoined` |
| 50 | 综合 | file attachment metadata round-trips through encode/decode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileAttachmentCodecRoundTrip` |
| 51 | 综合 | image attachment metadata round-trips | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageAttachmentCodecRoundTrip` |
| 52 | 综合 | extract reads the latest user message carrying file attachments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extractLatestUserFileAttachments` |
| 53 | 综合 | isContextCompaction matches renderKind or metadata marker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isContextCompactionDetection` |
| 54 | 综合 | AgentLoop 重试时间线事件可识别且不误判压缩 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `agentLoopRetryTimelineDetection` |
| 55 | 综合 | App Store Connect 提交时间线事件可识别且不回流 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appStoreSubmissionTimelineDetection` |
| 56 | 综合 | 模型切换时间线事件可识别且不回流 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelSwitchedTimelineDetection` |
| 57 | 综合 | 模型切换事件仅凭 renderKind 也可识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelSwitchedDetectionByRenderKind` |
| 58 | 综合 | isActualContextCompaction requires the actual marker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actualCompactionRequiresMarker` |
| 59 | 综合 | compactionReason maps known values and falls back to legacy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionReasonMapping` |
| 60 | 综合 | integerMetadata parses int strings and tolerates missing or non-numeric | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `integerMetadataParsing` |
| 61 | 综合 | 子代理委托时间线事件可识别且不回流 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `subagentDelegationTimelineDetection` |
| 62 | 综合 | 子代理委托事件仅凭 renderKind 也可识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `subagentDelegationDetectionByRenderKind` |

> 说明：全部 **62 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 45 / 45
- P2: 已覆盖 10 / 10
- **合计: 62 / 62**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（45 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（10 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 62 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
