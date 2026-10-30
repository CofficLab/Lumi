# TestPlan — KitTerminalCore

## 包概述

KitTerminalCore 可复用的终端会话核心包。封装基于 SwiftTerm 的终端渲染、Shell 集成、主题适配与多标签会话管理。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 7

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
- `TerminalSession`
- `TerminalTabsViewModel`
- `TerminalSessionContainerView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（7 条）：由 `shellIntegrationAutoDetect`、`shellDefaultPath`、`themeAdapterDefaultColors` 等用例锁定；改动该模块时优先跑对应测试文件。

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

> 说明：全部 **7 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 4 / 4
- P2: 已覆盖 3 / 3
- **合计: 7 / 7**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（4 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 7 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
