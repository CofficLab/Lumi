# TestPlan — PluginGit

## 包概述

GitPlugin Git integration plugin for Lumi editor.

平台: macOS 14+, iOS 17+
测试文件: 21 个，用例总数: 94

核心组件（源码目录）:
- `Capabilities/`
- `Features/`
- `Models/`
- `Providers/`
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
- **GitCommitToolPath**（6 条）：由 `absolutePathInsideRepoBecomesRelative`、`siblingSamePrefixIsRejected`、`externalPathIsRejected` 等用例锁定；绝对路径→相对路径转换必须用仓库边界判断（等于根或位于 root + "/" 之下），不得用裸 hasPrefix（#176）。
- **GitCommitRealCommit**（3 条）：由 `outOfRepoSiblingPrefixPathIsRejectedAndCommitsNothing`、`absolutePathInsideRepoCommitsCorrectFile`、`relativePathInsideRepoCommits` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitCommitAmendFiles**（3 条）：由 `amendStagesSpecifiedFileIntoAmendedCommit`、`amendWithEmptyFilesStagesAllChanges`、`amendMessageOnlyKeepsCommittedContent` 锁定。`commit(amend: true)` 必须先按 `files` 暂存再 amend（空列表暂存全部变更），否则指定修改会留在工作区却不进入 amended 提交（**回归 #358**）；改动 `commit` 的 amend 分支时优先跑对应测试文件。
- **GitIgnoreService**（3 条）：由 `roundTripWriteAndRead`、`parsingRecognizesCommentAndNegationAndDirectory`、`templatesReturnNonEmptyContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitServiceReadingContract**（7 条）：由 `statusSeparatesUntrackedFiles`、`isRepositoryDetectsRepository`、`isRepositoryToleratesMissingPath` 等用例锁定；改动该模块时优先跑对应测试文件。
- **子目录读取**：`GitServiceReadingContract` 要求传入仓库子目录时 status / log 与仓库根行为一致——判定（`isGitRepository`）与读取（`openRepository`）必须同为向上搜索语义（#912）。
- **GitServiceRemoteURL**（4 条）：由 `readsOriginRemoteURLVerbatim`、`readsNamedRemoteURL`、`returnsNilForUnknownRemote` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitService**（5 条）：由 `getStatusThrowsForNonGitDirectory`、`getStatusThrowsForNonexistentPath`、`getDiffThrowsForNonGitDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitSharedQueueHangRepro**（4 条）：由 `hungCallOnOneRepositoryDoesNotBlockOthers`、`queuedCallOnBusyRepositoryIsCancellable`、`queuedCallTimesOutInsteadOfWaitingForever` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitStashService**（3 条）：由 `pushPopRoundTrip`、`pushWithNoChangesReturnsNil`、`listAndCountMatch` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitSubmoduleService**（1 条）：由 `submoduleListReturnsEmptyForRepoWithoutSubmodules` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GitBranchDetachedHead**（1 条）：由 `detachedHeadIsNotReportedAsBranch` 锁定；detached HEAD 时 `currentBranch` 必须为 `nil`，提交哈希改由 `detachedHeadCommitHash` 提供。
- **GitBranchReadFailure**（1 条）：由 `unreadableCurrentBranchThrowsInsteadOfReturningNil` 锁定；`currentBranch` 的 `nil` 只能是 detached HEAD，HEAD 指向缺失引用等读取失败必须抛出（#915）。
- **GitShowShortHash**（2 条）：由 `shortHashResolvesDetailAndChangedFiles`、`unknownShortHashStillThrows` 锁定；`git_show` 必须接受 `git_log` 输出的 7 位短哈希，详情与变更文件两条路径都用解析后的完整 OID。
- **GitUnpushedState**（5 条）：由 `noUpstreamIsNotReportedAsPushed`、`pushedBranchIsUpToDate`、`aheadOfUpstreamReportsHashes` 等用例锁定；`git_unpushed` 必须区分 `noUpstream` / `upToDate` / `hasUnpushed` / `unavailable`——没有上游就没有可比较的远程基准，不得误报「全部已推送」。
- **GitStatusUntracked**（3 条）：由 `untrackedOnlyChangeIsNotReportedClean`、`untrackedListedAlongsideOtherChanges`、`genuinelyCleanRepoStillReportsClean` 锁定；`git_status` 必须把未跟踪文件列为工作区变更，仅存在未跟踪文件时不得报告「工作区干净」（#155）。
- **综合**（14 条）：由 `sourceControlPluginRegistersEditorContract`、`v2PluginRegistersAllLegacyGitToolNames`、`gitLogToolNormalizesCount` 等用例锁定；改动该模块时优先跑对应测试文件。读工具经注册链路（`ConversationScopedGitTool` 包装）声明 `parallelReadOnly`，写工具保持串行副作用（#1312）。

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
| 20 | GitChangeType | countsSourceLinesStartingWithPlusOrMinus（`+++i;` / `---i;` 必须计入，只有带空白的文件头才排除） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `countsSourceLinesStartingWithPlusOrMinus` |
| 21 | GitChangeType | ignoresContextAndHunkHeaders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresContextAndHunkHeaders` |
| 22 | GitChangeType | emptyDiffHasZeroCounts | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyDiffHasZeroCounts` |
| 23 | GitChangeType | multipleChangesAccumulate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleChangesAccumulate` |
| 24 | GitCommitToolPath | 仓库内绝对路径转换为相对路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `absolutePathInsideRepoBecomesRelative` |
| 25 | GitCommitToolPath | 嵌套目录的绝对路径正确转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedDirectoryAbsolutePathBecomesRelative` |
| 26 | GitCommitToolPath | 仓库根路径本身转换为空字符串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `repoRootItselfBecomesEmpty` |
| 27 | GitCommitToolPath | 同名前缀的兄弟目录文件必须判为仓库外，不得改写成内部路径 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `siblingSamePrefixIsRejected` |
| 28 | GitCommitToolPath | 前缀相似但非子路径的文件必须拒绝，不得错误匹配 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `siblingPrefixSubstringIsRejected` |
| 29 | GitCommitToolPath | 仓库外路径返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalPathIsRejected` |
| 30 | GitCommitRealCommit | 仓库外同名前缀路径必须抛错且不得提交任何内部文件 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `outOfRepoSiblingPrefixPathIsRejectedAndCommitsNothing` |
| 31 | GitCommitRealCommit | 仓库内绝对路径提交正确的文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `absolutePathInsideRepoCommitsCorrectFile` |
| 32 | GitCommitRealCommit | 仓库内相对路径按 git 约定提交 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relativePathInsideRepoCommits` |
| 33 | GitIgnoreService | roundTripWriteAndRead | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripWriteAndRead` |
| 34 | GitIgnoreService | parsingRecognizesCommentAndNegationAndDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsingRecognizesCommentAndNegationAndDirectory` |
| 35 | GitIgnoreService | templatesReturnNonEmptyContent | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `templatesReturnNonEmptyContent` |
| 36 | GitServiceReadingContract | getStatus 把未跟踪文件分流到 untracked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusSeparatesUntrackedFiles` |
| 37 | GitServiceReadingContract | isRepository 对仓库与非仓库目录判定正确 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isRepositoryDetectsRepository` |
| 38 | GitServiceReadingContract | isRepository 对不存在的路径返回 false 且不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isRepositoryToleratesMissingPath` |
| 39 | GitServiceReadingContract | commitChanges 返回该 commit 的变更文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commitChangesReturnsFiles` |
| 40 | GitServiceRemoteURL | 读取 origin 的远程地址并保持原始写法 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsOriginRemoteURLVerbatim` |
| 41 | GitServiceRemoteURL | 读取指定名称的远程地址 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsNamedRemoteURL` |
| 42 | GitServiceRemoteURL | 不存在的远程名称返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilForUnknownRemote` |
| 43 | GitServiceRemoteURL | 非仓库目录与不存在的路径返回 nil 且不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilForNonRepositoryPaths` |
| 44 | GitService | getStatus throws repositoryNotGit for non-git directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getStatusThrowsForNonGitDirectory` |
| 45 | GitService | getStatus throws repositoryNotGit for nonexistent path | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getStatusThrowsForNonexistentPath` |
| 46 | GitService | getDiff throws repositoryNotGit for non-git directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getDiffThrowsForNonGitDirectory` |
| 47 | GitService | repository root lookup rejects pathological paths quickly | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repositoryRootRejectsPathologicalPath` |
| 48 | GitService | getLog throws repositoryNotGit for non-git directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getLogThrowsForNonGitDirectory` |
| 49 | GitSharedQueueHangRepro | a hung call on one repository does not block other repositories | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hungCallOnOneRepositoryDoesNotBlockOthers` |
| 50 | GitSharedQueueHangRepro | a queued call on a busy repository can be cancelled promptly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `queuedCallOnBusyRepositoryIsCancellable` |
| 51 | GitSharedQueueHangRepro | a queued call times out instead of waiting forever | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `queuedCallTimesOutInsteadOfWaitingForever` |
| 52 | GitSharedQueueHangRepro | nested queue.sync inside the body must not deadlock | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nestedQueueSyncInsideBodyDoesNotDeadlock` |
| 53 | GitStashService | pushPopRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pushPopRoundTrip` |
| 54 | GitStashService | pushWithNoChangesReturnsNil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pushWithNoChangesReturnsNil` |
| 55 | GitStashService | listAndCountMatch | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listAndCountMatch` |
| 56 | GitSubmoduleService | submoduleListReturnsEmptyForRepoWithoutSubmodules | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `submoduleListReturnsEmptyForRepoWithoutSubmodules` |
| 57 | 综合 | sourceControlPluginRegistersEditorContract | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sourceControlPluginRegistersEditorContract` |
| 58 | 综合 | v2PluginRegistersAllLegacyGitToolNames | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2PluginRegistersAllLegacyGitToolNames` |
| 59 | 综合 | gitLogToolNormalizesCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gitLogToolNormalizesCount` |
| 60 | 综合 | registeredGitToolsDefaultToTheCallingConversationsProject | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `registeredGitToolsDefaultToTheCallingConversationsProject` |
| 61 | 综合 | validatePathRequiresAllowedDirectoryBoundary | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validatePathRequiresAllowedDirectoryBoundary` |
| 62 | 综合 | validatePathUsesCurrentProjectPathWhenToolPathIsBlank | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validatePathUsesCurrentProjectPathWhenToolPathIsBlank` |
| 63 | 综合 | gitServiceFindsRepositoryRootForFilePath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gitServiceFindsRepositoryRootForFilePath` |
| 64 | 综合 | validateBranchNameAcceptsCommonGitNames | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateBranchNameAcceptsCommonGitNames` |
| 65 | 综合 | validateBranchNameRejectsInvalidGitNames | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `validateBranchNameRejectsInvalidGitNames` |
| 66 | 综合 | remoteDisplayNamePreservesSpacesInLocalRemotePath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteDisplayNamePreservesSpacesInLocalRemotePath` |
| 67 | 综合 | remoteDisplayNameKeepsSshRepositoryPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteDisplayNameKeepsSshRepositoryPath` |
| 68 | GitLogTool count | 超大 Double 退回默认值而不是崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oversizedDoubleFallsBackToDefault` |
| 69 | GitLogTool count | 非有限值退回默认值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nonFiniteFallsBackToDefault` |
| 70 | GitLogTool count | 可表示但超范围的值被钳制 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `representableOutOfRangeIsClamped` |
| 71 | GitLogTool count | 范围内的值原样保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inRangeIsKept` |
| 72 | GitLogTool count | 缺失或非法值使用默认值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingOrInvalidUsesDefault` |
| 73 | GitServiceReadingContract | getDiff 指定单个文件时 filesChanged 只统计该文件 | 临时仓库有两处未暂存修改 | 分别按 `a.txt` 与不存在的 `missing.txt` 取 diff | `a.txt` 的 filesChanged 为 1 且 patch 不含 `b.txt`；不存在文件无 patch 且 stats 为 nil | P1 | ✅ 已覆盖 | `diffFileFilterCountsOnlyRequestedFile` |
| 74 | GitChangeType | countsContentStartingWithDoubleSign（以 `++`/`--` 开头的正文行正常计数） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `countsContentStartingWithDoubleSign` |
| 75 | GitShowShortHash | 7 位短哈希可查到 commit 详情与变更文件 | 临时仓库有一次提交 | 用 `git_log` 返回哈希的前 7 位调用 `getCommitDetail` / `getCommitChangedFiles` | 返回完整哈希、消息与变更文件 | P0 | ✅ 已覆盖 | `shortHashResolvesDetailAndChangedFiles` |
| 76 | GitShowShortHash | 无法匹配的短哈希仍然报错 | 同上 | 用 `0000000` 调用 `getCommitDetail` | 抛出错误而非返回空结果 | P1 | ✅ 已覆盖 | `unknownShortHashStillThrows` |
| 77 | GitBranchDetachedHead | detached HEAD 不当作分支名 | 临时仓库有一次提交 | `checkoutCommit` 后调用 `currentBranch` / `detachedHeadCommitHash` | 分支名为 nil，哈希为完整 OID；切回分支后相反 | P0 | ✅ 已覆盖 | `detachedHeadIsNotReportedAsBranch` |
| 78 | 综合 | git_branch 的失败分支抛出 `ToolExecutionError`（缺 name、未知 action、工作区脏） | 临时仓库，含一次提交并修改工作区文件 | 依次调用 `git_branch` 的 create / delete / checkout | 三次均抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `gitBranchToolThrowsForInvalidRequests` |
| 79 | 综合 | git_log / git_commit / git_diff / git_show 的失败分支抛出 `ToolExecutionError` | 非 Git 仓库目录 | 缺 message、缺 hash、对非仓库路径取日志/差异/详情 | 全部抛出 `ToolExecutionError`，不再返回字符串 | P1 | ✅ 已覆盖 | `gitToolsThrowForMissingOrInvalidArguments` |
| 80 | GitBranchReadFailure | 当前分支读取失败抛出而不是伪装成 detached HEAD（回归 #915） | 临时仓库有一次提交，`.git/HEAD` 指向不存在的 `refs/heads/missing-branch` | 调用 `currentBranch`，同时确认分支列表仍可读 | `currentBranch` 抛出 `LibGit2Error`，不再返回 `nil` | P0 | ✅ 已覆盖 | `unreadableCurrentBranchThrowsInsteadOfReturningNil` |
| 81 | GitServiceReadingContract | 项目路径是仓库子目录时仍能读取 status 与 log（回归 #912） | 临时仓库有一次提交，工作区有修改，项目路径取仓库下的 `Sources` 子目录 | 先 `isRepository`，再 `getStatus` 与 `getLog` | 判定为仓库，status 列出 `tracked.txt`，log 返回 1 条提交 | P1 | ✅ 已覆盖 | `readsStatusAndLogFromRepositorySubdirectory` |
| 82 | GitServiceReadingContract | 仅暂存的新增与删除保留 A/D 类型 | 临时仓库有一次提交，新文件已暂存、已有文件已暂存删除 | 调用 `getStatus` 并检查 `workingChanges` | `brand-new.txt` 为 added 且 staged，`gone.txt` 为 deleted 且 staged | P1 | ✅ 已覆盖 | `stagedAddAndDeleteKeepTheirStates` |
| 83 | GitUnpushedState | 没有上游分支时返回 noUpstream，而不是 upToDate | 临时仓库有一次提交，未配置上游 | 调用 `getUnpushedCommitsState` | 状态为 `noUpstream`，不误报「全部已推送」 | P0 | ✅ 已覆盖 | `noUpstreamIsNotReportedAsPushed` |
| 84 | GitUnpushedState | 已推送且没有领先提交时返回 upToDate | 临时仓库已推送到 bare 远程并配置上游 | 调用 `getUnpushedCommitsState` | 状态为 `upToDate` | P1 | ✅ 已覆盖 | `pushedBranchIsUpToDate` |
| 85 | GitUnpushedState | 有上游且本地领先时返回未推送哈希 | 推送后再新增一个本地提交 | 调用 `getUnpushedCommitsState` | `hasUnpushed` 且恰含 1 个哈希 | P1 | ✅ 已覆盖 | `aheadOfUpstreamReportsHashes` |
| 86 | GitUnpushedState | 路径不是 Git 仓库时返回 unavailable | 路径为普通目录 | 调用 `getUnpushedCommitsState` | 状态为 `unavailable` | P1 | ✅ 已覆盖 | `nonRepositoryIsUnavailable` |
| 87 | GitUnpushedState | 工具输出在无上游时给出明确提示 | 临时仓库未配置上游 | 执行 `GitUnpushedV2Tool` | 输出含「没有配置 upstream」，不含「所有 commit 都已推送」 | P1 | ✅ 已覆盖 | `toolExplainsMissingUpstream` |
| 88 | 综合 | 读工具经注册链路声明并行只读，写工具保持串行（#1312） | kernel 注册 ToolManager | `GitSourceControlPlugin.onBoot` 后按名查询工具 | git_status/git_diff/git_log/git_show/git_unpushed 为 `parallelReadOnly`；git_commit/git_branch 保持 `serialSideEffect` | P1 | ✅ 已覆盖 | `gitReadToolsDeclareParallelReadOnlyWhileWritesStaySerial` |
| 89 | GitCommitAmendFiles | amend 必须把指定文件的未暂存修改纳入 amended 提交（**回归 #358**） | 临时仓库种子提交 a.txt=v1，工作区改为 v2 未暂存 | `commit(files: ["a.txt"], amend: true)` | HEAD 变化，amended 提交含 v2，工作区与 HEAD 一致 | P0 | ✅ 已覆盖 | `amendStagesSpecifiedFileIntoAmendedCommit` |
| 90 | GitCommitAmendFiles | amend 空文件列表与新建提交一致：暂存全部变更 | 临时仓库种子提交 a.txt/b.txt=v1，两者均改为 v2 未暂存 | `commit(files: [], amend: true)` | 两个文件的 v2 都进入 amended 提交，无残留未提交修改 | P1 | ✅ 已覆盖 | `amendWithEmptyFilesStagesAllChanges` |
| 91 | GitCommitAmendFiles | 无工作区改动时 amend 仅改提交信息，保留已提交内容 | 临时仓库种子提交 a.txt=v1，无改动 | `commit(files: [], amend: true, message: "new message")` | HEAD 变化、信息更新，a.txt 仍为 v1 | P1 | ✅ 已覆盖 | `amendMessageOnlyKeepsCommittedContent` |
| 92 | GitStatusUntracked | 仅有未跟踪文件时不得报告工作区干净（**回归 #155**） | 临时仓库有一次提交，新增未 `git add` 的 `new-file.txt` | 执行 `GitStatusV2Tool` | 输出含 `new-file.txt` 与「未跟踪的文件」，不含「工作区干净」 | P0 | ✅ 已覆盖 | `untrackedOnlyChangeIsNotReportedClean` |
| 93 | GitStatusUntracked | 未跟踪文件与其它变更一并列出 | 临时仓库有一次提交，已跟踪文件被修改且另有未跟踪文件 | 执行 `GitStatusV2Tool` | 输出同时含「修改的文件」与「未跟踪的文件」及对应文件名 | P1 | ✅ 已覆盖 | `untrackedListedAlongsideOtherChanges` |
| 94 | GitStatusUntracked | 真正干净的仓库仍报告工作区干净（无回归） | 临时仓库有一次提交，无任何工作区改动 | 执行 `GitStatusV2Tool` | 输出含「工作区干净」，不含「未跟踪的文件」 | P1 | ✅ 已覆盖 | `genuinelyCleanRepoStillReportsClean` |

> 说明：全部 **94 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 16 / 16
- P1: 已覆盖 70 / 70
- P2: 已覆盖 8 / 8
- **合计: 94 / 94**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（16 条）
- **P1**: 其余功能性用例（70 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（8 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 94 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
