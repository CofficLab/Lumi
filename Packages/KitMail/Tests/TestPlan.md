# TestPlan — KitMail

## 包概述

KitMail 的实现包，包含 12 个主要类型；当前测试覆盖 27 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 27

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

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（1 条）：由 `testModuleExportsSessionProtocols` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailModels**（11 条）：由 `testAddressRoundTrip`、`testAddressRFC5322`、`testAddressHashable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailSessionProtocol**（10 条）：由 `testModuleExportsSessionProtocols`、`testMockSessionFullFlow`、`testMockSessionAuthFailure` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MimeMessageBuilder**（5 条）：由 `testBuildAndParseRoundTrip`、`testPlainOnlyBuild`、`testReplyHeaders` 等用例锁定；改动该模块时优先跑对应测试文件。

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

> 说明：全部 **27 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 26 / 26
- P2: 已覆盖 1 / 1
- **合计: 27 / 27**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（26 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 27 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
