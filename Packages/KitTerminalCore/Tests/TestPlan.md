# TestPlan — KitTerminalCore

## 包概述

KitTerminalCore 可复用的终端会话核心包。封装基于 SwiftTerm 的终端渲染、Shell 集成、主题适配与多标签会话管理。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 19

核心组件（源码目录）:
- `Core/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `KitTerminalCore`
- `KitTerminalCoreLocalization`
- `LumiTerminalView`
- `ShellIntegration`
- `TerminalThemeAdapter`
- `TerminalWorkingDirectory`
- `TerminalSession`
- `TerminalTabsViewModel`
- `TerminalSessionContainerView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（13 条）：由 `shellIntegrationAutoDetect`、`shellDefaultPath`、`themeAdapterDefaultColors` 等用例锁定；改动该模块时优先跑对应测试文件。
- **子进程环境**（#500，6 条）：`ShellIntegration.makeEnvironment` 须在 SwiftTerm 允许列表之上导出所选 shell 的 `SHELL`、继承父进程非空 `ZDOTDIR`（未设置/空串不写入），并保留 base 与 TERM/LANG/PATH；集成脚本 `setupZsh` 须能从环境数组恢复用户原始 `ZDOTDIR` 到 `USER_ZDOTDIR`，不得回退到家目录。由 `TerminalEnvironmentTests` 锁定。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | ShellIntegration autoDetectShell | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellIntegrationAutoDetect` |
| 2 | 综合 | ShellIntegration Shell defaultPath | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `shellDefaultPath` |
| 3 | 综合 | TerminalThemeAdapter defaultColors | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `themeAdapterDefaultColors` |
| 4 | 综合 | TerminalThemeAdapter colors for known themes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `themeAdapterKnownThemes` |
| 5 | 综合 | TerminalThemeAdapter unknown theme falls back to dark defaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `themeAdapterUnknownThemeFallsBack` |
| 6 | 综合 | TerminalTabsViewModel initialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tabsViewModelInit` |
| 7 | 综合 | TerminalSession initialization with theme | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sessionInitWithTheme` |
| 8 | 综合 | 切回较早会话后只有该会话可接收输入（**回归 #1018**） | 已选中较新的会话 | 把选中项切回较早会话，读取两个会话的呈现状态 | 较早会话不透明、可命中测试且 zIndex 更高；较新会话透明、不参与命中测试且 zIndex 更低 | P0 | ✅ 已覆盖 | `onlySelectedSessionIsHitTestable` |
| 9 | 综合 | 无效工作目录不得启动 shell 且保持未连接（**回归 #174**） | 工作目录不存在 | 以缺失目录创建会话并调用 startIfNeeded | 会话保持未连接、不创建进程且暴露 startupError | P0 | ✅ 已覆盖 | `invalidWorkingDirectoryDoesNotStartShell` |
| 10 | 综合 | 不存在的工作目录被拒绝（**回归 #174**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `workingDirectoryValidatorRejectsMissingPath` |
| 11 | 综合 | 普通文件不是目录被拒绝（**回归 #174**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `workingDirectoryValidatorRejectsRegularFile` |
| 12 | 综合 | 无搜索权限的目录被拒绝（**回归 #174**） | 非 root 运行 | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `workingDirectoryValidatorRejectsInaccessibleDirectory` |
| 13 | 综合 | nil/空串/有效目录均通过校验（**回归 #174**） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `workingDirectoryValidatorAcceptsValidInput` |
| 14 | 子进程环境 | 环境导出所选 shell 的 SHELL | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `environmentExportsSelectedShell` |
| 15 | 子进程环境 | 环境继承用户自定义 ZDOTDIR | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `environmentInheritsCustomZdotdir` |
| 16 | 子进程环境 | 父进程未设置 ZDOTDIR 时不写入该项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `environmentOmitsZdotdirWhenUnset` |
| 17 | 子进程环境 | 父进程 ZDOTDIR 为空串时不写入该项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `environmentOmitsZdotdirWhenEmpty` |
| 18 | 子进程环境 | 环境保留 base 与 TERM/LANG/PATH 等基础项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `environmentKeepsBaseAndTermVars` |
| 19 | 子进程环境 | 集成脚本从环境恢复用户 ZDOTDIR 而非回退家目录 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `integrationRecoversCustomZdotdir` |

> 说明：全部 **19 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> 变异验证（#500）：M1 删除 `makeEnvironment` 的 `env.append("SHELL=\(shellPath)")` → `environmentExportsSelectedShell` 转红；M2 删除继承 ZDOTDIR 的 `if let zDotDir …` 整块 → `environmentInheritsCustomZdotdir`、`integrationRecoversCustomZdotdir` 转红（集成回退家目录）；M3 去掉 `!zDotDir.isEmpty` 守卫 → `environmentOmitsZdotdirWhenEmpty` 转红（空串被写入）；M4 将 `var env = base` 改为 `var env: [String] = []` → `environmentKeepsBaseAndTermVars` 转红（base 丢失）。四处变异均单独施加并确认转红后还原，最终 19 条全绿。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 7 / 7
- P2: 已覆盖 4 / 4
- **合计: 19 / 19**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（7 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 19 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitTerminalCore
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」