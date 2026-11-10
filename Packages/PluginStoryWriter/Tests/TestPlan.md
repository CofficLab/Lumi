# TestPlan — PluginStoryWriter

## 包概述

StoryWriterPlugin A two-pane story writing workspace. - **Left pane (rail tab)**: story picker dropdown + chapter tree - **Right pane (ActivityBar view container)**: selected node editor (chapter markdown / story metadata) - **AI assistance**: via a dedicated ChatSection flow (configured separately) - **Persistence**: self-managed JSON under `~/Library/Application Support/.../StoryWriter/`

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 22

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

- **StoryStore**（5 条）：由 `storyChapterAndCharacterCRUDPersistsRelationships`、`storyListUsesUpdatedTimeAndIgnoresMalformedRecords`、`markdownExportIncludesSynopsisChaptersAndOptionalCharacterDetails`、`deletingMissingTargetsReportsNoDeletion` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StoryWriterPlugin**（4 条）：由 `v2PluginPreservesWorkspaceAndToolCatalog`、`activationScopesRailView`、`documentationEntriesAreRemovedWhenPluginUnregisters` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StoryWriterTool**（6 条）：由 `publicToolsExposeConsistentSchemasDescriptionsAndRisks`、`deletingMissingStoryOrChapterReportsNotFound`、`listingChaptersDistinguishesMissingStoryFromEmptyStory`、`toolsValidateArgumentsAndSupportStoryChapterLifecycle`、`toolsReportUnavailableStorage`、`validationFailuresThrowThroughExecuteResult` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StoryWriterViewModel**（4 条）：由 `selectionCrudAndMarkdownFlowsStayInSyncWithStore`、`reloadPreservesExistingSelectionAndFallsBackAfterDeletion`、`reloadKeepsSelectedChapterAndRefreshesItsContent`、`changeObserverBroadcastsAndCancellationIsIdempotent` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 14 | StoryStore | 删除不存在的故事/章节返回 false 且不误删现存对象 | 已有故事与章节 | 用随机 UUID 及错误 storyID 调用删除，再删真实对象 | 不存在时返回 false 且现存对象保留；真实删除返回 true | P1 | ✅ 已覆盖 | `deletingMissingTargetsReportsNoDeletion` |
| 15 | StoryWriterTool | 删除不存在的故事/章节不报告成功 | 有效存储目录 | 调用 delete_story / delete_chapter 传入随机 UUID | 分别抛出 `story not found` / `chapter not found` 的 `ToolExecutionError`；真实删除仍成功 | P1 | ✅ 已覆盖 | `deletingMissingStoryOrChapterReportsNotFound` |
| 16 | StoryWriterTool | 工具失败经 executeResult 抛出而非包成成功结果 | 有效存储目录 | 调用 create_story 缺 title、get_story 传随机 UUID，均走 `executeResult` | 两次均抛出 `ToolExecutionError`，不再产出 isError == false 的结果 | P1 | ✅ 已覆盖 | `validationFailuresThrowThroughExecuteResult` |
| 17 | StoryWriterViewModel | 磁盘重载保留仍存在的章节选择并刷新内容（**回归 #1011**） | 故事已选中章节，磁盘上的章节内容被 Agent 更新 | 调用 `reloadFromDisk()` | 仍选中该章节并展示最新内容；章节在磁盘被删除后再重载才回到故事概览 | P0 | ✅ 已覆盖 | `reloadKeepsSelectedChapterAndRefreshesItsContent` |
| 18 | StoryWriterTool | 章节状态在读取与更新工具之间无损往返（**回归 #1012**） | 已有进行中章节 | `get_chapter` 读取 status 后原样传给 `update_chapter`，并额外验证旧的 `inProgress` 令牌 | 读取输出 `in_progress` 而非 `inProgress`；更新成功且状态保持；旧令牌仍被接受 | P1 | ✅ 已覆盖 | `chapterStatusRoundTripsThroughReadAndUpdate` |
| 19 | StoryEditorDraft | 无本地未保存修改时采纳外部新版本（**回归 #1013**） | 草稿基线标题/简介为旧值 | 外部更新到达后调用 `applyExternalUpdate` | 简介与标题均为外部最新值，无未保存标记 | P1 | ✅ 已覆盖 | `cleanDraftAdoptsExternalSynopsisAndTitle` |
| 20 | StoryEditorDraft | 本地简介未保存时合并外部更新且不覆盖外部标题（**回归 #1013**） | 用户已在简介中输入，外部更新修改了标题与简介 | 应用外部更新后调用 `storyToSave()`，再模拟保存回声 | 本地输入保留；落盘标题为外部最新值；保存后无未保存标记 | P0 | ✅ 已覆盖 | `dirtySynopsisKeepsLocalTextButSavesAgainstLatestExternalVersion` |
| 21 | StoryWriterTool | 列出章节区分「父故事不存在」与「真实空故事」（**回归 #1064**） | 有效存储目录，另有一个已删除故事 | 用随机 UUID、空故事、已删除故事分别调用 `list_chapters` | 随机 UUID 与已删除故事抛出 `ToolExecutionError`；空故事返回「暂无章节」 | P1 | ✅ 已覆盖 | `listingChaptersDistinguishesMissingStoryFromEmptyStory` |
| 22 | StoryWriterPlugin | 首次启用不会替换其它工作区的内容与标题栏（**回归 #1019**） | ActivityBar 已选中 Code Editor，内容区已有内容 | 在从未 Boot 的情况下调用 `onBoot` | 选中项、标题栏与内容区保持原样，内容观察者不收到变更事件 | P0 | ✅ 已覆盖 | `bootingPluginKeepsOtherWorkspaceContent` |

> 说明：全部 **22 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 19 / 19
- P2: 已覆盖 0 / 0
- **合计: 22 / 22**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（18 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 22 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
