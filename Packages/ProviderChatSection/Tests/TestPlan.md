# TestPlan — ProviderChatSection

## 包概述

ProviderChatSection 的实现包，包含 3 个主要类型；当前测试覆盖 21 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 21

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ChatContext`
- `ChatSectionWidth`
- `DefaultChatSectionProviding`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（17 条）：由 `itemsAreSortedAndReplaced`、`dynamicItemRefreshCoalescesNotifications`、`barItemsAreSorted` 等用例锁定；改动该模块时优先跑对应测试文件。
- **工具栏横向滚动**（4 条）：由 `toolbarKeepsNaturalWidthWhenSpaceIsEnough`、`toolbarDoesNotCompressItemsWhenSpaceIsTight`、`multipleItemsKeepNaturalWidthWhenSpaceIsTight`、`itemsStayVerticallyCentered` 锁定「插件注入的 UI 宽度不足时不被压缩，而是横向滚动查看」；改动 `ChatToolbarRow` 时优先跑 `ChatToolbarScrollTests.swift`。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | 贡献按 order 排序并支持替换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `itemsAreSortedAndReplaced` |
| 2 | 综合 | 动态 item 刷新合并通知且不改变注册集合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dynamicItemRefreshCoalescesNotifications` |
| 3 | 综合 | Bar contribution 按 order 排序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `barItemsAreSorted` |
| 4 | 综合 | 状态变化会发送语义事件，并支持取消监听 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateChangesNotifyObservers` |
| 5 | 综合 | 贡献作用域只匹配当前聊天上下文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contributionScopeMatchesContext` |
| 6 | 综合 | 可切换当前聊天上下文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activeContextCanChange` |
| 7 | 综合 | 显隐和会话上下文状态可独立切换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visibilityAndContextState` |
| 8 | 综合 | root wrapper 按 order 排序、替换与移除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rootWrappersAreSortedReplacedAndRemoved` |
| 9 | 综合 | header 可见性独立于容器激活状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `headerVisibilityIsIndependent` |
| 10 | 综合 | 绑定会话选择后 header 可见性跟随选中状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bindingConversationSelectionTracksSelectedID` |
| 11 | 综合 | 重新绑定会话选择时取消旧观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rebindingConversationSelectionCancelsPreviousObserver` |
| 12 | 综合 | 首次激活使用推荐宽度，拖拽后按插件 ID 恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `widthProfileRestoresSavedWidth` |
| 13 | 综合 | 没有磁盘值时使用推荐宽度，保存值超出新范围时被限制 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `widthProfileUsesRecommendationAndClampsRestoredValue` |
| 14 | 综合 | 旧插件释放宽度时不会覆盖新插件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleDeactivationDoesNotResetCurrentProfile` |
| 15 | 综合 | clamp pins width to min/max and rejects non-finite | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `widthClampBranches` |
| 16 | 综合 | standard width allows arbitrary large values | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `standardWidthUpperUnbounded` |
| 17 | 综合 | init normalizes invalid bounds | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `initNormalizesBounds` |
| 18 | 工具栏横向滚动 | 宽度富余时工具栏内容按自然宽度左对齐，不被拉伸也不被压缩 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarKeepsNaturalWidthWhenSpaceIsEnough` |
| 19 | 工具栏横向滚动 | 宽度不足时贡献项保持自然宽度，而不是被压缩成容器宽度 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolbarDoesNotCompressItemsWhenSpaceIsTight` |
| 20 | 工具栏横向滚动 | 多个贡献项在窄容器下都保持自然宽度 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `multipleItemsKeepNaturalWidthWhenSpaceIsTight` |
| 21 | 工具栏横向滚动 | 贡献项在工具栏内保持垂直居中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `itemsStayVerticallyCentered` |

> 说明：全部 **21 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 17 / 17
- P2: 已覆盖 0 / 0
- **合计: 21 / 21**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（17 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 21 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderChatSection
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
