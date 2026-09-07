# Lumi 可能导致 App 崩溃的代码审查报告

审查日期：2026-09-04  
审查方式：静态扫描 + 逐处阅读上下文  
审查范围：生产 Swift 源码；排除 `**/Tests/**`、`build/**`，预览专用代码单独说明。  
本次只识别问题，没有修改业务代码。

## 结论摘要

发现以下几类可能触发 Swift 运行时 trap 或直接终止进程的代码：

- 强制解包/强制类型转换：`!`、`as!`、`try!`。
- 未验证的数组、字符串索引。
- `fatalError` / `preconditionFailure` 在初始化、启动或数据异常路径中的使用。
- 系统 API 返回的指针、长度和类型未充分校验。
- 将可能为 0 的布局尺寸用于转成整数索引。

最值得优先处理的是 SQL 解析器、Find 方法选择器、系统 CPU 监控，以及三个宿主工厂中的 `try! StorageSuperPlugin()`。

## 主要问题

### 高风险

#### 1. SQL 解析器可能把 `endIndex` 当成有效字符索引

位置：

- `Packages/PluginDatabaseManager/Sources/Core/SQL/SQLStatementParser.swift:31-50`
- `Packages/PluginDatabaseManager/Sources/Core/SQL/SQLStatementParser.swift:67-89`
- `Packages/PluginDatabaseManager/Sources/Core/SQL/SQLStatementParser.swift:120-133`

`String.index(_:offsetBy:limitedBy:)` 在下一个位置正好是 `endIndex` 时可以返回 `endIndex`，但代码只判断 `next != nil`，随后执行 `sql[next!]` / `statement[n!]`。因此 SQL 恰好以单个 `-`、`/`、`*` 或未闭合块注释结尾时，可能访问 `String` 的 `endIndex` 并触发越界崩溃。该问题同时存在于主解析循环和 `hasExecutableContent` 辅助函数。

#### 2. Find 方法选择器直接访问不存在的子视图

位置：`Packages/EditorSource/Sources/EditorSource/Find/PanelView/FindMethodPicker.swift:157-193`

`updateNSView` 在 `condensed == true` 时直接访问 `container.subviews[1]` 和 `container.subviews[2]`。但 `makeNSView` 只在创建时按 `condensed` 添加图标和 chevron；如果 SwiftUI 复用同一个 container 并发生 `condensed` 状态变化，或者容器层级不符合预期，就会触发数组越界。外层 `if let ... as?` 无法保护越界访问，因为下标访问发生在类型转换之前。

#### 3. CPU 监控使用未校验的 Mach 指针和数组范围

位置：`Packages/PluginDevice/Sources/PluginDevice/Services/SystemMonitorService.swift:229-272`

`host_processor_info` 成功后，代码在 `cpuInfoU![baseIndex + j]` 和 `prevCpuInfo[baseIndex + j]` 上同时依赖多个未校验前提：当前指针非空、返回的 CPU 数量与 `sysctl` 得到的 `numCPUs` 一致、历史指针仍具有足够长度。代码实际使用的是独立读取的 `numCPUs`，而不是本次 API 返回的 `numCPUsU`，也没有比较当前/历史 `numCpuInfo`。CPU 拓扑变化、API 返回不完整或历史状态异常时，可能发生强制解包或数组越界。

#### 4. 宿主工厂用 `try!` 创建存储插件，文件系统异常会阻止 App 启动

位置：

- `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift:147`
- `Packages/FactoryBookletMaker/Sources/FactoryBookletMaker/PluginFactory.swift:28`
- `Packages/FactoryAppIconDesigner/Sources/FactoryAppIconDesigner/PluginFactory.swift:23`

`StorageSuperPlugin()` 会创建 Application Support 下的目录，并且初始化器会抛错。目录不可写、Application Support 不可用或路径配置异常时，`try!` 会在构造插件列表期间直接终止对应宿主进程。

#### 5. Booklet Maker 初始化失败时使用 `preconditionFailure`

位置：`Packages/PluginBookletMaker/Sources/ViewModels/BookletMakerViewModel.swift:90-100`

