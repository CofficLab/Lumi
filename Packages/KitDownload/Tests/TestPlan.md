# TestPlan — KitDownload

## 包概述

KitDownload KitDownload 是 Lumi 项目中负责下载相关能力的 Package。

平台: macOS 14+, iOS 17+
测试文件: 10 个，用例总数: 79

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DownloadError`
- `DownloadManager`
- `DownloadProgress`
- `DownloadTask`
- `FileValidator`
- `HTTPClient`
- `KitDownloadLocalization`
- `RateLimiter`
- `ResumeHandler`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DefaultHTTPClient**（8 条）：由 `freshDownloadWritesEntireBody`、`nonSuccessStatusThrowsWithoutWritingFile`、`resumeAppendsWithRangeRequest` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadConfigurationAndState**（4 条）：由 `defaults`、`customOverrides`、`nonFinal` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadCoverage**（7 条）：由 `convenienceDownload`、`resumeWithoutPartialFile`、`isCompleteMissingFile` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadError**（2 条）：由 `errorDescriptionsNotEmpty`、`errorEquality` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadManager**（18 条）：由 `downloadSuccess`、`downloadFailure`、`getTaskState` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadProgress**（8 条）：由 `defaultProgress`、`fractionCompletedCalculation`、`zeroTotalBytes` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadTask**（5 条）：由 `taskCreation`、`incompleteURL`、`customId` 等用例锁定；改动该模块时优先跑对应测试文件。
- **FileValidator**（8 条）：由 `validateExistingFile`、`validateNonExistentFile`、`validateEmptyFile` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RateLimiter**（10 条）：由 `unlimitedRateLimiterReturnsImmediately`、`staticUnlimitedInstance`、`rateLimiterEnforcesSpeedLimit` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeHandler**（9 条）：由 `saveAndGetResumeData`、`removeResumeData`、`appendDataCreatesMissingDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DefaultHTTPClient | freshDownloadWritesEntireBody | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `freshDownloadWritesEntireBody` |
| 2 | DefaultHTTPClient | nonSuccessStatusThrowsWithoutWritingFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonSuccessStatusThrowsWithoutWritingFile` |
| 3 | DefaultHTTPClient | resumeAppendsWithRangeRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumeAppendsWithRangeRequest` |
| 4 | DefaultHTTPClient | serverIgnoringRangeRestartsFromScratch | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `serverIgnoringRangeRestartsFromScratch` |
| 5 | DefaultHTTPClient | customHeadersReachServerRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customHeadersReachServerRequest` |
| 6 | DefaultHTTPClient | largeBodyStreamsThroughBufferedWrites | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `largeBodyStreamsThroughBufferedWrites` |
| 7 | DefaultHTTPClient | resumeWithContentLengthOnlyReportsCumulativeTotal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumeWithContentLengthOnlyReportsCumulativeTotal` |
| 8 | DefaultHTTPClient | defaultHeadersImplementationFallsBackGracefully | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `defaultHeadersImplementationFallsBackGracefully` |
| 9 | DownloadConfigurationAndState | 默认配置：并发 3、超时 3600、启用续传、不限速 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `defaults` |
| 10 | DownloadConfigurationAndState | 自定义配置覆盖默认值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `customOverrides` |
| 11 | DownloadConfigurationAndState | 非终态：pending / downloading | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonFinal` |
| 12 | DownloadConfigurationAndState | 终态：completed / failed / cancelled | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `finalStates` |
| 13 | DownloadCoverage | convenience download without rate limit writes whole body | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convenienceDownload` |
| 14 | DownloadCoverage | resume with missing partial file starts fresh | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumeWithoutPartialFile` |
| 15 | DownloadCoverage | isComplete returns false for missing file | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isCompleteMissingFile` |
| 16 | DownloadCoverage | downloading same task twice throws and failure marks state failed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `duplicateTaskAndFailureState` |
| 17 | DownloadCoverage | DefaultHTTPClient 无请求头方法委托到带请求头版本 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultClientNoHeadersOverloadDelegates` |
| 18 | DownloadCoverage | 网络中途断开时抛出错误且已写字节保留在磁盘 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `midStreamFailureThrowsAndKeepsWrittenBytes` |
| 19 | DownloadCoverage | 本地化查找未命中时回退返回 key 本身 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localizationFallsBackToKey` |
| 20 | DownloadError | 错误描述不为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `errorDescriptionsNotEmpty` |
| 21 | DownloadError | 错误相等性 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorEquality` |
| 22 | DownloadManager | 下载文件成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `downloadSuccess` |
| 23 | DownloadManager | 下载失败抛出错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `downloadFailure` |
| 24 | DownloadManager | 获取任务状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getTaskState` |
| 25 | DownloadManager | 取消下载 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelDownload` |
| 26 | DownloadManager | 进度回调被调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `progressCallback` |
| 27 | DownloadManager | 已完整文件不重复下载 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `skipExistingFile` |
| 28 | DownloadManager | 取消所有下载 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelAll` |
| 29 | DownloadManager | 取消后可重新下载同 id 任务（暂停/恢复回归） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reDownloadAfterCancel` |
| 30 | DownloadManager | cancelAll 后可重新下载同 id 任务（暂停/恢复回归） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reDownloadAfterCancelAll` |
| 31 | DownloadManager | 磁盘部分文件作为续传起点传给 HTTPClient（字节级续传回归） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `existingBytesDrivenFromPartialFile` |
| 32 | DownloadManager | 无文件时 existingBytes 为 0（全新下载） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `existingBytesZeroForFreshDownload` |
| 33 | DownloadManager | 禁用续传时忽略部分文件（existingBytes 为 0） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `existingBytesIgnoredWhenResumeDisabled` |
| 34 | DownloadManager | setMaxBytesPerSecond 在默认 client 下生效并返回 true | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `setMaxBytesPerSecondWithDefaultClient` |
| 35 | DownloadManager | setMaxBytesPerSecond 在注入 client 下返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setMaxBytesPerSecondWithInjectedClient` |
| 36 | DownloadManager | DownloadTask.headers 被传给 HTTPClient（不丢弃） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `taskHeadersForwardedToClient` |
| 37 | DownloadManager | 每个进度事件只投递一次（无重复回调） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `progressDeliveredExactlyOnce` |
| 38 | DownloadManager | expectedSize 为 nil 时最终进度取实际文件大小 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `finalProgressUsesActualFileSize` |
| 39 | DownloadManager | 下载完成后再 cancel 不改写 completed 状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelAfterCompletionKeepsCompletedState` |
| 40 | DownloadProgress | 默认进度为 0 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultProgress` |
| 41 | DownloadProgress | 进度百分比计算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fractionCompletedCalculation` |
| 42 | DownloadProgress | 总字节数为 0 时进度为 0 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroTotalBytes` |
| 43 | DownloadProgress | 总字节数为 nil 时进度为 0 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nilTotalBytes` |
| 44 | DownloadProgress | 速度标签格式正确 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `speedLabelFormatting` |
| 45 | DownloadProgress | 速度为 0 时标签为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `zeroSpeedLabel` |
| 46 | DownloadProgress | 进度相等性 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `progressEquality` |
| 47 | DownloadProgress | 文件进度计算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileProgress` |
| 48 | DownloadTask | 任务创建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `taskCreation` |
| 49 | DownloadTask | 未完成文件路径正确 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `incompleteURL` |
| 50 | DownloadTask | 自定义 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customId` |
| 51 | DownloadTask | 自定义请求头 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customHeaders` |
| 52 | DownloadTask | 任务状态相等性 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `taskStateEquality` |
| 53 | FileValidator | 验证存在的文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateExistingFile` |
| 54 | FileValidator | 验证不存在的文件抛出错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateNonExistentFile` |
| 55 | FileValidator | 验证空文件抛出错误 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `validateEmptyFile` |
| 56 | FileValidator | 验证文件大小不匹配抛出错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateSizeMismatch` |
| 57 | FileValidator | 验证文件大小匹配成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateSizeMatch` |
| 58 | FileValidator | 检查完整文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isCompleteWithCompleteFile` |
| 59 | FileValidator | 检查不完整文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isCompleteWithIncompleteFile` |
| 60 | FileValidator | 检查不存在的文件返回 false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isCompleteWithNonExistentFile` |
| 61 | RateLimiter | 不限速时立即返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unlimitedRateLimiterReturnsImmediately` |
| 62 | RateLimiter | 静态不限速实例 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staticUnlimitedInstance` |
| 63 | RateLimiter | 限速器正确限制速率 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rateLimiterEnforcesSpeedLimit` |
| 64 | RateLimiter | 零字节申请立即返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroBytesReturnsImmediately` |
| 65 | RateLimiter | 负数字节申请立即返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `negativeBytesReturnsImmediately` |
| 66 | RateLimiter | 小量数据在令牌桶容量内立即返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `smallAmountWithinBucketCapacity` |
| 67 | RateLimiter | 运行时改为不限速后立即放行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateToUnlimitedUnblocksWaitingAcquire` |
| 68 | RateLimiter | 运行时调低限速后按新值限速 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateToLowerLimitEnforcesNewRate` |
| 69 | RateLimiter | 限速值为 0 视为不限速（避免令牌永不累积导致死等） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroLimitTreatedAsUnlimited` |
| 70 | RateLimiter | 等待令牌期间任务被取消时抛出 CancellationError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acquireThrowsCancellationWhenTaskCancelledWhileWaiting` |
| 71 | ResumeHandler | 保存和获取断点续传数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveAndGetResumeData` |
| 72 | ResumeHandler | 移除断点续传数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeResumeData` |
| 73 | ResumeHandler | appendData 自动创建缺失的目标目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendDataCreatesMissingDirectory` |
| 74 | ResumeHandler | 获取不存在的断点续传数据返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getNonExistentResumeData` |
| 75 | ResumeHandler | 获取部分文件大小 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getPartialFileSize` |
| 76 | ResumeHandler | 不存在的部分文件大小为 0 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getPartialFileSizeForNonExistent` |
| 77 | ResumeHandler | 追加数据到文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendData` |
| 78 | ResumeHandler | 完成下载重命名文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `finalizeDownload` |
| 79 | ResumeHandler | 完成下载覆盖已存在的文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `finalizeDownloadOverwrite` |

> 说明：全部 **79 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 67 / 67
- P2: 已覆盖 8 / 8
- **合计: 79 / 79**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（67 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（8 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 79 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitDownload
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
