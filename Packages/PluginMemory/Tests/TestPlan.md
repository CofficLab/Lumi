# TestPlan — PluginMemory

## 包概述

PluginMemory 的实现包，包含 9 个主要类型；当前测试覆盖 18 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 18

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
- **MemoryID 路径穿越防护**（6 条）：由 `fileNameEncodesPathSeparators`、`saveTraversalIDGlobalStaysWithinRoot`、`backslashAndAbsoluteIDStayWithinRoot` 等用例锁定。`fileName(forID:)` 的允许字符集为 `alphanumerics ∪ {-_.}`，`/`、`\` 等一律百分号编码为单一路径分量；含 `../`、反斜杠、绝对路径或纯点号的 id 经 save/load/delete 后，文件标准化路径必须仍落在 Memory 根目录内，不得逃出（**回归 #198**）。改动 `fileName(forID:)`、`allowedIDCharacters` 或存储路径拼接时优先跑对应测试文件。
- **Project 路径碰撞防护**（2 条）：由 `distinctProjectPathsDoNotCollide`、`projectPathPercentLiteralDoesNotCollide` 锁定。`sanitizeProjectPath` 必须把 project 路径一一映射为目录名（允许字符 `alphanumerics ∪ {-_./}` 原样保留，其余按 UTF-8 百分号编码，`%` 自身编码为 `%25`）；`/tmp/a b` 与 `/tmp/a-b`、以及字面量 `/tmp/a%20b` 不得共用同一记忆目录，保存/召回/列出/删除互不影响（**回归 #197**）。改动 `sanitizeProjectPath` 或 `projectsDirectory(for:)` 时优先跑对应测试文件。

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
| 11 | ID 穿越防护 | 穿越 id 的文件名编码不得保留真实路径分隔符（**回归 #198**） | — | 调用 `fileName(forID: "../../../outside")` | 结果不含 `/` 与反斜杠，等于 `..%2F..%2F..%2Foutside` | P0 | ✅ 已覆盖 | `fileNameEncodesPathSeparators` |
| 12 | ID 穿越防护 | project 作用域 save 穿越 id 必须落在 Memory 根目录内（**回归 #198**） | 空存储 | save(id 含 `../`, scope=project) | 文件标准化路径仍在根目录内且存在 | P0 | ✅ 已覆盖 | `saveTraversalIDProjectStaysWithinRoot` |
| 13 | ID 穿越防护 | global 作用域 save 穿越 id 必须落在 Memory 根目录内（**回归 #198**） | 空存储 | save(id 含 `../`, scope=global) | 文件标准化路径仍在根目录内且存在 | P0 | ✅ 已覆盖 | `saveTraversalIDGlobalStaysWithinRoot` |
| 14 | ID 穿越防护 | 反斜杠与绝对路径 id 不得逃出 Memory 根目录（**回归 #198**） | 空存储 | save 反斜杠穿越 id 与绝对路径 id `/etc/passwd` | 两者文件均在根目录内，编码不含分隔符 | P0 | ✅ 已覆盖 | `backslashAndAbsoluteIDStayWithinRoot` |
| 15 | ID 穿越防护 | 纯点号 id 不得逃出 Memory 根目录（**回归 #198**） | 空存储 | save(id: "..") 与 save(id: ".") | 两者文件均在根目录内 | P0 | ✅ 已覆盖 | `dotOnlyIDStaysWithinRoot` |
| 16 | ID 穿越防护 | load/delete 穿越 id 仅命中根目录内文件，不触及外部（**回归 #198**） | 已保存穿越 id | load 后 delete 同一 id | 召回内容一致，删除仅移除根目录内文件 | P1 | ✅ 已覆盖 | `loadAndDeleteTraversalIDStayContained` |
| 17 | Project 路径碰撞 | 不同 project 路径编码后不碰撞：保存、召回、删除互不影响（**回归 #197**） | 空存储 | 以 `/tmp/a b` 与 `/tmp/a-b` 各保存 id `architecture` 后召回/列出/删除 | 两条记录目录不同，删除 `/tmp/a b` 不影响 `/tmp/a-b` | P0 | ✅ 已覆盖 | `distinctProjectPathsDoNotCollide` |
| 18 | Project 路径碰撞 | project 路径中的字面量百分号不与编码结果碰撞（**回归 #197**） | 空存储 | 以 `/tmp/a b` 与字面量 `/tmp/a%20b` 各保存 id `architecture` 后召回 | 两条记录目录不同，内容各自独立 | P0 | ✅ 已覆盖 | `projectPathPercentLiteralDoesNotCollide` |

> 说明：全部 **18 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 8 / 8
- P2: 已覆盖 0 / 0
- **合计: 18 / 18**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（8 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 18 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
