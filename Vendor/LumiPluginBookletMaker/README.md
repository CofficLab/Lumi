# LumiPluginBookletMaker

Lumi 与 GameFactory 共享的 Booklet Maker 远程包。

## Products

本仓库导出两个 product，对应两层职责：

| Product | Target | 说明 |
|---------|--------|------|
| `BookletMakerCore` | `Sources/BookletMakerCore` | 纯领域逻辑：纸张尺寸、折页布局引擎、拆分计划。不依赖 Kernel / Providers / SwiftUI。 |
| `PluginBookletMaker` | `Sources/PluginBookletMaker` | 插件层：`SuperPlugin` 实现 + SwiftUI 界面 + PDF 检查/渲染/拆分/合并服务。 |

`BookletMakerCore` 保留原有仓库名对应的语义，两个宿主现有的 `LumiBookletMaker` 依赖可平滑迁移到本包。

## 宿主注入约定

本包同时服务两个形态差异很大的宿主（Lumi 的多插件工作台、GameFactory 的独立 App），
因此**不硬编码任何宿主专属概念**，全部通过 `BookletMakerPlugin.init` 注入。

### pluginID

```swift
public nonisolated static let defaultPluginID = "com.coffic.lumi.plugin.booklet-maker"

public init(
    id: String = BookletMakerPlugin.defaultPluginID,
    order: Int = 880,
    policy: PluginEnablePolicy = .disabledByDefault,
    onWorkspaceActivate: VisibilityHook? = nil,
    onWorkspaceDeactivate: VisibilityHook? = nil
)
```

- `id` 决定 `PluginMetadata.id` 与插件数据目录名，两个宿主各用各的命名空间，互不干扰。
- `order` / `policy` 决定加载顺序与启用策略。

### 聊天区显隐

Lumi 把 Booklet Maker 作为工作台展示，激活时需收起聊天区；GameFactory 的
Booklet Maker 是独立 App，没有聊天区概念。宿主按需注入钩子：

```swift
// Lumi
BookletMakerPlugin(
    id: "com.coffic.lumi.plugin.booklet-maker",
    onWorkspaceActivate: { chatProvider?.setVisible(false) },
    onWorkspaceDeactivate: { chatProvider?.setVisible(true) }
)

// GameFactory
BookletMakerPlugin(
    id: "com.coffic.bookletmaker.plugin.booklet-maker",
    policy: .required
)
```

不传钩子时插件照常启动与切换布局。详见 `ToastSuperPlugin` 的同类做法。

## 能力范围

- 小册子拼版：简单对折、骑马钉、折页签名，输出可打印 PDF
- PDF 拆分：按切点导出多个文件
- PDF 合并：按给定顺序合并
- macOS：NSSavePanel / NSOpenPanel 导出；iOS：文件选择与分享

本包**不**向 Agent 贡献工具（`pdf_inspect` / `booklet_make` / `pdf_split` / `pdf_merge` /
`booklet_preview`）与 Skill。原 Lumi 本地包中的 Agent Tools 与 Skills 目录已在迁移时移除，
以避免引入 `KitAgentTool` / `ProviderToolManager` / `ProviderSkill` 等宿主专属依赖。

## 依赖

全部为远程包，无本地路径依赖：

- `LumiKernel`
- `LumiProviders`
- `LumiUI`
- `LumiLocalization`
- `LumiLogging`

## Development

```sh
swift build
swift test
```

## Testing

本包自带三层测试，全部在仓库内，无需外部宿主工程即可验证。

| 层 | 位置 | 数量 | 运行方式 |
|---|---|---|---|
| 领域层 | `Tests/BookletMakerCoreTests` | swift-testing `@Suite` | `swift test` |
| 插件层 | `Tests/PluginBookletMakerTests` | 115 项 XCTest | `swift test` |
| 界面层 | `BookletMakerUITestHost/UITests` | 40 项 XCUITest | `xcodebuild test` |

### 单元测试

```sh
swift test                                   # 全部
swift test --filter BookletMakerViewModelTests
swift test --enable-code-coverage
```

其中 `BookletLocalizationCatalogTests` 是本地化目录的守卫，把四条容易静默退化的
规则固化为断言：key 在全部五种语言下必须有非空译文、各语言占位符数量须一致且
定位占位符（`%1$@`）位置连续、代码里引用的每个 key 必须存在于目录、`sourceLanguage`
须为 `en`。新增文案时忘记维护 xcstrings 会立刻失败，而不是等到某个语种的界面
里出现一两句漏翻译的英文。

### 界面测试

界面测试需要宿主 App 与 Xcode test runner，因此以 Xcode 工程形式内嵌在仓库内
（`project.yml` + XcodeGen 生成），不依赖任何宿主专属的私有包。

