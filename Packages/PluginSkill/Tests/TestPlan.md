# TestPlan — PluginSkill

## 包概述

PluginSkill 的实现包，包含 14 个主要类型；当前测试覆盖 56 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 56

核心组件（源码目录）:
- `Hooks/`
- `Models/`
- `Observers/`
- `Services/`
- `Support/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `SkillPlugin`
- `SkillPromptBuilder`
- `SkillScanning`
- `SkillInjectionHook`
- `SkillCreationError`
- `SkillChatToolbarObserver`
- `SkillSettingsObserver`
- `SkillCreationService`
- `SkillRuntime`
- `CreateSkillTool`
- `DeleteSkillTool`
- `ListSkillsTool`
- `ReadSkillTool`
- `SkillToolSupport`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CreateSkillTool**（12 条）：由 `createsScannableSkill`、`keepsExistingH1WithoutDuplicatingTitle`、`makeSkillMarkdownEdgeCases`、`normalizesName`、`rejectsDuplicateSkill`、`writesIntoConversationProject` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（12 条）：由 `promptBuilder`、`mergePolicy`、`serviceMergesBuiltin`、`settingsAvailableCountDeduplicatesOverriddenBaseSkills` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SkillCRUDTools**（18 条）：由 `listReturnsProjectSkills`、`listIncludesContentOnDemand`、`listMergesBuiltinBase` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SkillCRUD 与扫描器一致性**（6 条）：由 `readFallsBackToValidLegacySkill`、`oversizedMetadataIsRejected` 等用例锁定；改动 Skill 读写的有效性判定或大小约束时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CreateSkillTool | 创建后写入 metadata.json + SKILL.md，并被扫描器识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createsScannableSkill` |
| 2 | CreateSkillTool | 技能名自动规范化为 kebab-case，title 缺省回落为 name | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizesName` |
| 3 | CreateSkillTool | 同名技能已存在时报错，不覆盖原文件 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsDuplicateSkill` |
| 4 | CreateSkillTool | 缺少 name 或 description 时抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsMissingRequiredArguments` |
| 5 | CreateSkillTool | 正文自带 frontmatter 时原样写入，不重复包装 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `keepsProvidedFrontmatter` |
| 6 | CreateSkillTool | 正文已带一级标题时不再追加 title，只保留一个 H1 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsExistingH1WithoutDuplicatingTitle` |
| 7 | CreateSkillTool | makeSkillMarkdown 边界情况：空白、空正文、无空格 #、多个 H1 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `makeSkillMarkdownEdgeCases` |
| 8 | CreateSkillTool | 创建后使技能缓存失效，新技能立即可见 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidatesCacheAfterCreation` |
| 9 | CreateSkillTool | project_path 回退到当前项目；无当前项目时抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectPathFallback` |
| 10 | CreateSkillTool | 风险等级为 medium，展示描述包含技能名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `metadata` |
| 11 | 综合 | PromptBuilder 构造技能列表 prompt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `promptBuilder` |
| 12 | 综合 | SkillMergePolicy 合并内置与项目技能，同名项目优先 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mergePolicy` |
| 13 | 综合 | SkillService 合并底座与项目技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `serviceMergesBuiltin` |
| 14 | 综合 | SkillService 空项目路径时仅返回底座 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `serviceEmptyProjectPath` |
| 15 | 综合 | SkillService 扫描并缓存 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `serviceScansAndCaches` |
| 16 | 综合 | 插件 onBoot 注册设置入口与工具栏且不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginLifecycle` |
| 17 | 综合 | SkillSettingsViewModel 加载选中项目的技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsViewModelLoadsProjectSkills` |
| 18 | 综合 | SkillSettingsViewModel 无选中项目时清空技能 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `settingsViewModelEmptyWithoutProject` |
| 19 | 综合 | SkillSettingsObserver 同步项目列表与技能底座 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsObserverSyncsProjectsAndBase` |
| 20 | 综合 | 当前项目和技能贡献变化会更新工具栏 ViewModel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarObserverUpdatesViewModel` |
| 21 | 综合 | 可用技能总数按合并规则去重，同名项目技能覆盖底座 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsAvailableCountDeduplicatesOverriddenBaseSkills` |
| 22 | 综合 | 无同名技能时可用技能总数为两组之和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsAvailableCountSumsDistinctSkills` |
| 23 | SkillCRUDTools | list_skills 列出项目技能并标记来源 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listReturnsProjectSkills` |
| 24 | SkillCRUDTools | list_skills 传 include_content 时返回正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listIncludesContentOnDemand` |
| 25 | SkillCRUDTools | list_skills 混合内置底座并按名称排序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listMergesBuiltinBase` |
| 26 | SkillCRUDTools | list_skills limit 截断结果 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listRespectsLimit` |
| 27 | SkillCRUDTools | list_skills 无项目且无底座时返回提示文案而非 JSON | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `listEmptyProjectReturnsHint` |
| 28 | SkillCRUDTools | read_skill 返回元数据与正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readReturnsMetadataAndBody` |
| 29 | SkillCRUDTools | read_skill 技能不存在时抛 notFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readMissingSkillThrows` |
| 30 | SkillCRUDTools | update_skill 只改指定字段，其余保持原值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updatePreservesUntouchedFields` |
| 31 | SkillCRUDTools | update_skill 传空数组清空 triggers，未传则保留 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateTriggersClearSemantics` |
| 32 | SkillCRUDTools | update_skill 替换正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateReplacesBody` |
| 33 | SkillCRUDTools | update_skill 未传任何可改字段时抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateRequiresAField` |
| 34 | SkillCRUDTools | update_skill 技能不存在时抛 notFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateMissingSkillThrows` |
| 35 | SkillCRUDTools | delete_skill 移除技能目录，扫描器不再返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteRemovesSkill` |
| 36 | SkillCRUDTools | delete_skill 技能不存在时抛 notFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteMissingSkillThrows` |
| 37 | SkillCRUDTools | 创建 → 列出 → 读取 → 更新 → 删除 全链路 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullCrudLifecycle` |
| 38 | SkillCRUDTools | delete_skill 拒绝规范化后为空的 name，不会删掉整个 skills 目录 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `deleteRejectsEmptyNormalizedName` |
| 39 | SkillCRUDTools | SkillToolSupport 参数解析边界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `supportParsers` |
| 40 | SkillCRUDTools | SkillToolSupport 无当前项目且未传路径时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `supportProjectPathNil` |
| 41 | SkillCRUD 与扫描器一致性 | 残缺的 .lumi 条目不会让 read_skill 找不到历史技能 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readFallsBackToValidLegacySkill` |
| 42 | SkillCRUD 与扫描器一致性 | 残缺的 .lumi 条目不会让 update_skill 失败 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `updateFallsBackToValidLegacySkill` |
| 43 | SkillCRUD 与扫描器一致性 | 只有残缺条目时读取返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readReturnsNilWhenOnlyBrokenSkillExists` |
| 44 | SkillCRUD 与扫描器一致性 | 超出扫描器上限的元数据被拒绝写入 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oversizedMetadataIsRejected` |
| 45 | SkillCRUD 与扫描器一致性 | 更新到超限元数据被拒绝，不会让技能从列表消失 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oversizedUpdateIsRejected` |
| 46 | SkillCRUD 与扫描器一致性 | 正常大小的元数据可以正常创建并被扫描到 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalMetadataIsAccepted` |

