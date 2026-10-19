# TestPlan — PluginPrototypeDesigner

## 包概述

PluginPrototypeDesigner 的实现包，包含 14 个主要类型；当前测试覆盖 26 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 26

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

- **PrototypeDesignerPlugin**（22 条）：由 `pluginMetadataMatchesContract`、`contributesCompleteUniqueToolSet`、`everyToolAdvertisesAValidSchemaAndDescription` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PrototypeDesignerRuleContributor**（1 条）：由 `loadsPrototypeRuleFromResource` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PrototypeElementConversationAction**（3 条）：由 `appendsFileURL`、`unavailableInput`、`discardsStaleSelection` 等用例锁定；改动该模块时优先跑对应测试文件。

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

> 说明：全部 **26 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 19 / 19
- P2: 已覆盖 4 / 4
- **合计: 26 / 26**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（19 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 26 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