```sh
brew install xcodegen          # 一次性
./generate-ui-test-project.sh  # 生成 BookletMakerUITests.xcodeproj
xcodebuild test \
  -project BookletMakerUITests.xcodeproj \
  -scheme BookletMakerUITests \
  -destination 'platform=macOS'
```

`BookletMakerTestHost` 是一个最小宿主 App，按真实宿主（GameFactory 的
`BookletMakerApp`）的顺序装配：**注册 Provider → 启动插件 → 组装视图**。
该顺序不可颠倒：插件 `onBoot` 会向 Rail 注册 tab、向 ContentView 注入内容区，
提前组装会让这些区域停留在空状态。

覆盖范围：

| 套件 | 覆盖 |
|---|---|
| `BookletMakerBookletUITests` | 四个预览阶段切换、装订前纸张列表、纸张/版式/滑块/开关交互、补白开关在书本折叠版式下强制禁用、锚点跨语言稳定 |
| `BookletMakerSplitUITests` | 切分点选中与反选、多切分点独立、导出门控随有效性翻转、页面点击与侧栏输入两条路径等价、非法输入校验、分段重命名 |
| `BookletMakerMergeUITests` | 空队列与导出禁用、汇总如实反映队列规模、与小册子设置互斥 |
| `BookletMakerMergeQueueUITests` | 队列注入后的排序（双向）、边界按钮禁用、删除、导出门控变化、删空回到空态 |
| `BookletMakerExportPanelUITests` | 三个工具的导出面板、保存/取消、替换确认、面板关闭后界面恢复 |
| `BookletMakerToolSwitchUITests` | 三工具切换后侧栏设置与主按钮文案同步 |
| `BookletMakerLocalizationUITests` | en / zh-Hans / zh-Hant 文案，以及切换语言后锚点结构不变 |

#### 编写界面测试时的两条约定

1. **只用 `accessibilityIdentifier` 定位元素**，不要用文案——文案随本地化变动，
   identifier 不会。唯一例外是 `BookletMakerLocalizationUITests`，那里用文案
   正是为了验证文案本身。
2. **断言状态而非存在性**：元素存在只说明渲染了，真正要校验的是选中态、
   启用态、门控原因。

#### 系统面板（保存 / 选择文件夹）在 XCUITest 里的形态

导出用 `NSSavePanel.runModal()` / `NSOpenPanel.runModal()`，实测有几个反直觉之处：

| 现象 | 正确做法 |
|---|---|
| 面板挂在 `app.dialogs` 下，**不是** `app.sheets`，也不是 `app.windows` | `app.dialogs.matching(identifier:)` |
| 面板标题不暴露给 XCUITest（`label` 为空、无 StaticText 子节点） | 改用 identifier 区分：`save-panel` / `open-panel` |
| 两种面板的确认按钮都叫 `OKButton` | 不能靠它区分面板类型 |
| 目标文件已存在时叠一个「是否替换」的 sheet | `confirmReplaceIfPresent()`，按钮为 `action-button-1` |
| 面板打开期间查询下层界面报 `still interrupting` | `waitForModalPanelToClose()` 后再断言 |

此外：测试宿主**不开沙盒**，而 XCUITest runner 自带沙盒且与宿主进程隔离。
因此导出产物写在宿主指定的目录里，runner 既读不到也清理不掉——测试模式
下宿主会把面板预选到自己的临时目录，避免往用户文件夹里丢文件。

#### 关于导出产物的校验

界面测试**不**断言导出文件的内容：产物确实被正确写出，但 runner 无权读取，
且产物正确性（页数、分段、文件名）由 `BookletMakerViewModelTests` 覆盖。
界面测试只负责「交互链路完整走通」。

#### 一个容易踩的坑

**不要给容器视图打 `accessibilityIdentifier`。** SwiftUI 会把祖先的 identifier
下推到每一个叶子元素，导致容器内部的锚点全部被同一值覆盖而无法定位。本包
曾因此让 `split.cutPoint.*`、`split.summary`、`merge.insufficientHint`
一度全部失效。若需要判断某个区域是否出现，请在区域内的**叶子元素**上取锚点。

#### 已知差异

测试宿主使用公开的 `DefaultRootViewProviding` 并自行拼装根布局，而真实宿主使用
自己的根视图实现。测试宿主**不**装配 `CommandProviding` 与设置侧栏插件，因此
设置窗口相关界面不在本套件覆盖范围内——该能力来自宿主侧包，插件仓库无法自证。

### iOS 界面测试

iOS 侧的 UI 测试覆盖移动端独立架构（`BookletMakerMobileRootView` 直接挂载，不经过
Kernel Provider）。测试工程与 macOS 共用 `BookletMakerUITests.xcodeproj`，但 target
和宿主 App 完全独立。

