# TestPlan — PluginSkill

## 包概述

PluginSkill 的实现包，包含 14 个主要类型；当前测试覆盖 36 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 36

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

- **CreateSkillTool**（8 条）：由 `createsScannableSkill`、`normalizesName`、`rejectsDuplicateSkill` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（10 条）：由 `promptBuilder`、`mergePolicy`、`serviceMergesBuiltin` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SkillCRUDTools**（18 条）：由 `listReturnsProjectSkills`、`listIncludesContentOnDemand`、`listMergesBuiltinBase` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CreateSkillTool | 创建后写入 metadata.json + SKILL.md，并被扫描器识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createsScannableSkill` |
| 2 | CreateSkillTool | 技能名自动规范化为 kebab-case，title 缺省回落为 name | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizesName` |
| 3 | CreateSkillTool | 同名技能已存在时报错，不覆盖原文件 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsDuplicateSkill` |
| 4 | CreateSkillTool | 缺少 name 或 description 时抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsMissingRequiredArguments` |
| 5 | CreateSkillTool | 正文自带 frontmatter 时原样写入，不重复包装 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `keepsProvidedFrontmatter` |
| 6 | CreateSkillTool | 创建后使技能缓存失效，新技能立即可见 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidatesCacheAfterCreation` |
| 7 | CreateSkillTool | project_path 回退到当前项目；无当前项目时抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectPathFallback` |
| 8 | CreateSkillTool | 风险等级为 medium，展示描述包含技能名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `metadata` |
| 9 | 综合 | PromptBuilder 构造技能列表 prompt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `promptBuilder` |
| 10 | 综合 | SkillMergePolicy 合并内置与项目技能，同名项目优先 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mergePolicy` |
| 11 | 综合 | SkillService 合并底座与项目技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `serviceMergesBuiltin` |
| 12 | 综合 | SkillService 空项目路径时仅返回底座 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `serviceEmptyProjectPath` |
| 13 | 综合 | SkillService 扫描并缓存 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `serviceScansAndCaches` |
| 14 | 综合 | 插件 onBoot 注册设置入口与工具栏且不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginLifecycle` |
| 15 | 综合 | SkillSettingsViewModel 加载选中项目的技能 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsViewModelLoadsProjectSkills` |
| 16 | 综合 | SkillSettingsViewModel 无选中项目时清空技能 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `settingsViewModelEmptyWithoutProject` |
| 17 | 综合 | SkillSettingsObserver 同步项目列表与技能底座 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsObserverSyncsProjectsAndBase` |
| 18 | 综合 | 当前项目和技能贡献变化会更新工具栏 ViewModel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarObserverUpdatesViewModel` |
| 19 | SkillCRUDTools | list_skills 列出项目技能并标记来源 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listReturnsProjectSkills` |
| 20 | SkillCRUDTools | list_skills 传 include_content 时返回正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listIncludesContentOnDemand` |
| 21 | SkillCRUDTools | list_skills 混合内置底座并按名称排序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listMergesBuiltinBase` |
| 22 | SkillCRUDTools | list_skills limit 截断结果 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listRespectsLimit` |
| 23 | SkillCRUDTools | list_skills 无项目且无底座时返回提示文案而非 JSON | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `listEmptyProjectReturnsHint` |
| 24 | SkillCRUDTools | read_skill 返回元数据与正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readReturnsMetadataAndBody` |
| 25 | SkillCRUDTools | read_skill 技能不存在时抛 notFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readMissingSkillThrows` |
| 26 | SkillCRUDTools | update_skill 只改指定字段，其余保持原值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updatePreservesUntouchedFields` |
| 27 | SkillCRUDTools | update_skill 传空数组清空 triggers，未传则保留 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateTriggersClearSemantics` |
| 28 | SkillCRUDTools | update_skill 替换正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateReplacesBody` |
| 29 | SkillCRUDTools | update_skill 未传任何可改字段时抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateRequiresAField` |
| 30 | SkillCRUDTools | update_skill 技能不存在时抛 notFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateMissingSkillThrows` |
| 31 | SkillCRUDTools | delete_skill 移除技能目录，扫描器不再返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteRemovesSkill` |
| 32 | SkillCRUDTools | delete_skill 技能不存在时抛 notFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteMissingSkillThrows` |
| 33 | SkillCRUDTools | 创建 → 列出 → 读取 → 更新 → 删除 全链路 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullCrudLifecycle` |
| 34 | SkillCRUDTools | delete_skill 拒绝规范化后为空的 name，不会删掉整个 skills 目录 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `deleteRejectsEmptyNormalizedName` |
| 35 | SkillCRUDTools | SkillToolSupport 参数解析边界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `supportParsers` |
| 36 | SkillCRUDTools | SkillToolSupport 无当前项目且未传路径时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `supportProjectPathNil` |

> 说明：全部 **36 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 25 / 25
- P2: 已覆盖 5 / 5
- **合计: 36 / 36**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（25 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 36 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
