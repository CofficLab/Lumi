# TestPlan — PluginFileLog

## 包概述

PluginFileLog 的实现包，包含 2 个主要类型；当前测试覆盖 20 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 11

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `FileLogCoordinator`
- `FileLogPlugin`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **FileLogCoordinator**（20 条）：由 `preparesLogDirectory`、`matchesLumiAndKitLLMSubsystems`、`recordsReadyToWriteAreChronologicalStableAndRespectCutoff` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | FileLogCoordinator | preparesLogDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preparesLogDirectory` |
| 2 | FileLogCoordinator | matchesLumiAndKitLLMSubsystems | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchesLumiAndKitLLMSubsystems` |
| 3 | FileLogCoordinator | recordsReadyToWriteAreChronologicalStableAndRespectCutoff | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `recordsReadyToWriteAreChronologicalStableAndRespectCutoff` |
| 4 | FileLogCoordinator | startAndStopCreateACompleteHeaderLog | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startAndStopCreateACompleteHeaderLog` |
| 5 | FileLogCoordinator | startupPurgesOldestLogsUntilDirectoryIsWithinItsLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startupPurgesOldestLogsUntilDirectoryIsWithinItsLimit` |
| 6 | FileLogCoordinator | migratesLegacyLogsIntoPluginIDDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `migratesLegacyLogsIntoPluginIDDirectory` |
| 7 | FileLogCoordinator | migrationPreservesCollisionsAndLeavesNonLogFilesAlone | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `migrationPreservesCollisionsAndLeavesNonLogFilesAlone` |
| 8 | FileLogCoordinator | migrationSkipsMissingOrIdenticalDirectoriesAndRemovesAnEmptyLegacyDirectory | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `migrationSkipsMissingOrIdenticalDirectoriesAndRemovesAnEmptyLegacyDirectory` |
| 9 | FileLogCoordinator | createsDiagnosticsArchiveWithLogAndManifest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createsDiagnosticsArchiveWithLogAndManifest` |
| 10 | FileLogCoordinator | pluginMigratesLogsRegistersDiagnosticsAndStops | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginMigratesLogsRegistersDiagnosticsAndStops` |
| 11 | FileLogCoordinator | pluginBootWithoutStorageUsesFallbackAndCanShutDown | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginBootWithoutStorageUsesFallbackAndCanShutDown` |
| 12 | PollingParameters | 默认轮询间隔为 15 秒 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `defaultPollIntervalIsFifteenSeconds` |
| 13 | PollingParameters | 默认写入延迟为 1 秒 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `defaultWriteDelayIsOneSecond` |
| 14 | PollingParameters | 轮询间隔不再导致 logd 100% 占用 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pollIntervalKeepsLogdLoadReasonable` |
| 15 | PollingParameters | 去重集合有容量上界，不会无界增长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `seenRecordKeysAreBounded` |
| 16 | Deduplication | 超出容量时按 FIFO 淘汰最旧的键 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `evictsOldestKeysFirst` |
| 17 | Deduplication | 重复插入不增加容量占用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `duplicateInsertDoesNotGrow` |
| 18 | Deduplication | 容量内不发生淘汰 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `keepsAllKeysWithinCapacity` |
| 19 | WriteCutoff | 读到的日志立即满足写盘条件（cutoff 为当前时刻） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `polledRecordsAreImmediatelyWritable` |
| 20 | WriteCutoff | 修复前的双重滞后语义会留下一条 pending（回归对照） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyCutoffLeavesRecordPending` |

> 说明：全部 **20 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 12 / 12
- P2: 已覆盖 3 / 3
- **合计: 20 / 20**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（9 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 20 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginFileLog
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
