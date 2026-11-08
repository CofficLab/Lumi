# TestPlan — PluginMail

## 包概述

PluginMail 的实现包，包含 15 个主要类型；当前测试覆盖 61 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 61

核心组件（源码目录）:
- `Agent/`
- `Services/`
- `Support/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MailPlugin`
- `MailAgentToolService`
- `MailAccountDraft`
- `MailAccountDraftError`
- `MailAccountStore`
- `MailCacheItem`
- `MailCacheService`
- `MailComposerService`
- `MailProviderPreset`
- `MailSessionManager`
- `MailSyncStats`
- `MailPluginLocalStore`
- `MailPluginRuntime`
- `MailAccountFormView`
- `MailComposeView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MailAccountStore**（26 条）：由 `testUpsertAndLoad`、`testUpsertUpdatesExistingByID`、`testDeleteRemovesAccountAndPassword` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailAgentTools**（10 条）：由 `testRiskLevelsAndCapabilities`、`testListMessagesWithoutAccount`、`testListMessagesReturnsRecentSummaries` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailComposerService**（8 条）：由 `testSendBuildsMIMEAndAppendsToSent`、`testSendThrowsAuthFailedWithoutPassword`、`testSentFolderDiscoveryPrefersSentKind` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailSessionManager**（5 条）：由 `testSessionCachesByAccount`、`testSessionThrowsAuthFailedWhenPasswordMissing`、`testSessionThrowsAuthFailedOnBadCredentials` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailSyncService**（10 条）：由 `testUpsertAndLastUID`、`testContainsAndOverwrite`、`testUnreadCounts` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailPluginRuntime**（2 条）：由 `usesInjectedDirectory`、`refusesFallbackWithoutInjection` 锁定；改动数据目录解析时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MailAccountStore | testUpsertAndLoad | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpsertAndLoad` |
| 2 | MailAccountStore | testUpsertUpdatesExistingByID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpsertUpdatesExistingByID` |
| 3 | MailAccountStore | testDeleteRemovesAccountAndPassword | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDeleteRemovesAccountAndPassword` |
| 4 | MailAccountStore | testPasswordRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPasswordRoundTrip` |
| 5 | MailAccountStore | testStoredConfigLandsInPluginDirectoryWithoutPassword | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStoredConfigLandsInPluginDirectoryWithoutPassword` |
| 6 | MailAccountStore | testLoadEmptyWhenNoConfigFileExists | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testLoadEmptyWhenNoConfigFileExists` |
| 7 | MailAccountStore | testPresetHostsAndPorts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPresetHostsAndPorts` |
| 8 | MailAccountStore | testInferFromIMAPHost | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInferFromIMAPHost` |
| 9 | MailAccountStore | testToConfigMapsTypes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToConfigMapsTypes` |
| 10 | MailAccountStore | testApplyPresetKeepsCustomHosts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testApplyPresetKeepsCustomHosts` |
| 11 | MailAgentTools | testRiskLevelsAndCapabilities | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRiskLevelsAndCapabilities` |
| 12 | MailAgentTools | testListMessagesWithoutAccount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListMessagesWithoutAccount` |
| 13 | MailAgentTools | testListMessagesReturnsRecentSummaries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListMessagesReturnsRecentSummaries` |
| 14 | MailAgentTools | testReadMessageMarksAsReadAndReturnsBody | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadMessageMarksAsReadAndReturnsBody` |
| 15 | MailAgentTools | testSearchMessagesFindsCachedHits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSearchMessagesFindsCachedHits` |
| 16 | MailAgentTools | testSendMessageSendsAndAppends | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendMessageSendsAndAppends` |
| 17 | MailAgentTools | testSendMessageThrowsAuthFailedWithoutCredentials | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendMessageThrowsAuthFailedWithoutCredentials` |
| 18 | MailComposerService | testSendBuildsMIMEAndAppendsToSent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendBuildsMIMEAndAppendsToSent` |
| 19 | MailComposerService | testSendThrowsAuthFailedWithoutPassword | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendThrowsAuthFailedWithoutPassword` |
| 20 | MailComposerService | testSentFolderDiscoveryPrefersSentKind | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSentFolderDiscoveryPrefersSentKind` |
| 21 | MailComposerService | testNewModeDefaultsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testNewModeDefaultsEmpty` |
| 22 | MailComposerService | testReplyModePrefills | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReplyModePrefills` |
| 23 | MailComposerService | testReplyPrefixNotDuplicated | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReplyPrefixNotDuplicated` |
| 24 | MailComposerService | testForwardModePrefills | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testForwardModePrefills` |
| 25 | MailComposerService | testSendFailureRetainsDraftState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendFailureRetainsDraftState` |
| 26 | MailSessionManager | testSessionCachesByAccount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionCachesByAccount` |
| 27 | MailSessionManager | testSessionThrowsAuthFailedWhenPasswordMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionThrowsAuthFailedWhenPasswordMissing` |
| 28 | MailSessionManager | testSessionThrowsAuthFailedOnBadCredentials | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionThrowsAuthFailedOnBadCredentials` |
| 29 | MailSessionManager | testDisconnectAndDisconnectAll | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDisconnectAndDisconnectAll` |
| 30 | MailSessionManager | testTestConnectionDoesNotCache | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTestConnectionDoesNotCache` |
| 31 | MailAccountStore | testDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testDefaults` |
| 32 | MailSyncService | testUpsertAndLastUID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpsertAndLastUID` |
| 33 | MailSyncService | testContainsAndOverwrite | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testContainsAndOverwrite` |
| 34 | MailSyncService | testUnreadCounts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUnreadCounts` |
| 35 | MailSyncService | testRemoveKeepingAndPurge | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRemoveKeepingAndPurge` |
| 36 | MailSyncService | testSearchMatchesSubjectAndFrom | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSearchMatchesSubjectAndFrom` |
| 37 | MailSyncService | testIncrementalSyncInsertsNewOnly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIncrementalSyncInsertsNewOnly` |
| 38 | MailSyncService | testIncrementalSyncSkipsAlreadyCached | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIncrementalSyncSkipsAlreadyCached` |
| 39 | MailSyncService | testFullSyncRemovesDeleted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFullSyncRemovesDeleted` |
| 40 | MailSyncService | testIncrementalSyncDoesNotDelete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIncrementalSyncDoesNotDelete` |
| 41 | MailSyncService | testSyncMultipleFolders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSyncMultipleFolders` |
| 42 | MailAccountDraft | 端口为 -1/0/65536/70000 时 toConfig 抛校验错误而非 UInt16 转换 trap | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testToConfigRejectsOutOfRangePorts` |
| 43 | MailAccountDraft | 端口边界 1 与 65535 可正常转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToConfigAcceptsPortBoundaries` |
| 44 | MailAgentTools | 读取邮件 uid 超过 UInt32.max 时返回参数错误且不触达会话层 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testReadMessageRejectsUIDAboveUInt32` |
| 45 | MailAccountStore | testEmptyStringPasswordIsTreatedAsDelete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEmptyStringPasswordIsTreatedAsDelete` |
| 46 | MailAccountStore | testAccountsSurviveANewStoreInstance | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAccountsSurviveANewStoreInstance` |
| 47 | MailAccountStore | testCorruptConfigIsQuarantinedAndReadsAsEmpty | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCorruptConfigIsQuarantinedAndReadsAsEmpty` |
| 48 | MailAccountStore | testLegacyAccountsAreImportedIntoPlist | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLegacyAccountsAreImportedIntoPlist` |
| 49 | MailAccountStore | testLegacyKeyIsClearedAfterSuccessfulMigration | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLegacyKeyIsClearedAfterSuccessfulMigration` |
| 50 | MailAccountStore | testMigrationIsIdempotentAcrossRestarts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMigrationIsIdempotentAcrossRestarts` |
| 51 | MailAccountStore | testNoLegacyDataLeavesStoreEmpty | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoLegacyDataLeavesStoreEmpty` |
| 52 | MailAccountStore | testCorruptLegacyDataIsPreservedAndNotMarkedMigrated | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCorruptLegacyDataIsPreservedAndNotMarkedMigrated` |
| 53 | MailAccountStore | testExistingAccountsAreNotOverwrittenByLegacyData | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testExistingAccountsAreNotOverwrittenByLegacyData` |
| 54 | MailAccountStore | testRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRoundTrip` |
| 55 | MailAccountStore | testPreferencesLandInPluginDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPreferencesLandInPluginDirectory` |
| 56 | MailAccountStore | testPreferencesSurviveNewStoreInstance | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPreferencesSurviveNewStoreInstance` |
| 57 | MailAccountStore | testCorruptPreferencesAreQuarantined | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCorruptPreferencesAreQuarantined` |
| 58 | MailPluginRuntime | usesInjectedDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesInjectedDirectory` |
| 59 | MailPluginRuntime | refusesFallbackWithoutInjection | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refusesFallbackWithoutInjection` |
| 60 | MailAgentTools | limit 为 -1/0/51 时返回参数错误，避免 `suffix` 负数导致进程终止 | 已配置账户 | 以越界 `limit` 调用 `mail_list_messages` | 抛出 `ToolExecutionError`，错误信息指出 limit 非法 | P0 | ✅ 已覆盖 | `testListMessagesRejectsOutOfRangeLimit` |
| 61 | MailAgentTools | limit schema 声明 1...50 范围 | — | 读取 `mail_list_messages` 的 inputSchema | `minimum` 为 1、`maximum` 为 50 | P1 | ✅ 已覆盖 | `testListMessagesLimitSchemaDeclaresRange` |

> 说明：全部 **61 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 51 / 51
- P2: 已覆盖 3 / 3
- **合计: 61 / 61**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（51 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 61 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMail
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
