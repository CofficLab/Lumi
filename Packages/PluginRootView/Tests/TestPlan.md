# TestPlan — PluginRootView

## 包概述

PluginRootView Lumi 的根布局插件。 本包不是公共 `ProviderRootView` Provider。公共协议与默认实现来自远程 `LumiProviders` 包，本包只提供 Lumi 专属的桌面布局、视图装配和 `RootViewPlugin` 生命周期适配。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 26

核心组件（源码目录）:
- `PanelBottom/`
- `Providers/`
- `Support/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `RootTrailingPaneEvent`
- `RootViewPlugin`
- `PanelBottomPlugin`
- `PanelBottomStateStore`
- `LumiRootViewProvider`
- `BadgeOverflowLayout`
- `ContentPlaceholderView`
- `DefaultRootHostView`
- `PanelBottomView`
- `RootMainContentView`
- `RootWelcomeView`
- `WorkbenchSplitView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **PanelBottomSuperPlugin**（2 条）：由 `installsAndUninstallsFooterContainer`、`reusesProviderAcrossKernelRestart` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（24 条）：由 `rootViewPluginManagesProviderLifecycle`、`rootOverlaysRegisterAndRemoveByID`、`rootViewChangesAreObservable` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | PanelBottomSuperPlugin | 注册 PanelBottomProviding 并按入口安装/撤回 footer 容器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installsAndUninstallsFooterContainer` |
| 2 | PanelBottomSuperPlugin | 内核重启复用 provider 实例并恢复容器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reusesProviderAcrossKernelRestart` |
| 3 | 综合 | RootViewPlugin 在生命周期中注册并撤销 RootViewProviding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rootViewPluginManagesProviderLifecycle` |
| 4 | 综合 | 根叠层按顺序注册且可独立撤回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rootOverlaysRegisterAndRemoveByID` |
| 5 | 综合 | 根视图状态变化会发布类型化观察事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rootViewChangesAreObservable` |
| 6 | 综合 | DefaultRootViewProvider 无工具栏时返回根视图 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultProviderReturnsRootViewWithoutToolbar` |
| 7 | 综合 | ChatSection 可见性同步到 trailing pane | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trailingPaneFollowsChatSectionVisibility` |
| 8 | 综合 | Trailing pane 状态变化会发布类型化观察事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trailingPaneChangesAreObservable` |
| 9 | 综合 | 重新绑定 ChatSection 显隐时取消旧观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rebindingTrailingPaneVisibilityCancelsPreviousObserver` |
| 10 | 综合 | ChatSection 宽度绑定到 trailing pane 并转发用户拖拽 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trailingPaneFollowsChatSectionWidthAndForwardsResize` |
| 11 | 综合 | 重新绑定 ChatSection 宽度时取消旧观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rebindingTrailingPaneWidthCancelsPreviousObserver` |
| 12 | 综合 | Rail 可见性绑定到根布局 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `railVisibilityFollowsProvider` |
| 13 | 综合 | 重新绑定 Rail 显隐时取消旧观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rebindingRailVisibilityCancelsPreviousObserver` |
| 14 | 综合 | Rail 宽度绑定并转发用户拖拽回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `railWidthFollowsProviderAndForwardsResize` |
| 15 | 综合 | Content Footer 高度 profile 支持恢复约束并保存拖拽结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentFooterHeightProfileRestoresAndSaves` |
| 16 | 综合 | 没有容器时可通过 trailing pane 渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visibleTrailingPaneCountsAsActiveContentWithoutContainer` |
| 17 | 综合 | 注入工具栏后返回根视图 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultProviderReturnsRootViewWithToolbar` |
| 18 | 综合 | 注入 ActivityBar 后返回根视图 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultProviderReturnsRootViewWithActivityBar` |
| 19 | 综合 | 同时注入工具栏与 ActivityBar 后返回根视图 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultProviderReturnsRootViewWithToolbarAndActivityBar` |
| 20 | 综合 | 同时注入工具栏、ActivityBar、Rail 与内容后返回根视图 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultProviderReturnsRootViewWithAllInjections` |
| 21 | 综合 | RootViewProviding 可作为 any RootViewProviding 使用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerAccessibleThroughProtocol` |
| 22 | 综合 | 自定义实现可被协议访问 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customProviderWorks` |
| 23 | 综合 | Footer 注入后被视为主内容并返回根视图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentFooterCountsAsActiveContent` |
| 24 | 综合 | 重复注入相同类型视图时跳过赋值（不发布类型化事件） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedSameTypeInjectionSkipsPublish` |
| 25 | 综合 | 注入状态变化（nil ↔ 非 nil）时正常更新（发布类型化事件） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueTransitionStillPublishes` |
| 26 | 综合 | 重复注入 nil 时跳过赋值（不发布类型化事件） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedNilInjectionSkipsPublish` |

> 说明：全部 **26 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 19 / 19
- P2: 已覆盖 5 / 5
- **合计: 26 / 26**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（19 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 26 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginRootView
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
