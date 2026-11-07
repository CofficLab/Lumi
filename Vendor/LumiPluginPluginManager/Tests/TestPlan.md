# TestPlan — PluginPluginManager

## 包概述

PluginPluginManager 的实现包，包含 14 个主要类型；当前测试覆盖 7 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 7

核心组件（源码目录）:
- `Capabilities/`
- `Models/`
- `Observers/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `PluginPluginManager`
- `PluginManagementCapability`
- `PluginManagementFilter`
- `PluginPluginManagerText`
- `PluginManagementObserver`
- `PluginManagementItem`
- `PluginDefaultAboutView`
- `PluginEnableControl`
- `PluginListRow`
- `PluginManagementHeader`
- `PluginManagementView`
- `PluginManagerAboutView`
- `PluginManagerManualView`
- `PluginSettingsDetailView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（7 条）：由 `viewModelRefreshesPluginsRegisteredAfterInitialSnapshot`、`statusFilterNarrowsPlugins`、`pluginMetadataMatchesLegacy` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | 插件列表刷新时包含稍后注册的插件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `viewModelRefreshesPluginsRegisteredAfterInitialSnapshot` |
| 2 | 综合 | 启用状态筛选按启用与否收窄列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusFilterNarrowsPlugins` |
| 3 | 综合 | pluginMetadataMatchesLegacy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginMetadataMatchesLegacy` |
| 4 | 综合 | onBootRegistersSettingEntryAndShutdownRemoves | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootRegistersSettingEntryAndShutdownRemoves` |
| 5 | 综合 | entryUsesLegacyPresentation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `entryUsesLegacyPresentation` |
| 6 | 综合 | 浏览插件建议指向插件管理设置入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `browseSuggestionTargetsPluginManagementEntry` |
| 7 | 综合 | onBootDegradesGracefullyWithoutSettingsProvider | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `onBootDegradesGracefullyWithoutSettingsProvider` |

> 说明：全部 **7 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 6 / 6
- P2: 已覆盖 0 / 0
- **合计: 7 / 7**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（6 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 7 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd LumiPluginPluginManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
