# TestPlan — PluginStoryWriter

## 包概述

StoryWriterPlugin A two-pane story writing workspace. - **Left pane (rail tab)**: story picker dropdown + chapter tree - **Right pane (ActivityBar view container)**: selected node editor (chapter markdown / story metadata) - **AI assistance**: via a dedicated ChatSection flow (configured separately) - **Persistence**: self-managed JSON under `~/Library/Application Support/.../StoryWriter/`

平台: macOS 14+, iOS 17+
测试文件: 9 个，用例总数: 45

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
- **StoryEditorIdentity**（3 条）：由 `storyEditorIdentityFollowsSelectedStory`、`storyEditorIdentityIsStableAcrossRendersForSameStory`、`reMaterializedEditorDraftBindsToNewStory` 用例锁定；改动 `StoryWriterView` 故事分支或 `StoryEditorView` 时优先跑对应测试文件。
- **StoryWriterCreationIdentity**（4 条）：由 `lateChapterCreationDoesNotPolluteSwitchedStory`、`lateMarkdownImportDoesNotPolluteSwitchedStory`、`lateCharacterCreationDoesNotPolluteSwitchedStory`、`creationWithoutStorySwitchStillAppendsAndSelects` 用例锁定；改动 `StoryWriterViewModel` 创建类方法或 `loadStoryContent` 的代次逻辑时优先跑对应测试文件。
- **StoryStoreSaveFailure**（6 条）：由 `createChapterThrowsAndLeavesNoDanglingID`、`createCharacterThrowsAndLeavesNoDanglingID`、`importMarkdownThrowsAndLeavesNoDanglingID`、`createStoryThrowsWhenStoriesDirUnwritable`、`createChapterRollsBackChapterFileWhenStorySaveFails`、`updateChapterThrowsWhenChapterFileUnwritable` 用例锁定；改动 `StoryStore` 保存/创建/更新路径的错误传播或回滚逻辑时优先跑对应测试文件（**回归 #431**）。

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
| 23 | ChapterWordCount | 字数统计与逐字符非空白统计语义一致 | — | 对多组正文样本构造 Chapter 并读取 wordCount | 等于过滤空白后的字符数 | P1 | ✅ 已覆盖 | `wordCountMatchesCharacterCount` |
| 24 | ChapterWordCount | 修改正文后字数同步更新 | — | 依次改写 content 并读取 wordCount | 字数随正文即时变化 | P1 | ✅ 已覆盖 | `wordCountUpdatesWithContent` |
| 25 | ChapterWordCount | 解码后字数正确重算 | — | 编码再解码 Chapter | 解码对象 wordCount 与原文一致 | P1 | ✅ 已覆盖 | `wordCountIsRecomputedAfterDecoding` |
| 26 | ChapterWordCount | 编码载荷不含派生字数字段 | — | 编码 Chapter 后检查 JSON 键 | 无 wordCount 键，保留 content | P1 | ✅ 已覆盖 | `encodedPayloadOmitsWordCount` |
| 27 | ChapterWordCount | 解码无字数字段的旧文件仍得到正确字数 | — | 解码不含 wordCount 的历史 JSON | wordCount 由 content 重算正确 | P1 | ✅ 已覆盖 | `decodingLegacyPayloadWithoutWordCountWorks` |
| 28 | StoryExport | 导出写入可在后台任务完成且内容完整一致（**回归 #1248**） | 临时目录 | 在 detached 任务中写大 Markdown 再读回 | 读回内容与原文逐字一致 | P1 | ✅ 已覆盖 | `writesOffMain` |
| 29 | StoryExport | 写入失败抛出错误供 UI 提示而非静默吞掉（**回归 #1248**） | 不存在的父目录 | 在 detached 任务中向缺失目录写入 | 抛出错误而非静默成功 | P1 | ✅ 已覆盖 | `writeFailureThrows` |
| 30 | StoryWriterViewModel | 内存应用即时生效，持久化不得回写覆盖更新的内存内容 | 已创建故事与章节 | applyChapterInMemory 后再 persistChapter 旧版本 | 内存保留新内容；磁盘落盘旧内容 | P0 | ✅ 已覆盖 | `inMemoryApplyIsImmediateAndPersistDoesNotWriteBack` |
| 31 | StoryWriterTool | 创建章节时显式 status 覆盖正文默认值，非法 status 必须抛错（**回归 #820**） | 有效存储目录与故事 | create_chapter / import_markdown_as_chapter 传 done/draft/缺省/非法 status | 显式状态生效；缺省保持正文推导默认；非法抛 ToolExecutionError | P0 | ✅ 已覆盖 | `chapterCreationHonorsExplicitStatusArgument` |
| 32 | StoryEditorIdentity | 切换故事后编辑器 identity 必须换成新故事，不得复用旧草稿误写/误删原文档（**回归 #289**） | 故事 A、B 均已创建 | 选中 A 求值 body 取编辑器 identity，再切到 B 求值 | identity 分别为 A.id、B.id 且互不相同（Mirror 查找包裹 StoryEditorView 的 IDView.id） | P0 | ✅ 已覆盖 | `storyEditorIdentityFollowsSelectedStory` |
| 33 | StoryEditorIdentity | 同一故事多次渲染编辑器 identity 保持稳定，不清空用户草稿（**回归 #289**） | 已选中故事 A 并创建章节 | 求值 body 取 identity，更新章节后再求值 | 两次 identity 均等于 A.id（防止 .id(UUID()) 之类不稳定标识） | P1 | ✅ 已覆盖 | `storyEditorIdentityIsStableAcrossRendersForSameStory` |
| 34 | StoryEditorIdentity | 切换故事重建的草稿必须绑定新故事，不得继承旧故事未保存简介或误写旧故事（**回归 #289**） | A 草稿有未保存简介，B 为另一故事 | 以 B 全新初始化 StoryEditorDraft（.id 强制重建）后 storyToSave | 草稿基线/简介为 B、无未保存标记，落盘 id==B.id 且 !=A.id | P0 | ✅ 已覆盖 | `reMaterializedEditorDraftBindsToNewStory` |
| 35 | StoryWriterCreationIdentity | 切换故事后晚到的章节创建只落盘原故事，不得污染新故事大纲与选择（**回归 #432**） | 门闩 stub 挂起 A 的 createChapter | 挂起期间切到 B 再放行创建 | 章节落盘在 A；B 的 chapters 为空、选择仍为 B/.story；切回 A 可见该章节 | P0 | ✅ 已覆盖 | `lateChapterCreationDoesNotPolluteSwitchedStory` |
| 36 | StoryWriterCreationIdentity | 切换故事后晚到的 Markdown 导入不得进入新故事章节列表与字数（**回归 #432**） | 门闩 stub 挂起 A 的 importMarkdownAsChapter | 挂起期间切到 B 再放行导入 | 导入章节落盘在 A 且正文完整；B 的 chapters 为空、totalWordCount==0、选择仍为 B/.story | P0 | ✅ 已覆盖 | `lateMarkdownImportDoesNotPolluteSwitchedStory` |
| 37 | StoryWriterCreationIdentity | 切换故事后晚到的角色创建只落盘原故事，不得污染新故事角色列表与选择（**回归 #432**） | 门闩 stub 挂起 A 的 createCharacter | 挂起期间切到 B 再放行创建 | 角色落盘在 A；B 的 characters 为空、选择仍为 B/.story | P0 | ✅ 已覆盖 | `lateCharacterCreationDoesNotPolluteSwitchedStory` |
| 38 | StoryWriterCreationIdentity | 故事未切换时创建章节/角色仍追加进列表并选中（**回归 #432**） | 门闩 stub 不挂起，单一故事 | 依次 createChapter、createCharacter | 章节/角色进入列表，选择指向最新创建的角色 | P1 | ✅ 已覆盖 | `creationWithoutStorySwitchStillAppendsAndSelects` |
| 39 | StoryStoreSaveFailure | chapters 目录不可写时 createChapter 抛出，story 不得残留悬空章节 ID（**回归 #431**） | 已有故事，chapters 路径被普通文件占用 | 调用 createChapter | 抛出错误；重载 story.chapterIDs 为空、loadChapters 为空 | P0 | ✅ 已覆盖 | `createChapterThrowsAndLeavesNoDanglingID` |
| 40 | StoryStoreSaveFailure | characters 目录不可写时 createCharacter 抛出，story 不得残留悬空角色 ID（**回归 #431**） | 已有故事，characters 路径被普通文件占用 | 调用 createCharacter | 抛出错误；重载 story.characterIDs 为空、loadCharacters 为空 | P0 | ✅ 已覆盖 | `createCharacterThrowsAndLeavesNoDanglingID` |
| 41 | StoryStoreSaveFailure | chapters 目录不可写时 importMarkdownAsChapter 抛出，不得残留悬空章节 ID（**回归 #431**） | 已有故事，chapters 路径被普通文件占用 | 调用 importMarkdownAsChapter | 抛出错误；重载 story.chapterIDs 为空、loadChapters 为空 | P0 | ✅ 已覆盖 | `importMarkdownThrowsAndLeavesNoDanglingID` |
| 42 | StoryStoreSaveFailure | stories 目录不可写时 createStory 抛出而非伪装成功（**回归 #431**） | stories 路径被普通文件占用 | 调用 createStory | 抛出错误，不返回未落盘的故事 | P1 | ✅ 已覆盖 | `createStoryThrowsWhenStoriesDirUnwritable` |
| 43 | StoryStoreSaveFailure | story 引用写失败时 createChapter 必须回滚章节文件，二者保持一致（**回归 #431**，macOS） | 已有故事，story.json 置 immutable 使引用写失败 | 调用 createChapter | 抛出错误；chapters 目录无残留章节文件，story.chapterIDs 为空 | P0 | ✅ 已覆盖 | `createChapterRollsBackChapterFileWhenStorySaveFails` |
| 44 | StoryStoreSaveFailure | 章节文件不可写时 updateChapter 抛出，不得伪装成功（**回归 #431**，macOS） | 已有章节，章节文件置 immutable | 调用 updateChapter | 抛出错误，磁盘内容保持原样 | P0 | ✅ 已覆盖 | `updateChapterThrowsWhenChapterFileUnwritable` |
| 45 | StoryWriterTool | 保存失败时 create_chapter/import 工具必须抛 ToolExecutionError，不得包装成成功文案（**回归 #431**） | 有效存储目录与故事，chapters 路径被普通文件占用 | 调用 create_chapter、import_markdown_as_chapter | 两者均抛 ToolExecutionError；story.chapterIDs 为空、loadChapters 为空 | P0 | ✅ 已覆盖 | `createChapterToolThrowsWhenSaveFailsAndLeavesNoDanglingID` |