```sh
# 生成工程（如果还没生成）
./generate-ui-test-project.sh

# 运行 iOS UI 测试
xcodebuild test \
  -project BookletMakerUITests.xcodeproj \
  -scheme BookletMakerMobileUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

#### iOS 与 macOS 测试的五处实质差异

1. **无窗口前台等待**：macOS 需要 `NSWorkspace.frontmostApplication` 轮询，因为首次
   点击会被窗口激活竞态吞掉；iOS 上 App 启动即为前台，没有这个竞态。
2. **点击用 tap 而非 click**：`XCUIElement.click()` 在 iOS 上不存在。
3. **必须滚动**：XCUITest 查询基于当前快照，首屏之外的元素在 AX 树里不存在（不是
   不可见，是**不存在**）。所有存在性断言都先滚动再判断。
4. **语言注入方式不同**：macOS 用 `-AppleLanguages`；iOS 还需一并覆盖 `AppleLocale`，
   否则系统组件仍可能显示宿主语言。
5. **系统面板形态不同**：macOS 的 `NSSavePanel` 挂在 `app.dialogs` 下可驱动；iOS 的
   `UIDocumentPickerViewController` / `UIActivityViewController` 在 App 的辅助功能树
   之外运行，XCUITest 既无法驱动也无法断言其结果。

#### iOS 测试覆盖范围

| 套件 | 覆盖 | 状态 |
|---|---|---|
| `BookletMakerMobileToolSwitchUITests` | 欢迎页 → 概览页 → 工具页导航、工具切换后内容正确性、关闭文档回到欢迎页 | ✅ 5/5 |
| `BookletMakerMobileBookletUITests` | 六阶段指示器切换、参数面板控件、补白开关门控、拼版预览页序、摘要文本 | ✅ 9/9 |
| `BookletMakerMobileSplitUITests` | 切分点点击增删、批量输入、非法输入校验、摘要随切分点变化、分段切换 | ✅ 9/9 |
| `BookletMakerMobileMergeUITests` | 空队列门控、摘要文本 | ⚠️ 1/6 |

合并测试的其余 5 项涉及队列注入（`-SeedMergeQueue N`），当前存在时序问题：宿主应用
在 `onAppear` 时延迟注入，但工具切换和注入完成的时序难以精确同步。空队列测试已通过，
验证了门控逻辑正确。完整的合并队列测试需要进一步调试宿主注入逻辑或采用不同的测试方案
（如手动 UI 操作添加文件，但 iOS `fileImporter` 无法被 XCUITest 驱动）。

#### iOS 测试的关键技术点

**滚动处理**：iOS 测试基类提供了 `scrollTo()` 和 `scrollHorizontallyTo()` 方法，
自动处理首屏外元素的可见性问题。阶段指示器是横向 `ScrollView`，只有前两项在首屏内，
其余需要横向滚动。

**键盘处理**：文本框获得焦点后软键盘会占据屏幕下半部分，把下方内容挤出可命中区域。
测试基类的 `dismissKeyboard()` 通过点击导航栏标题收起键盘，避免影响后续断言。

**锚点设计**：iOS 侧的锚点遵循 `overview.*` / `booklet.*` / `split.*` / `merge.*` /
`welcome.*` / `params.*` / `stage.*` 等前缀，与 macOS 侧的锚点体系不重叠。所有锚点
都加在叶子元素上，避免 SwiftUI 的 identifier 下推问题。

**选中态断言**：SwiftUI 对被横向轨道**裁剪**的元素会错误地报告 `isSelected == true`。
阶段切换测试改为断言「该阶段呈现的内容」而非「选中态」，绕开了 trait 报告缺陷。

#### iOS 宿主装配

`BookletMakerMobileTestHostApp` 直接挂载 `BookletMakerMobileRootView(feature:)`，
不经过 Kernel Provider 装配。这与 macOS 宿主的「注册 Provider → 启动插件 → 组装视图」
顺序完全不同，反映了 iOS 端独立 App 的架构特点。

合并队列测试通过 `-SeedMergeQueue N` 启动参数注入测试用 PDF。宿主应用检测到该参数后
会调用 `feature.importDocuments(from:)`，该方法会检测到参数并自动切换到合并工具，
确保文档被正确加载为合并队列而不是单个文档。

#### 已知限制

1. **合并队列注入时序**：宿主在 `onAppear` 后延迟 1 秒注入，但测试切换到合并工具的
   时机不确定，可能导致注入在工具切换前或后发生。当前只有空队列测试稳定通过。
2. **文件选择器无法自动化**：iOS 的 `fileImporter` 呈现系统文件选择器，XCUITest 无法
   驱动。因此所有需要导入文件的测试都依赖宿主注入或示例文档。
3. **导出面板测试缺失**：iOS 端的导出走 `UIActivityViewController`（分享面板）或
   `fileExporter`（系统保存对话框），都在 App 进程外运行，无法被 XCUITest 断言。
   导出链路的正确性由单元测试（`BookletMakerViewModelTests`）覆盖。

