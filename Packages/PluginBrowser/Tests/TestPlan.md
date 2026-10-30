# TestPlan — PluginBrowser

## 包概述

PluginBrowser Lumi's browser capability plugin: an integrated WebKit workspace and the official Chrome DevTools MCP server for controlling Chrome.

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 5

核心组件（源码目录）:
- `Services/`
- `Tools/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `BrowserPlugin`
- `BrowserSession`
- `BrowserWebView`
- `BrowserWorkspaceView`
- `BrowserInteractTool`
- `BrowserOpenTool`
- `BrowserReadTool`
- `BrowserStatusTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **BrowserPlugin**（5 条）：由 `browserManagesRailLifecycle`、`browserSuppressesContentHeaderWhileActive`、`browserRestoresHiddenContentHeaderOnDeactivate` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | BrowserPlugin | Browser 激活和关闭时管理 Rail 生命周期 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `browserManagesRailLifecycle` |
| 2 | BrowserPlugin | Browser 激活期间持续压制 content header，退出时还原激活前的值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `browserSuppressesContentHeaderWhileActive` |
| 3 | BrowserPlugin | Browser 退出时不强行显示本该隐藏的 content header | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `browserRestoresHiddenContentHeaderOnDeactivate` |
| 4 | BrowserPlugin | plugin metadata is stable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadata` |
| 5 | BrowserPlugin | 新用户安装后 Browser 插件默认不启动，ActivityBar 不出现浏览器图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `disabledByDefaultSkipsActivityBarItem` |

> 说明：全部 **5 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 3 / 3
- P2: 已覆盖 2 / 2
- **合计: 5 / 5**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（3 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 5 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginBrowser
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
