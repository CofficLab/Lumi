# TestPlan — PluginResumeDesigner

## 包概述

PluginResumeDesigner 的实现包，包含 15 个主要类型；当前测试覆盖 30 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 30

核心组件（源码目录）:
- `Observers/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ResumeDesignerPlugin`
- `ResumeDesignerRuleContributor`
- `ResumeDesignerSkillContributor`
- `ResumeDesignerProjectObserver`
- `ResumeDesignerLocalization`
- `ResumeDesignerRuntime`
- `CreateResumeTool`
- `ExportResumeTool`
- `ImportResumeAssetTool`
- `LintResumeTool`
- `ListResumesTool`
- `PatchResumeHTMLTool`
- `PreviewResumePageTool`
- `ReadResumeHTMLTool`
- `ResumeExportTargets`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ResumeDesignerPlugin**（4 条）：由 `registersAndActivatesContributions`、`promptSuggestionLocalizationResolves`、`promptSuggestionActivatesPluginEntry`、`registersAndRemovesAgentTools` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeDesignerRuleContributor**（1 条）：由 `loadsResumeRuleFromResource` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeDocumentStore**（4 条）：由 `fullCRUD`、`rejectsInvalidSlugAndDuplicate`、`patchRequiresUniqueOldText` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeTools**（9 条）：由 `createResumeToolCreatesDocument`、`listResumesToolListsDocuments`、`readResumeToolReturnsMetadata` 等用例锁定；改动该模块时优先跑对应测试文件，其中 `aliasedResumeIDNotifyKeepsNormalizedSelection` 与 `importAssetWithUppercaseResumeIDKeepsSelection` 锁定「工具别名 ID 刷新后 UI 仍选中规范化文档」。