> 说明：全部 **45 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> 变异验证（#289）：`StoryWriterView` 的 `.story` 分支原先直接渲染 `StoryEditorView(viewModel:story:)` 而无 `.id(story.id)`（相邻 `.chapter` 分支已正确加 `.id(chapter.id)`）。切换故事时 SwiftUI 复用同一编辑器 identity，`@State draft` 不重新初始化，简介更新/标题保存经 `draft.storyToSave()` 仍带旧故事 id，误写原文档；导出正文来自 ViewModel 新选择而文件名取自旧故事。修复为给 `.story` 分支补 `.id(story.id)`，切换故事即重新物化编辑器。M1 移除该 `.id(story.id)`（还原裸 `StoryEditorView`）→ `storyEditorIdentityFollowsSelectedStory`（identity 查找返回 nil，3 处断言）、`storyEditorIdentityIsStableAcrossRendersForSameStory`（2 处断言）转红，`reMaterializedEditorDraftBindsToNewStory` 仍绿（草稿 init 契约未变）。变异施加并确认转红后还原，最终 34 条全绿。
>
> 变异验证（#432）：`createChapter` / `importMarkdownAsChapter` / `createCharacter` 原先在 `await store.…` 后无条件把结果追加进共享 `chapters`/`characters` 并改写选择；await 期间切换故事时，旧故事的创建结果晚到污染新故事大纲。修复为 `loadStoryContent` 递增 `storyGeneration`，三个创建方法写回前比对代次与 `currentStoryID`（不匹配只返回已创建对象，磁盘操作仍归属原故事）；存储依赖经 `StoryWriting` 协议注入以便门闩测试。M1 移除 createChapter 的守卫 → 用例 35 转红（3 处断言）；M2 移除 createCharacter 的守卫 → 用例 37 转红（3 处断言）；M3 移除 importMarkdownAsChapter 的守卫 → 用例 36 转红（chapters.isEmpty）。三处变异各自独立命中对应用例，用例 38 始终绿；还原后 38 条全绿。
>
> 变异验证（#431）：`StoryStore` 的 `saveStory`/`saveChapter`/`saveCharacter` 原先用 `try?` 吞掉写盘错误，`createChapter` 等在落盘失败后仍把 ID 追加进 `story.chapterIDs`，留下悬空引用；工具层把失败当成功文案返回。修复为保存助手与全部变更方法 `throws`（创建路径在 `saveStory` 失败时回滚已落盘的实体文件），协议同步 `throws`，工具 `execute` 用 `try` 传播并以 `do/catch` 把底层错误统一包成 `ToolExecutionError.executionFailed`（ViewModel 公开 API 经 `try?` 保持稳定，#432 代次守卫不变）。M1 移除 createChapter 的章节文件回滚 → 用例 43 转红（chapters 目录残留文件）；M2 把 `try saveChapter` 还原为 `try?`（吞错并追加 ID）→ 用例 39 转红（未抛错且 chapterIDs 非空）；M3 工具 catch 改为透传原始 NSError → 用例 45 转红（错误类型非 ToolExecutionError）。三处变异各自独立命中对应用例；还原后 45 条全绿。

## 覆盖率统计

- P0: 已覆盖 16 / 16
- P1: 已覆盖 29 / 29
- P2: 已覆盖 0 / 0
- **合计: 45 / 45**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（16 条）
- **P1**: 其余功能性用例（29 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 45 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
