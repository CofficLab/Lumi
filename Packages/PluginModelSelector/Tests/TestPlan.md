# TestPlan — PluginModelSelector

## 包概述

PluginModelSelector Model Selector 插件（KernelCore 体系），由旧版 `Plugins/ModelSelectorPlugin` （KernelLumi / LumiPlugin 架构）完美复刻而来。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 15

核心组件（源码目录）:
- `Capabilities/`
- `Observers/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ModelSelectorPlugin`
- `ProviderUsageRecord`
- `ModelSelectionCapability`
- `LLMProviderManagerBox`
- `ModelSelectorViewModel`
- `ActionBarButton`
- `ModelListItem`
- `ModelCategory`
- `PopoverContent`
- `ProviderListItem`
- `ProviderScope`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ModelListViewRender**（3 条）：由 `visibleModelsFollowSnapshot`、`remoteModelsCarryMetadata`、`fallsBackToStaticCatalog` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（12 条）：由 `classifiesViaMetadata`、`classifiesViaHeuristics`、`missingMetadataFallsBackToLanguage` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ModelListViewRender | 刷新后 box 快照与渲染管线同步更新，无需重开 popover | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visibleModelsFollowSnapshot` |
| 2 | ModelListViewRender | 远程新增模型带元数据进入 UI，不被分类筛选误过滤 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteModelsCarryMetadata` |
| 3 | ModelListViewRender | 静态清单兜底：远程为空时仍为 6 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToStaticCatalog` |
| 4 | 综合 | Classifies language, vision and tool models via metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesViaMetadata` |
| 5 | 综合 | Classifies audio and image models via id heuristics | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesViaHeuristics` |
| 6 | 综合 | Missing metadata falls back to id-only classification | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingMetadataFallsBackToLanguage` |
| 7 | 综合 | Cloud and local scopes use provider metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filtersUsingIsLocal` |
| 8 | 综合 | Persists approximate provider usage and ranks by count | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistsAndRanksUsage` |
| 9 | 综合 | Hides search bar while the selected provider has few models | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hidesSearchBarForFewModels` |
| 10 | 综合 | Shows search bar once models exceed the threshold | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `showsSearchBarForManyModels` |
| 11 | 综合 | No provider selected means no search bar | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noProviderHidesSearchBar` |
| 12 | 综合 | Keeps legacy plugin id, order and policy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `identityAndPolicy` |
| 13 | 综合 | 选中对话时写入对话模型，不覆盖全局模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionWithConversationUpdatesConversation` |
| 14 | 综合 | 没有选中对话时写入全局模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionWithoutConversationUpdatesGlobal` |
| 15 | 综合 | Refreshes its snapshot through typed events | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshesSnapshotThroughTypedEvents` |

> 说明：全部 **15 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 14 / 14
- P2: 已覆盖 0 / 0
- **合计: 15 / 15**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（14 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 15 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginModelSelector
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