| 47 | SkillCRUDTools | 创建时拒绝与历史目录同名的技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createRejectsNameExistingInLegacyDirectory` |
| 48 | SkillCRUDTools | 读取工具能读到历史目录中的技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readToolReadsLegacyAgentDirectory` |
| 49 | SkillCRUDTools | 删除工具删掉历史目录中的技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteToolRemovesLegacyAgentDirectory` |
| 50 | SkillCRUDTools | 扫描器同时读取两个目录的技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scannerMergesBothDirectories` |
| 51 | SkillSettingsLayout | 插件设置 scaffold 会吃掉垂直空间 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginSettingsScaffoldEatsVerticalSpace` |

| 52 | SkillCRUDTools | 扫描器能读到历史目录中的技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scannerReadsLegacyAgentDirectory` |
| 53 | SkillCRUDTools | 更新工具在历史目录原位更新技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateToolEditsLegacyAgentDirectoryInPlace` |
| 54 | SkillSettingsLayout | 技能页面不增加垂直留白 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skillPageAddsNoVerticalSlack` |
| 55 | CreateSkillTool | 未传 project_path 时写入会话绑定项目 | 会话绑定项目 A，UI 当前为 B | 调用 `executeResult(context:arguments:)` | 技能目录创建在 A，B 无新目录 | P1 | ✅ 已覆盖 | `writesIntoConversationProject` |
| 56 | CreateSkillTool | 显式 project_path 优先于会话绑定项目 | 会话绑定 A，显式传 B | 调用 `executeResult(context:arguments:)` | 技能目录创建在 B，A 无新目录 | P1 | ✅ 已覆盖 | `explicitPathBeatsConversationProject` |

> 说明：全部 **56 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 40 / 40
- P2: 已覆盖 6 / 6
- **合计: 56 / 56**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（40 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 56 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginSkill
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
