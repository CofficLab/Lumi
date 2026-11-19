# TestPlan — KitMail

## 包概述

KitMail 的实现包，包含 13 个主要类型；当前测试覆盖 40 条用例。

平台: macOS 14+, iOS 17+
测试文件: 9 个，用例总数: 43

核心组件（源码目录）:
- `Models/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `KitMail`
- `MailCoreAdapterFactory`
- `MailError`
- `MailSessionServing`
- `MimeMessageDraft`
- `SpikeSmoke`
- `MailLoginType`
- `MailAddress`
- `MailAttachment`
- `MailFolderKind`
- `MailMessageDetail`
- `MailMessageSummary`
- `MailUID`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（1 条）：由 `testModuleExportsSessionProtocols` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailModels**（11 条）：由 `testAddressRoundTrip`、`testAddressRFC5322`、`testAddressHashable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailSessionProtocol**（13 条）：由 `testModuleExportsSessionProtocols`、`testMockSessionFullFlow`、`testMockSessionAuthFailure`、`testSentAppendUsesSeenWithoutDraft`、`testDraftAppendUsesDraftFlag` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MimeMessageBuilder**（5 条）：由 `testBuildAndParseRoundTrip`、`testPlainOnlyBuild`、`testReplyHeaders` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailUID**（2 条）：由 `testValidatedAcceptsProtocolRange`、`testValidatedRejectsZeroAndOutOfRange` 等用例锁定；改动 UID 边界时优先跑对应测试文件。
- **MailCoreCallbackBridge**（4 条）：由 `testVoidOperationSucceedsWithoutValue`、`testValueOperationStillRejectsMissingValue` 等用例锁定；改动回调桥接或错误判定时优先跑对应测试文件。
- **MailCoreAdapterAttachment**（4 条）：由 `testFetchAttachmentsKeepsFilenamelessAttachment`、`testFetchAttachmentsAssignsUniqueNamesToMultipleFilenamelessAttachments` 等用例锁定；改动附件遍历、文件名回退或落盘映射时优先跑对应测试文件。
- **MailCoreAdapterConnectionType**（3 条）：由 `testSMTPOnPort587UsesSTARTTLSEvenWithUseTLS`、`testSMTPOnPort465KeepsImplicitTLS`、`testSMTPFollowsUseTLSFlagOnOtherPorts` 锁定；SMTP 587 必须 STARTTLS、465 隐式 TLS、其余端口跟随 useTLS（issue #309）。

> **#403 变异验证**（`MailCoreAdapterAppendFlagsTests`）：把适配层标记选择 `isDraft ? .draft : .seen` 改为恒 `.draft`（复现原 bug）→ `testSentAppendUsesSeenWithoutDraft` 失败（记录到 `.draft`=16 而非 `.seen`=1，且含 `\Draft`），`testDraftAppendUsesDraftFlag` 仍 GREEN。该变异锁定「已发送归档不得带 `\Draft`」的适配层不变量； composer 侧调用点的变异见 PluginMail TestPlan。

