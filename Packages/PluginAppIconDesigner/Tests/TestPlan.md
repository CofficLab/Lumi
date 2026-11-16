# TestPlan — PluginAppIconDesigner

## 包概述

PluginAppIconDesigner 的实现包，包含 14 个主要类型；当前测试覆盖 34 条用例。

平台: macOS 14+, iOS 17+
测试文件: 8 个，用例总数: 34

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppIconDesignerPlugin`
- `AppIconDesignerRuleContributor`
- `AppIconDesignerSkillContributor`
- `AppIconArtifact`
- `IconDocument`
- `IconPreset`
- `IconDesignerProjectObserver`
- `AppIconArtifactStore`
- `AppIconDesignerLocalization`
- `AppIconExportService`
- `IconComposerExportService`
- `IconScope`
- `IconDocumentFileService`
- `IconDocumentFileStore`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AppIconDesignerPlugin**（7 条）：由 `registersAndActivatesContributions`、`registersPromptSuggestionWhileDisabled`、`promptSuggestionLocalizationResolves` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AppIconDesignerRuleContributor**（1 条）：由 `contributesAppIconRule` 等用例锁定；改动该模块时优先跑对应测试文件。
- **IconDocumentFileStore**（3 条）：由 `deleteClearsAllDerivedFilesOfID`、`loadAllDeduplicatesByIDKeepingNewest`、`deleteStillRemovesSingleVersion` 锁定；改动文件名派生/落盘/删除/重载去重时优先跑对应测试文件。
- **错误镜像**（1 条）：由 `exportErrorIsMirroredAndClearedOnSuccess` 锁定；改动 `AppIconDesignerViewModel` 对 store 的镜像同步（objectWillChange 时序，#293）时优先跑对应测试文件。
- **落盘失败传播**（3 条，#428）：由 `updateDocumentThrowsAndRollsBackWhenSaveFails`、`replaceDocumentThrowsAndRollsBackWhenSaveFails`、`updateDocumentPersistsAndClearsErrorWhenSaveSucceeds` 锁定——`persist` 必须报告真实写入结果，`updateDocument`/`replaceDocument` 落盘失败时还原内存并抛 `IconDocumentStoreError.persistenceFailed`，不得把只在内存里的改动当成成功落盘（工具据此上报失败、`lastError` 保持可见）；可写存储下正常落盘并清错。改动 `IconDocumentStore` 的落盘/回滚链路时必须优先跑该文件。
- **导出 off-main**（2 条，#1289/#1291）：由 `encodesOffMain`、`exportsDocumentOffMain` 锁定——preview PNG 压缩与 Xcode `.icon` 导出管线必须在后台线程执行，主 actor 只做 ImageRenderer 栅格化，导出结果仍完整正确。改动 `AppIconExportService`/`IconComposerExportService` 的线程模型时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AppIconDesignerPlugin | 启动后注册 ActivityBar 与 Rail，并在激活时联动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAndActivatesContributions` |
| 2 | AppIconDesignerPlugin | 禁用时仍注册提示词，并标记为需要启用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersPromptSuggestionWhileDisabled` |
| 3 | AppIconDesignerPlugin | 提示词标题本地化 key 可解析 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `promptSuggestionLocalizationResolves` |
| 4 | AppIconDesignerPlugin | 图标文档在项目作用域创建并落盘 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `createsAndPersistsProjectDocument` |
| 5 | AppIconDesignerPlugin | 启动后 15 个 Agent 工具注册到 ToolManagerProviding，停止后移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAndRemovesAgentTools` |
| 6 | AppIconDesignerPlugin | create_icon_document 工具可执行并创建文档 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `executeCreateIconDocumentTool` |
| 7 | AppIconDesignerPlugin | preview_icon 工具返回带 PNG 图片附件的结构化结果 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `executePreviewIconToolReturnsImage` |
| 8 | AppIconDesignerRuleContributor | 图标设计插件贡献自己的 Agent Rule | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `contributesAppIconRule` |
| 9 | Agent 工具 | 没有项目存储时 create_icon_document 在改状态前失败 | 未打开项目 | 调用工具 | 抛 `invalidStorageScope`，内存中无新文档 | P1 | ✅ 已覆盖 | `createIconDocumentFailsWithoutProjectStorage` |
| 10 | Agent 工具 | 没有项目存储时 apply_icon_preset 在改状态前失败 | 未打开项目 | 调用工具 | 抛 `invalidStorageScope`，内存中无新文档 | P1 | ✅ 已覆盖 | `applyIconPresetFailsWithoutProjectStorage` |
| 11 | 跨对话隔离 | 对话 A 的工具调用写入对话 A 的项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationScopedToolWritesIntoItsOwnProject` |
| 12 | 跨对话隔离 | 对话 A 的工具调用读取对话 A 的项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationScopedToolReadsFromItsOwnProject` |
| 13 | 跨对话隔离 | 跨项目写入不污染 UI 当前项目的 store | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `crossProjectWriteDoesNotPolluteSharedStore` |
| 14 | 跨对话隔离 | 对话项目与当前项目相同时复用 shared store | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sameProjectReusesSharedStore` |
| 15 | 跨对话隔离 | 对话未绑定项目时回退到当前项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unscopedConversationFallsBackToCurrentProject` |
| 16 | 跨对话隔离 | 15 个工具都按对话项目路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registeredToolsAreConversationScoped` |
| 17 | 存储 | 加入项目不预建存储目录，真正写入时才创建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotCreateStorageDirectoryUntilWrite` |
| 18 | Agent 工具 | `replaceSelected=true` 时用不同 ID 的 JSON 替换当前选中文档，保留其 ID 并清理旧文件 | 已选中文档 A，B 的 JSON 位于存储目录外 | 调用 `load_icon_document(inputPath=B, replaceSelected=true)` | 列表中仅一条文档，ID 为 A，内容为 B，磁盘重载也只有一条 | P1 | ✅ 已覆盖 | `loadIconDocumentReplacesSelectedDocumentWithDifferentId` |
| 19 | Agent 工具 | `replaceSelected=false` 时导入新副本而不是替换 | 已选中文档 A | 调用 `load_icon_document(inputPath=B)` | 列表两条文档，新副本拥有独立 ID 并被选中 | P1 | ✅ 已覆盖 | `loadIconDocumentImportsCopyWhenReplaceSelectedIsFalse` |
| 20 | 跨对话隔离 | 缓存的项目 store 使用前从磁盘重载，旧快照不覆盖新修订 | 项目 A 由对话缓存，UI 切到项目 A 用 shared 编辑后再切回 | 再次通过对话使用缓存 store 编辑同一文档 | 内存与磁盘都保留 shared 写入的新修订 | P1 | ✅ 已覆盖 | `cachedScopedStoreReloadsBeforeUse` |
| 21 | 导出 | 径向背景半径随导出尺寸缩放，各尺寸外观一致 | 1024 文档，径向渐变 endRadius=512 | 分别渲染 1024px 与 64px PNG | 小尺寸角落同样到达渐变末端 | P1 | ✅ 已覆盖 | `radialBackgroundScalesWithRenderSize` |
| 22 | 导出 | SVG 导出保留渐变、阴影与模糊，不丢失视觉效果 | 线性渐变背景 + 径向渐变光晕（模糊） + 带阴影矩形 | 调用 `IconSVGRenderer.render` | 输出 `linearGradient`/`radialGradient` defs、`url(#…)` 填充、多段 `stop` 及 `feGaussianBlur`/`feFlood` 滤镜 | P0 | ✅ 已覆盖 | `svgExportPreservesGradientsShadowAndBlur` |
| 23 | 导出 | SVG 导出不得把 SF Symbol 输出为字面名称 | 含 `sparkles` 符号图层与阴影 | 调用 `IconSVGRenderer.render` | 输出内嵌 base64 PNG 的 `<image>`，不出现 `<text>` 或符号名字面文本 | P0 | ✅ 已覆盖 | `svgExportRasterizesSymbolsInsteadOfLiteralNames` |
| 24 | Agent 工具 | 缺少必填参数时抛出 `ToolExecutionError`，不返回本地化错误字符串 | 无 | 调用 `apply_icon_preset` / `export_app_icon` 不传必填参数 | 两次均抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `missingParameterThrows` |
| 25 | Agent 工具 | 未知预设抛出 `ToolExecutionError` | 无 | 调用 `apply_icon_preset(presetId: not-a-preset)` | 抛出 `ToolExecutionError`，不返回错误文案 | P1 | ✅ 已覆盖 | `unknownPresetThrows` |
| 26 | 文件存储 | delete 清除同一 ID 的全部派生文件，旧标题残留文件不得保留（**回归 #292**） | 同一 ID 以旧/新两个标题各落盘一个 JSON | 以新标题文档调用 `IconDocumentFileStore.delete` | 该 ID 后缀的全部 JSON 文件均被删除 | P0 | ✅ 已覆盖 | `deleteClearsAllDerivedFilesOfID` |
| 27 | 文件存储 | loadAll 按 ID 去重，保留 updatedAt 最新修订而非文件名最后一条（**回归 #292**） | 同一 ID 落盘两个标题文件，较新修订标题字母序靠前 | 调用 `IconDocumentFileStore.loadAll` | 仅返回一条，id 匹配且标题为最新修订 | P1 | ✅ 已覆盖 | `loadAllDeduplicatesByIDKeepingNewest` |
| 28 | 文件存储 | delete 仍清除单一版本文档，常规删除路径不回归 | 目录内仅一个文档文件 | 调用 `IconDocumentFileStore.delete` | 重载后列表为空 | P1 | ✅ 已覆盖 | `deleteStillRemovesSingleVersion` |
| 29 | 错误镜像 | objectWillChange 在新值安装前触发，ViewModel 必须镜像安装后的导出错误，成功后不得残留旧错误（**回归 #293**） | 新建 store 与 ViewModel | `store.setError(...)` 后再 `store.setExportURL(...)` | 错误及时镜像显示；成功后 lastError 归 nil、lastExportURL 更新 | P0 | ✅ 已覆盖 | `exportErrorIsMirroredAndClearedOnSuccess` |
| 30 | 落盘失败传播 | updateDocument 落盘失败时抛错、还原内存、错误保持可见（**回归 #428**） | 存储目录路径被普通文件占据，importDocument 已只在内存里建文档 | 调用 `updateDocument` 改背景 | 抛 `IconDocumentStoreError`，内存还原为改动前文档，lastError 不被清空 | P0 | ✅ 已覆盖 | `updateDocumentThrowsAndRollsBackWhenSaveFails` |
| 31 | 落盘失败传播 | replaceDocument 落盘失败时抛错并还原内存（**回归 #428**） | 同上，目标文档标题不变（文件名不变，不触发删除） | 调用 `replaceDocument` 替换背景 | 抛 `IconDocumentStoreError`，列表仍为原文档，lastError 不被清空 | P0 | ✅ 已覆盖 | `replaceDocumentThrowsAndRollsBackWhenSaveFails` |
| 32 | 落盘失败传播 | 可写存储下 updateDocument 正常落盘并清错（**回归 #428** 护栏） | 真实可写存储目录 | importDocument 后 `updateDocument` 改背景 | lastError 为 nil，返回新背景，磁盘重载首条背景一致 | P1 | ✅ 已覆盖 | `updateDocumentPersistsAndClearsErrorWhenSaveSucceeds` |
| 33 | 导出 off-main | preview PNG 在后台线程压缩，主 actor 只栅格化（**回归 #1289**） | 512 文档，主 actor 捕获 256px CGImage | `Task.detached` 中 `AppIconExportService.encodePNG` | 解码回 256×256 单图 PNG，编码不占用主 actor | P1 | ✅ 已覆盖 | `encodesOffMain` |
| 34 | 导出 off-main | async 导出在后台产出完整 `.icon` 图标集（**回归 #1291**） | 512 文档，临时输出目录 | `await IconComposerExportService().export(...)` | `.icon` 存在，Artwork.png 与 icon.json 均非空 | P1 | ✅ 已覆盖 | `exportsDocumentOffMain` |

> 说明：全部 **34 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 22 / 22
- P2: 已覆盖 6 / 6
- **合计: 34 / 34**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（22 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 34 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAppIconDesigner
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
