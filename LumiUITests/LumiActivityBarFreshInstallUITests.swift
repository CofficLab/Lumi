import XCTest

/// 全新安装后左侧不应出现 ActivityBar 的 UI 测试。
///
/// ## 为什么需要这条测试
///
/// ActivityBar 的显示判据是 `shouldDisplayActivityBar = items.count > 1`
/// （见 `ActivityBarViewModel.refresh()` 读取 `ActivityBarProviding` 的默认实现）。
/// 全新安装时只有 `ChatPanel`（`policy: .alwaysOn`）会注册入口，其余贡献入口的
/// 插件几乎都是 `disabledByDefault`，因此条目数为 1，ActivityBar 整条栏不渲染。
///
/// 这条链路（插件 policy → PluginManager 启用集合 → `addItems` → Provider 排序 →
/// ViewModel 刷新 → View 条件渲染）每一环都可能静默失效：多一个 alwaysOn 插件、
/// 或者启用态持久化被误当作默认启用，都会让全新安装的用户莫名其妙看到一条
/// 空白或只有单项的 ActivityBar。单元测试只能覆盖 `items.count > 1` 这一个纯函数，
/// 覆盖不了「插件到底启用了哪些」这段真实启动流程，因此必须驱动真实 App。
///
/// ## 确定性来源
///
/// `--lumi-ui-testing-isolated-storage` 把数据根目录重定向到临时目录下的
/// 全新 UUID 子目录（见 `KernelFactory.uiTestingDataRootDirectory()`）。
/// 效果等价于全新安装：没有 `PluginManager/plugin-enabled-overrides.plist`，
/// 没有任何已启用插件的记录，ActivityBar 的 `active-item.json` 也不存在。
///
/// ## 判据为什么用 AX label 而不是几何位置
///
/// `ActivityBarView` 位于外部包 `LumiPluginActivityBar`，未设置
/// `accessibilityIdentifier`，无法按标识符定位。其入口是
/// `AppActivityIconButton`，内部为 `Image(systemName:)`，在 macOS 上桥接出的
/// AX label 就是系统图标名（与 `LumiUITests` 中设置按钮 label 为
/// "Gear Shape" 的既有事实一致）。因此断言 Chat 入口图标
/// `bubble.left.and.bubble.right.fill` 不存在，即等价于断言 ActivityBar 未渲染。
/// 若外部包日后补上 accessibilityIdentifier，应改用标识符判据。
final class LumiActivityBarFreshInstallUITests: XCTestCase {
    private var app: XCUIApplication!

    /// Chat 入口在 ActivityBar 中的 SF Symbol 名。
    ///
    /// 与 `ChatPanelPlugin.onReady` 中 `systemImage: "bubble.left.and.bubble.right.fill"` 一致。
    /// 该常量定义在 App 进程外，故此处以字面量书写；改动图标会让本断言失效，
    /// 属于预期的显式耦合。
    private enum ChatEntry {
        static let systemImageName = "bubble.left.and.bubble.right.fill"
        static let title = "Chat"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 先终止残留实例（与既有 UI 测试一致），避免复用 Background 旧进程：
        // 旧进程里保存着上一次启动累积的插件启用态与 ActivityBar 激活项，
        // 正是本测试要排除的污染源。
        app.terminate()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // 数据根目录重定向到临时目录的全新子目录 = 全新安装态。
            "--lumi-ui-testing-isolated-storage",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 查找 ActivityBar 上的入口按钮（按 SF Symbol 图标名匹配 AX label）。
    ///
    /// 限定在主窗口内查找，避免匹配到设置窗口或其它独立窗口里的同名图标。
    private func activityBarEntry(systemImageName: String) -> XCUIElement {
        element(identifier: "root.main")
            .buttons
            .matching(NSPredicate(format: "label == %@", systemImageName))
            .firstMatch
    }

    /// 等待主窗口就绪。
    ///
    /// 隔离存储会让新手引导重新出现（完成标记存在插件数据目录里），它是覆盖在
    /// 聊天区之上的浮层。本测试断言的是左侧 ActivityBar 的有无，浮层不遮挡左侧
    /// 竖栏，因此无需关闭引导 —— 保持引导开启反而更贴近真实全新安装首启画面。
    private func waitForMainWindow() {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30),
            "主窗口未就绪，无法判断 ActivityBar 是否显示"
        )
    }

    // MARK: - Tests

    /// 全新安装首启：左侧不出现 ActivityBar。
    ///
    /// 断言分三层，缺一层都会漏掉不同的失败模式：
    ///
    /// 1. 主窗口正常渲染 —— 否则「看不到 ActivityBar」可能只是 App 根本没起来；
    /// 2. Chat 入口图标不存在 —— 直接证明 ActivityBar 栏未渲染（核心判据）；
    /// 3. Chat 入口标题文案也不存在 —— 交叉验证。`.help(label)` 会把标题写进
    ///    AX 的 help 属性，部分 SwiftUI 版本下会被并入 label，单独校验图标名
    ///    可能因桥接差异漏判，标题是第二道独立证据。
    func testFreshInstallDoesNotShowActivityBar() throws {
        waitForMainWindow()

        // 全新安装唯一必然注册的 ActivityBar 入口（ChatPanel 为 alwaysOn）。
        // 它存在与否决定了 items.count 是否越过 1 的显示阈值。
        let chatEntry = activityBarEntry(systemImageName: ChatEntry.systemImageName)

        XCTAssertFalse(
            chatEntry.exists,
            """
            全新安装时左侧出现了 ActivityBar（检测到入口图标 \
            "\(ChatEntry.systemImageName)"）。\
            新装状态下只有 ChatPanel 一个 alwaysOn 入口，条目数应低于显示阈值；\
            若此项失败，检查是否有插件被误标为 alwaysOn，或启用态持久化被误当作默认启用。
            """
        )

        // 交叉验证：入口标题文案同样不应出现在主窗口内。
        let chatTitle = element(identifier: "root.main")
            .descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", ChatEntry.title))
            .firstMatch
        XCTAssertFalse(
            chatTitle.exists,
            "全新安装时主窗口内出现了 ActivityBar 入口文案「\(ChatEntry.title)」"
        )

        // 主窗口仍在 —— 上述断言不是「App 已崩溃」造成的假阴性。
        XCTAssertTrue(
            element(identifier: "root.main").exists,
            "主窗口消失，App 可能已崩溃，ActivityBar 断言失去意义"
        )
    }
}
