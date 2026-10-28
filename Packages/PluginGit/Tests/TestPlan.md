# TestPlan — PluginGit

## 包概述

GitPlugin Git integration plugin for Lumi editor.

平台: macOS 14+, iOS 17+
测试文件: 14 个，用例总数: 70

核心组件（源码目录）:
- `Capabilities/`
- `Features/`
- `Models/`
- `Providers/`
- `Renderers/`
- `Services/`
- `Tools/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppGitVM`
- `GitSkillContributor`
- `GitSourceControlPlugin`
- `GitProjectCapability`
- `AutoPushConfig`
- `GitConflictService`
- `GitConflictViewModel`
- `GitIgnoreService`
- `GitIgnoreViewModel`
- `GitLFSService`
- `GitLFSViewModel`
- `GitStashService`
- `GitStashViewModel`
- `GitSubmoduleService`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AutoPushConfig**（3 条）：由 `defaultConfigHasReasonableValues`、`configIsCodable`、`conflictPathsDeduplicate` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitAsyncBridgeCrashRepro**（4 条）：由 `manyParallelDetachedThroughSharedQueue`、`cancellingDetachedTasksMidFlight`、`errorPropagationUnderLoad` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitAsyncBridge**（4 条）：由 `continuationGuardCompletesOnlyOnce`、`gitAsyncBridgeHandlesManyConcurrentCalls`、`gitAsyncBridgePropagatesWorkQueueErrors` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitChangeType**（12 条）：由 `mapsSingleLetterCodes`、`mapsFullWords`、`isCaseInsensitive` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitCommitToolPath**（8 条）：由 `absolutePathShouldBeConvertedToRelative`、`relativePathShouldRemainUnchanged`、`emptyFilesListShouldReturnEmpty` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitIgnoreService**（3 条）：由 `roundTripWriteAndRead`、`parsingRecognizesCommentAndNegationAndDirectory`、`templatesReturnNonEmptyContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitLogStructuredRenderer**（4 条）：由 `structuredPayloadRoundTrips`、`rendererExtractsJSONFromFullContent`、`canRenderMatchesGitLogWithPayload` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitServiceReadingContract**（4 条）：由 `statusSeparatesUntrackedFiles`、`isRepositoryDetectsRepository`、`isRepositoryToleratesMissingPath` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitServiceRemoteURL**（4 条）：由 `readsOriginRemoteURLVerbatim`、`readsNamedRemoteURL`、`returnsNilForUnknownRemote` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitService**（5 条）：由 `getStatusThrowsForNonGitDirectory`、`getStatusThrowsForNonexistentPath`、`getDiffThrowsForNonGitDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitSharedQueueHangRepro**（4 条）：由 `hungCallOnOneRepositoryDoesNotBlockOthers`、`queuedCallOnBusyRepositoryIsCancellable`、`queuedCallTimesOutInsteadOfWaitingForever` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitStashService**（3 条）：由 `pushPopRoundTrip`、`pushWithNoChangesReturnsNil`、`listAndCountMatch` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitSubmoduleService**（1 条）：由 `submoduleListReturnsEmptyForRepoWithoutSubmodules` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（11 条）：由 `sourceControlPluginRegistersEditorContract`、`v2PluginRegistersAllLegacyGitToolNames`、`gitLogToolNormalizesCount` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AutoPushConfig | defaultConfigHasReasonableValues | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultConfigHasReasonableValues` |
| 2 | AutoPushConfig | configIsCodable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `configIsCodable` |
| 3 | AutoPushConfig | conflictPathsDeduplicate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conflictPathsDeduplicate` |
| 4 | GitAsyncBridgeCrashRepro | many parallel detached tasks through shared serial queue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `manyParallelDetachedThroughSharedQueue` |
| 5 | GitAsyncBridgeCrashRepro | cancelling detached tasks mid-bridge does not trap | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingDetachedTasksMidFlight` |
| 6 | GitAsyncBridgeCrashRepro | bridge propagates errors thrown from the work body under load | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorPropagationUnderLoad` |
| 7 | GitAsyncBridgeCrashRepro | mixed success/error/cancel storm through bridge | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mixedStorm` |
| 8 | GitAsyncBridge | continuationGuardCompletesOnlyOnce | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `continuationGuardCompletesOnlyOnce` |
| 9 | GitAsyncBridge | gitAsyncBridgeHandlesManyConcurrentCalls | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `gitAsyncBridgeHandlesManyConcurrentCalls` |
| 10 | GitAsyncBridge | gitAsyncBridgePropagatesWorkQueueErrors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gitAsyncBridgePropagatesWorkQueueErrors` |
| 11 | GitAsyncBridge | gitAsyncBridgeSupportsNestedAsyncCallsThroughSharedQueue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gitAsyncBridgeSupportsNestedAsyncCallsThroughSharedQueue` |
| 12 | GitChangeType | mapsSingleLetterCodes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mapsSingleLetterCodes` |
| 13 | GitChangeType | mapsFullWords | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mapsFullWords` |
| 14 | GitChangeType | isCaseInsensitive | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isCaseInsensitive` |
| 15 | GitChangeType | copiedMapsToRenamed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copiedMapsToRenamed` |
| 16 | GitChangeType | unknownDefaultsToModified | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unknownDefaultsToModified` |
| 17 | GitChangeType | displayLabelMatchesRawValue | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayLabelMatchesRawValue` |
| 18 | GitChangeType | countsSimpleAdditionsAndDeletions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `countsSimpleAdditionsAndDeletions` |
| 19 | GitChangeType | skipsFileHeaders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsFileHeaders` |
| 20 | GitChangeType | countsContentStartingWithPlusPlus | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `countsContentStartingWithPlusPlus` |
| 21 | GitChangeType | ignoresContextAndHunkHeaders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresContextAndHunkHeaders` |
| 22 | GitChangeType | emptyDiffHasZeroCounts | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyDiffHasZeroCounts` |
| 23 | GitChangeType | multipleChangesAccumulate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleChangesAccumulate` |
| 24 | GitCommitToolPath | 绝对路径应转换为相对路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `absolutePathShouldBeConvertedToRelative` |
| 25 | GitCommitToolPath | 相对路径应保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relativePathShouldRemainUnchanged` |
| 26 | GitCommitToolPath | 空文件列表应返回空列表 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyFilesListShouldReturnEmpty` |
| 27 | GitCommitToolPath | 不在仓库目录下的路径应保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonRepoPathShouldRemainUnchanged` |
| 28 | GitCommitToolPath | 混合路径应正确处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mixedPathsShouldBeHandledCorrectly` |
| 29 | GitCommitToolPath | 嵌套目录的绝对路径应正确转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedDirectoryAbsolutePathShouldConvert` |
| 30 | GitCommitToolPath | 仓库根路径本身应转换为空字符串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `repoPathItselfShouldConvertToEmpty` |
| 31 | GitCommitToolPath | 前缀相似但不是子路径的情况应保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prefixSimilarButNotChildShouldRemainUnchanged` |
| 32 | GitIgnoreService | roundTripWriteAndRead | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripWriteAndRead` |
| 33 | GitIgnoreService | parsingRecognizesCommentAndNegationAndDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsingRecognizesCommentAndNegationAndDirectory` |
| 34 | GitIgnoreService | templatesReturnNonEmptyContent | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `templatesReturnNonEmptyContent` |
| 35 | GitLogStructuredRenderer | structuredPayload 生成可解析的 JSON 代码块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `structuredPayloadRoundTrips` |
| 36 | GitLogStructuredRenderer | 渲染器从完整工具返回内容中提取 JSON 块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererExtractsJSONFromFullContent` |
| 37 | GitLogStructuredRenderer | canRender 命中 git_log 且包含 JSON 块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canRenderMatchesGitLogWithPayload` |
| 38 | GitLogStructuredRenderer | canRender 对无 JSON 块或无结果返回 false | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `canRenderRejectsPlainResults` |
| 39 | GitServiceReadingContract | getStatus 把未跟踪文件分流到 untracked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusSeparatesUntrackedFiles` |
| 40 | GitServiceReadingContract | isRepository 对仓库与非仓库目录判定正确 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isRepositoryDetectsRepository` |
| 41 | GitServiceReadingContract | isRepository 对不存在的路径返回 false 且不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isRepositoryToleratesMissingPath` |
| 42 | GitServiceReadingContract | commitChanges 返回该 commit 的变更文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commitChangesReturnsFiles` |
| 43 | GitServiceRemoteURL | 读取 origin 的远程地址并保持原始写法 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsOriginRemoteURLVerbatim` |
| 44 | GitServiceRemoteURL | 读取指定名称的远程地址 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsNamedRemoteURL` |
| 45 | GitServiceRemoteURL | 不存在的远程名称返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilForUnknownRemote` |
| 46 | GitServiceRemoteURL | 非仓库目录与不存在的路径返回 nil 且不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilForNonRepositoryPaths` |
| 47 | GitService | getStatus throws repositoryNotGit for non-git directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getStatusThrowsForNonGitDirectory` |
| 48 | GitService | getStatus throws repositoryNotGit for nonexistent path | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getStatusThrowsForNonexistentPath` |
| 49 | GitService | getDiff throws repositoryNotGit for non-git directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getDiffThrowsForNonGitDirectory` |
| 50 | GitService | repository root lookup rejects pathological paths quickly | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repositoryRootRejectsPathologicalPath` |
| 51 | GitService | getLog throws repositoryNotGit for non-git directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getLogThrowsForNonGitDirectory` |
| 52 | GitSharedQueueHangRepro | a hung call on one repository does not block other repositories | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hungCallOnOneRepositoryDoesNotBlockOthers` |
| 53 | GitSharedQueueHangRepro | a queued call on a busy repository can be cancelled promptly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `queuedCallOnBusyRepositoryIsCancellable` |
| 54 | GitSharedQueueHangRepro | a queued call times out instead of waiting forever | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `queuedCallTimesOutInsteadOfWaitingForever` |
| 55 | GitSharedQueueHangRepro | nested queue.sync inside the body must not deadlock | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nestedQueueSyncInsideBodyDoesNotDeadlock` |
| 56 | GitStashService | pushPopRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pushPopRoundTrip` |
| 57 | GitStashService | pushWithNoChangesReturnsNil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pushWithNoChangesReturnsNil` |
| 58 | GitStashService | listAndCountMatch | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listAndCountMatch` |
| 59 | GitSubmoduleService | submoduleListReturnsEmptyForRepoWithoutSubmodules | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `submoduleListReturnsEmptyForRepoWithoutSubmodules` |
| 60 | 综合 | sourceControlPluginRegistersEditorContract | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sourceControlPluginRegistersEditorContract` |
| 61 | 综合 | v2PluginRegistersAllLegacyGitToolNames | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2PluginRegistersAllLegacyGitToolNames` |
| 62 | 综合 | gitLogToolNormalizesCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gitLogToolNormalizesCount` |
| 63 | 综合 | registeredGitToolsDefaultToTheCallingConversationsProject | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `registeredGitToolsDefaultToTheCallingConversationsProject` |
| 64 | 综合 | validatePathRequiresAllowedDirectoryBoundary | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validatePathRequiresAllowedDirectoryBoundary` |
| 65 | 综合 | validatePathUsesCurrentProjectPathWhenToolPathIsBlank | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validatePathUsesCurrentProjectPathWhenToolPathIsBlank` |
| 66 | 综合 | gitServiceFindsRepositoryRootForFilePath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gitServiceFindsRepositoryRootForFilePath` |
| 67 | 综合 | validateBranchNameAcceptsCommonGitNames | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateBranchNameAcceptsCommonGitNames` |
| 68 | 综合 | validateBranchNameRejectsInvalidGitNames | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `validateBranchNameRejectsInvalidGitNames` |
| 69 | 综合 | remoteDisplayNamePreservesSpacesInLocalRemotePath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteDisplayNamePreservesSpacesInLocalRemotePath` |
| 70 | 综合 | remoteDisplayNameKeepsSshRepositoryPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteDisplayNameKeepsSshRepositoryPath` |

> 说明：全部 **70 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 56 / 56
- P2: 已覆盖 9 / 9
- **合计: 70 / 70**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（56 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（9 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 70 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginGit
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
