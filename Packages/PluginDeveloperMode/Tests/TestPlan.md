# TestPlan — PluginDeveloperMode

## 包概述

PluginDeveloperMode 的实现包，包含 6 个主要类型；当前测试覆盖 14 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 14

核心组件（源码目录）:
- `Capabilities/`
- `Observers/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DeveloperModePlugin`
- `DeveloperModeCapability`
- `DeveloperModeObserver`
- `DeveloperModeViewModel`
- `DebugBadgeView`
- `DeveloperModeToggleView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DeveloperModePlugin**（2 条）：由 `bootRegistersProviderAndToolbarItem`、`toolbarToggleUpdatesProvider` 等用例锁定；改动该模块时优先跑对应测试文件。
- **开发者模式 ViewModel**（3 条）：由 `startsDisabled`、`updateAppliesExternalState`、`toggleForwardsToCapability` 等用例锁定；改动该模块时优先跑对应测试文件。
- **开发者模式 Observer**（3 条）：由 `syncsInitialState`、`appliesEnabledChangedEvent`、`cancelStopsUpdates` 等用例锁定；改动该模块时优先跑对应测试文件。
- **开发者模式能力适配器**（3 条）：由 `forwardsToProvider`、`treatsReleasedProviderAsDisabled`、`forwardsObserverSubscription` 等用例锁定；改动该模块时优先跑对应测试文件。
- **开发者模式插件生命周期**（3 条）：由 `bootWithoutProviderIsNoop`、`bootWithoutToolbarIsNoop`、`shutdownRemovesToolbarItems` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DeveloperModePlugin | registers the provider and a leading toolbar toggle | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootRegistersProviderAndToolbarItem` |
| 2 | DeveloperModePlugin | toolbar toggle updates the kernel provider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarToggleUpdatesProvider` |
| 3 | 开发者模式 ViewModel | 初始状态为关闭 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startsDisabled` |
| 4 | 开发者模式 ViewModel | update 写入外部状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateAppliesExternalState` |
| 5 | 开发者模式 ViewModel | toggle 转发给能力层 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toggleForwardsToCapability` |
| 6 | 开发者模式 Observer | 初始化时同步能力层当前状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `syncsInitialState` |
| 7 | 开发者模式 Observer | 收到 enabledChanged 事件后更新 ViewModel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appliesEnabledChangedEvent` |
| 8 | 开发者模式 Observer | 取消后释放订阅并停止更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelStopsUpdates` |
| 9 | 开发者模式能力适配器 | 转发启用状态与切换动作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forwardsToProvider` |
| 10 | 开发者模式能力适配器 | Provider 释放后按关闭处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `treatsReleasedProviderAsDisabled` |
| 11 | 开发者模式能力适配器 | 观察者订阅透传到 Provider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forwardsObserverSubscription` |
| 12 | 开发者模式插件生命周期 | 缺少开发者模式 Provider 时不注册工具栏项也不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutProviderIsNoop` |
| 13 | 开发者模式插件生命周期 | 缺少工具栏 Provider 时启动不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutToolbarIsNoop` |
| 14 | 开发者模式插件生命周期 | 关闭时移除工具栏项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRemovesToolbarItems` |

> 说明：全部 **14 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 14 / 14
- P2: 已覆盖 0 / 0
- **合计: 14 / 14**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（14 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 14 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginDeveloperMode
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
