# TestPlan — KitKeychain

## 包概述

KitKeychain KitKeychain 是 Lumi 项目中负责密钥链存储相关能力的 Package。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 42

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `KeychainResult`
- `KeychainStatus`
- `KeychainStore`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **KeychainStoreAdditionalCoverage**（7 条）：由 `transientThenSuccessRecovers`、`defaultReadAllowsInteraction`、`stringWithoutPromptSuccess` 等用例锁定；改动该模块时优先跑对应测试文件。
- **KeychainStoreCoverage**（26 条）：由 `testTransientRetryDelayDoublesExponentially`、`testTransientFailureSleepsBetweenRetriesWithBackoff`、`testClassifySuccessWithData` 等用例锁定；改动该模块时优先跑对应测试文件。
- **KeychainStore**（9 条）：由 `testReportingReadReturnsValue`、`testReportingReadReturnsNilOnlyForMissingItem`、`testFalseNotFoundCanLookMissingUntilANewReadFindsExistingItem` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | KeychainStoreAdditionalCoverage | 瞬时失败后重试成功，且只在第一次前退避一次 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `transientThenSuccessRecovers` |
| 2 | KeychainStoreAdditionalCoverage | 瞬时失败后 read 允许交互（默认路径） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultReadAllowsInteraction` |
| 3 | KeychainStoreAdditionalCoverage | stringWithoutPrompt 成功返回值且以 allowInteraction=false 读取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stringWithoutPromptSuccess` |
| 4 | KeychainStoreAdditionalCoverage | 无提示迁移：keychain 为空时从 UserDefaults 迁移并写回 keychain | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `noPromptMigrationMigratesLegacyValue` |
| 5 | KeychainStoreAdditionalCoverage | 迁移时 keychain 写入失败则抛错且保留 legacy 值不丢失 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `migrationPropagatesWriteFailure` |
| 6 | KeychainStoreAdditionalCoverage | keychain 已有值时不触发 UserDefaults 迁移 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `prefersKeychainOverLegacy` |
| 7 | KeychainStoreAdditionalCoverage | KeychainBackend 扩展 read(service:account:) 默认 allowInteraction=true | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `backendExtensionDefaultsToInteractive` |
| 8 | KeychainStoreCoverage | testTransientRetryDelayDoublesExponentially | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTransientRetryDelayDoublesExponentially` |
| 9 | KeychainStoreCoverage | testTransientFailureSleepsBetweenRetriesWithBackoff | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTransientFailureSleepsBetweenRetriesWithBackoff` |
| 10 | KeychainStoreCoverage | testClassifySuccessWithData | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testClassifySuccessWithData` |
| 11 | KeychainStoreCoverage | testClassifySuccessWithoutDataIsUnexpected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testClassifySuccessWithoutDataIsUnexpected` |
| 12 | KeychainStoreCoverage | testClassifyMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testClassifyMissing` |
| 13 | KeychainStoreCoverage | testClassifyTransientStatuses | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testClassifyTransientStatuses` |
| 14 | KeychainStoreCoverage | testClassifyUnexpectedStatus | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testClassifyUnexpectedStatus` |
| 15 | KeychainStoreCoverage | testEmptyKeyShortCircuitsAllOperations | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEmptyKeyShortCircuitsAllOperations` |
| 16 | KeychainStoreCoverage | testWriteTrimsWhitespaceBeforeStoring | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWriteTrimsWhitespaceBeforeStoring` |
| 17 | KeychainStoreCoverage | testWriteWhitespaceOnlyValueRemovesKey | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWriteWhitespaceOnlyValueRemovesKey` |
| 18 | KeychainStoreCoverage | testWriteFailureDoesNotDeleteExistingValueFirst | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWriteFailureDoesNotDeleteExistingValueFirst` |
| 19 | KeychainStoreCoverage | testRemoveThrowsDeleteFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRemoveThrowsDeleteFailure` |
| 20 | KeychainStoreCoverage | testNonThrowingWrappersSwallowFailures | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNonThrowingWrappersSwallowFailures` |
| 21 | KeychainStoreCoverage | testObservedStatusReceivesFinalStatus | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testObservedStatusReceivesFinalStatus` |
| 22 | KeychainStoreCoverage | testObservedStatusReceivesLastTransientStatus | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testObservedStatusReceivesLastTransientStatus` |
| 23 | KeychainStoreCoverage | testLegacyMigrationMovesValueToKeychain | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLegacyMigrationMovesValueToKeychain` |
| 24 | KeychainStoreCoverage | testKeychainValueWinsOverLegacy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testKeychainValueWinsOverLegacy` |
| 25 | KeychainStoreCoverage | testWhitespaceOnlyKeychainValueFallsBackToLegacy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWhitespaceOnlyKeychainValueFallsBackToLegacy` |
| 26 | KeychainStoreCoverage | testMigrationReturnsNilWhenBothSourcesEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testMigrationReturnsNilWhenBothSourcesEmpty` |
| 27 | KeychainStoreCoverage | testErrorDescriptions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testErrorDescriptions` |
| 28 | KeychainStoreCoverage | testReadFailedDescriptionIncludesStatus | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadFailedDescriptionIncludesStatus` |
| 29 | KeychainStoreCoverage | testFailedDescriptionFallsBackForUnknownStatus | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFailedDescriptionFallsBackForUnknownStatus` |
| 30 | KeychainStoreCoverage | testMissingEntitlementDescriptionIsActionable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testMissingEntitlementDescriptionIsActionable` |
| 31 | KeychainStoreCoverage | testPromptFreeReadPassesAllowInteractionFalse | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPromptFreeReadPassesAllowInteractionFalse` |
| 32 | KeychainStoreCoverage | testDefaultReadStillAllowsInteraction | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testDefaultReadStillAllowsInteraction` |
| 33 | KeychainStoreCoverage | testPromptFreeReadFoldsInteractionDeniedIntoNil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPromptFreeReadFoldsInteractionDeniedIntoNil` |
| 34 | KeychainStore | testReportingReadReturnsValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReportingReadReturnsValue` |
| 35 | KeychainStore | testReportingReadReturnsNilOnlyForMissingItem | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReportingReadReturnsNilOnlyForMissingItem` |
| 36 | KeychainStore | testFalseNotFoundCanLookMissingUntilANewReadFindsExistingItem | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFalseNotFoundCanLookMissingUntilANewReadFindsExistingItem` |
| 37 | KeychainStore | testReportingReadThrowsUnexpectedOSStatus | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReportingReadThrowsUnexpectedOSStatus` |
| 38 | KeychainStore | testReportingReadRetriesTransientFailureThenThrowsStatus | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReportingReadRetriesTransientFailureThenThrowsStatus` |
| 39 | KeychainStore | testReportingReadRejectsInvalidUTF8 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testReportingReadRejectsInvalidUTF8` |
| 40 | KeychainStore | testReportingReadRejectsSuccessWithoutData | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testReportingReadRejectsSuccessWithoutData` |
| 41 | KeychainStore | testReportingWritePreservesFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReportingWritePreservesFailure` |
| 42 | KeychainStore | testReportingRemoveTreatsAlreadyMissingAsSuccess | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReportingRemoveTreatsAlreadyMissingAsSuccess` |

> 说明：全部 **42 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 29 / 29
- P2: 已覆盖 8 / 8
- **合计: 42 / 42**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（29 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（8 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 42 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitKeychain
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
