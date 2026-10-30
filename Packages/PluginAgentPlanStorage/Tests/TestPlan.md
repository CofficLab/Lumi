# TestPlan — PluginAgentPlanStorage

## 包概述

PluginAgentPlanStorage 的实现包，包含 8 个主要类型；当前测试覆盖 30 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 30

核心组件（源码目录）:
- `Services/`
- `Store/`
- `Tools/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AgentPlanStoragePlugin`
- `AgentPlanStorageRuntime`
- `PlanFileInfo`
- `AgentPlanStoragePluginLocalStore`
- `DeletePlanTool`
- `ListPlansTool`
- `ReadPlanTool`
- `WritePlanTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AgentPlanStorageTools**（21 条）：由 `writePlanStoresContent`、`writePlanRequiresArguments`、`readPlanReturnsContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（9 条）：由 `pluginMetadataAndToolNamesAreStable`、`storageSupportsNestedReadWriteListAndDelete`、`storageRejectsTraversalAndAbsolutePaths` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentPlanStorageTools | write_plan 写入文件并返回路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writePlanStoresContent` |
| 2 | AgentPlanStorageTools | write_plan 缺少参数时抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writePlanRequiresArguments` |
| 3 | AgentPlanStorageTools | read_plan 读取已写入内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readPlanReturnsContent` |
| 4 | AgentPlanStorageTools | read_plan 缺少参数或文件不存在时抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readPlanReportsMissingInput` |
| 5 | AgentPlanStorageTools | delete_plan 删除已存在文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deletePlanRemovesFile` |
| 6 | AgentPlanStorageTools | delete_plan 缺少参数时抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deletePlanRequiresFilename` |
| 7 | AgentPlanStorageTools | list_plans 空目录时给出提示与存储信息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `listPlansDescribesEmptyStorage` |
| 8 | AgentPlanStorageTools | list_plans 列出文件名、大小与修改时间 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listPlansDescribesFiles` |
| 9 | AgentPlanStorageTools | 四个工具的名称、风险等级与展示描述稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `toolsExposeStableMetadata` |
| 10 | AgentPlanStorageTools | 写入工具的 schema 声明 filename 与 content 必填 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writeToolSchemaDeclaresRequiredFields` |
| 11 | AgentPlanStorageTools | 未配置时使用默认 30 天 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultsToThirtyDays` |
| 12 | AgentPlanStorageTools | 写入后读回保留天数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripsRetentionDays` |
| 13 | AgentPlanStorageTools | 保留天数被夹取到至少 1 天 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clampsRetentionDaysToAtLeastOne` |
| 14 | AgentPlanStorageTools | 设置文件损坏时回退到默认值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fallsBackToDefaultOnCorruptedFile` |
| 15 | AgentPlanStorageTools | 注入目录后 settingsDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesInjectedDirectory` |
| 16 | AgentPlanStorageTools | 重置后清空注入目录，不再回退到真实数据目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetClearsInjectedDirectory` |
| 17 | AgentPlanStorageTools | 启动后注册四个计划工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootRegistersTools` |
| 18 | AgentPlanStorageTools | 启动时把插件数据目录注入运行时配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootInjectsStorageDirectory` |
| 19 | AgentPlanStorageTools | 缺少存储 Provider 时启动失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootFailsWithoutStorageProvider` |
| 20 | AgentPlanStorageTools | 关闭时移除四个计划工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRemovesTools` |
| 21 | AgentPlanStorageTools | 没有工具管理器时启动仍然成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootSucceedsWithoutToolManager` |
| 22 | 综合 | pluginMetadataAndToolNamesAreStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataAndToolNamesAreStable` |
| 23 | 综合 | storageSupportsNestedReadWriteListAndDelete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storageSupportsNestedReadWriteListAndDelete` |
| 24 | 综合 | storageRejectsTraversalAndAbsolutePaths | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `storageRejectsTraversalAndAbsolutePaths` |
| 25 | 综合 | cleanupRemovesOnlyFilesOlderThanRetention | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cleanupRemovesOnlyFilesOlderThanRetention` |
| 26 | 综合 | readAndDeleteReportMissingOrNonFileTargets | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readAndDeleteReportMissingOrNonFileTargets` |
| 27 | 综合 | emptyOrWhitespaceFilenamesAreInvalid | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyOrWhitespaceFilenamesAreInvalid` |
| 28 | 综合 | listFilesSortsByRecencyAndExcludesDirectories | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listFilesSortsByRecencyAndExcludesDirectories` |
| 29 | 综合 | retentionClampsToAtLeastOneDay | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `retentionClampsToAtLeastOneDay` |
| 30 | 综合 | storageErrorsExposeDescriptionsWithContext | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storageErrorsExposeDescriptionsWithContext` |

> 说明：全部 **30 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 23 / 23
- P2: 已覆盖 4 / 4
- **合计: 30 / 30**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（23 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 30 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAgentPlanStorage
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
