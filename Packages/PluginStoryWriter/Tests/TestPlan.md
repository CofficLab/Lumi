# TestPlan — PluginStoryWriter

## 包概述

StoryWriterPlugin A two-pane story writing workspace. - **Left pane (rail tab)**: story picker dropdown + chapter tree - **Right pane (ActivityBar view container)**: selected node editor (chapter markdown / story metadata) - **AI assistance**: via a dedicated ChatSection flow (configured separately) - **Persistence**: self-managed JSON under `~/Library/Application Support/.../StoryWriter/`

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 13

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Persistence/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `StoryWriterPlugin`
- `Chapter`
- `Character`
- `Story`
- `StoryWriterNodeKind`
- `StoryWriterChangeCenter`
- `StoryStore`
- `RuntimeBridge`
- `StoryWriterViewModel`
- `ChapterEditorView`
- `StoryEditorView`
- `StoryOutlineView`
- `StoryWriterAboutView`
- `StoryWriterManualView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **StoryStore**（4 条）：由 `storyChapterAndCharacterCRUDPersistsRelationships`、`storyListUsesUpdatedTimeAndIgnoresMalformedRecords`、`markdownExportIncludesSynopsisChaptersAndOptionalCharacterDetails` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StoryWriterPlugin**（3 条）：由 `v2PluginPreservesWorkspaceAndToolCatalog`、`activationScopesRailView`、`documentationEntriesAreRemovedWhenPluginUnregisters` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StoryWriterTool**（3 条）：由 `publicToolsExposeConsistentSchemasDescriptionsAndRisks`、`toolsValidateArgumentsAndSupportStoryChapterLifecycle`、`toolsReportUnavailableStorage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StoryWriterViewModel**（3 条）：由 `selectionCrudAndMarkdownFlowsStayInSyncWithStore`、`reloadPreservesExistingSelectionAndFallsBackAfterDeletion`、`changeObserverBroadcastsAndCancellationIsIdempotent` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | StoryStore | storyChapterAndCharacterCRUDPersistsRelationships | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storyChapterAndCharacterCRUDPersistsRelationships` |
| 2 | StoryStore | storyListUsesUpdatedTimeAndIgnoresMalformedRecords | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storyListUsesUpdatedTimeAndIgnoresMalformedRecords` |
| 3 | StoryStore | markdownExportIncludesSynopsisChaptersAndOptionalCharacterDetails | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `markdownExportIncludesSynopsisChaptersAndOptionalCharacterDetails` |
| 4 | StoryStore | modelsCountNonWhitespaceContentAndExposeAllChapterStates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelsCountNonWhitespaceContentAndExposeAllChapterStates` |
| 5 | StoryWriterPlugin | v2PluginPreservesWorkspaceAndToolCatalog | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2PluginPreservesWorkspaceAndToolCatalog` |
| 6 | StoryWriterPlugin | 激活时仅显示故事创作自己的 RailView，停用后恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationScopesRailView` |
| 7 | StoryWriterPlugin | documentationEntriesAreRemovedWhenPluginUnregisters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `documentationEntriesAreRemovedWhenPluginUnregisters` |
| 8 | StoryWriterTool | publicToolsExposeConsistentSchemasDescriptionsAndRisks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `publicToolsExposeConsistentSchemasDescriptionsAndRisks` |
| 9 | StoryWriterTool | toolsValidateArgumentsAndSupportStoryChapterLifecycle | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolsValidateArgumentsAndSupportStoryChapterLifecycle` |
| 10 | StoryWriterTool | toolsReportUnavailableStorage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolsReportUnavailableStorage` |
| 11 | StoryWriterViewModel | selectionCrudAndMarkdownFlowsStayInSyncWithStore | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionCrudAndMarkdownFlowsStayInSyncWithStore` |
| 12 | StoryWriterViewModel | reloadPreservesExistingSelectionAndFallsBackAfterDeletion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reloadPreservesExistingSelectionAndFallsBackAfterDeletion` |
| 13 | StoryWriterViewModel | changeObserverBroadcastsAndCancellationIsIdempotent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `changeObserverBroadcastsAndCancellationIsIdempotent` |

> 说明：全部 **13 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 13 / 13
- P2: 已覆盖 0 / 0
- **合计: 13 / 13**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（13 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 13 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginStoryWriter
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
