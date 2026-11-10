# TestPlan — PluginTextActions

## 包概述

PluginTextActions 的实现包，包含 12 个主要类型；当前测试覆盖 102 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 102

核心组件（源码目录）:
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `TextSelectionReadPolicy`
- `TextActionCoordinates`
- `TextActionMenuLayout`
- `TextActionDismissPolicy`
- `TextActionsManualView`
- `TextActionsPlugin`
- `TextActionsPluginLocalStore`
- `TextActionsRuntime`
- `TextActionsSettings`
- `TextSelectionManager`
- `TextActionMenuController`
- `TextActionMenuPanel`
- `TextActionsAboutView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **TextActionsPlugin**（16 条）：由 `pluginMetadata`、`localStorePersistsEnabledFlagInBinaryPlist`、`localStoreWritesNoUserDefaults` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TextActionsCore**（31 条）：由 `doesNotPresentMenuForBlankText`、`presentsMenuForRealText`、`retryConstants`、`selectionRectWinsOverMouseAnchor` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TextActionsPluginLifecycle**（11 条）：由 `registerAddsDocsEntries`、`registerWithoutDocsProviderIsNoop`、`bootInjectsStorageDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TextActionsStorage**（10 条）：由 `usesConfiguredDirectory`、`resetsToFallbackDirectory`、`roundTripsValue` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TextActionMenuPanel**（13 条）：由 `initialStateIsActions`、`performForwardsToHandler`、`stateChangeNotifies` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TextSelectionSuppression**（7 条）：键盘消失后的一次性抑制语义——只压制让菜单消失的那一次按键随后的同文本 keyUp（命中即消费），键码变化或选区清空立即解除；改动该逻辑时优先跑对应测试文件（issue #1058）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | TextActionsPlugin | pluginMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginMetadata` |
| 2 | TextActionsPlugin | localStorePersistsEnabledFlagInBinaryPlist | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localStorePersistsEnabledFlagInBinaryPlist` |
| 3 | TextActionsPlugin | localStoreWritesNoUserDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `localStoreWritesNoUserDefaults` |
| 4 | TextActionsPlugin | textActionCatalogIsComplete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textActionCatalogIsComplete` |
| 5 | TextActionsPlugin | searchURLEncodesQueryItems | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchURLEncodesQueryItems` |
| 6 | TextActionsPlugin | translationRequestUsesSelectedTextAndTranslationInstruction | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `translationRequestUsesSelectedTextAndTranslationInstruction` |
| 7 | TextActionsPlugin | v2TranslationRequestPreservesPromptAndText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2TranslationRequestPreservesPromptAndText` |
| 8 | TextActionsPlugin | v2PluginPreservesIdentityAndOptInPolicy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2PluginPreservesIdentityAndOptInPolicy` |
| 9 | TextActionsPlugin | copyActionWritesToPasteboard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copyActionWritesToPasteboard` |
| 10 | TextActionsPlugin | emptySelectionDoesNotPresentMenu | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptySelectionDoesNotPresentMenu` |
| 11 | TextActionsPlugin | nonEmptySelectionPresentsMenu | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonEmptySelectionPresentsMenu` |
| 12 | TextActionsPlugin | menuLayoutClampsToScreenEdges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `menuLayoutClampsToScreenEdges` |
| 13 | TextActionsPlugin | selectionManagerStartsOnlyOnceAndStopsMonitoring | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionManagerStartsOnlyOnceAndStopsMonitoring` |
| 14 | TextActionsPlugin | selectionManagerDoesNotMonitorWithoutAccessibilityPermission | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionManagerDoesNotMonitorWithoutAccessibilityPermission` |
| 15 | TextActionsPlugin | selectionManagerCanStartAfterPermissionIsGranted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionManagerCanStartAfterPermissionIsGranted` |
| 16 | TextActionsPlugin | selectedTextProviderCanSimulateAXRetrySequence | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `selectedTextProviderCanSimulateAXRetrySequence` |
| 17 | TextActionsCore | 空白与空选区不弹菜单 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotPresentMenuForBlankText` |
| 18 | TextActionsCore | 有内容的选区弹菜单 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `presentsMenuForRealText` |
| 19 | TextActionsCore | 重试节奏常量固定 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryConstants` |
| 20 | TextActionsCore | Quartz 左上原点翻转为 Cocoa 左下原点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `flipsVerticalOrigin` |
| 21 | TextActionsCore | 多屏下主屏左侧的负坐标保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsNegativeCoordinates` |
| 22 | TextActionsCore | 菜单显示在选区上方居中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `placesAboveSelectionCentered` |
| 23 | TextActionsCore | 上方空间不足时放到选区下方 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBelowWhenNoRoomAbove` |
| 24 | TextActionsCore | 选区靠左时夹到屏幕左边距 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clampsToLeftEdge` |
| 25 | TextActionsCore | 选区靠右时夹到屏幕右边距 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clampsToRightEdge` |
| 26 | TextActionsCore | 无选区 bounds 时回退到锚点上方 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToAnchor` |
| 27 | TextActionsCore | 上下都放不下时夹回屏幕内 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clampsVerticallyWhenNeitherSideFits` |
| 28 | TextActionsCore | 自定义边距与间距生效 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `respectsCustomMarginAndGap` |
| 29 | TextActionsCore | 普通按键与快捷键让菜单消失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keyDownDismisses` |
| 30 | TextActionsCore | 仅 Shift 的组合不消失——正在调整选区 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `shiftOnlyDoesNotDismiss` |
| 31 | TextActionsCore | 菜单不可见时只有带修饰键的 keyUp 触发重读 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keyUpEvaluationGating` |
| 32 | TextActionsCore | 滚动阈值固定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `scrollThresholdIsStable` |
| 33 | TextActionsCore | 三个动作可枚举且标识稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `actionsAreCaseIterable` |
| 34 | TextActionsCore | 每个动作有标题与图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `actionsHaveTitlesAndIcons` |
| 35 | TextActionsCore | 搜索地址用百分号编码查询词 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsSearchURL` |
| 36 | TextActionsCore | 翻译请求带固定的 system 指令与原文 user 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsTranslationRequest` |
| 37 | TextActionsCore | 旧版翻译请求与新版语义一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyTranslationRequestMatchesV2` |
| 38 | TextActionsCore | 选区结果按值比较 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedTextIsEquatable` |
| 39 | TextActionsCore | 携带选区 bounds 参与比较 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `carriesSelectionRect` |
| 40 | TextActionsPluginLifecycle | 注册时写入关于与说明书文档条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerAddsDocsEntries` |
| 41 | TextActionsPluginLifecycle | 缺少文档 Provider 时注册不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerWithoutDocsProviderIsNoop` |
| 42 | TextActionsPluginLifecycle | 启动时把存储目录注入运行时 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootInjectsStorageDirectory` |
| 43 | TextActionsPluginLifecycle | 缺少存储 Provider 时启动不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutStorageProviderIsNoop` |
| 44 | TextActionsPluginLifecycle | 关闭时移除设置入口并清理观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownCleansUp` |
| 45 | TextActionsPluginLifecycle | 注销时移除文档条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unregisterRemovesDocsEntries` |
| 46 | TextActionsPluginLifecycle | 插件元数据保持稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 47 | TextActionsPluginLifecycle | 没有旧开关时不做任何导入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsWhenNoLegacyValue` |
| 48 | TextActionsPluginLifecycle | 取不到旧域时不做任何导入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsWhenDomainUnavailable` |
| 49 | TextActionsPluginLifecycle | 旧开关被导入插件专属存储 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `importsLegacyValue` |
| 50 | TextActionsPluginLifecycle | 存储已有值时不被旧开关覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotOverwriteExistingValue` |
| 51 | TextActionsStorage | 注入目录后 settingsDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesConfiguredDirectory` |
| 52 | TextActionsStorage | 重置后回到默认回退目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetClearsInjectedDirectory` |
| 53 | TextActionsStorage | 写入后能读回同一个值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripsValue` |
| 54 | TextActionsStorage | 写入 nil 会移除该键 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removingValue` |
| 55 | TextActionsStorage | 未写入的键读回 nil 与 false | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `missingKeyReadsAsEmpty` |
| 56 | TextActionsStorage | 非布尔值按 false 处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonBooleanReadsAsFalse` |
| 57 | TextActionsStorage | 启用开关可读写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `enabledSwitchRoundTrips` |
| 58 | TextActionsStorage | 存储落在 settings.plist 且能被新实例读回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistsAcrossInstances` |
| 59 | TextActionsStorage | 损坏的 plist 被当作空字典 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `treatsCorruptFileAsEmpty` |
| 60 | TextActionsStorage | 不同实例使用各自隔离的目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isolatesInstancesByDirectory` |
| 61 | TextActionMenuPanel | 初始状态是动作条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initialStateIsActions` |
| 62 | TextActionMenuPanel | perform 转发给注入的处理器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `performForwardsToHandler` |
| 63 | TextActionMenuPanel | 状态切换触发 onStateChange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stateChangeNotifies` |
| 64 | TextActionMenuPanel | 文本变化不自动重置状态——由控制器决定何时回到动作条 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textChangeDoesNotResetState` |
| 65 | TextActionMenuPanel | 动作条渲染出内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actionsStateRendersContent` |
| 66 | TextActionMenuPanel | 复制反馈渲染出内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copiedStateRendersContent` |
| 67 | TextActionMenuPanel | 翻译结果渲染出内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `translatedStateRendersContent` |
| 68 | TextActionMenuPanel | 翻译失败渲染出内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedStateRendersContent` |
| 69 | TextActionMenuPanel | 面板不抢焦点、不在后台隐藏 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `panelIsNonActivatingAndPersistent` |
| 70 | TextActionMenuPanel | 面板跨 Space 且可叠加在全屏应用上 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `panelCollectionBehavior` |
| 71 | TextActionMenuPanel | 译文卡片在 SwiftUI 布局完成后上报实际尺寸 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `translatedIntrinsicSizeFollowsLayout` |
| 72 | TextActionMenuPanel | 长译文把浮层撑到滚动上限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `longTranslationExpandsPanel` |
| 73 | TextActionMenuPanel | 品牌标识使用 App 图标资源 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `brandMarkUsesBundledAppIcon` |
| 74 | TextActionsPluginLifecycle | 从未写入过开关时默认启用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `defaultsToEnabledWhenNeverWritten` |
| 75 | TextActionsPluginLifecycle | 停用与关闭都会停止选区监听 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `disableAndShutdownStopSelectionMonitoring` |
| 76 | TextActionsPluginLifecycle | 运行时启用会启动选区监听 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `enableStartsSelectionMonitoring` |
| 77 | TextActionsPluginLifecycle | 插件开关关闭时 onReady 不启动监听 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readyDoesNotStartMonitoringWhenDisabled` |
| 78 | TextActionsPluginLifecycle | onReady 即启动选区监听 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readyStartsSelectionMonitoring` |
| 79 | TextActionsPluginLifecycle | 显式关闭后保持关闭 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staysDisabledAfterExplicitlyDisabled` |
| 80 | TextActionsPermission | 未授权时不启动监听 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotMonitorWhenPermissionMissing` |
| 81 | TextActionsPermission | 已授权状态可被识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `grantedStatusIsRecognized` |
| 82 | TextActionsPermission | 授权后可以启动监听 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `monitorsAfterPermissionGranted` |
| 83 | TextActionsPermission | 状态对象初始化即反映真实授权状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `permissionStateReflectsRealStatusOnInit` |
| 84 | TextActionsPermission | 刷新推进 revision 以驱动视图重绘 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshAdvancesRevision` |
| 85 | TextActionsPermission | 授权翻转时通知外部启动监听，且只通知一次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsGrantThroughCallback` |
| 86 | TextActionsPermission | 状态查询不触发系统授权弹窗 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusQueryDoesNotPromptSystem` |
| 87 | TextActionsPermission | 停止激活监听可安全重复调用 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stopIsIdempotent` |
| 88 | TextSelectionSuppression | 匹配的同文本 keyUp 只被抑制一次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingKeyUpIsSuppressedOnlyOnce` |
| 89 | TextSelectionSuppression | 键码不同视为新的选择动作并解除抑制 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `differentKeyCodeStartsNewSelection` |
| 90 | TextSelectionSuppression | 同一按键不会被 keyUp 清掉 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sameKeyCodeKeepsSuppression` |
| 91 | TextSelectionSuppression | 选区清空后解除抑制 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearingSelectionReleasesSuppression` |
| 92 | TextSelectionSuppression | 不同键码不命中抑制 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `differentKeyCodeDoesNotMatch` |
| 93 | TextSelectionSuppression | 不同文本不命中抑制 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `differentTextDoesNotMatch` |
| 94 | TextSelectionSuppression | 没有展示中的文本时抑制不会生效 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingPresentedTextDoesNotArm` |
| 95 | TextActionsCore | 有选区 bounds 时按选区所在屏幕布局 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionRectWinsOverMouseAnchor` |
| 96 | TextActionsCore | 无选区 bounds 时回退到鼠标锚点所在屏幕 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToAnchorWithoutSelectionRect` |
| 97 | TextActionsCore | 空选区 bounds 等同不可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptySelectionRectFallsBackToAnchor` |
| 98 | TextActionsCore | 选区中心落在屏幕外时回退到锚点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `offscreenSelectionFallsBackToAnchor` |
| 99 | TextActionsCore | 没有屏幕时返回 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `noScreensReturnsNil` |
| 100 | TextActionsCore | 落在浮层窗口内的事件不算外部事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `eventInsidePanelIsIgnored` |
| 101 | TextActionsCore | 落在其他窗口的事件会关闭浮层 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `eventInOtherWindowIsDismissed` |
| 102 | TextActionsCore | 窗口号未知时不能误判为浮层内 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownWindowNumberNeverMatches` |

> 说明：全部 **102 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 87 / 87
- P2: 已覆盖 10 / 10
- **合计: 102 / 102**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（87 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（10 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 102 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginTextActions
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
