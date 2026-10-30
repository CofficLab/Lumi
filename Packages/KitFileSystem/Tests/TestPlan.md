# TestPlan — KitFileSystem

## 包概述

KitFileSystem KitFileSystem 是 Lumi 项目中负责文件系统相关能力的 Package。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 129

核心组件（源码目录）:
- `Tree/`
- `Workspace/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `FileTreeKitLocalization`
- `FileTreeService`
- `FileTreeStore`
- `FileTreeWatcher`
- `WorkspaceDirectoryListing`
- `WorkspaceFileEditOutcome`
- `WorkspaceFileError`
- `WorkspaceFileKitLocalization`
- `WorkspaceFileReadResult`
- `WorkspaceFileWriter`
- `WorkspacePathResolver`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **FileTreeService**（35 条）：由 `isDirectoryReturnsTrueForDirectory`、`isDirectoryReturnsFalseForFile`、`isDirectoryReturnsFalseForNonexistent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **FileTreeStore**（27 条）：由 `setAndGetString`、`setAndGetArray`、`setNilRemovesKey` 等用例锁定；改动该模块时优先跑对应测试文件。
- **FileTreeWatcher**（17 条）：由 `watchCountInitiallyZero`、`startWatchingIncreasesCount`、`stopWatchingDecreasesCount` 等用例锁定；改动该模块时优先跑对应测试文件。
- **KitFileSystemCoverage**（6 条）：由 `editNotFoundInExistingFile`、`editNoopThrows`、`editEmptyOldStringOnNonEmptyFile` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WorkspaceFileKit**（44 条）：由 `testWriteAndReadTextFile`、`testWriteDirectoryReportsDirectoryInsteadOfSystemError`、`testWriteWhenParentIsFileReportsParentPathClearly` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | FileTreeService | isDirectory returns true for directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isDirectoryReturnsTrueForDirectory` |
| 2 | FileTreeService | isDirectory returns false for file | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isDirectoryReturnsFalseForFile` |
| 3 | FileTreeService | isDirectory returns false for nonexistent path | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isDirectoryReturnsFalseForNonexistent` |
| 4 | FileTreeService | filterAndSortContents filters .DS_Store and .git by default | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `filterFiltersHiddenFiles` |
| 5 | FileTreeService | filterAndSortContents places folders before files | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sortFoldersFirst` |
| 6 | FileTreeService | filterAndSortContents sorts names with localized standard compare | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sortLocalizedStandard` |
| 7 | FileTreeService | filterAndSortContents uses custom hidden names | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filterCustomHiddenNames` |
| 8 | FileTreeService | filterAndSortContents returns empty for empty input | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `filterEmptyInput` |
| 9 | FileTreeService | loadContents returns sorted directory listing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadContentsReturnsSorted` |
| 10 | FileTreeService | loadContents throws for nonexistent directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadContentsThrowsForNonexistent` |
| 11 | FileTreeService | loadContents returns empty for empty directory | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `loadContentsReturnsEmpty` |
| 12 | FileTreeService | iconSFSymbol returns correct icons for known extensions | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `iconSFSymbolKnownExtensions` |
| 13 | FileTreeService | iconSFSymbol is case insensitive | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `iconSFSymbolCaseInsensitive` |
| 14 | FileTreeService | iconSFSymbol returns doc for unknown extensions | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `iconSFSymbolUnknownExtension` |
| 15 | FileTreeService | iconSFSymbol for URL returns folder.fill for directory | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `iconSFSymbolForURLDirectory` |
| 16 | FileTreeService | iconSFSymbol for URL returns extension-based icon for file | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `iconSFSymbolForURLFile` |
| 17 | FileTreeService | displayName returns last path component | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayNameReturnsLastPathComponent` |
| 18 | FileTreeService | modificationDate returns date for existing file | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modificationDateReturnsDate` |
| 19 | FileTreeService | modificationDate returns nil for nonexistent file | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modificationDateReturnsNilForNonexistent` |
| 20 | FileTreeService | formatDate returns non-empty string for valid date | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `formatDateReturnsNonEmpty` |
| 21 | FileTreeService | formatDate returns empty string for nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `formatDateReturnsEmptyForNil` |
| 22 | FileTreeService | createFile creates file and returns URL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createFileSuccess` |
| 23 | FileTreeService | createFile returns nil for empty name | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `createFileEmptyName` |
| 24 | FileTreeService | createFile rejects path-like names | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `createFilePathLikeName` |
| 25 | FileTreeService | createFile returns nil if file already exists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createFileAlreadyExists` |
| 26 | FileTreeService | createFolder creates directory and returns URL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createFolderSuccess` |
| 27 | FileTreeService | createFolder returns nil for empty name | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `createFolderEmptyName` |
| 28 | FileTreeService | createFolder rejects current and parent directory names | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `createFolderPathTraversalNames` |
| 29 | FileTreeService | createFolder returns nil if folder already exists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createFolderAlreadyExists` |
| 30 | FileTreeService | renameItem renames file and returns new URL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renameItemSuccess` |
| 31 | FileTreeService | renameItem returns nil for empty name | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `renameItemEmptyName` |
| 32 | FileTreeService | renameItem rejects path-like names | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `renameItemPathLikeName` |
| 33 | FileTreeService | renameItem returns nil if target already exists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renameItemTargetExists` |
| 34 | FileTreeService | trashItem moves file to trash | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trashItemSuccess` |
| 35 | FileTreeService | trashItem returns false for nonexistent file | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trashItemNonexistent` |
| 36 | FileTreeStore | set and object round-trip for string | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setAndGetString` |
| 37 | FileTreeStore | set and object round-trip for array | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setAndGetArray` |
| 38 | FileTreeStore | set nil removes key | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setNilRemovesKey` |
| 39 | FileTreeStore | object returns nil for nonexistent key | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `objectReturnsNilForMissingKey` |
| 40 | FileTreeStore | string returns nil for non-string value | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stringReturnsNilForNonString` |
| 41 | FileTreeStore | expandedPaths returns empty for new project | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `expandedPathsEmptyForNewProject` |
| 42 | FileTreeStore | setExpandedPaths and expandedPaths round-trip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setAndGetExpandedPaths` |
| 43 | FileTreeStore | expandedPaths are isolated per project | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `expandedPathsIsolatedPerProject` |
| 44 | FileTreeStore | addExpandedPath adds path to existing set | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addExpandedPath` |
| 45 | FileTreeStore | addExpandedPath deduplicates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addExpandedPathDeduplicates` |
| 46 | FileTreeStore | addExpandedPath works on empty store | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `addExpandedPathEmptyStore` |
| 47 | FileTreeStore | removeExpandedPath removes path from set | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeExpandedPath` |
| 48 | FileTreeStore | removeExpandedPath handles nonexistent path gracefully | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `removeExpandedPathNonexistent` |
| 49 | FileTreeStore | lastProjectPath returns nil initially | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lastProjectPathNilInitially` |
| 50 | FileTreeStore | setLastProjectPath and lastProjectPath round-trip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setAndGetLastProjectPath` |
| 51 | FileTreeStore | setLastProjectPath overwrites previous value | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setLastProjectPathOverwrites` |
| 52 | FileTreeStore | data persists across store instances | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dataPersistsAcrossInstances` |
| 53 | FileTreeStore | set quarantines invalid settings file and recovers | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `setQuarantinesInvalidSettingsFileAndRecovers` |
| 54 | FileTreeStore | non-dictionary plist root is quarantined and reads return empty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonDictionaryPlistRootIsQuarantined` |
| 55 | FileTreeStore | flushDirtyCache persists debounced changes immediately | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `flushDirtyCachePersistsDebouncedChanges` |
| 56 | FileTreeStore | pending debounced changes are persisted on deinit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `debouncedChangesPersistOnDeinit` |
| 57 | FileTreeStore | set reports failure when settings directory is blocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setReportsFailureWhenSettingsDirectoryIsBlocked` |
| 58 | FileTreeStore | project roots with special characters are handled correctly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectRootSpecialCharacters` |
| 59 | FileTreeStore | different project roots with similar names are isolated | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `similarProjectRootsIsolated` |
| 60 | FileTreeStore | set overwrites existing value in same store instance | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setOverwritesExistingValue` |
| 61 | FileTreeStore | expandedPaths overwrites previous set for same project | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `expandedPathsOverwritesPrevious` |
| 62 | FileTreeStore | concurrent reads and writes do not crash | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `concurrentAccessSafety` |
| 63 | FileTreeWatcher | watchCount is zero initially | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `watchCountInitiallyZero` |
| 64 | FileTreeWatcher | startWatching increases watchCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startWatchingIncreasesCount` |
| 65 | FileTreeWatcher | stopWatching decreases watchCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopWatchingDecreasesCount` |
| 66 | FileTreeWatcher | stopAll clears all watches | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopAllClearsWatches` |
| 67 | FileTreeWatcher | startWatching same URL twice does not duplicate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startWatchingIdempotent` |
| 68 | FileTreeWatcher | stopWatching nonexistent URL is no-op | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopWatchingNonexistentNoOp` |
| 69 | FileTreeWatcher | updateWatchedDirectories adds new directories | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateWatchedDirectoriesAdds` |
| 70 | FileTreeWatcher | updateWatchedDirectories removes old directories | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateWatchedDirectoriesRemoves` |
| 71 | FileTreeWatcher | updateWatchedDirectories with empty set stops all | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateWatchedDirectoriesEmptyStopsAll` |
| 72 | FileTreeWatcher | updateWatchedDirectories is idempotent for same set | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateWatchedDirectoriesIdempotent` |
| 73 | FileTreeWatcher | watcher fires callback when directory content changes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `watcherFiresCallbackOnFileChange` |
| 74 | FileTreeWatcher | startWatching with verbose true logs without crash | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `startWatchingVerboseTrue` |
| 75 | FileTreeWatcher | stopWatching with verbose true logs without crash | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stopWatchingVerboseTrue` |
| 76 | FileTreeWatcher | stopAll with verbose true logs without crash | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stopAllVerboseTrue` |
| 77 | FileTreeWatcher | watcher deinit cleans up active watches | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `watcherDeinitCleansUp` |
| 78 | FileTreeWatcher | updateWatchedDirectories fires callback when new watched directory changes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateWatchedDirectoriesFiresCallback` |
| 79 | FileTreeWatcher | watcher does not fire for unwatched directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `watcherDoesNotFireForUnwatched` |
| 80 | KitFileSystemCoverage | 编辑已有文件但 oldString 未命中 → 抛错且内容不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editNotFoundInExistingFile` |
| 81 | KitFileSystemCoverage | oldString 与 newString 完全相同 → 抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editNoopThrows` |
| 82 | KitFileSystemCoverage | 编辑已有非空文件但 oldString 为空 → 抛错 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `editEmptyOldStringOnNonEmptyFile` |
| 83 | KitFileSystemCoverage | 内容长度恰好等于上限时不截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `boundaryAtExactLimit` |
| 84 | KitFileSystemCoverage | recordRead / snapshot / clear 按会话隔离 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recordSnapshotClear` |
| 85 | KitFileSystemCoverage | 更多扩展名映射为已知图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `moreIcons` |
| 86 | WorkspaceFileKit | testWriteAndReadTextFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWriteAndReadTextFile` |
| 87 | WorkspaceFileKit | testWriteDirectoryReportsDirectoryInsteadOfSystemError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWriteDirectoryReportsDirectoryInsteadOfSystemError` |
| 88 | WorkspaceFileKit | testWriteWhenParentIsFileReportsParentPathClearly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWriteWhenParentIsFileReportsParentPathClearly` |
| 89 | WorkspaceFileKit | testReadTruncatesLongText | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testReadTruncatesLongText` |
| 90 | WorkspaceFileKit | testReadImageReturnsDataAndMimeType | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadImageReturnsDataAndMimeType` |
| 91 | WorkspaceFileKit | testReadNonUTF8ReturnsSupportedImageExtensions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadNonUTF8ReturnsSupportedImageExtensions` |
| 92 | WorkspaceFileKit | testReadMissingTextFileReportsMissingFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadMissingTextFileReportsMissingFile` |
| 93 | WorkspaceFileKit | testReadDirectoryReportsDirectoryInsteadOfNonUTF8 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadDirectoryReportsDirectoryInsteadOfNonUTF8` |
| 94 | WorkspaceFileKit | testReadDetectsUTF16TextFiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadDetectsUTF16TextFiles` |
| 95 | WorkspaceFileKit | testEditRequiresUniqueMatchUnlessReplaceAll | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditRequiresUniqueMatchUnlessReplaceAll` |
| 96 | WorkspaceFileKit | testEditCreatesNewFileWhenOldStringIsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEditCreatesNewFileWhenOldStringIsEmpty` |
| 97 | WorkspaceFileKit | testEditCreateWhenParentIsFileReportsParentPathClearly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditCreateWhenParentIsFileReportsParentPathClearly` |
| 98 | WorkspaceFileKit | testEditWritesExistingEmptyFile | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEditWritesExistingEmptyFile` |
| 99 | WorkspaceFileKit | testEditDirectoryReportsDirectoryInsteadOfInvalidText | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testEditDirectoryReportsDirectoryInsteadOfInvalidText` |
| 100 | WorkspaceFileKit | testEditAcceptsFileURLString | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditAcceptsFileURLString` |
| 101 | WorkspaceFileKit | testEditPreservesDetectedTextEncoding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditPreservesDetectedTextEncoding` |
| 102 | WorkspaceFileKit | testEditMatchesLFInputAgainstCRLFFileAndPreservesLineEndings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditMatchesLFInputAgainstCRLFFileAndPreservesLineEndings` |
| 103 | WorkspaceFileKit | testEditSwiftFunctionSignatureDoesNotDuplicateAdjacentCode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditSwiftFunctionSignatureDoesNotDuplicateAdjacentCode` |
| 104 | WorkspaceFileKit | testEditMultilineSwiftFunctionBlockDoesNotDuplicateAdjacentCode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditMultilineSwiftFunctionBlockDoesNotDuplicateAdjacentCode` |
| 105 | WorkspaceFileKit | testEditRejectsOversizedFile | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testEditRejectsOversizedFile` |
| 106 | WorkspaceFileKit | testEditRejectedWhenFileModifiedAfterRead | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testEditRejectedWhenFileModifiedAfterRead` |
| 107 | WorkspaceFileKit | testEditAllowedWhenFileUnchangedAfterRead | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditAllowedWhenFileUnchangedAfterRead` |
| 108 | WorkspaceFileKit | testEditPreservesCurlyQuoteStyleInReplacement | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditPreservesCurlyQuoteStyleInReplacement` |
| 109 | WorkspaceFileKit | testEditDoesNotAlterStraightQuoteFiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditDoesNotAlterStraightQuoteFiles` |
| 110 | WorkspaceFileKit | testEditDiffShowsRemovedAndAddedLines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditDiffShowsRemovedAndAddedLines` |
| 111 | WorkspaceFileKit | testEditMissingFileSuggestsSimilarFilename | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditMissingFileSuggestsSimilarFilename` |
| 112 | WorkspaceFileKit | testEditMissingFileNoSuggestionWhenNoSimilarFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditMissingFileNoSuggestionWhenNoSimilarFile` |
| 113 | WorkspaceFileKit | testEditDistanceBasic | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditDistanceBasic` |
| 114 | WorkspaceFileKit | testListDirectorySkipsHiddenFiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListDirectorySkipsHiddenFiles` |
| 115 | WorkspaceFileKit | testListMissingDirectoryReportsPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListMissingDirectoryReportsPath` |
| 116 | WorkspaceFileKit | testListFilePathReportsNotDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListFilePathReportsNotDirectory` |
| 117 | WorkspaceFileKit | testRecursiveListFilePathReportsNotDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRecursiveListFilePathReportsNotDirectory` |
| 118 | WorkspaceFileKit | testRecursiveListCanTruncate | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRecursiveListCanTruncate` |
| 119 | WorkspaceFileKit | testRecursiveListOnlyDropsRootPrefix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRecursiveListOnlyDropsRootPrefix` |
| 120 | WorkspaceFileKit | testRelativePathRejectsSiblingWithSharedPrefix | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRelativePathRejectsSiblingWithSharedPrefix` |
| 121 | WorkspaceFileKit | testPathResolverAcceptsFileURLString | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPathResolverAcceptsFileURLString` |
| 122 | WorkspaceFileKit | testPathResolverTrimsCopiedPathWhitespace | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPathResolverTrimsCopiedPathWhitespace` |
| 123 | WorkspaceFileKit | testPathResolverTrimsCopiedFileURLWhitespace | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPathResolverTrimsCopiedFileURLWhitespace` |
| 124 | WorkspaceFileKit | testPathResolverAcceptsUnescapedFileURLString | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPathResolverAcceptsUnescapedFileURLString` |
| 125 | WorkspaceFileKit | testPathResolverDecodesPercentEncodedFileURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPathResolverDecodesPercentEncodedFileURL` |
| 126 | WorkspaceFileKit | testPathResolverDecodesUppercasePercentEncodingAndSpaces | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPathResolverDecodesUppercasePercentEncodingAndSpaces` |
| 127 | WorkspaceFileKit | testPathResolverExpandsTilde | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPathResolverExpandsTilde` |
| 128 | WorkspaceFileKit | testPathResolverTreatsPlainPathAsFilePath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPathResolverTreatsPlainPathAsFilePath` |
| 129 | WorkspaceFileKit | testPathResolverKeepsInvalidPercentSequenceVerbatim | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testPathResolverKeepsInvalidPercentSequenceVerbatim` |

> 说明：全部 **129 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 17 / 17
- P1: 已覆盖 91 / 91
- P2: 已覆盖 21 / 21
- **合计: 129 / 129**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（17 条）
- **P1**: 其余功能性用例（91 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（21 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 129 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitFileSystem
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