- **ResumeDesignerSuite**（8 条）：由 `conversationScopedToolWritesIntoItsOwnProject`、`conversationScopedToolReadsFromItsOwnProject` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TestStorage**（1 条）：由 `doesNotCreateStorageDirectoryUntilWrite` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeExportTargets**（3 条）：由 `fileNamesMatchExportMode`、`reportsEveryExistingTarget`、`pngOnlyIgnoresPDFConflict` 锁定 GUI 导出的目标清单与同名冲突检测。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ResumeDesignerPlugin | 启动后注册 ActivityBar 入口、Rail 标签与 Docs 文档，停止后全部撤回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAndActivatesContributions` |
| 2 | ResumeDesignerPlugin | 提示词标题本地化 key 可解析 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `promptSuggestionLocalizationResolves` |
| 3 | ResumeDesignerPlugin | 启动后 10 个 Agent 工具注册到 ToolManagerProviding，停止后移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAndRemovesAgentTools` |
| 4 | ResumeDesignerRuleContributor | 简历设计插件从 Markdown 资源贡献 Agent Rule | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsResumeRuleFromResource` |
| 5 | ResumeDocumentStore | 创建、读取、替换、补丁与删除的完整生命周期 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullCRUD` |
| 6 | ResumeDocumentStore | 非法 slug 与重复创建分别抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidSlugAndDuplicate` |
| 7 | ResumeDocumentStore | 补丁要求旧文本唯一，缺失或重复均抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `patchRequiresUniqueOldText` |
| 8 | ResumeDocumentStore | listResumes 返回全部简历并按更新时间倒序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listsResumesNewestFirst` |
| 9 | ResumeTools | resume_create 创建简历并落盘（manifest + index.html） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createResumeToolCreatesDocument` |
| 10 | ResumeTools | resume_list 列出已创建的简历 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listResumesToolListsDocuments` |
| 11 | ResumeTools | resume_read 返回 manifest 元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readResumeToolReturnsMetadata` |
| 12 | ResumeTools | resume_lint 对模板输出 PASS | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lintResumeToolPassesOnTemplate` |
| 13 | ResumeTools | resume_patch_html 原子应用补丁并更新 HTML | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `patchResumeHTMLToolAppliesPatch` |
| 14 | ResumeTools | resume_create 拒绝非法 paper 值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `createResumeToolRejectsInvalidPaper` |
| 15 | ResumeTools | resume_create 缺少必填 slug 抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `createResumeToolRejectsMissingSlug` |
| 16 | ResumeDesignerSuite | 对话 A 的工具调用写入对话 A 的项目，而不是 UI 当前打开的项目 B | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationScopedToolWritesIntoItsOwnProject` |
| 17 | ResumeDesignerSuite | 对话 A 的工具读取只看到项目 A 的简历 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationScopedToolReadsFromItsOwnProject` |
| 18 | ResumeDesignerSuite | 跨项目写入不会刷新 UI 当前打开项目的面板 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `crossProjectWriteDoesNotReloadWorkspaceOfAnotherProject` |
| 19 | ResumeDesignerSuite | 未绑定项目的对话回退到 UI 当前打开项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unscopedConversationFallsBackToCurrentProject` |
| 20 | ResumeDesignerSuite | 对话绑定的项目路径无效时不会写进别的项目 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `scopedConversationWithMissingProjectNeverWritesElsewhere` |
| 21 | ResumeDesignerSuite | 插件注册的 Agent 工具都带对话作用域包装 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registeredToolsAreConversationScoped` |
| 22 | TestStorage | 加入项目不预建存储目录，真正写入时才创建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotCreateStorageDirectoryUntilWrite` |
| 23 | ResumeDesignerPlugin | 启动器建议激活完整插件入口而不是只切换 Rail（**回归 #1006**） | 构造插件实例 | 读取 `promptSuggestion.action` | 为 `.activatePluginEntry`，ActivityBar 入口为 `<id>.entry`，Rail tab 为 `railTabID` | P1 | ✅ 已覆盖 | `promptSuggestionActivatesPluginEntry` |
| 24 | ResumeExportTargets | PDF 导出列出 PDF 与全部页 PNG，PNG 导出不含 PDF | — | 调用 `fileNames` | 文件名顺序与写入顺序一致，PNG 模式不含 `.pdf` | P1 | ✅ 已覆盖 | `fileNamesMatchExportMode` |
| 25 | ResumeExportTargets | 目标目录已有同名文件时全部报告，未冲突时不报告（**回归 #1007**） | 临时目录预置 `alice.pdf` 与 `alice-p02.png` | 调用 `existingFiles` | 空目录返回空；预置后按顺序返回两个冲突文件 | P0 | ✅ 已覆盖 | `reportsEveryExistingTarget` |
| 26 | ResumeExportTargets | PNG-only 导出不把已有 PDF 算作冲突 | 临时目录预置 `alice.pdf` | 调用 `existingFiles(pngOnly: true)`，再预置 `alice-p01.png` 重查 | 首次为空；预置 PNG 后只报告该 PNG | P1 | ✅ 已覆盖 | `pngOnlyIgnoresPDFConflict` |
| 27 | ResumeTools | 别名 resumeId（`" ALICE "`）刷新后 UI 仍选中规范化文档 `alice`（**回归 #1090**） | 项目内已有 `alice` 且已选中 | 调用 `ResumeToolSupport.notify(resumeID: " ALICE ")` | `selectedResumeID == "alice"`，`selectedResume` 不为空 | P0 | ✅ 已覆盖 | `aliasedResumeIDNotifyKeepsNormalizedSelection` |
| 28 | ResumeTools | `resume_import_asset` 用大写 ID 导入素材后保留规范化选中与预览（**回归 #1090**） | 项目内已有 `alice` 且已选中，临时目录写入 2x2 PNG | 以 `resumeId: "ALICE"` 执行导入 | 素材落在 `resumes/alice/assets/photo.png`；选中仍为 `alice` 且预览未清空 | P0 | ✅ 已覆盖 | `importAssetWithUppercaseResumeIDKeepsSelection` |
| 29 | ResumeDesignerSuite | 后台项目（A）的预览失败不污染 UI 当前项目（B）的错误状态（**回归 #1089**） | UI 显示项目 B，对话 A 预览 A 中不存在的简历 | 以对话 A 作用域执行 `resume_preview_page` | 结果 `isError`；`lastError` 保持为空，当前项目仍为 B | P0 | ✅ 已覆盖 | `backgroundPreviewFailureDoesNotSetCurrentProjectError` |
| 30 | ResumeDesignerSuite | 当前项目自身的预览失败仍会写入错误提示（**回归 #1089**） | UI 显示项目 B，作用域也是项目 B | 预览 B 中不存在的简历 | 结果 `isError` 且 `lastError` 非空 | P1 | ✅ 已覆盖 | `currentProjectPreviewFailureSurfacesError` |

> 说明：全部 **30 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 9 / 9
- P1: 已覆盖 20 / 20
- P2: 已覆盖 1 / 1
- **合计: 30 / 30**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（9 条）
- **P1**: 其余功能性用例（19 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 26 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginResumeDesigner
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
