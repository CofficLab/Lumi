# TestPlan — KitDownload

## 包概述

KitDownload KitDownload 是 Lumi 项目中负责下载相关能力的 Package。

平台: macOS 14+, iOS 17+
测试文件: 13 个，用例总数: 95

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
- **DownloadConcurrencyLimit**（3 条）：由 `maxConcurrentDownloadsLimitIsEnforced`、`defaultLimitAllowsThreeConcurrentButNotFour`、`failedDownloadReleasesSlotForQueuedDownload` 锁定 `maxConcurrentDownloads` 必须真正限制并发：名额耗尽时后续下载不得进入 HTTPClient，下载到达任一终态（含失败）必须归还名额并唤醒排队者（**回归 #484**）；改动下载并发调度时优先跑对应测试文件。
- **DownloadCoverage**（7 条）：由 `convenienceDownload`、`resumeWithoutPartialFile`、`isCompleteMissingFile` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadError**（2 条）：由 `errorDescriptionsNotEmpty`、`errorEquality` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadManager**（18 条）：由 `downloadSuccess`、`downloadFailure`、`getTaskState` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadRestartIdentity**（1 条）：由 `cancelledTaskLateCleanupDoesNotAffectRestartedSameID` 锁定取消后以同 id 重启时，旧任务的晚到终态写回与收尾清理必须按代次作废，不得把新任务改成 `.cancelled` 或注销其 `activeTasks`/`progressHandlers`（**回归 #157**）；改动下载取消/重启或状态写回时优先跑对应测试文件。
- **DownloadProgress**（8 条）：由 `defaultProgress`、`fractionCompletedCalculation`、`zeroTotalBytes` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DownloadTask**（5 条）：由 `taskCreation`、`incompleteURL`、`customId` 等用例锁定；改动该模块时优先跑对应测试文件。
- **FileValidator**（10 条）：由 `validateExistingFile`、`validateNonExistentFile`、`validateEmptyFileWithoutExpectationSucceeds`、`validateZeroByteFileWithExpectedZero` 等用例锁定大小匹配必须先于空文件判断，合法零字节文件（含 `expectedSize == 0` 与 nil）不得被误判为 emptyFile 失败（**回归 #159**）；改动该模块时优先跑对应测试文件。
- **ZeroByteDownload**（2 条）：由 `zeroByteDownloadWithNilExpectedSizeCompletes`、`zeroByteDownloadWithZeroExpectedSizeCompletes` 锁定服务器成功返回零字节文件时下载任务必须进入 `.completed`，覆盖 DownloadManager → FileValidator 完整链路（**回归 #159**）；改动下载完成校验时优先跑对应测试文件。
- **RateLimiter**（10 条）：由 `unlimitedRateLimiterReturnsImmediately`、`staticUnlimitedInstance`、`rateLimiterEnforcesSpeedLimit` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeHandler**（12 条）：由 `saveAndGetResumeData`、`removeResumeData`、`appendDataCreatesMissingDirectory`、`finalizeDownloadKeepsExistingFileWhenSourceMissing` 等用例锁定 `finalizeDownload` 必须先校验源文件、再用原子替换覆盖，源缺失或替换失败时不得删除已存在的最终文件（**回归 #160**）；改动该模块时优先跑对应测试文件。

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
| 55 | FileValidator | 无期望大小时合法空文件必须验证成功，不得误判为空文件失败（**回归 #159**） | 成功下载产生的空文件，expectedSize 为 nil | 调用 `validate` | 返回 true，不抛 emptyFile | P0 | ✅ 已覆盖 | `validateEmptyFileWithoutExpectationSucceeds` |
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
| 80 | DefaultHTTPClient | 服务器忽略 Range 时中途失败保留旧文件并清理临时文件 | 目标已有文件，服务器返回 200 且传一部分后断连 | 调用 `download(existingBytes: 旧文件大小)` | 抛错，目标文件内容不变，目录中无临时文件 | P0 | ✅ 已覆盖 | `replacementFailureKeepsExistingFileAndRemovesTemporaryFile` |
| 81 | DefaultHTTPClient | 远程 validator 变化时向服务器发 If-Range，并用完整内容替换部分文件 | 本地部分文件与已保存 validator | 服务器返回 200 完整内容 | 请求带 Range 与 If-Range，最终文件为完整新内容，无临时文件 | P0 | ✅ 已覆盖 | `ifRangeMismatchDownloadsFullBodyAndReplacesPartial` |
| 82 | DefaultHTTPClient | 服务器忽略 If-Range 返回 206 但 ETag 已变时从头重下 | 本地 validator 与响应 ETag 不一致 | 第一次 206、第二次 200 | 共 2 次请求，第二次无 Range，最终文件为新版本完整内容 | P0 | ✅ 已覆盖 | `ignoredIfRangeWithChangedETagRestartsFromScratch` |
| 83 | DefaultHTTPClient | 下载中断后持久化 validator，再次请求可条件续传 | 下载到一半被取消 | 重新下载同一 URL | If-Range 携带原 validator，续传后文件完整，完成后清除 validator | P1 | ✅ 已覆盖 | `interruptedDownloadPersistsValidatorAndResumesConditionally` |
| 84 | DownloadManager | URLSession 的 URLError.cancelled 保持为 cancelled 状态 | 底层客户端抛出 NSURLError -999 | 调用 `download` | 抛出 `DownloadError.cancelled`，任务状态为 `.cancelled` | P1 | ✅ 已覆盖 | `urlSessionCancellationStaysCancelled` |
| 85 | FileValidator | 期望大小为零的空文件必须验证成功，不得误判失败（**回归 #159**） | 空文件，expectedSize 为 0 | 调用 `validate` | 返回 true，不抛 emptyFile | P0 | ✅ 已覆盖 | `validateZeroByteFileWithExpectedZero` |
| 86 | FileValidator | 期望大小为零但文件非空时抛出大小不匹配 | 非空文件，expectedSize 为 0 | 调用 `validate` | 抛出 `DownloadError.sizeMismatch` | P1 | ✅ 已覆盖 | `validateNonEmptyFileWithExpectedZeroThrows` |
| 87 | ZeroByteDownload | expectedSize 为 nil 的零字节下载必须进入完成态，不得误判失败（**回归 #159**） | MockHTTPClient 返回 200 + 空 body，expectedSize 为 nil | 调用 `DownloadManager.download` | 返回目标路径（.completed），磁盘文件 0 字节 | P0 | ✅ 已覆盖 | `zeroByteDownloadWithNilExpectedSizeCompletes` |
| 88 | ZeroByteDownload | expectedSize 为 0 的零字节下载必须进入完成态，不得误判失败（**回归 #159**） | MockHTTPClient 返回 200 + 空 body，expectedSize 为 0 | 调用 `DownloadManager.download` | 返回目标路径（.completed） | P0 | ✅ 已覆盖 | `zeroByteDownloadWithZeroExpectedSizeCompletes` |
| 89 | ResumeHandler | 源文件缺失时不得删除已存在的最终文件（**回归 #160**） | 最终文件已存在且内容有效，未完成源文件不存在 | 调用 `finalizeDownload(from:to:)` | 抛错，最终文件内容不变，目录中无临时文件 | P0 | ✅ 已覆盖 | `finalizeDownloadKeepsExistingFileWhenSourceMissing` |
| 90 | ResumeHandler | 源文件缺失且无最终文件时抛错且不创建任何文件 | 源文件与最终文件均不存在 | 调用 `finalizeDownload(from:to:)` | 抛错，不创建最终文件，目录为空 | P1 | ✅ 已覆盖 | `finalizeDownloadMissingSourceThrowsWithoutCreatingDestination` |
| 91 | ResumeHandler | 原子替换覆盖后只保留最终文件，不残留源或临时文件 | 最终文件与源文件均存在且内容不同 | 调用 `finalizeDownload(from:to:)` | 最终文件为新内容，源文件被消费，目录仅剩最终文件 | P1 | ✅ 已覆盖 | `finalizeDownloadOverwriteLeavesNoResidualFiles` |
| 92 | DownloadRestartIdentity | 取消后以同 id 重启，旧任务的晚到收尾不得取消或注销新任务（**回归 #157**） | 门控 HTTPClient 挂起 A/B 下载，精确控制取消收尾晚于重启 | 启动 A→取消→同 id 启动 B→放行 A 的取消收尾 | B 状态不被改成 `.cancelled` 且仍在下载，同 id 第三个下载仍被去重拒绝 | P0 | ✅ 已覆盖 | `cancelledTaskLateCleanupDoesNotAffectRestartedSameID` |
| 93 | DownloadConcurrencyLimit | maxConcurrentDownloads 必须真正限制并发，名额耗尽时后续下载不得进入 HTTPClient（**回归 #484**） | maxConcurrentDownloads=1，门控 HTTPClient 记录进入次数与峰值并发 | 第一个进入占满名额后启动第二个，再放行第一个 | 放行前仅 1 个进入，放行后第二个才进入，峰值并发为 1 | P0 | ✅ 已覆盖 | `maxConcurrentDownloadsLimitIsEnforced` |
| 94 | DownloadConcurrencyLimit | 默认并发上限 3：四个下载时只有三个进入，第四个排队补位 | 默认配置（maxConcurrentDownloads=3），门控 HTTPClient | 依次启动前三个占满名额，再启动第四个，放行一个 | 第四个放行前不得进入（共 3 个），放行后补位（共 4 个），峰值并发为 3 | P1 | ✅ 已覆盖 | `defaultLimitAllowsThreeConcurrentButNotFour` |
| 95 | DownloadConcurrencyLimit | 下载失败必须归还名额，排队的后续下载得以进入并完成（**回归 #484**） | maxConcurrentDownloads=1，第一个下载放行后失败 | 第一个占满名额后启动第二个，放行第一个使其失败 | 第二个仍被挡住直到第一个失败归还名额，随后进入并完成，峰值并发为 1 | P0 | ✅ 已覆盖 | `failedDownloadReleasesSlotForQueuedDownload` |

> 说明：全部 **95 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> **回归 #484 变异验证**（`DownloadConcurrencyLimitTests`，逐条单独施加后跑、确认 RED 再还原）：
> - **M1** 移除 `performDownload` 的 `await acquireSlot()` + `defer { releaseSlot() }`（完全不门控）→ 93/94/95 全 RED（峰值并发 2 / 4，超出配置）。
> - **M2** `acquireSlot` 容量判断 `> 0` 改成 `>= 0`（多放一个名额）→ 93/94/95 全 RED（峰值并发 2 / 4）。
> - **M3** `releaseSlot` 只 `availableSlots += 1`、不再唤醒 `slotWaiters` 队首（排队者永久饿死）→ 93/94/95 全 RED（后续下载永不进入，`waitUntilStarted` 超时）。
> 三处变异各自独立命中并发上限的不同失效面，还原后 95 条全绿。

## 覆盖率统计

- P0: 已覆盖 15 / 15
- P1: 已覆盖 73 / 73
- P2: 已覆盖 7 / 7
- **合计: 95 / 95**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（15 条）
- **P1**: 其余功能性用例（73 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 95 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
