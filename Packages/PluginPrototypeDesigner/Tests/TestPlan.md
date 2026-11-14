# TestPlan — PluginPrototypeDesigner

## 包概述

PluginPrototypeDesigner 的实现包，包含 14 个主要类型；当前测试覆盖 39 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 39

核心组件（源码目录）:
- `Conversation/`
- `Observers/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `PrototypeDesignerPlugin`
- `PrototypeDesignerRuleContributor`
- `PrototypeDesignerSkillContributor`
- `PrototypeElementConversationActionOutcome`
- `PrototypeDesignerProjectObserver`
- `PrototypeDesignerRuntime`
- `PrototypeLocalization`
- `AddPrototypeScreenTool`
- `PrototypeConversationProjectScope`
- `CreatePrototypeProjectTool`
- `DeletePrototypeProjectTool`
- `DeletePrototypeScreenTool`
- `DuplicatePrototypeScreenTool`
- `ExportPrototypeTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **PrototypeDesignerPlugin**（23 条）：由 `pluginMetadataMatchesContract`、`contributesCompleteUniqueToolSet`、`everyToolAdvertisesAValidSchemaAndDescription` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PrototypeDesignerRuleContributor**（1 条）：由 `loadsPrototypeRuleFromResource` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PrototypeElementConversationAction**（3 条）：由 `appendsFileURL`、`unavailableInput`、`discardsStaleSelection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PrototypeExport 安装**（3 条）：由 `installsIntoDirectoryThatDoesNotExistYet`、`rollsBackWhenAnInstallStepFails`、`backsUpAndReplacesExistingFile` 用例锁定；`ExportPrototypeTool.installStagedExports` 必须先创建用户选中的导出目录（含中间目录）再 moveItem，中途失败必回滚已安装文件并恢复备份，覆盖前先备份（#427）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | PrototypeDesignerPlugin | pluginMetadataMatchesContract | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginMetadataMatchesContract` |
| 2 | PrototypeDesignerPlugin | contributesCompleteUniqueToolSet | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contributesCompleteUniqueToolSet` |
| 3 | PrototypeDesignerPlugin | everyToolAdvertisesAValidSchemaAndDescription | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `everyToolAdvertisesAValidSchemaAndDescription` |
| 4 | PrototypeDesignerPlugin | destructiveToolsAreHighRisk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `destructiveToolsAreHighRisk` |
| 5 | PrototypeDesignerPlugin | exportEscalatesRiskWhenOverwriting | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportEscalatesRiskWhenOverwriting` |
| 6 | PrototypeDesignerPlugin | 提示词标题本地化 key 可解析 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `promptSuggestionLocalizationResolves` |
| 7 | PrototypeDesignerPlugin | deviceParsingUsesPresetAndOverrides | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deviceParsingUsesPresetAndOverrides` |
| 8 | PrototypeDesignerPlugin | deviceParsingRejectsInvalidInput | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `deviceParsingRejectsInvalidInput` |
| 9 | PrototypeDesignerPlugin | runtimeUsesProjectScopedPrototypeDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `runtimeUsesProjectScopedPrototypeDirectory` |
| 10 | PrototypeDesignerPlugin | storagePathIsEmptyWithoutOpenProject | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `storagePathIsEmptyWithoutOpenProject` |
| 11 | PrototypeDesignerPlugin | emptyStateHasNoSelectionAndNeedsNoToolbar | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyStateHasNoSelectionAndNeedsNoToolbar` |
| 12 | PrototypeDesignerPlugin | skillContributorLoadsPrototypeDesignerSkill | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skillContributorLoadsPrototypeDesignerSkill` |
| 13 | PrototypeDesignerPlugin | toolsCreateProjectAddScreensAndPersistInProjectStorage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolsCreateProjectAddScreensAndPersistInProjectStorage` |
| 14 | PrototypeDesignerPlugin | patchToolAppliesExactUniqueReplacement | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `patchToolAppliesExactUniqueReplacement` |
| 15 | PrototypeDesignerPlugin | patchToolRejectsMissingTextWithoutWriting | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `patchToolRejectsMissingTextWithoutWriting` |
| 16 | PrototypeDesignerPlugin | replaceHTMLRejectsDanglingNavigationTarget | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `replaceHTMLRejectsDanglingNavigationTarget` |
| 17 | PrototypeDesignerPlugin | linkingBetweenScreensIsRecordedInProjectSummary | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `linkingBetweenScreensIsRecordedInProjectSummary` |
| 18 | PrototypeDesignerPlugin | reorderAndStartScreenToolsUpdateProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reorderAndStartScreenToolsUpdateProject` |
| 19 | PrototypeDesignerPlugin | updateProjectToolChangesTitleAndDevice | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateProjectToolChangesTitleAndDevice` |
| 20 | PrototypeDesignerPlugin | importAssetToolCopiesIntoScreenReferencablePath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `importAssetToolCopiesIntoScreenReferencablePath` |
| 21 | PrototypeDesignerPlugin | toolsRequireAnOpenProject | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolsRequireAnOpenProject` |
| 22 | PrototypeDesignerPlugin | activatingPluginEntryShowsChatAndActivatesRail | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginEntryShowsChatAndActivatesRail` |
| 23 | PrototypeDesignerRuleContributor | 原型设计插件从 Markdown 资源贡献 Agent Rule | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsPrototypeRuleFromResource` |
| 24 | PrototypeElementConversationAction | appends the screen HTML file URL without submitting | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendsFileURL` |
| 25 | PrototypeElementConversationAction | returns unavailable when no input provider exists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unavailableInput` |
| 26 | PrototypeElementConversationAction | discards stale screen selections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `discardsStaleSelection` |
| 27 | PrototypeDocumentStore 素材目录 | 项目不存在时素材目录请求抛出 notFound 且不创建目录 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `missingProjectThrowsWithoutCreatingDirectory` |
| 28 | PrototypeDocumentStore 素材目录 | 项目不存在时导入素材失败且 slug 仍可被创建 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `missingProjectDoesNotBlockLaterCreation` |
| 29 | PrototypeDocumentStore 素材目录 | 项目存在时返回其素材目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `existingProjectReturnsAssetsDirectory` |
| 30 | PrototypeExportNaming | 文件名按顺序编号 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filenamesAreOrderedAndNumbered` |
| 31 | PrototypeExportNaming | 目标目录为空时没有冲突 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noConflictsInEmptyDirectory` |
| 32 | PrototypeExportNaming | 已存在的同名文件被识别为冲突 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `detectsExistingFiles` |
| 33 | PrototypeExportNaming | 未参与导出的同名文件不算冲突 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresUnrelatedFiles` |
| 34 | PrototypeDesignerPlugin | 加入项目不预建存储目录，真正写入时才创建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotCreateStorageDirectoryUntilWrite` |
| 35 | 工具参数边界 | 超大设备尺寸在写盘前被拒绝（**回归 #1000**） | custom 宽 `1e20`；预设叠加 `1e20` 倍率 | 调用 `prototype_create_project` | 抛参数错误且不留下项目目录 | P0 | ✅ 已覆盖 | `oversizedDeviceMetricsAreRejectedBeforeWritingProject` |
| 36 | PrototypeDesignerPlugin | 运行时停用后 17 个 Agent 工具、Skill 与 Rule 撤出，重新启用恢复（**回归 #1021**） | 插件已 Boot 并注册贡献 | 调用 `disablePlugin` 再 `enablePlugin` | 停用后工具/贡献者全部不可见，启用后全部恢复 | P0 | ✅ 已覆盖 | `disablingPluginWithdrawsAgentToolsAndEnablingRestores` |
| 37 | PrototypeExport 安装 | 导出目录尚不存在时必须先创建再安装（**回归 #427**） | 暂存目录有两张 PNG，用户选中的多级导出目录尚不存在 | 调用 `installStagedExports` | 导出目录被创建，两张 PNG 均按内容安装到位 | P0 | ✅ 已覆盖 | `installsIntoDirectoryThatDoesNotExistYet` |
| 38 | PrototypeExport 安装 | 中途失败时回滚已安装文件，不留半成品 | 第一张暂存文件有效、第二张暂存文件缺失 | 调用 `installStagedExports` | 抛错，第一张已安装文件被回滚删除，目标目录无残留 | P0 | ✅ 已覆盖 | `rollsBackWhenAnInstallStepFails` |
| 39 | PrototypeExport 安装 | 覆盖已有文件时先备份再替换 | 目标目录已有用户同名文件 | 调用 `installStagedExports` 安装替换文件 | 目标为新内容，备份目录保留用户旧内容 | P1 | ✅ 已覆盖 | `backsUpAndReplacesExistingFile` |

> 说明：全部 **39 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> **鉴别力验证（#427）**：本轮用三处独立变异确认用例不是「恒绿」——
> （1）删掉 `installStagedExports` 里 `createDirectory(at: outputDirectory)` 一行（还原 #427 缺陷）后，
> 向尚不存在的导出目录 moveItem 首张即失败，ID 37 失败；
> （2）删掉 catch 里回滚已安装文件的 `removeItem` 循环后，中途失败时第一张残留，ID 38 失败；
> （3）删掉覆盖前的备份分支（`moveItem` 到 backupURL 与 `backups.append`）后，
> 已有目标文件未被备份、替换 moveItem 因目标仍在而失败，ID 39 失败。三处变异均已还原。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 25 / 25
- P2: 已覆盖 4 / 4
- **合计: 39 / 39**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（25 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 39 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginPrototypeDesigner
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」

