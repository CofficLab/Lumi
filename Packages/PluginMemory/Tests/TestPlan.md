# TestPlan — PluginMemory

## 包概述

PluginMemory 的实现包，包含 9 个主要类型；当前测试覆盖 10 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 10

核心组件（源码目录）:
- `Models/`
- `Services/`
- `Support/`
- `Tools/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MemoryPlugin`
- `MemoryType`
- `MemoryFileStorage`
- `DeleteMemoryTool`
- `ListMemoriesTool`
- `MemoryToolSupport`
- `RecallMemoryTool`
- `SaveMemoryTool`
- `MemorySettingsView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（7 条）：由 `saveAndLoad`、`saveUpdatesPreservesCreatedAt`、`listAndDelete` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DeleteMemoryTool（不存在目标）**（3 条）：由 `deletingMissingMemoryThrows`、`secondDeleteOfSameIDThrows`、`storageDeleteMissingThrowsNotFound` 锁定。删除不存在的记忆必须抛出工具错误，不得返回 `Memory Deleted` 成功文案；存储层对缺失文件抛 `MemoryError.notFound`，重复删除同一 ID 第二次必须失败（**回归 #809**）。改动 `delete_memory` 或 `MemoryFileStorage.delete` 时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | 存储保存并读取记忆 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveAndLoad` |
| 2 | 综合 | 存储更新保留 createdAt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveUpdatesPreservesCreatedAt` |
| 3 | 综合 | 存储列出与删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listAndDelete` |
| 4 | 综合 | SaveMemoryTool 保存并返回成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `saveTool` |
| 5 | 综合 | RecallMemoryTool 未找到返回提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recallToolNotFound` |
| 6 | 综合 | 插件注册 4 个记忆工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersTools` |
| 7 | 综合 | 不同 ID 编码后不碰撞：保存、召回、删除互不影响 | 空存储 | 依次保存 `a b`、`a@b`、`a%20b` 后召回/列出/删除 | 三条记录各自独立，删除 `a b` 不影响其余 | P0 | ✅ 已覆盖 | `distinctIDsDoNotCollide` |
| 8 | DeleteMemoryTool | 删除不存在的记忆必须抛出错误而非报成功（**回归 #809**） | 空存储，ID `definitely-missing` 不存在 | 调用 `delete_memory(id, scope=global)` | 抛出 `ToolExecutionError`，不返回成功文案 | P0 | ✅ 已覆盖 | `deletingMissingMemoryThrows` |
| 9 | DeleteMemoryTool | 重复删除同一 ID：首次成功，第二次必须报错（**回归 #809**） | 已保存 ID `once` | 连续两次调用 `delete_memory` | 首次成功且文件被删，第二次抛出 `ToolExecutionError` | P0 | ✅ 已覆盖 | `secondDeleteOfSameIDThrows` |
| 10 | DeleteMemoryTool | 存储层删除不存在的记忆抛出 notFound | 空存储 | 调用 `storage.delete(id: "ghost")` | 抛出 `MemoryError.notFound("ghost")` | P1 | ✅ 已覆盖 | `storageDeleteMissingThrowsNotFound` |

> 说明：全部 **10 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 7 / 7
- P2: 已覆盖 0 / 0
- **合计: 10 / 10**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（7 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 10 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMemory
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
