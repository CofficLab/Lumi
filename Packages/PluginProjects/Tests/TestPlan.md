# TestPlan — PluginProjects

## 包概述

PluginProjects 的实现包，包含 14 个主要类型；当前测试覆盖 14 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 14

核心组件（源码目录）:
- `Capabilities/`
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

- `ProjectsPlugin`
- `ProjectRAGStatusCapability`
- `ProjectsProjectCapability`
- `ProjectPathInjectionHook`
- `ProjectEntry`
- `ProjectsStoreError`
- `ConversationProjectSyncObserver`
- `ProjectOpenedFilesPersistence`
- `ProjectProvidingObserver`
- `ProjectRAGStatusObserver`
- `ProjectsLegacyMigration`
- `ProjectsRuntime`
- `ProjectOpenedFiles`
- `AddProjectTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ConversationProjectSyncObserver**（7 条）：由 `selectingConversationWithProjectOpensProject`、`selectingConversationWithoutProjectDoesNotOpen`、`deselectDoesNotOpenProject` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（5 条）：由 `projectsPersistenceRoundTrip`、`openedFilesPersistenceRoundTrip`、`restoresAndPersistsOpenedFilesThroughProjectProviding` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProjectPathInjectionHook**（2 条）：由 `injectsConversationProject`、`skipsUnboundConversation` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationProjectSyncObserver | 创建并选中绑定项目的对话会调用 openProject 切换到该对话的项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectingConversationWithProjectOpensProject` |
| 2 | ConversationProjectSyncObserver | 选中未绑定项目的对话不会打开任何项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectingConversationWithoutProjectDoesNotOpen` |
| 3 | ConversationProjectSyncObserver | 取消选中（nil）不会打开任何项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deselectDoesNotOpenProject` |
| 4 | ConversationProjectSyncObserver | 当前项目已等于对话绑定项目时不重复打开 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `selectingAlreadyBoundProjectDoesNotReopen` |
| 5 | ConversationProjectSyncObserver | 切换选中到已存在的绑定项目对话会打开该项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectingExistingConversationOpensProject` |
| 6 | ConversationProjectSyncObserver | 项目切换尚未完成时快速选择另一对话，最终项目跟随最新选择 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rapidSelectionChangesSynchronizeLatestProject` |
| 7 | ConversationProjectSyncObserver | cancel 后不再响应选中变化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelStopsObserving` |
| 8 | 综合 | projectsPersistenceRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectsPersistenceRoundTrip` |
| 9 | 综合 | openedFilesPersistenceRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openedFilesPersistenceRoundTrip` |
| 10 | 综合 | restoresAndPersistsOpenedFilesThroughProjectProviding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `restoresAndPersistsOpenedFilesThroughProjectProviding` |
| 11 | 综合 | addProjectValidatesDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addProjectValidatesDirectory` |
| 12 | 综合 | storageDirectoryUsesPluginID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storageDirectoryUsesPluginID` |
| 13 | ProjectPathInjectionHook | injects the conversation project instead of the currently open project | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `injectsConversationProject` |
| 14 | ProjectPathInjectionHook | does not inject when the conversation has no project | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsUnboundConversation` |

> 说明：全部 **14 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 13 / 13
- P2: 已覆盖 0 / 0
- **合计: 14 / 14**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（13 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 14 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginProjects
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