ViewModel 初始化时强制生成演示 PDF；任何 PDF 创建失败都会进入 `preconditionFailure`。这使一个可报告的资源/生成错误升级为 App 崩溃，尤其影响 Booklet Maker 宿主启动或首次展示该功能时。

#### 6. `RangeStore` 的 Rope 重平衡实现是可执行的 `fatalError`

位置：`Packages/EditorSource/Sources/EditorSource/RangeStore/RangeStore+StoredRun.swift:48-56`

两个 `RopeElement.rebalance` 实现直接调用 `fatalError("Unimplemented")`。当前 `isUndersized` 固定返回 `false`，因此正常路径可能暂时不会触发，但只要底层 Rope 在某种插入、删除或未来实现变化下调用重平衡，就会直接崩溃。该项应视为“接口存在但实现不完整”的运行时终止点。

### 中风险

#### 7. SwiftData 双重回退失败时仍使用 `try! ModelContainer()`

位置：

- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobRecordStore.swift:20-33`
- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolCallRecordStore.swift:34-48`

持久化容器创建失败后，代码尝试内存容器；内存容器也失败时使用 `try! ModelContainer()`。这条兜底路径仍可能抛错，因此数据库损坏、SwiftData schema/configuration 不兼容或系统资源不足时，创建记录存储会导致进程崩溃。

#### 8. AppManager / Clipboard 的最终容器失败路径使用 `preconditionFailure`

位置：

- `Packages/PluginAppManager/Sources/Services/CacheManager.swift:85-95`
- `Packages/PluginClipboardManager/Sources/Services/ClipboardHistoryManager.swift:80-93`

持久化容器失败后会尝试内存容器，但内存容器失败时直接 `preconditionFailure`。这属于低频但真实的初始化崩溃路径。

#### 9. Finder 扩展配置缺失时直接 `preconditionFailure`

位置：`Packages/PluginRClick/FinderExtension/FinderRuntimeEnvironment.swift:7-13`

只要扩展 Info.plist 中缺少必需配置、值为空或仍包含 `$(...)`，静态属性初始化就会终止 Finder 扩展进程。该问题主要影响 Finder 扩展，不一定直接杀死主 App，但会表现为扩展崩溃/无法加载。

#### 10. Finder 扩展和 Computer Use 对系统图标结果强制解包

位置：

- `Packages/PluginRClick/FinderExtension/FinderSync.swift:61-63`
- `Packages/PluginComputerUse/Sources/ComputerUsePlugin/Views/ComputerUseSettingsView.swift:130-139`

`NSImage(systemSymbolName:..., accessibilityDescription: nil)!` 依赖指定 SF Symbol 在当前系统中一定存在。图标名称不可用、系统版本/资源环境不符合预期时会触发强制解包。Finder toolbar 属性访问和 Computer Use 设置页构建列表时都可能触发。

#### 11. Computer Use / Screen Recorder 对系统 API 返回值使用 `as!`

位置：

- `Packages/PluginComputerUse/Sources/ComputerUsePlugin/Services/ComputerUseInputExecutor.swift:145-158`
- `Packages/PluginComputerUse/Sources/ComputerUsePlugin/Services/ComputerUseWindowProvider.swift:17-23`
- `Packages/PluginScreenRecorder/Sources/ScreenRecorderPlugin/Services/RecordableWindowProvider.swift:52-59`

辅助功能和窗口枚举数据来自 `CFTypeRef` / `[CFString: Any]`。代码对 focused element 或 window bounds 直接执行 `as! AXUIElement` / `as! CFDictionary`。系统返回类型、桥接行为或第三方窗口数据异常时会触发强制类型转换崩溃；其中 `TextSelectionObserver` 虽然先检查了 `CFGetTypeID`，但仍保留了不必要的强制转换。

#### 12. 三个设备图表把可能产生非有限值的结果转换为整数

位置：

- `Packages/PluginDevice/Sources/PluginDevice/Views/CPUHistoryGraphView.swift:178-183`
- `Packages/PluginDevice/Sources/PluginDevice/Views/GPUHistoryGraphView.swift:174-179`
- `Packages/PluginDevice/Sources/PluginDevice/Views/MemoryHistoryGraphView.swift:165-170`

