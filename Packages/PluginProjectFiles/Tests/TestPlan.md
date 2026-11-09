# TestPlan — PluginProjectFiles

## 包概述

PluginProjectFiles 的实现包，包含 6 个主要类型；当前测试覆盖 15 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 15

核心组件（源码目录）:
- `Capabilities/`
- `Observers/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ProjectFilesPlugin`
- `ProjectFilesTabState`
- `ProjectFilesTabStripView`
- `ProjectFilesTabViewModel`
- `ProjectFilesProjectCapability`
- `ProjectFilesProjectObserver`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ProjectFilesTabState**（3 条）：由 `projectsOpenFiles`、`emptyState`、`observesMultiplePinnedFiles` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Project Files ViewModel**（6 条）：由 `reloadPicksUpNewFiles`、`activateForwardsToCapability`、`closeClearsCurrentFileWhenNotPinned` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Project Files 插件生命周期**（6 条）：由 `bootHidesHeaderWithoutFiles`、`bootShowsHeaderWithFiles`、`bootFailsWithoutProjectProvider` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ProjectFilesTabState | projects ProjectProviding open files in source order | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectsOpenFiles` |
| 2 | ProjectFilesTabState | empty ProjectProviding state produces no project file tabs | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyState` |
| 3 | ProjectFilesTabState | ProjectFiles tab updates when multiple files are pinned | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observesMultiplePinnedFiles` |
| 4 | Project Files ViewModel | reload 重新读取打开文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reloadPicksUpNewFiles` |
| 5 | Project Files ViewModel | activate 转发给能力层 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activateForwardsToCapability` |
| 6 | Project Files ViewModel | close 关闭文件并清空指向该文件的当前文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `closeClearsCurrentFileWhenNotPinned` |
| 7 | Project Files ViewModel | close 仍在打开列表中的文件时保留当前文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `closeKeepsCurrentFileWhenPinned` |
| 8 | Project Files ViewModel | closeOthers 只关闭其它文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `closeOthersKeepsGivenFile` |
| 9 | Project Files ViewModel | projectIsOpen 跟随当前项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectIsOpenFollowsCurrentProject` |
| 10 | Project Files 插件生命周期 | 启动后注册 content header 且无文件时隐藏 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootHidesHeaderWithoutFiles` |
| 11 | Project Files 插件生命周期 | 有打开文件时显示 content header | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootShowsHeaderWithFiles` |
| 12 | Project Files 插件生命周期 | 缺少项目 Provider 时启动失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootFailsWithoutProjectProvider` |
| 13 | Project Files 插件生命周期 | 缺少根视图 Provider 时启动失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootFailsWithoutRootViewProvider` |
| 14 | Project Files 插件生命周期 | 关闭时清空 content header | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownClearsContentHeader` |
| 15 | Project Files 插件生命周期 | 非文件工作区激活时，恢复打开文件不会重新显示 content header（**回归 #1015**） | Terminal（不保留 header）已激活并隐藏 header，项目中已有打开文件 | 在 Terminal 激活状态下让项目恢复/新增打开文件，触发项目事件 | ProjectFiles 不覆盖工作区决定，content header 保持隐藏 | P0 | ✅ 已覆盖 | `restoringFilesKeepsHeaderHiddenInForeignWorkspace` |

> 说明：全部 **15 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 13 / 13
- P2: 已覆盖 1 / 1
- **合计: 15 / 15**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（13 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 15 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginProjectFiles
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
