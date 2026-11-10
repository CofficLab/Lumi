# TestPlan — PluginChatPanel

## 包概述

PluginChatPanel 的实现包，包含 2 个主要类型；当前测试覆盖 7 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 10

核心组件（源码目录）:
- `Observers/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `FileRailActiveTabStore`
- `ChatPanelRailObserver`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ChatPanelPlugin**（7 条）：由 `chatActivationTogglesRootContentVisibility`、`chatRestoresLastActiveRailTab`、`chatActivationInjectsAndShowsRailView` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ChatPanelPlugin | 激活 Chat 时隐藏 RootView 内容，切换入口时恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatActivationTogglesRootContentVisibility` |
| 2 | ChatPanelPlugin | Chat 激活时恢复上次保存的 Rail active tab | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatRestoresLastActiveRailTab` |
| 3 | ChatPanelPlugin | Chat 激活时 Rail 视图已注入且可见 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatActivationInjectsAndShowsRailView` |
| 4 | ChatPanelPlugin | 无任何可见 Rail tab 的全新安装态下，Chat 仍保持 Rail 可见 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatKeepsRailVisibleWhenHostBindsWithoutVisibleTabs` |
| 5 | ChatPanelPlugin | Chat 激活期间 Rail 可见类别被清空时仍保持 Rail 可见 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `chatKeepsRailVisibleWhenVisibleCategoriesEmpty` |
| 6 | ChatPanelPlugin | 切到其它入口再切回 Chat 时 Rail 恢复可见 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `railRestoresWhenReactivatingChat` |
| 7 | ChatPanelPlugin | Chat 在 tab 延迟注册后仍恢复保存的 Rail active tab | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatRestoresTabRegisteredAfterReady` |
| 8 | Rail 偏好恢复 | 切回 Chat 时恢复离开前选择的 Chats，不被临时回退项覆盖（**回归 #887**） | 已注册 Explorer（`.fileTree`）与 Chats（`.chat`），用户选中 Chats | 切到其它插件收窄分类，再切回 Chat | 选中的是 Chats，不是回退项 Explorer | P0 | ✅ 已覆盖 | `reactivatingChatRestoresChatsNotFallbackTab` |
| 9 | Rail 偏好恢复 | 可见分类切换产生的临时回退项不得写入偏好存储（**回归 #887**） | 同上 | 同上 | 偏好存储里是 Chats，不是 Explorer | P0 | ✅ 已覆盖 | `fallbackTabIsNotPersisted` |
| 10 | Rail 偏好恢复 | 恢复后偏好仍然指向用户选择的标签（**回归 #887 护栏**） | 同上 | 反复切走切回两次 | 稳定恢复 Chats，不来回漂移 | P0 | ✅ 已覆盖 | `preferenceRemainsUserSelectionAfterRestore` |

> 说明：全部 **10 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 6 / 6
- P2: 已覆盖 1 / 1
- **合计: 10 / 10**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（6 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 10 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginChatPanel
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