代码计算 `Int(x / width * CGFloat(dataPoints.count - 1))`，但没有保证 `width > 0` 或结果是有限数。布局尚未完成、视图被压缩为 0 宽度时，浮点结果可能为 `NaN`/无穷大，把它转换为 `Int` 可能触发 Swift 运行时错误。后续的 `safeIndex` 只能保护合法整数，不能保护前一步的转换。

#### 13. MLX 模型默认目录依赖 Application Support 一定存在

位置：`Packages/PluginLLMProviderMLX/Sources/PluginLLMProviderMLX/MLXModelPaths.swift:5-6`

`FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!` 强制假设系统总能返回目录 URL。通常成立，但在受限运行环境、特殊测试环境或 API 返回空数组时会在 MLX 类型首次初始化时崩溃。

#### 14. White Noise 初始化强制解包音频格式

位置：`Packages/PluginWhiteNoise/Sources/PluginWhiteNoise/Services/NoiseGenerator.swift:71-76`

`AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!` 是可失败初始化器。音频格式不受支持或音频环境异常时会直接崩溃，而不是让插件报告不可用。

#### 15. App Store Connect 显示规格初始化使用 `preconditionFailure`

位置：`Packages/PluginAppStoreConnect/Sources/PluginAppStoreConnect/Sources/Models/ScreenshotDisplaySpec.swift:16-34`

`sizesByDisplayType` 是静态属性，初始化时要求共享的 `AppStorePromoDisplaySpec` 必须包含所有列出的类型。共享规格遗漏、资源版本不一致或迁移不完整时，第一次访问该静态属性会触发 `preconditionFailure`。

### 低风险/需确认

#### 16. HTTP 网络适配器对可选 URLResponse 强制解包

位置：`Packages/PluginNetworkManager/Sources/PluginNetworkManager/Services/LLMNetworkProviderAdapter.swift:22-52`

请求 URL 缺失时使用 `about:blank`，随后强制解包 `HTTPURLResponse(...)!`。正常 LLM 请求通常是 HTTP/HTTPS URL，因此风险较低；但传入非 HTTP URL、无效 URL 或 Foundation 不接受该 URL 时，构造 response 可能返回 nil。

#### 17. GlobalHotkeyManager 对键盘布局数据指针缺少空指针校验

位置：`Packages/PluginQuickLauncher/Sources/Services/GlobalHotkeyManager.swift:73-90`

虽然 `TISGetInputSourceProperty` 的属性指针做了非空检查，但之后 `CFDataGetBytePtr(layoutData)` 的结果没有检查就通过 `unsafeBitCast` 作为 `UCKeyboardLayout` 指针传入 `UCKeyTranslate`。空数据或异常键盘布局可能导致无效指针使用。

## 已扫描但未列入主要问题的代码

- 各类 `required init?(coder:) { fatalError("init(coder:) has not been implemented") }`：这些类均提供了程序化初始化，且部分标记为 `unavailable`，属于 AppKit 常见的不可用反序列化入口；若未来通过 nib/storyboard 实例化，仍会崩溃，但当前不视为主路径问题。
- `#Preview` 中的 `try!`，例如 `SheetPreviewView`、`FlipBookView`、`AddRuleFormView` 和 `PromoImageRowView`：只在 Xcode Preview 运行，不计入生产 App 主问题。
- 由同一条件保证的强制解包，例如 `responseStatusCode != nil` 后的 `responseStatusCode!`、`message?.isEmpty == false` 后的 `message!`、`best == nil || ... best!`：当前上下文中具备短路或前置条件，暂未判定为独立崩溃点。
- 由 `count > 1`、`!isEmpty` 或 `count >= 2` 明确保护的数组索引：当前上下文未发现独立越界路径。

## 建议排查顺序

1. 先验证 SQL 解析器对末尾 `-`、`/`、`*`、未闭合 `/*` 的输入。
2. 验证 `FindMethodPicker` 在 `condensed` 来回切换时的 `NSView` 复用行为。
3. 给 CPU 监控增加当前/历史 Mach buffer 长度和 CPU 数量的一致性检查。
4. 清理宿主工厂、SwiftData fallback 和 Booklet Maker 初始化中的进程级 trap。
5. 对所有系统 API 返回的图像、CF 对象、音频格式和布局尺寸采用可失败处理，并补充异常输入测试。

