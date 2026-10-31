# TestPlan — KitEditorKernel

## 包概述

KitEditorKernel 可复用的编辑器内核纯逻辑模块（SwiftPM 包），尽量与 UI 解耦。 ## 全局技术架构 Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。 ```text 应用装配层 (LumiApp) ↓ 插件扩展层 (Packages/Plugin*) ↓ Host 内部服务 target (EditorService) ↓ ↓ 视图层 (EditorSource) 内核逻辑层 (EditorKernel) ← 本 Package ↓ 渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols) ``` ## 本 Package 的位置 | 属性 | 值 | |------|-----| | **层级** | 内核逻辑层 | | **职责** | 无 UI 依赖的编辑域纯逻辑：选择集、多光标、查找替换、折叠、导航、保存工作流、LSP 请求模型与策略 | | **上游依赖** | `LanguageServerProtocol` | | **下游消费者** | `EditorService`（桥接为 App 侧控制器）、`EditorService/Proto`（扩展点协议引用内核模型） | | **不得依赖** | 任何 Plugin、`EditorSource`、`EditorTextView`、SwiftUI/AppKit 视图 |

平台: macOS 14+, iOS 17+
测试文件: 18 个，用例总数: 318

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `CommandKey`
- `EditorCommandCategory`
- `EditorCommandShortcut`
- `EditorCommandPresentationModel`
- `EditorCommandRouterBridge`
- `EditorCommandSuggestionPolicy`
- `EditorInputCommandController`
- `EditorSettingsQuickOpenSearchItem`
- `EditorShortcutDefinition`
- `EditorFindController`
- `EditorFindMatch`
- `EditorFindReplaceController`
- `EditorFindReplaceOptions`
- `EditorFindReplaceState`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **EditorCommandCategoryLocalization**（1 条）：由 `loadsSimplifiedChineseCategoryTitles` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorDocumentSymbol**（24 条）：由 `initializationWithRequestDocumentSymbols`、`refreshSetsIsLoadingAndUpdatesSymbols`、`clearResetsState` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorKernelCoverageAdditional**（37 条）：由 `findMatchingBracketAtOpenAndClosePositions`、`findMatchingBracketRejectsInvalidCursor`、`shouldAutoCloseRespectsStringAndCommentContexts` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorKernel**（127 条）：由 `textInputControllerBuildsBracketAndIndentPlans`、`bracketAndIndentPoliciesHandleLanguageAndOutdentRules`、`inputCommandControllerBuildsLineEditAndCursorPlans` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextDiffEngine**（10 条）：由 `identicalTextsProduceEmptyDiff`、`emptyToContentIsPureAddition`、`contentToEmptyIsPureRemoval` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorLSPActionPolicy**（5 条）：由 `languageIDMapping`、`statusMessageKeyMapping`、`referenceResultSorting` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorNavigationController**（3 条）：由 `resolveReferenceRequest`、`cursorPositionsForDiagnostic`、`resolvedDefinitionTargetHighlightLine` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorOpenItemCommandController**（7 条）：由 `resolveWorkspaceSymbolCommand`、`resolveWorkspaceSymbolCommandWithUnescapedFileURL`、`resolveProblemCommand` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorSemanticModels**（19 条）：由 `workspaceFolderInitialization`、`workspaceFolderEquality`、`semanticPreflightStrengthCases` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorSnippetSession**（9 条）：由 `placeholderGroupInitialization`、`placeholderGroupEquality`、`snippetSessionInitialization` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorStatusMessage**（23 条）：由 `externalFileChangedOnDiskWithFileName`、`externalFileChangedOnDiskWithoutFileName`、`externalFileChangedOnDiskWithEmptyFileName` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LSPRequestCache**（9 条）：由 `cacheStoreAndRetrieve`、`cacheMissingKey`、`cacheDifferentiatesByKind` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LSPViewportScheduler**（8 条）：由 `significantViewportChange`、`kindDefaultPriority`、`kindDefaultDebounceMs` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LineOffsetBugVerify**（3 条）：由 `replaceRemovingNewlineWithLongerText`、`equalLengthReplaceRemovingNewline`、`multiLineReplaceInsertingNewlines` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LineOffsetTableIncremental**（20 条）：由 `initProducesCorrectLineStarts`、`initProducesCorrectLineStartsWithEmptyString`、`initSingleLineNoTrailingNewline` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WorkspaceEditFileOperationsCoverage**（8 条）：由 `fileURLRejects`、`createBranches`、`renameBranches` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WorkspaceEditFileOperations**（2 条）：由 `fileURLParsing`、`createDeleteOperations` 等用例锁定；改动该模块时优先跑对应测试文件。
- **XCConfigSyntaxCore**（3 条）：由 `tokenizeContent`、`includeDirectiveAtLocation`、`keyOccurrences` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | EditorCommandCategoryLocalization | loads simplified Chinese category titles from bundle | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `loadsSimplifiedChineseCategoryTitles` |
| 2 | EditorDocumentSymbol | initializationWithRequestDocumentSymbols | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initializationWithRequestDocumentSymbols` |
| 3 | EditorDocumentSymbol | refreshSetsIsLoadingAndUpdatesSymbols | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshSetsIsLoadingAndUpdatesSymbols` |
| 4 | EditorDocumentSymbol | clearResetsState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearResetsState` |
| 5 | EditorDocumentSymbol | resetDoesNotClearSymbols | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetDoesNotClearSymbols` |
| 6 | EditorDocumentSymbol | applySymbolsUpdatesSymbolsList | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `applySymbolsUpdatesSymbolsList` |
| 7 | EditorDocumentSymbol | activeItemsReturnsCorrectItems | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activeItemsReturnsCorrectItems` |
| 8 | EditorDocumentSymbol | activeItemsReturnsEmptyForOutOfRange | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `activeItemsReturnsEmptyForOutOfRange` |
| 9 | EditorDocumentSymbol | activePathIDsReturnsCorrectIDs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activePathIDsReturnsCorrectIDs` |
| 10 | EditorDocumentSymbol | activeAncestorIDsReturnsCorrectSet | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activeAncestorIDsReturnsCorrectSet` |
| 11 | EditorDocumentSymbol | handlesNestedSymbols | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `handlesNestedSymbols` |
| 12 | EditorDocumentSymbol | initializationFromDocumentSymbol | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initializationFromDocumentSymbol` |
| 13 | EditorDocumentSymbol | initializationWithPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initializationWithPath` |
| 14 | EditorDocumentSymbol | initializationWithChildren | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initializationWithChildren` |
| 15 | EditorDocumentSymbol | lineAndColumnProperties | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineAndColumnProperties` |
| 16 | EditorDocumentSymbol | iconSymbolForDifferentKinds | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `iconSymbolForDifferentKinds` |
| 17 | EditorDocumentSymbol | iconSymbolDefaultForUnknownKind | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `iconSymbolDefaultForUnknownKind` |
| 18 | EditorDocumentSymbol | containsLineInRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `containsLineInRange` |
| 19 | EditorDocumentSymbol | activePathForLineInRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activePathForLineInRange` |
| 20 | EditorDocumentSymbol | activePathReturnsNilForOutOfRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activePathReturnsNilForOutOfRange` |
| 21 | EditorDocumentSymbol | activePathWithChildren | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activePathWithChildren` |
| 22 | EditorDocumentSymbol | activeItemsForLineInRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activeItemsForLineInRange` |
| 23 | EditorDocumentSymbol | activeItemsWithNestedChildren | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activeItemsWithNestedChildren` |
| 24 | EditorDocumentSymbol | equality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equality` |
| 25 | EditorDocumentSymbol | inequality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inequality` |
| 26 | EditorKernelCoverageAdditional | findMatchingBracketAtOpenAndClosePositions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findMatchingBracketAtOpenAndClosePositions` |
| 27 | EditorKernelCoverageAdditional | findMatchingBracketRejectsInvalidCursor | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `findMatchingBracketRejectsInvalidCursor` |
| 28 | EditorKernelCoverageAdditional | shouldAutoCloseRespectsStringAndCommentContexts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldAutoCloseRespectsStringAndCommentContexts` |
| 29 | EditorKernelCoverageAdditional | shouldAutoSurroundAndAutoClosingEdit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldAutoSurroundAndAutoClosingEdit` |
| 30 | EditorKernelCoverageAdditional | smartIndentEnterProducesIndentedNewlines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `smartIndentEnterProducesIndentedNewlines` |
| 31 | EditorKernelCoverageAdditional | smartIndentTabAndBacktabAdjustSelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `smartIndentTabAndBacktabAdjustSelections` |
| 32 | EditorKernelCoverageAdditional | verticalMotionUsesDesiredColumnAndClamps | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `verticalMotionUsesDesiredColumnAndClamps` |
| 33 | EditorKernelCoverageAdditional | lineEndHandlesCRLFAndPlainLines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineEndHandlesCRLFAndPlainLines` |
| 34 | EditorKernelCoverageAdditional | smartHomeTogglesBetweenContentAndColumnZero | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `smartHomeTogglesBetweenContentAndColumnZero` |
| 35 | EditorKernelCoverageAdditional | paragraphMotionMovesBetweenBlocks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paragraphMotionMovesBetweenBlocks` |
| 36 | EditorKernelCoverageAdditional | leftRightMotionClampBoundaries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `leftRightMotionClampBoundaries` |
| 37 | EditorKernelCoverageAdditional | minimapPolicyTitlesAndDetails | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `minimapPolicyTitlesAndDetails` |
| 38 | EditorKernelCoverageAdditional | largeFileModeThresholdsAndFlags | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `largeFileModeThresholdsAndFlags` |
| 39 | EditorKernelCoverageAdditional | longLineDetectorFindsOnlyLinesOverLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `longLineDetectorFindsOnlyLinesOverLimit` |
| 40 | EditorKernelCoverageAdditional | viewportRenderControllerClampsRenderRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `viewportRenderControllerClampsRenderRange` |
| 41 | EditorKernelCoverageAdditional | textInputPlanProducesBracketAutoClosing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textInputPlanProducesBracketAutoClosing` |
| 42 | EditorKernelCoverageAdditional | textInputPlanFallsThroughForPlainCharacters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textInputPlanFallsThroughForPlainCharacters` |
| 43 | EditorKernelCoverageAdditional | textInputPlanMultiCursorAutoClosing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textInputPlanMultiCursorAutoClosing` |
| 44 | EditorKernelCoverageAdditional | newlineAndTabPlansUseSmartIndent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `newlineAndTabPlansUseSmartIndent` |
| 45 | EditorKernelCoverageAdditional | stateTransitionsTogglePanelAndQueries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateTransitionsTogglePanelAndQueries` |
| 46 | EditorKernelCoverageAdditional | matchesResultAndIndexNavigation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchesResultAndIndexNavigation` |
| 47 | EditorKernelCoverageAdditional | replaceTransactionsUseSelectedMatchAndReplaceAll | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `replaceTransactionsUseSelectedMatchAndReplaceAll` |
| 48 | EditorKernelCoverageAdditional | stateAndRangeHelpers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateAndRangeHelpers` |
| 49 | EditorKernelCoverageAdditional | occurrenceSearchAndSessionFlow | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `occurrenceSearchAndSessionFlow` |
| 50 | EditorKernelCoverageAdditional | resolvedContextReusesMatchingSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvedContextReusesMatchingSession` |
| 51 | EditorKernelCoverageAdditional | replacementAndOperationResultsBuildTransactions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `replacementAndOperationResultsBuildTransactions` |
| 52 | EditorKernelCoverageAdditional | textEditTransactionRemapsCurrentSelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textEditTransactionRemapsCurrentSelections` |
| 53 | EditorKernelCoverageAdditional | inputEditTransactionValidatesRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inputEditTransactionValidatesRanges` |
| 54 | EditorKernelCoverageAdditional | completionEditCombinesAdditionalEditsAndPositionsCursor | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completionEditCombinesAdditionalEditsAndPositionsCursor` |
| 55 | EditorKernelCoverageAdditional | snippetEditBuildsSessionWithRemappedPlaceholderRanges | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `snippetEditBuildsSessionWithRemappedPlaceholderRanges` |
| 56 | EditorKernelCoverageAdditional | commitPayloadCountsLinesAndMapsSelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commitPayloadCountsLinesAndMapsSelections` |
| 57 | EditorKernelCoverageAdditional | saveNowIfNeededRunsOnlyWhenDirty | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveNowIfNeededRunsOnlyWhenDirty` |
| 58 | EditorKernelCoverageAdditional | saveNowSkipsWhileSaving | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveNowSkipsWhileSaving` |
| 59 | EditorKernelCoverageAdditional | prepareAndSaveNowWithoutContentOrURLDoesNothing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prepareAndSaveNowWithoutContentOrURLDoesNothing` |
| 60 | EditorKernelCoverageAdditional | jumpShowsStatusAndPerforms | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `jumpShowsStatusAndPerforms` |
| 61 | EditorKernelCoverageAdditional | promptRenameHonorsCancelledPromptAndEditability | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `promptRenameHonorsCancelledPromptAndEditability` |
| 62 | EditorKernelCoverageAdditional | renameReportsFailureWhenServerReturnsNothing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renameReportsFailureWhenServerReturnsNothing` |
| 63 | EditorKernel | textInputControllerBuildsBracketAndIndentPlans | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textInputControllerBuildsBracketAndIndentPlans` |
| 64 | EditorKernel | bracketAndIndentPoliciesHandleLanguageAndOutdentRules | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bracketAndIndentPoliciesHandleLanguageAndOutdentRules` |
| 65 | EditorKernel | inputCommandControllerBuildsLineEditAndCursorPlans | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inputCommandControllerBuildsLineEditAndCursorPlans` |
| 66 | EditorKernel | callHierarchyControllerPreparesCoordinatesAndOpensOnlyWhenRootExists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `callHierarchyControllerPreparesCoordinatesAndOpensOnlyWhenRootExists` |
| 67 | EditorKernel | configModelsNormalizeScopesAndApplyOverrides | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `configModelsNormalizeScopesAndApplyOverrides` |
| 68 | EditorKernel | configPersistencePolicyResolvesScopesAndEncodesOverrides | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `configPersistencePolicyResolvesScopesAndEncodesOverrides` |
| 69 | EditorKernel | referenceResultBuildsStableIdentifiersFromCanonicalPaths | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `referenceResultBuildsStableIdentifiersFromCanonicalPaths` |
| 70 | EditorKernel | editorReferenceResultBuildsStableIdentifiersFromCanonicalPaths | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `editorReferenceResultBuildsStableIdentifiersFromCanonicalPaths` |
| 71 | EditorKernel | foldingStateTracksCollapsedRangesAndEmptyState | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `foldingStateTracksCollapsedRangesAndEmptyState` |
| 72 | EditorKernel | semanticModelsPreserveSeverityReasonAndProblemProjection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticModelsPreserveSeverityReasonAndProblemProjection` |
| 73 | EditorKernel | panelSessionStateDefaultsAndSnapshotStayInSync | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `panelSessionStateDefaultsAndSnapshotStayInSync` |
| 74 | EditorKernel | projectContextModelsExposeStatusDescriptionsAndSnapshotFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectContextModelsExposeStatusDescriptionsAndSnapshotFields` |
| 75 | EditorKernel | configFileStorePersistsAndRemovesValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `configFileStorePersistsAndRemovesValues` |
| 76 | EditorKernel | configFileStoreQuarantinesCorruptSettingsAndRecovers | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `configFileStoreQuarantinesCorruptSettingsAndRecovers` |
| 77 | EditorKernel | saveControllerBuildsPipelineOptionsAndClearsSavedState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveControllerBuildsPipelineOptionsAndClearsSavedState` |
| 78 | EditorKernel | saveControllerStopsWhenCurrentFileChangesDuringDeferredActions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveControllerStopsWhenCurrentFileChangesDuringDeferredActions` |
| 79 | EditorKernel | formattingControllerFormatsAndPreparesSaveText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formattingControllerFormatsAndPreparesSaveText` |
| 80 | EditorKernel | commandSuggestionPolicyDeduplicatesAndTracksRecents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commandSuggestionPolicyDeduplicatesAndTracksRecents` |
| 81 | EditorKernel | commandRouterBridgeMapsRegistryCommandsAndFallsBackToLegacy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commandRouterBridgeMapsRegistryCommandsAndFallsBackToLegacy` |
| 82 | EditorKernel | commandRouterBridgeRegistersLegacySuggestionsAndMapsContext | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commandRouterBridgeRegistersLegacySuggestionsAndMapsContext` |
| 83 | EditorKernel | externalFileControllerTracksConflictsAndReloadThresholds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalFileControllerTracksConflictsAndReloadThresholds` |
| 84 | EditorKernel | externalFileControllerLoadsAndAppliesExternalText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalFileControllerLoadsAndAppliesExternalText` |
| 85 | EditorKernel | cursorMotionWordAndLineBehaviorsRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `cursorMotionWordAndLineBehaviorsRemainStable` |
| 86 | EditorKernel | cursorDeleteWordLeftReturnsExpectedRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cursorDeleteWordLeftReturnsExpectedRange` |
| 87 | EditorKernel | cursorWordMotionClampsStaleLocations | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cursorWordMotionClampsStaleLocations` |
| 88 | EditorKernel | cursorLineAndParagraphMotionClampNegativeLocations | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cursorLineAndParagraphMotionClampNegativeLocations` |
| 89 | EditorKernel | snippetParserSeedsRepeatedPlaceholdersAndImplicitExit | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `snippetParserSeedsRepeatedPlaceholdersAndImplicitExit` |
| 90 | EditorKernel | snippetParserSupportsMultiDigitShorthandPlaceholders | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `snippetParserSupportsMultiDigitShorthandPlaceholders` |
| 91 | EditorKernel | multiCursorEditEngineInsertDeleteAndOutdentBehaviorsRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `multiCursorEditEngineInsertDeleteAndOutdentBehaviorsRemainStable` |
| 92 | EditorKernel | multiCursorEditEngineKeepsIndentedLineSelectionsInBounds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multiCursorEditEngineKeepsIndentedLineSelectionsInBounds` |
| 93 | EditorKernel | multiCursorEditEngineClampsOverflowingSelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multiCursorEditEngineClampsOverflowingSelections` |
| 94 | EditorKernel | textEditApplierHandlesMultipleEditsAndRejectsInvalidRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `textEditApplierHandlesMultipleEditsAndRejectsInvalidRanges` |
| 95 | EditorKernel | editorSelectionSetNormalizesOrderingAndSupportsMultiCursorRoundTrip | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `editorSelectionSetNormalizesOrderingAndSupportsMultiCursorRoundTrip` |
| 96 | EditorKernel | editorSelectionSetMutationHelpersRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `editorSelectionSetMutationHelpersRemainStable` |
| 97 | EditorKernel | textEditTransactionBuilderMapsUnicodeOffsetsAndRejectsInvalidLines | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `textEditTransactionBuilderMapsUnicodeOffsetsAndRejectsInvalidLines` |
| 98 | EditorKernel | multiCursorTransactionBuilderDeleteBackwardBuildsExpectedReplacements | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multiCursorTransactionBuilderDeleteBackwardBuildsExpectedReplacements` |
| 99 | EditorKernel | findReplaceTransactionBuilderPreservesCaseAndSelectionUpdate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findReplaceTransactionBuilderPreservesCaseAndSelectionUpdate` |
| 100 | EditorKernel | findReplaceTransactionBuilderReplaceAllAndPreviewRespectCurrentSemantics | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findReplaceTransactionBuilderReplaceAllAndPreviewRespectCurrentSemantics` |
| 101 | EditorKernel | findReplaceControllerMatchesRespectWordBoundariesAndSelectionScopes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findReplaceControllerMatchesRespectWordBoundariesAndSelectionScopes` |
| 102 | EditorKernel | findReplaceControllerMergesOverlappingSelectionScopesInDocumentOrder | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findReplaceControllerMergesOverlappingSelectionScopesInDocumentOrder` |
| 103 | EditorKernel | findReplaceControllerPrefersCurrentOrNextMatch | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findReplaceControllerPrefersCurrentOrNextMatch` |
| 104 | EditorKernel | findReplaceControllerTreatsStaleSelectedIndexAsNoSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findReplaceControllerTreatsStaleSelectedIndexAsNoSelection` |
| 105 | EditorKernel | findControllerStateAndMatchUpdatesRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `findControllerStateAndMatchUpdatesRemainStable` |
| 106 | EditorKernel | findReplaceStateControllerPreservesOptionsAndResultMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findReplaceStateControllerPreservesOptionsAndResultMetadata` |
| 107 | EditorKernel | quickOpenFilePolicyResolvesProjectRelativePathsAndParentLabels | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `quickOpenFilePolicyResolvesProjectRelativePathsAndParentLabels` |
| 108 | EditorKernel | quickOpenFilePolicyRejectsSiblingProjectWithSharedPrefix | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `quickOpenFilePolicyRejectsSiblingProjectWithSharedPrefix` |
| 109 | EditorKernel | quickOpenFilePolicyTrimsCopiedProjectRootPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quickOpenFilePolicyTrimsCopiedProjectRootPath` |
| 110 | EditorKernel | quickOpenFilePolicyMatchesFuzzyQueriesAndEngineeringFiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quickOpenFilePolicyMatchesFuzzyQueriesAndEngineeringFiles` |
| 111 | EditorKernel | quickOpenFilePolicyMergesAndOrdersCandidates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quickOpenFilePolicyMergesAndOrdersCandidates` |
| 112 | EditorKernel | saveParticipantControllerTrimsTrailingWhitespaceAndPreservesCRLF | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveParticipantControllerTrimsTrailingWhitespaceAndPreservesCRLF` |
| 113 | EditorKernel | savePipelineControllerAppliesFormattingAndDeferredActions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `savePipelineControllerAppliesFormattingAndDeferredActions` |
| 114 | EditorKernel | statusMessageCatalogBuildsExpectedMessages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusMessageCatalogBuildsExpectedMessages` |
| 115 | EditorKernel | stateSupportTypesAndOverlayModelsRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stateSupportTypesAndOverlayModelsRemainStable` |
| 116 | EditorKernel | gutterDecorationModelsPreserveKindsAndDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `gutterDecorationModelsPreserveKindsAndDefaults` |
| 117 | EditorKernel | undoControllerAndManagerMaintainUndoRedoStacks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `undoControllerAndManagerMaintainUndoRedoStacks` |
| 118 | EditorKernel | editorBufferAppliesTransactionsAndPreservesSelectionPassThrough | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editorBufferAppliesTransactionsAndPreservesSelectionPassThrough` |
| 119 | EditorKernel | editorBufferRejectsInvalidRangeWithoutMutatingState | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `editorBufferRejectsInvalidRangeWithoutMutatingState` |
| 120 | EditorKernel | lineEditingControllerSupportsDeleteInsertSortAndTranspose | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineEditingControllerSupportsDeleteInsertSortAndTranspose` |
| 121 | EditorKernel | lineEditingControllerPreservesCRLFLineEndings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineEditingControllerPreservesCRLFLineEndings` |
| 122 | EditorKernel | lineEditingControllerMovesLineDownWithoutAddingTrailingNewline | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineEditingControllerMovesLineDownWithoutAddingTrailingNewline` |
| 123 | EditorKernel | lineEditingControllerPreservesAdjacentMultiCursorsWhenCopyingLines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineEditingControllerPreservesAdjacentMultiCursorsWhenCopyingLines` |
| 124 | EditorKernel | lineEditingControllerRejectsNonContiguousMultiCursorLineMoves | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `lineEditingControllerRejectsNonContiguousMultiCursorLineMoves` |
| 125 | EditorKernel | lineEditingControllerRejectsStaleSelectionsWithoutCrashing | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `lineEditingControllerRejectsStaleSelectionsWithoutCrashing` |
| 126 | EditorKernel | commandRegistryFiltersAndExecutesCommandsByContext | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commandRegistryFiltersAndExecutesCommandsByContext` |
| 127 | EditorKernel | transactionControllerBuildsCompletionAndCommitPayloads | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transactionControllerBuildsCompletionAndCommitPayloads` |
| 128 | EditorKernel | transactionControllerRejectsInvalidEditRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `transactionControllerRejectsInvalidEditRanges` |
| 129 | EditorKernel | editorPerformanceCollectsSummariesAndSlowEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editorPerformanceCollectsSummariesAndSlowEvents` |
| 130 | EditorKernel | editorPerformanceRecentSlowEventsClampsNonPositiveLimits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editorPerformanceRecentSlowEventsClampsNonPositiveLimits` |
| 131 | EditorKernel | externalFileReloadPolicyChoosesConflictOrApplyBasedOnDirtyState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalFileReloadPolicyChoosesConflictOrApplyBasedOnDirtyState` |
| 132 | EditorKernel | externalFileWorkflowControllerDelegatesPollingAndConflictRegistration | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalFileWorkflowControllerDelegatesPollingAndConflictRegistration` |
| 133 | EditorKernel | saveWorkflowPolicyGuardsAutosaveAndDuplicateSaveRuns | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveWorkflowPolicyGuardsAutosaveAndDuplicateSaveRuns` |
| 134 | EditorKernel | editorCommandCategoryAndPresentationRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `editorCommandCategoryAndPresentationRemainStable` |
| 135 | EditorKernel | editorCommandPresentationToleratesDuplicateSuggestionIDs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editorCommandPresentationToleratesDuplicateSuggestionIDs` |
| 136 | EditorKernel | editorCommandPresentationFiltersByShortcutAndCategoryScope | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editorCommandPresentationFiltersByShortcutAndCategoryScope` |
| 137 | EditorKernel | quickOpenQueryParserParsesScopedQueries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quickOpenQueryParserParsesScopedQueries` |
| 138 | EditorKernel | quickOpenQueryParserDefaultsToFileSearchForPlainQuery | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `quickOpenQueryParserDefaultsToFileSearchForPlainQuery` |
| 139 | EditorKernel | largeFileModeThresholdsAndFeatureFlagsRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `largeFileModeThresholdsAndFeatureFlagsRemainStable` |
| 140 | EditorKernel | lineOffsetTableSupportsUnicodeAndBounds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineOffsetTableSupportsUnicodeAndBounds` |
| 141 | EditorKernel | longLineDetectorAndMinimapPolicyRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `longLineDetectorAndMinimapPolicyRemainStable` |
| 142 | EditorKernel | renderedRangePolicyFiltersOffsetsAndMatches | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renderedRangePolicyFiltersOffsetsAndMatches` |
| 143 | EditorKernel | viewportFeaturePolicyRemainsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `viewportFeaturePolicyRemainsStable` |
| 144 | EditorKernel | runtimeAvailabilityPolicyClampsViewportAndClearDecisions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runtimeAvailabilityPolicyClampsViewportAndClearDecisions` |
| 145 | EditorKernel | inlineRenameStatePreviewFlagsRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `inlineRenameStatePreviewFlagsRemainStable` |
| 146 | EditorKernel | renamePolicyNormalizesInputAndFormatsSummary | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renamePolicyNormalizesInputAndFormatsSummary` |
| 147 | EditorKernel | workspaceEditSummaryBuilderSummarizesCurrentAndExternalEdits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceEditSummaryBuilderSummarizesCurrentAndExternalEdits` |
| 148 | EditorKernel | workspaceEditSummaryRejectsSiblingProjectWithSharedPrefix | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `workspaceEditSummaryRejectsSiblingProjectWithSharedPrefix` |
| 149 | EditorKernel | workspaceEditSummaryUsesUnescapedFileURLsForLabels | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `workspaceEditSummaryUsesUnescapedFileURLsForLabels` |
| 150 | EditorKernel | workspaceEditControllerAppliesDocumentAndFileOperations | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceEditControllerAppliesDocumentAndFileOperations` |
| 151 | EditorKernel | workspaceEditControllerAppliesUnescapedExternalFileURLs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceEditControllerAppliesUnescapedExternalFileURLs` |
| 152 | EditorKernel | workspaceEditControllerAppliesTextEditsToFiles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceEditControllerAppliesTextEditsToFiles` |
| 153 | EditorKernel | workspaceEditControllerAppliesTextEditsToUTF16Files | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceEditControllerAppliesTextEditsToUTF16Files` |
| 154 | EditorKernel | saveStateAndControllerRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `saveStateAndControllerRemainStable` |
| 155 | EditorKernel | appearanceAndDocumentReplaceControllersRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `appearanceAndDocumentReplaceControllersRemainStable` |
| 156 | EditorKernel | multiCursorStateAndStateControllerRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `multiCursorStateAndStateControllerRemainStable` |
| 157 | EditorKernel | multiCursorMatcherAndSearchControllerRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `multiCursorMatcherAndSearchControllerRemainStable` |
| 158 | EditorKernel | multiCursorMatcherRejectsInvalidSelectionRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `multiCursorMatcherRejectsInvalidSelectionRanges` |
| 159 | EditorKernel | multiCursorWorkflowControllerRemainsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `multiCursorWorkflowControllerRemainsStable` |
| 160 | EditorKernel | multiCursorControllerBuildsTransactionsAndSessions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multiCursorControllerBuildsTransactionsAndSessions` |
| 161 | EditorKernel | shortcutCatalogPolicyFiltersAndDetectsConflicts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shortcutCatalogPolicyFiltersAndDetectsConflicts` |
| 162 | EditorKernel | selectionMappingPolicyNormalizesRangesAndGuardsMultiCursorLoss | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `selectionMappingPolicyNormalizesRangesAndGuardsMultiCursorLoss` |
| 163 | EditorKernel | peekControllerBuildsDefinitionPresentationFromCurrentBuffer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `peekControllerBuildsDefinitionPresentationFromCurrentBuffer` |
| 164 | EditorKernel | peekControllerAcceptsUnescapedFileURLs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `peekControllerAcceptsUnescapedFileURLs` |
| 165 | EditorKernel | peekControllerReadsExternalUTF16Previews | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `peekControllerReadsExternalUTF16Previews` |
| 166 | EditorKernel | peekControllerRejectsSiblingProjectWithSharedPrefix | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `peekControllerRejectsSiblingProjectWithSharedPrefix` |
| 167 | EditorKernel | settingsQuickOpenPolicyFiltersAndSortsMatchingItems | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsQuickOpenPolicyFiltersAndSortsMatchingItems` |
| 168 | EditorKernel | workspaceSearchPolicyParsesRipgrepOutputAndFormatsMarkdown | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceSearchPolicyParsesRipgrepOutputAndFormatsMarkdown` |
| 169 | EditorKernel | workspaceSearchPolicyRejectsSiblingProjectWithSharedPrefix | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `workspaceSearchPolicyRejectsSiblingProjectWithSharedPrefix` |
| 170 | EditorKernel | workspaceSearchControllerHandlesEmptyQueryAndExportsMarkdown | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `workspaceSearchControllerHandlesEmptyQueryAndExportsMarkdown` |
| 171 | EditorKernel | workspaceSearchControllerHandlesLargeRipgrepOutput | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceSearchControllerHandlesLargeRipgrepOutput` |
| 172 | EditorKernel | workspaceSearchControllerSkipsBuildDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceSearchControllerSkipsBuildDirectory` |
| 173 | EditorKernel | statusToastPolicyNormalizesDurationsByLevel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusToastPolicyNormalizesDurationsByLevel` |
| 174 | EditorKernel | saveWorkflowControllerRunsOnlyWhenSaveIsNeeded | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveWorkflowControllerRunsOnlyWhenSaveIsNeeded` |
| 175 | EditorKernel | documentSymbolItemBuildsTreePathsAndIcons | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `documentSymbolItemBuildsTreePathsAndIcons` |
| 176 | EditorKernel | scrollStateDefaultsAndStoresViewportOrigin | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `scrollStateDefaultsAndStoresViewportOrigin` |
| 177 | EditorKernel | lspRequestPipelineTracksGenerationCancellationAndLatestApply | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lspRequestPipelineTracksGenerationCancellationAndLatestApply` |
| 178 | EditorKernel | panelModelsAndControllerToggleExclusivePanelsAndMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `panelModelsAndControllerToggleExclusivePanelsAndMetadata` |
| 179 | EditorKernel | panelCommandControllerTogglesAndClosesRemainingPanels | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `panelCommandControllerTogglesAndClosesRemainingPanels` |
| 180 | EditorKernel | findReplaceStateControllerWithoutExistingStateUsesDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `findReplaceStateControllerWithoutExistingStateUsesDefaults` |
| 181 | EditorKernel | panelVisibilityPolicyPresentsExclusiveBottomPanels | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `panelVisibilityPolicyPresentsExclusiveBottomPanels` |
| 182 | EditorKernel | panelVisibilityPolicySelectsMatchingDiagnosticAcrossSingleAndMultiLineRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `panelVisibilityPolicySelectsMatchingDiagnosticAcrossSingleAndMultiLineRanges` |
| 183 | EditorKernel | panelDataPolicyKeepsOnlyVisibleWorkspaceSearchState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `panelDataPolicyKeepsOnlyVisibleWorkspaceSearchState` |
| 184 | EditorKernel | panelDataPolicyDropsReferenceSelectionWhenResultDisappears | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `panelDataPolicyDropsReferenceSelectionWhenResultDisappears` |
| 185 | EditorKernel | fileWatcherControllerDelegatesSetupAndCleanup | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileWatcherControllerDelegatesSetupAndCleanup` |
| 186 | EditorKernel | sessionItemModelsPreserveIDsAndDefaultTitles | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sessionItemModelsPreserveIDsAndDefaultTitles` |
| 187 | EditorKernel | packageManifestSyntaxParsesDependenciesAndHoverMarkdown | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `packageManifestSyntaxParsesDependenciesAndHoverMarkdown` |
| 188 | EditorKernel | packageManifestSyntaxIgnoresParenthesesInsideStringLiterals | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `packageManifestSyntaxIgnoresParenthesesInsideStringLiterals` |
| 189 | EditorKernel | stringPreviewLinesReturnsExpectedPrefixesAndSuffixes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stringPreviewLinesReturnsExpectedPrefixesAndSuffixes` |
| 190 | EditorTextDiffEngine | 相同文本产生空 diff | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `identicalTextsProduceEmptyDiff` |
| 191 | EditorTextDiffEngine | 空文本到内容为纯新增 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyToContentIsPureAddition` |
| 192 | EditorTextDiffEngine | 内容到空文本为纯删除 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `contentToEmptyIsPureRemoval` |
| 193 | EditorTextDiffEngine | 单行修改产生 removed + added 对 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singleLineModification` |
| 194 | EditorTextDiffEngine | 相距较远的变更切分为多个 hunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `distantChangesSplitIntoHunks` |
| 195 | EditorTextDiffEngine | 相距较近的变更合并为一个 hunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nearbyChangesMergeIntoOneHunk` |
| 196 | EditorTextDiffEngine | 行号映射：旧行号与新行号各自连续正确 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineNumbersMapCorrectly` |
| 197 | EditorTextDiffEngine | CRLF 与 LF 混合输入可比较（行尾 CR 归一化） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `crlfInputsNormalize` |
| 198 | EditorTextDiffEngine | 同输入必得同输出（确定性） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deterministicOutput` |
| 199 | EditorTextDiffEngine | 尾随换行差异不产生空行 diff | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trailingNewlineHandling` |
| 200 | EditorLSPActionPolicy | language id mapping is case-insensitive | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languageIDMapping` |
| 201 | EditorLSPActionPolicy | jump kind maps to status message key | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusMessageKeyMapping` |
| 202 | EditorLSPActionPolicy | reference results sort by path line column | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `referenceResultSorting` |
| 203 | EditorLSPActionPolicy | reference results accept unescaped file URLs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `referenceResultsAcceptUnescapedFileURLs` |
| 204 | EditorLSPActionPolicy | reference display paths reject sibling projects with shared prefixes | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `referenceResultDisplayPathRejectsSiblingProjectPrefix` |
| 205 | EditorNavigationController | reference request resolves to reference target | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolveReferenceRequest` |
| 206 | EditorNavigationController | diagnostic cursor position includes selection range | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cursorPositionsForDiagnostic` |
| 207 | EditorNavigationController | highlighted definition target expands to full line | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvedDefinitionTargetHighlightLine` |
| 208 | EditorOpenItemCommandController | workspace symbol command resolves navigation and closes symbol search | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolveWorkspaceSymbolCommand` |
| 209 | EditorOpenItemCommandController | workspace symbol command accepts unescaped file URLs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolveWorkspaceSymbolCommandWithUnescapedFileURL` |
| 210 | EditorOpenItemCommandController | problem command keeps diagnostic and opens problems panel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolveProblemCommand` |
| 211 | EditorOpenItemCommandController | workspace symbol command with invalid URI resolves to nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resolveWorkspaceSymbolCommandWithInvalidURI` |
| 212 | EditorOpenItemCommandController | reference command resolves navigation and opens references panel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolveReferenceCommand` |
| 213 | EditorOpenItemCommandController | call hierarchy command resolves navigation without bottom panel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolveCallHierarchyCommand` |
| 214 | EditorOpenItemCommandController | document symbol command resolves cursor position only | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolveDocumentSymbolCommand` |
| 215 | EditorSemanticModels | workspaceFolderInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceFolderInitialization` |
| 216 | EditorSemanticModels | workspaceFolderEquality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceFolderEquality` |
| 217 | EditorSemanticModels | semanticPreflightStrengthCases | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticPreflightStrengthCases` |
| 218 | EditorSemanticModels | semanticAvailabilitySeverityRawValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticAvailabilitySeverityRawValues` |
| 219 | EditorSemanticModels | semanticAvailabilityReasonInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticAvailabilityReasonInitialization` |
| 220 | EditorSemanticModels | semanticAvailabilityReasonWithoutSuggestion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticAvailabilityReasonWithoutSuggestion` |
| 221 | EditorSemanticModels | semanticAvailabilityReasonEquality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticAvailabilityReasonEquality` |
| 222 | EditorSemanticModels | semanticAvailabilityReportInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticAvailabilityReportInitialization` |
| 223 | EditorSemanticModels | semanticAvailabilityReportEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `semanticAvailabilityReportEmpty` |
| 224 | EditorSemanticModels | semanticAvailabilityReportEquality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticAvailabilityReportEquality` |
| 225 | EditorSemanticModels | languageFeatureErrorInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languageFeatureErrorInitialization` |
| 226 | EditorSemanticModels | languageFeatureErrorWithoutSuggestion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languageFeatureErrorWithoutSuggestion` |
| 227 | EditorSemanticModels | languageFeatureErrorEquality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languageFeatureErrorEquality` |
| 228 | EditorSemanticModels | languageFeatureErrorLocalizedError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languageFeatureErrorLocalizedError` |
| 229 | EditorSemanticModels | semanticProblemInitializationDirect | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticProblemInitializationDirect` |
| 230 | EditorSemanticModels | semanticProblemInitializationFromReason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticProblemInitializationFromReason` |
| 231 | EditorSemanticModels | semanticProblemEquality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticProblemEquality` |
| 232 | EditorSemanticModels | semanticProblemFromReasonEquality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticProblemFromReasonEquality` |
| 233 | EditorSemanticModels | semanticProblemIdentifiable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `semanticProblemIdentifiable` |
| 234 | EditorSnippetSession | placeholderGroupInitialization | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderGroupInitialization` |
| 235 | EditorSnippetSession | placeholderGroupEquality | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderGroupEquality` |
| 236 | EditorSnippetSession | snippetSessionInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `snippetSessionInitialization` |
| 237 | EditorSnippetSession | currentGroupReturnsActiveGroup | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `currentGroupReturnsActiveGroup` |
| 238 | EditorSnippetSession | currentGroupReturnsNilWhenIndexOutOfRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `currentGroupReturnsNilWhenIndexOutOfRange` |
| 239 | EditorSnippetSession | currentGroupReturnsNilWhenGroupsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `currentGroupReturnsNilWhenGroupsEmpty` |
| 240 | EditorSnippetSession | snippetSessionEquality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `snippetSessionEquality` |
| 241 | EditorSnippetSession | snippetSessionInequality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `snippetSessionInequality` |
| 242 | EditorSnippetSession | multiplePlaceholderGroups | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `multiplePlaceholderGroups` |
| 243 | EditorStatusMessage | externalFileChangedOnDiskWithFileName | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalFileChangedOnDiskWithFileName` |
| 244 | EditorStatusMessage | externalFileChangedOnDiskWithoutFileName | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalFileChangedOnDiskWithoutFileName` |
| 245 | EditorStatusMessage | externalFileChangedOnDiskWithEmptyFileName | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `externalFileChangedOnDiskWithEmptyFileName` |
| 246 | EditorStatusMessage | externalFileChangedOnDiskForProjectFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalFileChangedOnDiskForProjectFile` |
| 247 | EditorStatusMessage | externalFileChangedOnDiskForProjectFileWithFileName | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalFileChangedOnDiskForProjectFileWithFileName` |
| 248 | EditorStatusMessage | projectFileSaveConfirmation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectFileSaveConfirmation` |
| 249 | EditorStatusMessage | saveFailedWithDetail | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveFailedWithDetail` |
| 250 | EditorStatusMessage | saveFailedWithoutDetail | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveFailedWithoutDetail` |
| 251 | EditorStatusMessage | saveFailedWithEmptyDetail | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `saveFailedWithEmptyDetail` |
| 252 | EditorStatusMessage | fileNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileNotFound` |
| 253 | EditorStatusMessage | formattingUnavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formattingUnavailable` |
| 254 | EditorStatusMessage | languageFeatureUnavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languageFeatureUnavailable` |
| 255 | EditorStatusMessage | idleStateIcon | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `idleStateIcon` |
| 256 | EditorStatusMessage | editingStateIcon | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `editingStateIcon` |
| 257 | EditorStatusMessage | savingStateIcon | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `savingStateIcon` |
| 258 | EditorStatusMessage | savedStateIcon | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `savedStateIcon` |
| 259 | EditorStatusMessage | conflictStateIcon | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `conflictStateIcon` |
| 260 | EditorStatusMessage | errorStateIcon | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `errorStateIcon` |
| 261 | EditorStatusMessage | stateEquality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateEquality` |
| 262 | EditorStatusMessage | stateInequality | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateInequality` |
| 263 | EditorStatusMessage | applySaveSuccessCallsAllCallbacks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `applySaveSuccessCallsAllCallbacks` |
| 264 | EditorStatusMessage | applySaveFailureSetsErrorState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `applySaveFailureSetsErrorState` |
| 265 | EditorStatusMessage | applyMissingFileFailureSetsErrorState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `applyMissingFileFailureSetsErrorState` |
| 266 | LSPRequestCache | cache stores and retrieves values | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheStoreAndRetrieve` |
| 267 | LSPRequestCache | cache returns nil for missing keys | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheMissingKey` |
| 268 | LSPRequestCache | cache differentiates by kind | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheDifferentiatesByKind` |
| 269 | LSPRequestCache | cache differentiates by position | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheDifferentiatesByPosition` |
| 270 | LSPRequestCache | cache removes specific entry | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheRemove` |
| 271 | LSPRequestCache | cache clears all entries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheClear` |
| 272 | LSPRequestCache | cache invalidates by URI | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cacheInvalidateByURI` |
| 273 | LSPRequestCache | cache removes all entries of specific kind | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheRemoveByKind` |
| 274 | LSPRequestCache | cache respects generation invalidation | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cacheGenerationInvalidation` |
| 275 | LSPViewportScheduler | significant viewport change respects threshold | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `significantViewportChange` |
| 276 | LSPViewportScheduler | Kind defaultPriority returns correct priority | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `kindDefaultPriority` |
| 277 | LSPViewportScheduler | Kind defaultDebounceMs returns correct values | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `kindDefaultDebounceMs` |
| 278 | LSPViewportScheduler | Priority comparison works correctly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `priorityComparison` |
| 279 | LSPViewportScheduler | cancelAll cancels all tasks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelAll` |
| 280 | LSPViewportScheduler | high priority task cancels lower priority tasks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `highPriorityCancelsLower` |
| 281 | LSPViewportScheduler | cancelBelow cancels tasks below specified priority | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelBelowPriority` |
| 282 | LSPViewportScheduler | disableCancelLowerPriority prevents cancellation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `disableCancelLowerPriority` |
| 283 | LineOffsetBugVerify | replaceRemovingNewlineWithLongerText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `replaceRemovingNewlineWithLongerText` |
| 284 | LineOffsetBugVerify | equalLengthReplaceRemovingNewline | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equalLengthReplaceRemovingNewline` |
| 285 | LineOffsetBugVerify | multiLineReplaceInsertingNewlines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multiLineReplaceInsertingNewlines` |
| 286 | LineOffsetTableIncremental | initProducesCorrectLineStarts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initProducesCorrectLineStarts` |
| 287 | LineOffsetTableIncremental | initProducesCorrectLineStartsWithEmptyString | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `initProducesCorrectLineStartsWithEmptyString` |
| 288 | LineOffsetTableIncremental | initSingleLineNoTrailingNewline | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initSingleLineNoTrailingNewline` |
| 289 | LineOffsetTableIncremental | initUnicodeContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initUnicodeContent` |
| 290 | LineOffsetTableIncremental | updateRejectsInvalidEditRangesWithoutChangingTable | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `updateRejectsInvalidEditRangesWithoutChangingTable` |
| 291 | LineOffsetTableIncremental | updateInsertCharacterOnFirstLine | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateInsertCharacterOnFirstLine` |
| 292 | LineOffsetTableIncremental | updateInsertCharacterOnSecondLine | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateInsertCharacterOnSecondLine` |
| 293 | LineOffsetTableIncremental | updateDeleteCharacter | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateDeleteCharacter` |
| 294 | LineOffsetTableIncremental | updateInsertNewlineAddsLine | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateInsertNewlineAddsLine` |
| 295 | LineOffsetTableIncremental | updateInsertNewlineAtBeginning | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateInsertNewlineAtBeginning` |
| 296 | LineOffsetTableIncremental | updateInsertMultipleNewlines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateInsertMultipleNewlines` |
| 297 | LineOffsetTableIncremental | updateDeleteNewlineRemovesLine | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateDeleteNewlineRemovesLine` |
| 298 | LineOffsetTableIncremental | updateEmptyContentInsert | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateEmptyContentInsert` |
| 299 | LineOffsetTableIncremental | updateEmptyContentInsertWithNewline | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateEmptyContentInsertWithNewline` |
| 300 | LineOffsetTableIncremental | updateInsertAtEndOfDocument | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateInsertAtEndOfDocument` |
| 301 | LineOffsetTableIncremental | lineContainingAfterInsert | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineContainingAfterInsert` |
| 302 | LineOffsetTableIncremental | lineContainingAfterDelete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineContainingAfterDelete` |
| 303 | LineOffsetTableIncremental | utf16OffsetAfterInsert | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `utf16OffsetAfterInsert` |
| 304 | LineOffsetTableIncremental | updateMatchesFullRebuildForSimpleInsertion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateMatchesFullRebuildForSimpleInsertion` |
| 305 | LineOffsetTableIncremental | updateMatchesFullRebuildForNewlineInsertion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateMatchesFullRebuildForNewlineInsertion` |
| 306 | WorkspaceEditFileOperationsCoverage | fileURL rejects non-file input | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fileURLRejects` |
| 307 | WorkspaceEditFileOperationsCoverage | create honors overwrite and ignoreIfExists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createBranches` |
| 308 | WorkspaceEditFileOperationsCoverage | rename moves files and honors options | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renameBranches` |
| 309 | WorkspaceEditFileOperationsCoverage | rename via URI parameters handles missing and existing targets | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renameURIParameters` |
| 310 | WorkspaceEditFileOperationsCoverage | delete handles directories and ignoreIfNotExists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteBranches` |
| 311 | WorkspaceEditFileOperationsCoverage | executor applies create/rename/delete off the main thread | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executorRoundTrip` |
| 312 | WorkspaceEditFileOperationsCoverage | policy predicates match VS Code semantics | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `policyPredicates` |
| 313 | WorkspaceEditFileOperationsCoverage | display names are unique and non-empty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayNames` |
| 314 | WorkspaceEditFileOperations | fileURL supports file URI and absolute path | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileURLParsing` |
| 315 | WorkspaceEditFileOperations | create and delete file operations succeed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createDeleteOperations` |
| 316 | XCConfigSyntaxCore | tokenize captures include and keys | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenizeContent` |
| 317 | XCConfigSyntaxCore | include directive resolves by cursor location | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `includeDirectiveAtLocation` |
| 318 | XCConfigSyntaxCore | key occurrences reports key and line | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keyOccurrences` |

> 说明：全部 **318 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 20 / 20
- P1: 已覆盖 239 / 239
- P2: 已覆盖 59 / 59
- **合计: 318 / 318**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（20 条）
- **P1**: 其余功能性用例（239 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（59 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 318 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitEditorKernel
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
