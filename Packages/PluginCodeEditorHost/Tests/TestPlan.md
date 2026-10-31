# TestPlan — PluginCodeEditorHost

## 包概述

PluginCodeEditorHost 的实现包，包含 14 个主要类型；当前测试覆盖 202 条用例。

平台: macOS 14+, iOS 17+
测试文件: 22 个，用例总数: 202

核心组件（源码目录）:
- `Editor/`
- `Facade/`
- `Host/`
- `Kernel/`
- `LSP/`
- `Proto/`
- `Registries/`
- `Store/`
- `Utilities/`
- `V2/`
- `Workbench/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `EditorHostEnvironment`
- `EditorService`
- `EditorServiceLocalization`
- `LumiEditorServicing`
- `DocumentHighlightCoordinator`
- `DocumentHighlightPrewarmScheduler`
- `EditorCoordinator`
- `EditorFileTreeHighlightResolver`
- `EditorInputRouter`
- `EditorJumpToDefinitionDelegate`
- `ScrollCoordinator`
- `SourceEditorAdapter`
- `TextViewBridge`
- `EditorCommandService`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DocumentHighlightCoordinator**（1 条）：由 `testActivateRestoresCachedSnapshotToTextStorage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DocumentHighlightPrewarmScheduler**（2 条）：由 `testOpenTabsAreAllScheduledIncludingInactiveOnes`、`testCloseTabDoesNotCrashScheduler` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorBuffer**（5 条）：由 `testReplaceTextUpdatesSnapshotAndVersion`、`testApplyTransactionReplacesMultipleRangesFromBackToFront`、`testApplyTransactionPreservesProvidedSelections` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorCallHierarchyItem**（2 条）：由 `testFileBadgeAcceptsUnescapedFileURL`、`testFileBadgeFallsBackForNonFileURI` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorConfigStore**（2 条）：由 `testSettingsDirectoryDoesNotDuplicateStorageDirectoryForDefaultRoot`、`testSettingsDirectoryUsesHostPersistenceRootWhenProvided` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorContributionRegistry**（7 条）：由 `installAndWithdraw`、`contextMenuContributionInstallAndWithdraw`、`replaceSwapsAtomically` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorExtensionRegistry**（2 条）：由 `testHighlightProvidersCachesResultsPerLanguage`、`testRegisterHighlightContributorViaKernelBridge` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorFindReplaceController**（9 条）：由 `testMatchesPlainTextCaseInsensitive`、`testMatchesWholeWordSkipsSubstrings`、`testMatchesInSelectionOnlyUsesNonEmptySelections` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorJumpToDefinitionDelegate**（14 条）：由 `testSubstringIfValidReturnsTextForValidRange`、`testSubstringIfValidRejectsStaleRanges`、`testLSPFileURLAcceptsUnescapedFileURL` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorKernelPureLogic**（69 条）：由 `testEditorMinimapPolicyVisibleStateUsesUserPreference`、`testEditorMinimapPolicyLargeFileStateIsGated`、`testEditorPeekModeTitlesRemainStable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorKeybindingStore**（4 条）：由 `testBindingsFileUsesDefaultRootWithoutForceUnwrappingApplicationSupport`、`testBindingsFileUsesHostPersistenceRootWhenProvided`、`testCorruptBindingsFileIsQuarantinedAndRecovered` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorOpenItemCommand**（1 条）：由 `testCallHierarchyItemCommandAcceptsUnescapedFileURL` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorProjectContextLSPRefresh**（24 条）：由 `testBuildServerPathChangeRequiresServerRestart`、`testLegacyReuseLogicIgnoredBuildServerPathChange`、`testBuildServerKindExtractsInitializationOption` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorProvidingV2AdapterCapability**（15 条）：由 `testOpenDocumentLoadsContentAndActivatesSession`、`testOpenDocumentInBackgroundDoesNotActivate`、`testDiagnosticsSnapshotMapsSeverityMessageAndDocumentURI` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorSelectionSet**（11 条）：由 `testInitialSelection`、`testEmptySelectionsFallbackToInitial`、`testMultipleSelectionsAreSortedByLocation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorServiceFacade**（11 条）：由 `testOpenFileSessionOnlySignalsPendingContentLoadForActiveSession`、`testOpenFileCreatesAndActivatesSession`、`testOpenFileReusesExistingSessionForSameURL` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorStateTheme**（2 条）：由 `testThemeObserverCancellationStopsCallbacks`、`testSameThemeNotificationRefreshesThemeAfterContributorRegistration` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorSyntaxThemeResolver**（2 条）：由 `testResolveUsesRegisteredContributorPalette`、`testRegisterOrReplaceThemeContributorOverridesFallback` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorViewportRuntime**（14 条）：由 `testViewportRenderControllerComputesBufferedRenderRange`、`testViewportRenderControllerClampsAtDocumentBounds`、`testViewportRenderControllerDebounceDecisionTracksScrollDelta` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LSPCoordinatorJumpToDefinition**（3 条）：由 `testRequestDefinitionReturnsNilBeforeDocumentOpen`、`testRequestDefinitionForwardsURIToServiceLayer`、`testRequestDefinitionWaitsForInFlightOpenTask` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CodeEditorHostSuperPlugin**（2 条）：由 `registersEditorServices`、`removesEditorServices` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DocumentHighlightCoordinator | testActivateRestoresCachedSnapshotToTextStorage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testActivateRestoresCachedSnapshotToTextStorage` |
| 2 | DocumentHighlightPrewarmScheduler | testOpenTabsAreAllScheduledIncludingInactiveOnes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOpenTabsAreAllScheduledIncludingInactiveOnes` |
| 3 | DocumentHighlightPrewarmScheduler | testCloseTabDoesNotCrashScheduler | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCloseTabDoesNotCrashScheduler` |
| 4 | EditorBuffer | testReplaceTextUpdatesSnapshotAndVersion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReplaceTextUpdatesSnapshotAndVersion` |
| 5 | EditorBuffer | testApplyTransactionReplacesMultipleRangesFromBackToFront | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testApplyTransactionReplacesMultipleRangesFromBackToFront` |
| 6 | EditorBuffer | testApplyTransactionPreservesProvidedSelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testApplyTransactionPreservesProvidedSelections` |
| 7 | EditorBuffer | testApplyTransactionReturnsNilForInvalidRange | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testApplyTransactionReturnsNilForInvalidRange` |
| 8 | EditorBuffer | testApplyEmptyTransactionPreservesSnapshotButPassesSelectionsThrough | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testApplyEmptyTransactionPreservesSnapshotButPassesSelectionsThrough` |
| 9 | EditorCallHierarchyItem | testFileBadgeAcceptsUnescapedFileURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFileBadgeAcceptsUnescapedFileURL` |
| 10 | EditorCallHierarchyItem | testFileBadgeFallsBackForNonFileURI | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFileBadgeFallsBackForNonFileURI` |
| 11 | EditorConfigStore | testSettingsDirectoryDoesNotDuplicateStorageDirectoryForDefaultRoot | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testSettingsDirectoryDoesNotDuplicateStorageDirectoryForDefaultRoot` |
| 12 | EditorConfigStore | testSettingsDirectoryUsesHostPersistenceRootWhenProvided | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSettingsDirectoryUsesHostPersistenceRootWhenProvided` |
| 13 | EditorContributionRegistry | 安装后语言与 grammar 生效，撤回后完全移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installAndWithdraw` |
| 14 | EditorContributionRegistry | 右键菜单贡献经 Provider 契约安装，并随插件撤回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextMenuContributionInstallAndWithdraw` |
| 15 | EditorContributionRegistry | 替换 Bundle：旧语言撤回、新语言生效（原子 swap generation） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `replaceSwapsAtomically` |
| 16 | EditorContributionRegistry | 校验失败不改现有状态（pluginID 伪造 / 版本不兼容 / 重复 id） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `validationFailureKeepsState` |
| 17 | EditorContributionRegistry | availability：语法能力按语言/grammar 判定，其余 Feature 如实 noProvider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `availabilityResolution` |
| 18 | EditorContributionRegistry | 撤回 Bundle 后贡献与 installedPlugins 同步清除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `withdrawRemovesContributionsAndSyncsInstalledPlugins` |
| 19 | EditorContributionRegistry | Provider 经宿主桥安装为 SuperEditor 贡献者，撤回后移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `featureProviderBridgeInstallsAndWithdraws` |
| 20 | EditorExtensionRegistry | testHighlightProvidersCachesResultsPerLanguage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHighlightProvidersCachesResultsPerLanguage` |
| 21 | EditorExtensionRegistry | testRegisterHighlightContributorViaKernelBridge | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRegisterHighlightContributorViaKernelBridge` |
| 22 | EditorFindReplaceController | testMatchesPlainTextCaseInsensitive | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMatchesPlainTextCaseInsensitive` |
| 23 | EditorFindReplaceController | testMatchesWholeWordSkipsSubstrings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMatchesWholeWordSkipsSubstrings` |
| 24 | EditorFindReplaceController | testMatchesInSelectionOnlyUsesNonEmptySelections | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testMatchesInSelectionOnlyUsesNonEmptySelections` |
| 25 | EditorFindReplaceController | testMatchesInSelectionOnlyUsesAllNonEmptySelectionsInMultiSelectionMode | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testMatchesInSelectionOnlyUsesAllNonEmptySelectionsInMultiSelectionMode` |
| 26 | EditorFindReplaceController | testMatchesInSelectionOnlyFallsBackToPrimarySelectionWhenSelectionsAreEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testMatchesInSelectionOnlyFallsBackToPrimarySelectionWhenSelectionsAreEmpty` |
| 27 | EditorFindReplaceController | testMatchesPreferSelectedMatchRangeWhenPresent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMatchesPreferSelectedMatchRangeWhenPresent` |
| 28 | EditorFindReplaceController | testMatchesPickContainingMatchForPrimarySelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMatchesPickContainingMatchForPrimarySelection` |
| 29 | EditorFindReplaceController | testMatchesPickNextMatchAfterPrimarySelectionWhenNotInsideMatch | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMatchesPickNextMatchAfterPrimarySelectionWhenNotInsideMatch` |
| 30 | EditorFindReplaceController | testNextAndPreviousMatchIndexWrapAround | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNextAndPreviousMatchIndexWrapAround` |
| 31 | EditorJumpToDefinitionDelegate | testSubstringIfValidReturnsTextForValidRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSubstringIfValidReturnsTextForValidRange` |
| 32 | EditorJumpToDefinitionDelegate | testSubstringIfValidRejectsStaleRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testSubstringIfValidRejectsStaleRanges` |
| 33 | EditorJumpToDefinitionDelegate | testLSPFileURLAcceptsUnescapedFileURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLSPFileURLAcceptsUnescapedFileURL` |
| 34 | EditorJumpToDefinitionDelegate | testSameFileComparisonNormalizesUnescapedLSPFileURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSameFileComparisonNormalizesUnescapedLSPFileURL` |
| 35 | EditorJumpToDefinitionDelegate | testReferencePreviewLineReadsUTF16File | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReferencePreviewLineReadsUTF16File` |
| 36 | EditorJumpToDefinitionDelegate | testASTSearchFromRootFindsEarlierSwiftDefinition | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testASTSearchFromRootFindsEarlierSwiftDefinition` |
| 37 | EditorJumpToDefinitionDelegate | testASTSearchFromRootFindsLaterSwiftDefinition | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testASTSearchFromRootFindsLaterSwiftDefinition` |
| 38 | EditorJumpToDefinitionDelegate | testASTSearchFromCursorSubtreeMissesEarlierDefinition | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testASTSearchFromCursorSubtreeMissesEarlierDefinition` |
| 39 | EditorJumpToDefinitionDelegate | testQueryLinksPrefersLSPResultOverLocalFallback | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testQueryLinksPrefersLSPResultOverLocalFallback` |
| 40 | EditorJumpToDefinitionDelegate | testQueryLinksReturnsCrossFileLinkFromLSP | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testQueryLinksReturnsCrossFileLinkFromLSP` |
| 41 | EditorJumpToDefinitionDelegate | testQueryLinksUsesRegexWhenTreeSitterUnavailableEvenInStructuredProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testQueryLinksUsesRegexWhenTreeSitterUnavailableEvenInStructuredProject` |
| 42 | EditorJumpToDefinitionDelegate | testQueryLinksUsesLspClientProviderWhenDirectClientMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testQueryLinksUsesLspClientProviderWhenDirectClientMissing` |
| 43 | EditorJumpToDefinitionDelegate | testQueryLinksReturnsNilWhenAllStrategiesMiss | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testQueryLinksReturnsNilWhenAllStrategiesMiss` |
| 44 | EditorJumpToDefinitionDelegate | testRefreshExtensionProvidersRebindsJumpDelegateLSPClient | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRefreshExtensionProvidersRebindsJumpDelegateLSPClient` |
| 45 | EditorKernelPureLogic | testEditorMinimapPolicyVisibleStateUsesUserPreference | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorMinimapPolicyVisibleStateUsesUserPreference` |
| 46 | EditorKernelPureLogic | testEditorMinimapPolicyLargeFileStateIsGated | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorMinimapPolicyLargeFileStateIsGated` |
| 47 | EditorKernelPureLogic | testEditorPeekModeTitlesRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEditorPeekModeTitlesRemainStable` |
| 48 | EditorKernelPureLogic | testEditorFileStateRelativeFilePathRejectsSiblingProjectWithSharedPrefix | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testEditorFileStateRelativeFilePathRejectsSiblingProjectWithSharedPrefix` |
| 49 | EditorKernelPureLogic | testEditorFileStateRelativeFilePathTrimsCopiedProjectRootPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorFileStateRelativeFilePathTrimsCopiedProjectRootPath` |
| 50 | EditorKernelPureLogic | testEditorPeekControllerBuildsDefinitionPresentationFromCurrentBuffer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorPeekControllerBuildsDefinitionPresentationFromCurrentBuffer` |
| 51 | EditorKernelPureLogic | testEditorPeekControllerReferencesFallBackWhenNoFileCanBeResolved | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorPeekControllerReferencesFallBackWhenNoFileCanBeResolved` |
| 52 | EditorKernelPureLogic | testTextEditApplierAppliesMultipleEditsFromBackToFront | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTextEditApplierAppliesMultipleEditsFromBackToFront` |
| 53 | EditorKernelPureLogic | testTextEditApplierReturnsNilWhenEditRangeIsInvalid | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTextEditApplierReturnsNilWhenEditRangeIsInvalid` |
| 54 | EditorKernelPureLogic | testTextEditTransactionBuilderMapsUnicodeLSPPositionsToEditorRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTextEditTransactionBuilderMapsUnicodeLSPPositionsToEditorRanges` |
| 55 | EditorKernelPureLogic | testTextEditTransactionBuilderRejectsOutOfBoundsLines | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTextEditTransactionBuilderRejectsOutOfBoundsLines` |
| 56 | EditorKernelPureLogic | testTextViewBridgeRejectsOverflowingNativeRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTextViewBridgeRejectsOverflowingNativeRanges` |
| 57 | EditorKernelPureLogic | testTextViewBridgeLastCharacterKeepsComposedCharactersIntact | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTextViewBridgeLastCharacterKeepsComposedCharactersIntact` |
| 58 | EditorKernelPureLogic | testTextViewBridgeLastCharacterRejectsInvalidLocations | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTextViewBridgeLastCharacterRejectsInvalidLocations` |
| 59 | EditorKernelPureLogic | testEditorCommandSuggestionHelpersClampNonPositiveLimits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorCommandSuggestionHelpersClampNonPositiveLimits` |
| 60 | EditorKernelPureLogic | testEditorStateSymbolNameForRenameKeepsComposedIdentifierCharacters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateSymbolNameForRenameKeepsComposedIdentifierCharacters` |
| 61 | EditorKernelPureLogic | testEditorStateSymbolNameForRenameSupportsNonLatinIdentifiers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateSymbolNameForRenameSupportsNonLatinIdentifiers` |
| 62 | EditorKernelPureLogic | testEditorStateSymbolNameForRenameRejectsNonIdentifierCharacters | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testEditorStateSymbolNameForRenameRejectsNonIdentifierCharacters` |
| 63 | EditorKernelPureLogic | testEditorViewStateControllerIgnoresOverflowingSelectionEnds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorViewStateControllerIgnoresOverflowingSelectionEnds` |
| 64 | EditorKernelPureLogic | testEditorViewStateControllerDoesNotOverflowFallbackSelectionEnd | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorViewStateControllerDoesNotOverflowFallbackSelectionEnd` |
| 65 | EditorKernelPureLogic | testEditorOverlayControllerRejectsInvalidSelectionEndOffsets | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testEditorOverlayControllerRejectsInvalidSelectionEndOffsets` |
| 66 | EditorKernelPureLogic | testFindReplaceTransactionBuilderReplaceCurrentPreservesUppercaseMatch | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFindReplaceTransactionBuilderReplaceCurrentPreservesUppercaseMatch` |
| 67 | EditorKernelPureLogic | testFindReplaceTransactionBuilderReplaceAllPreservesTitleCaseAndClearsSelections | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testFindReplaceTransactionBuilderReplaceAllPreservesTitleCaseAndClearsSelections` |
| 68 | EditorKernelPureLogic | testFindReplaceTransactionBuilderReturnsNilWhenNoSelectedMatchExists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFindReplaceTransactionBuilderReturnsNilWhenNoSelectedMatchExists` |
| 69 | EditorKernelPureLogic | testFindReplaceTransactionBuilderPreviewReturnsReplacementWithoutCasePreservation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFindReplaceTransactionBuilderPreviewReturnsReplacementWithoutCasePreservation` |
| 70 | EditorKernelPureLogic | testEditorConfigContextNormalizesWorkspacePathAndLanguage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorConfigContextNormalizesWorkspacePathAndLanguage` |
| 71 | EditorKernelPureLogic | testEditorConfigOverrideScopeUsesNormalizedKeys | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorConfigOverrideScopeUsesNormalizedKeys` |
| 72 | EditorKernelPureLogic | testEditorScopedOverrideSnapshotAppliesOnlyProvidedFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorScopedOverrideSnapshotAppliesOnlyProvidedFields` |
| 73 | EditorKernelPureLogic | testEditorScopedOverrideSnapshotDictionaryRoundTrips | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorScopedOverrideSnapshotDictionaryRoundTrips` |
| 74 | EditorKernelPureLogic | testEditorQuickOpenControllerParsesScopedQueries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorQuickOpenControllerParsesScopedQueries` |
| 75 | EditorKernelPureLogic | testEditorQuickOpenControllerDefaultsToFileSearchForPlainQuery | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEditorQuickOpenControllerDefaultsToFileSearchForPlainQuery` |
| 76 | EditorKernelPureLogic | testCursorMotionControllerMoveWordLeftSkipsWhitespaceAndOperators | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCursorMotionControllerMoveWordLeftSkipsWhitespaceAndOperators` |
| 77 | EditorKernelPureLogic | testCursorMotionControllerMoveWordRightStopsAtEndOfNextWord | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCursorMotionControllerMoveWordRightStopsAtEndOfNextWord` |
| 78 | EditorKernelPureLogic | testCursorMotionControllerDeleteWordLeftReturnsDeletionRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCursorMotionControllerDeleteWordLeftReturnsDeletionRange` |
| 79 | EditorKernelPureLogic | testCursorMotionControllerSmartHomeTogglesBetweenIndentAndLineStart | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCursorMotionControllerSmartHomeTogglesBetweenIndentAndLineStart` |
| 80 | EditorKernelPureLogic | testCursorMotionControllerMoveToEndOfLineHandlesCRLF | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCursorMotionControllerMoveToEndOfLineHandlesCRLF` |
| 81 | EditorKernelPureLogic | testCursorMotionControllerParagraphNavigationRespectsBlankLines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCursorMotionControllerParagraphNavigationRespectsBlankLines` |
| 82 | EditorKernelPureLogic | testMultiCursorEditEngineInsertReplacesSelectionAndPreservesOrder | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultiCursorEditEngineInsertReplacesSelectionAndPreservesOrder` |
| 83 | EditorKernelPureLogic | testMultiCursorEditEngineDeleteBackwardDeletesSelectedTextAndPreviousCharacter | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultiCursorEditEngineDeleteBackwardDeletesSelectedTextAndPreviousCharacter` |
| 84 | EditorKernelPureLogic | testMultiCursorEditEngineIndentExpandsCoveredSelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultiCursorEditEngineIndentExpandsCoveredSelections` |
| 85 | EditorKernelPureLogic | testMultiCursorEditEngineOutdentRemovesLeadingSpacesAndShiftsSelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultiCursorEditEngineOutdentRemovesLeadingSpacesAndShiftsSelections` |
| 86 | EditorKernelPureLogic | testMultiCursorStateAddSecondaryRejectsDuplicatesAndInvalidSelections | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testMultiCursorStateAddSecondaryRejectsDuplicatesAndInvalidSelections` |
| 87 | EditorKernelPureLogic | testEditorMultiCursorStateControllerReplacingPrimaryPreservesSecondaryOrder | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorMultiCursorStateControllerReplacingPrimaryPreservesSecondaryOrder` |
| 88 | EditorKernelPureLogic | testEditorMultiCursorMatcherNormalizedRangeClampsToTextBounds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorMultiCursorMatcherNormalizedRangeClampsToTextBounds` |
| 89 | EditorKernelPureLogic | testEditorMultiCursorMatcherResolvesWordSelectionFromCaret | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorMultiCursorMatcherResolvesWordSelectionFromCaret` |
| 90 | EditorKernelPureLogic | testEditorMultiCursorMatcherRangesUseWholeWordMatchingForIdentifiers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorMultiCursorMatcherRangesUseWholeWordMatchingForIdentifiers` |
| 91 | EditorKernelPureLogic | testEditorMultiCursorSearchControllerResolvedContextReusesExistingSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorMultiCursorSearchControllerResolvedContextReusesExistingSession` |
| 92 | EditorKernelPureLogic | testEditorMultiCursorSearchControllerNextSelectionSkipsAlreadySelectedMatches | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorMultiCursorSearchControllerNextSelectionSkipsAlreadySelectedMatches` |
| 93 | EditorKernelPureLogic | testEditorMultiCursorControllerSummaryTextReflectsCursorCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorMultiCursorControllerSummaryTextReflectsCursorCount` |
| 94 | EditorKernelPureLogic | testEditorFindControllerStateUpdatesKeepPanelVisibleAndPreserveOtherFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorFindControllerStateUpdatesKeepPanelVisibleAndPreserveOtherFields` |
| 95 | EditorKernelPureLogic | testEditorFindControllerApplyMethodsUpdateMatchSelectionState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorFindControllerApplyMethodsUpdateMatchSelectionState` |
| 96 | EditorKernelPureLogic | testEditorFindReplaceStateControllerPreservesOptionsAndResultMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorFindReplaceStateControllerPreservesOptionsAndResultMetadata` |
| 97 | EditorKernelPureLogic | testMultiCursorTransactionBuilderDeleteBackwardBuildsExpectedReplacements | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultiCursorTransactionBuilderDeleteBackwardBuildsExpectedReplacements` |
| 98 | EditorKernelPureLogic | testEditorTransactionControllerTransactionForInputEditRejectsInvalidRange | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testEditorTransactionControllerTransactionForInputEditRejectsInvalidRange` |
| 99 | EditorKernelPureLogic | testEditorTransactionControllerCompletionEditMovesCursorAfterAdditionalEdits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorTransactionControllerCompletionEditMovesCursorAfterAdditionalEdits` |
| 100 | EditorKernelPureLogic | testEditorTransactionControllerCommitPayloadMapsSelectionsIntoBothForms | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorTransactionControllerCommitPayloadMapsSelectionsIntoBothForms` |
| 101 | EditorKernelPureLogic | testCommandRouterContextMirrorsLegacyValuesAndEditorStateFlags | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCommandRouterContextMirrorsLegacyValuesAndEditorStateFlags` |
| 102 | EditorKernelPureLogic | testCommandRouterRegistersSuggestionsAndExecutesViaRegistry | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCommandRouterRegistersSuggestionsAndExecutesViaRegistry` |
| 103 | EditorKernelPureLogic | testCommandRouterFallsBackToLegacySuggestionsWhenRegistryMisses | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCommandRouterFallsBackToLegacySuggestionsWhenRegistryMisses` |
| 104 | EditorKernelPureLogic | testEditorInputCommandControllerDeleteWordLeftProducesDeletionTransaction | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorInputCommandControllerDeleteWordLeftProducesDeletionTransaction` |
| 105 | EditorKernelPureLogic | testEditorInputCommandControllerSmartHomeSelectExpandsSelectionFromAnchor | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorInputCommandControllerSmartHomeSelectExpandsSelectionFromAnchor` |
| 106 | EditorKernelPureLogic | testEditorSnippetParserSeedsRepeatedPlaceholdersAndTracksExplicitExit | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEditorSnippetParserSeedsRepeatedPlaceholdersAndTracksExplicitExit` |
| 107 | EditorKernelPureLogic | testEditorSnippetParserUsesImplicitExitAtEndWhenZeroPlaceholderIsMissing | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEditorSnippetParserUsesImplicitExitAtEndWhenZeroPlaceholderIsMissing` |
| 108 | EditorKernelPureLogic | testEditorSnippetParserTreatsEscapedMarkersAsLiteralText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorSnippetParserTreatsEscapedMarkersAsLiteralText` |
| 109 | EditorKernelPureLogic | testEditorCommandCategoryResolveAndOrderIndexFallBackToOther | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorCommandCategoryResolveAndOrderIndexFallBackToOther` |
| 110 | EditorKernelPureLogic | testEditorCommandPresentationModelBuildsRecentFrequentAndCategorizedSections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorCommandPresentationModelBuildsRecentFrequentAndCategorizedSections` |
| 111 | EditorKernelPureLogic | testEditorCommandPresentationModelFiltersByQueryShortcutAndAllowedCategories | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorCommandPresentationModelFiltersByQueryShortcutAndAllowedCategories` |
| 112 | EditorKernelPureLogic | testCommandSuggestionsSortByCategoryOrderThenCommandOrderThenTitle | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testCommandSuggestionsSortByCategoryOrderThenCommandOrderThenTitle` |
| 113 | EditorKernelPureLogic | testEditorCommandCategoryScopeSetsRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEditorCommandCategoryScopeSetsRemainStable` |
| 114 | EditorKeybindingStore | testBindingsFileUsesDefaultRootWithoutForceUnwrappingApplicationSupport | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testBindingsFileUsesDefaultRootWithoutForceUnwrappingApplicationSupport` |
| 115 | EditorKeybindingStore | testBindingsFileUsesHostPersistenceRootWhenProvided | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBindingsFileUsesHostPersistenceRootWhenProvided` |
| 116 | EditorKeybindingStore | testCorruptBindingsFileIsQuarantinedAndRecovered | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCorruptBindingsFileIsQuarantinedAndRecovered` |
| 117 | EditorKeybindingStore | testSetBindingReportsFailureWhenSettingsDirectoryIsBlocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSetBindingReportsFailureWhenSettingsDirectoryIsBlocked` |
| 118 | EditorOpenItemCommand | testCallHierarchyItemCommandAcceptsUnescapedFileURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCallHierarchyItemCommandAcceptsUnescapedFileURL` |
| 119 | EditorProjectContextLSPRefresh | testBuildServerPathChangeRequiresServerRestart | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBuildServerPathChangeRequiresServerRestart` |
| 120 | EditorProjectContextLSPRefresh | testLegacyReuseLogicIgnoredBuildServerPathChange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLegacyReuseLogicIgnoredBuildServerPathChange` |
| 121 | EditorProjectContextLSPRefresh | testBuildServerKindExtractsInitializationOption | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBuildServerKindExtractsInitializationOption` |
| 122 | EditorProjectContextLSPRefresh | testBuildServerKindChangeRequiresServerRestart | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBuildServerKindChangeRequiresServerRestart` |
| 123 | EditorProjectContextLSPRefresh | testBuildServerPathExtractsInitializationOption | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBuildServerPathExtractsInitializationOption` |
| 124 | EditorProjectContextLSPRefresh | testSameBuildServerPathCanReuseExistingServer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSameBuildServerPathCanReuseExistingServer` |
| 125 | EditorProjectContextLSPRefresh | testBuildServerPathUpdateRequiresRestartEvenWhenPreviouslyAvailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBuildServerPathUpdateRequiresRestartEvenWhenPreviouslyAvailable` |
| 126 | EditorProjectContextLSPRefresh | testStartTaskSignatureIncludesBuildServerPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStartTaskSignatureIncludesBuildServerPath` |
| 127 | EditorProjectContextLSPRefresh | testOpenDocumentRegressionWhenBuildServerPathBecomesAvailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOpenDocumentRegressionWhenBuildServerPathBecomesAvailable` |
| 128 | EditorProjectContextLSPRefresh | testOpenDocumentDoesNotRestartWhenContextUnchanged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOpenDocumentDoesNotRestartWhenContextUnchanged` |
| 129 | EditorProjectContextLSPRefresh | testRefreshWhenBuildContextBecomesAvailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRefreshWhenBuildContextBecomesAvailable` |
| 130 | EditorProjectContextLSPRefresh | testNoRefreshWhileBuildContextStillResolving | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoRefreshWhileBuildContextStillResolving` |
| 131 | EditorProjectContextLSPRefresh | testNoRefreshWithoutOpenFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoRefreshWithoutOpenFile` |
| 132 | EditorProjectContextLSPRefresh | testNoRefreshForNonStructuredProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoRefreshForNonStructuredProject` |
| 133 | EditorProjectContextLSPRefresh | testDefaultEditorHostNotificationDoesNotMatchBridgeContract | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testDefaultEditorHostNotificationDoesNotMatchBridgeContract` |
| 134 | EditorProjectContextLSPRefresh | testSuppressesNoSuchModuleBeforeBuildContextReady | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSuppressesNoSuchModuleBeforeBuildContextReady` |
| 135 | EditorProjectContextLSPRefresh | testPublishesNoSuchModuleAfterBuildContextReady | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPublishesNoSuchModuleAfterBuildContextReady` |
| 136 | EditorProjectContextLSPRefresh | testSuppressesKnownModuleDiagnosticAfterBuildContextReady | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSuppressesKnownModuleDiagnosticAfterBuildContextReady` |
| 137 | EditorProjectContextLSPRefresh | testPublishesOtherDiagnosticsBeforeBuildContextReady | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPublishesOtherDiagnosticsBeforeBuildContextReady` |
| 138 | EditorProjectContextLSPRefresh | testEditorStateRefreshesLSPWhenBuildContextBecomesAvailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateRefreshesLSPWhenBuildContextBecomesAvailable` |
| 139 | EditorProjectContextLSPRefresh | testEditorStateDoesNotRefreshLSPWhileBuildContextStillResolving | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateDoesNotRefreshLSPWhileBuildContextStillResolving` |
| 140 | EditorProjectContextLSPRefresh | testEditorStateReceivesBridgeNotificationAfterRefreshExtensionProviders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateReceivesBridgeNotificationAfterRefreshExtensionProviders` |
| 141 | EditorProjectContextLSPRefresh | testInitializationOptionsMissingUntilBuildServerIsReady | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInitializationOptionsMissingUntilBuildServerIsReady` |
| 142 | EditorProjectContextLSPRefresh | testInitializationOptionsIncludeBuildServerPathWhenReady | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInitializationOptionsIncludeBuildServerPathWhenReady` |
| 143 | EditorProvidingV2AdapterCapability | testOpenDocumentLoadsContentAndActivatesSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOpenDocumentLoadsContentAndActivatesSession` |
| 144 | EditorProvidingV2AdapterCapability | testOpenDocumentInBackgroundDoesNotActivate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOpenDocumentInBackgroundDoesNotActivate` |
| 145 | EditorProvidingV2AdapterCapability | testDiagnosticsSnapshotMapsSeverityMessageAndDocumentURI | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDiagnosticsSnapshotMapsSeverityMessageAndDocumentURI` |
| 146 | EditorProvidingV2AdapterCapability | testDiagnosticsSnapshotEmptyWhenNoServiceData | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testDiagnosticsSnapshotEmptyWhenNoServiceData` |
| 147 | EditorProvidingV2AdapterCapability | testDocumentSymbolsMapTreeAndRefreshForwardsToProvider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDocumentSymbolsMapTreeAndRefreshForwardsToProvider` |
| 148 | EditorProvidingV2AdapterCapability | testPanelPresentAndObserveRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPanelPresentAndObserveRoundTrip` |
| 149 | EditorProvidingV2AdapterCapability | testReferencesStateMapsResultsAndSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReferencesStateMapsResultsAndSelection` |
| 150 | EditorProvidingV2AdapterCapability | testCallHierarchyPrepareAndRootMapping | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCallHierarchyPrepareAndRootMapping` |
| 151 | EditorProvidingV2AdapterCapability | testCallHierarchyFetchForRootNodeUsesRootItemFallback | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCallHierarchyFetchForRootNodeUsesRootItemFallback` |
| 152 | EditorProvidingV2AdapterCapability | testWorkspaceSearchStateMapsResultsSummaryAndError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWorkspaceSearchStateMapsResultsSummaryAndError` |
| 153 | EditorProvidingV2AdapterCapability | testDefaultExtensionsHostingIsSharedWithServiceRegistry | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testDefaultExtensionsHostingIsSharedWithServiceRegistry` |
| 154 | EditorProvidingV2AdapterCapability | testComputeDiffProducesHunksWithLineKinds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testComputeDiffProducesHunksWithLineKinds` |
| 155 | EditorProvidingV2AdapterCapability | testWorkingDiffEmptyWithoutDocument | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testWorkingDiffEmptyWithoutDocument` |
| 156 | EditorProvidingV2AdapterCapability | testWorkingDiffReflectsBufferVersusDisk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWorkingDiffReflectsBufferVersusDisk` |
| 157 | EditorProvidingV2AdapterCapability | testAcceptHunksAppliesOnlyAcceptedHunks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAcceptHunksAppliesOnlyAcceptedHunks` |
| 158 | EditorSelectionSet | testInitialSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInitialSelection` |
| 159 | EditorSelectionSet | testEmptySelectionsFallbackToInitial | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEmptySelectionsFallbackToInitial` |
| 160 | EditorSelectionSet | testMultipleSelectionsAreSortedByLocation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultipleSelectionsAreSortedByLocation` |
| 161 | EditorSelectionSet | testReplacingPrimaryKeepsSecondarySelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReplacingPrimaryKeepsSecondarySelections` |
| 162 | EditorSelectionSet | testAddingSelectionPreservesSortedOrder | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAddingSelectionPreservesSortedOrder` |
| 163 | EditorSelectionSet | testRemovingLastSecondaryDropsTrailingSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRemovingLastSecondaryDropsTrailingSelection` |
| 164 | EditorSelectionSet | testClearingSecondaryKeepsOnlyPrimary | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testClearingSecondaryKeepsOnlyPrimary` |
| 165 | EditorSelectionSet | testRoundTripsMultiCursorSelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRoundTripsMultiCursorSelections` |
| 166 | EditorSelectionSet | testToMultiCursorStateReflectsPrimaryAndEnabledState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToMultiCursorStateReflectsPrimaryAndEnabledState` |
| 167 | EditorSelectionSet | testReplacingAllFallsBackToInitialForEmptySelections | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testReplacingAllFallsBackToInitialForEmptySelections` |
| 168 | EditorSelectionSet | testRemovingLastSecondaryLeavesSingleSelectionUntouched | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRemovingLastSecondaryLeavesSingleSelectionUntouched` |
| 169 | EditorServiceFacade | testOpenFileSessionOnlySignalsPendingContentLoadForActiveSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOpenFileSessionOnlySignalsPendingContentLoadForActiveSession` |
| 170 | EditorServiceFacade | testOpenFileCreatesAndActivatesSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOpenFileCreatesAndActivatesSession` |
| 171 | EditorServiceFacade | testOpenFileReusesExistingSessionForSameURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOpenFileReusesExistingSessionForSameURL` |
| 172 | EditorServiceFacade | testCloseOtherSessionsKeepsOnlyRequestedSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCloseOtherSessionsKeepsOnlyRequestedSession` |
| 173 | EditorServiceFacade | testNavigationBackAndForwardSwitchesActiveSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNavigationBackAndForwardSwitchesActiveSession` |
| 174 | EditorServiceFacade | testCloseAllSessionsClearsTabsAndActiveSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCloseAllSessionsClearsTabsAndActiveSession` |
| 175 | EditorServiceFacade | testSessionLookupMapToleratesDuplicateSessionIDs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionLookupMapToleratesDuplicateSessionIDs` |
| 176 | EditorServiceFacade | testBuiltinSavePersistsDirtyBufferAndClearsDirtyState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBuiltinSavePersistsDirtyBufferAndClearsDirtyState` |
| 177 | EditorServiceFacade | testReplaceCurrentDocumentTextUpdatesContentAndDirtyState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReplaceCurrentDocumentTextUpdatesContentAndDirtyState` |
| 178 | EditorServiceFacade | testRefreshProjectContextClosesPreviousContextWhenSwitchingToNonXcodeProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRefreshProjectContextClosesPreviousContextWhenSwitchingToNonXcodeProject` |
| 179 | EditorServiceFacade | testClearingEditorInvalidatesPendingFileLoads | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testClearingEditorInvalidatesPendingFileLoads` |
| 180 | EditorStateTheme | testThemeObserverCancellationStopsCallbacks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testThemeObserverCancellationStopsCallbacks` |
| 181 | EditorStateTheme | testSameThemeNotificationRefreshesThemeAfterContributorRegistration | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSameThemeNotificationRefreshesThemeAfterContributorRegistration` |
| 182 | EditorSyntaxThemeResolver | testResolveUsesRegisteredContributorPalette | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResolveUsesRegisteredContributorPalette` |
| 183 | EditorSyntaxThemeResolver | testRegisterOrReplaceThemeContributorOverridesFallback | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRegisterOrReplaceThemeContributorOverridesFallback` |
| 184 | EditorViewportRuntime | testViewportRenderControllerComputesBufferedRenderRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testViewportRenderControllerComputesBufferedRenderRange` |
| 185 | EditorViewportRuntime | testViewportRenderControllerClampsAtDocumentBounds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testViewportRenderControllerClampsAtDocumentBounds` |
| 186 | EditorViewportRuntime | testViewportRenderControllerDebounceDecisionTracksScrollDelta | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testViewportRenderControllerDebounceDecisionTracksScrollDelta` |
| 187 | EditorViewportRuntime | testEditorRuntimeModeControllerViewportFeatureRules | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorRuntimeModeControllerViewportFeatureRules` |
| 188 | EditorViewportRuntime | testEditorRuntimeModeControllerDisablesSyntaxFeaturesWhenLongLineProtectionApplies | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorRuntimeModeControllerDisablesSyntaxFeaturesWhenLongLineProtectionApplies` |
| 189 | EditorViewportRuntime | testEditorStateApplyViewportObservationUpdatesMirroredRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateApplyViewportObservationUpdatesMirroredRanges` |
| 190 | EditorViewportRuntime | testEditorStateRenderedRangeHelpersUseViewportRenderRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateRenderedRangeHelpersUseViewportRenderRange` |
| 191 | EditorViewportRuntime | testEditorStateRenderedRangeHelpersFilterOutOfViewportContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateRenderedRangeHelpersFilterOutOfViewportContent` |
| 192 | EditorViewportRuntime | testEditorStateResetViewportObservationClearsRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateResetViewportObservationClearsRanges` |
| 193 | EditorViewportRuntime | testEditorStateStaticViewportHelpersMirrorRuntimeModeController | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateStaticViewportHelpersMirrorRuntimeModeController` |
| 194 | EditorViewportRuntime | testEditorStatePresentsSignatureHelpOverlayWhenCursorIsRendered | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStatePresentsSignatureHelpOverlayWhenCursorIsRendered` |
| 195 | EditorViewportRuntime | testEditorStateHidesOverlaysWhenPrimaryCursorFallsOutsideRenderedViewport | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateHidesOverlaysWhenPrimaryCursorFallsOutsideRenderedViewport` |
| 196 | EditorViewportRuntime | testEditorStateHandleViewportRuntimeTransitionClearsTransientProviders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateHandleViewportRuntimeTransitionClearsTransientProviders` |
| 197 | EditorViewportRuntime | testEditorStateAvailabilityChangeHandlersClearOnlyWhenDisabling | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditorStateAvailabilityChangeHandlersClearOnlyWhenDisabling` |
| 198 | LSPCoordinatorJumpToDefinition | testRequestDefinitionReturnsNilBeforeDocumentOpen | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRequestDefinitionReturnsNilBeforeDocumentOpen` |
| 199 | LSPCoordinatorJumpToDefinition | testRequestDefinitionForwardsURIToServiceLayer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRequestDefinitionForwardsURIToServiceLayer` |
| 200 | LSPCoordinatorJumpToDefinition | testRequestDefinitionWaitsForInFlightOpenTask | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRequestDefinitionWaitsForInFlightOpenTask` |
| 201 | CodeEditorHostSuperPlugin | registers the shared editor service and every host capability | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersEditorServices` |
| 202 | CodeEditorHostSuperPlugin | removes every editor capability during shutdown | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removesEditorServices` |

> 说明：全部 **202 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 15 / 15
- P1: 已覆盖 168 / 168
- P2: 已覆盖 19 / 19
- **合计: 202 / 202**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（15 条）
- **P1**: 其余功能性用例（168 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（19 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 202 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginCodeEditorHost
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