> **#844 变异验证**（`MailCoreAdapterAttachmentTests`）：两处变异均令全部 4 条用例 RED。① 把 `parser.attachments()` 改回 `parser.attachments`（漏写括号的 ObjC 方法引用，转数组恒失败 → parts 恒空）→ 连有名附件也被丢弃（`testFetchAttachmentsPreservesNamedAttachmentAndOrder` 返回 0）；② 把文件名回退 `attachment_\(index + 1)` 改回 `guard let filename = part.filename, !filename.isEmpty else { continue }`（复现原 bug）→ 无名/空名附件被丢弃。两处变异分别锁定「附件 part 必须真正取到」与「无 filename 的合法附件不得丢弃」两条不变量。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | testModuleExportsSessionProtocols | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testModuleExportsSessionProtocols` |
| 2 | MailModels | testAddressRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAddressRoundTrip` |
| 3 | MailModels | testAddressRFC5322 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAddressRFC5322` |
| 4 | MailModels | testAddressHashable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAddressHashable` |
| 5 | MailModels | testAccountConfigRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAccountConfigRoundTrip` |
| 6 | MailModels | testAccountConfigDefaultTLS | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testAccountConfigDefaultTLS` |
| 7 | MailModels | testFolderKindInference | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFolderKindInference` |
| 8 | MailModels | testFolderNameFromPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFolderNameFromPath` |
| 9 | MailModels | testFolderRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFolderRoundTrip` |
| 10 | MailModels | testSummaryRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSummaryRoundTrip` |
| 11 | MailModels | testMailErrorRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMailErrorRoundTrip` |
| 12 | MailModels | testMailErrorLocalizationKeys | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMailErrorLocalizationKeys` |
| 13 | MailSessionProtocol | testModuleExportsSessionProtocols | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testModuleExportsSessionProtocols` |
| 14 | MailSessionProtocol | testMockSessionFullFlow | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMockSessionFullFlow` |
| 15 | MailSessionProtocol | testMockSessionAuthFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMockSessionAuthFailure` |
| 16 | MailSessionProtocol | testMockSessionFetchFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMockSessionFetchFailure` |
| 17 | MailSessionProtocol | testMockSessionNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMockSessionNotFound` |
| 18 | MailSessionProtocol | testMapsAuthError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMapsAuthError` |
| 19 | MailSessionProtocol | testMapsNetworkErrors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMapsNetworkErrors` |
| 20 | MailSessionProtocol | testMapsNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMapsNotFound` |
| 21 | MailSessionProtocol | testMapsUnknownToProtocol | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMapsUnknownToProtocol` |
| 22 | MailSessionProtocol | testMapsForeignDomainToProtocol | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMapsForeignDomainToProtocol` |
| 23 | MimeMessageBuilder | testBuildAndParseRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBuildAndParseRoundTrip` |
| 24 | MimeMessageBuilder | testPlainOnlyBuild | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPlainOnlyBuild` |
| 25 | MimeMessageBuilder | testReplyHeaders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReplyHeaders` |
| 26 | MimeMessageBuilder | testQuotedReplyText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testQuotedReplyText` |
| 27 | MimeMessageBuilder | testReplyReferencesChain | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReplyReferencesChain` |
| 28 | MailUID | 1 与 UInt32.max 可安全收窄 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testValidatedAcceptsProtocolRange` |
| 29 | MailUID | 0、UInt32.max+1、UInt64.max 返回 nil 而非 trap | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testValidatedRejectsZeroAndOutOfRange` |
| 30 | MailSessionProtocol | 文件夹列表使用 IMAP LIST（全部文件夹），不退化为 LSUB（仅已订阅） | 用记录调用的 MCOIMAPSession 子类替换会话 | 调用 `MailCoreAdapter.fetchFoldersOperation(using:)` | 仅调用 `fetchAllFoldersOperation`，未调用 `fetchSubscribedFoldersOperation` | P1 | ✅ 已覆盖 | `testFolderListingRequestsAllFoldersNotSubscribed` |
| 31 | MailCoreCallbackBridge | 回归 #1073：Void 操作回调 `(nil, nil)` 视为成功，不再误判为 empty result | 使用内部桥接并注入回调 | 调用 `performVoid` 并回调 `completion(nil)` | 正常返回，不抛错 | P0 | ✅ 已覆盖 | `testVoidOperationSucceedsWithoutValue` |
| 32 | MailCoreCallbackBridge | Void 操作的回调错误按 MCOErrorCode 映射为 MailError | 回调携带认证错误 | 调用 `performVoid` | 抛出 `.authFailed` | P1 | ✅ 已覆盖 | `testVoidOperationSurfacesMappedError` |
| 33 | MailCoreCallbackBridge | Void 操作回调超时归为网络错误，且不会二次 resume | 回调永不触发，超时 0.05s | 调用 `performVoid` | 抛出 `.network` | P1 | ✅ 已覆盖 | `testVoidOperationTimesOutWhenCallbackNeverFires` |
| 34 | MailCoreCallbackBridge | 有返回值操作仍拒绝「无错误且无值」的回调，避免语义混淆 | 回调为 `(nil, nil)` | 调用 `perform` 取 `Data` | 抛出 `.protocolError("empty result")` | P1 | ✅ 已覆盖 | `testValueOperationStillRejectsMissingValue` |
| 35 | MailSessionProtocol | 回归 #403：已发送归档用 `\Seen`，Sent 副本不得带 `\Draft` | 用记录 APPEND 标记的 MCOIMAPSession 子类替换会话 | 以 `isDraft: false` 调用 `MailCoreAdapter.appendMessageOperation(using:folder:mime:isDraft:)` | 标记为 `.seen` 且不含 `.draft` | P0 | ✅ 已覆盖 | `testSentAppendUsesSeenWithoutDraft` |
| 36 | MailSessionProtocol | 草稿归档仍用 `\Draft`，与已发送归档区分 | 用记录 APPEND 标记的 MCOIMAPSession 子类替换会话 | 以 `isDraft: true` 调用 `MailCoreAdapter.appendMessageOperation(using:folder:mime:isDraft:)` | 标记为 `.draft` | P1 | ✅ 已覆盖 | `testDraftAppendUsesDraftFlag` |
| 37 | MailCoreAdapterAttachment | 回归 #844：`Content-Disposition: attachment` 无 filename 的合法附件不得被丢弃，生成确定性回退名并保留数据 | 构造含无名附件的 multipart/mixed MIME 并解析 | 调用 `fetchAttachments(for:uid:folder:)` | 返回 1 个附件，名为 `attachment_1`，mimeType 与 data 与原始字节一致 | P0 | ✅ 已覆盖 | `testFetchAttachmentsKeepsFilenamelessAttachment` |
| 38 | MailCoreAdapterAttachment | 回归 #844：空文件名附件不得被丢弃，回退为序号名 | 构造 filename="" 的附件 MIME 并解析 | 调用 `fetchAttachments(for:uid:folder:)` | 返回 1 个附件，名为 `attachment_1`，保留 mimeType 与 data | P1 | ✅ 已覆盖 | `testFetchAttachmentsKeepsEmptyFilenameAttachment` |
| 39 | MailCoreAdapterAttachment | 回归 #844：同一消息多个无名附件的回退名互不覆盖 | 构造两个无名附件的 MIME 并解析 | 调用 `fetchAttachments(for:uid:folder:)` | 返回 2 个附件，名为 `attachment_1`/`attachment_2`，data 各自对应 | P0 | ✅ 已覆盖 | `testFetchAttachmentsAssignsUniqueNamesToMultipleFilenamelessAttachments` |
| 40 | MailCoreAdapterAttachment | 回归 #844：有名附件保留原名与原始顺序，与无名附件共存 | 构造 named+unnamed 附件的 MIME 并解析 | 调用 `fetchAttachments(for:uid:folder:)` | 返回 `["report.pdf", "attachment_2"]`，顺序与 data 不变 | P1 | ✅ 已覆盖 | `testFetchAttachmentsPreservesNamedAttachmentAndOrder` |
| 41 | MailCoreAdapterConnectionType | SMTP 587 即使 useTLS=true 也必须走 STARTTLS（回归 #309） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testSMTPOnPort587UsesSTARTTLSEvenWithUseTLS` |
| 42 | MailCoreAdapterConnectionType | SMTP 465 保持隐式 TLS 直连（回归 #309） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSMTPOnPort465KeepsImplicitTLS` |
| 43 | MailCoreAdapterConnectionType | 其余端口 SMTP 连接类型跟随 useTLS 开关（回归 #309） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSMTPFollowsUseTLSFlagOnOtherPorts` |

> 说明：全部 **40 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 36 / 36
- P2: 已覆盖 1 / 1
- **合计: 43 / 43**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（36 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 43 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitMail
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
