import XCTest

/// 主窗口与设置窗口的基础 UI 测试。
///
/// - Important: 必须带 `--lumi-ui-testing-isolated-storage`。它把数据根目录
///   重定向到临时目录（见 `KernelFactory.uiTestingDataRootDirectory()`），
///   等价于全新安装态：不读用户真实数据库，测试之间也不互相污染。
///   缺了它，`testGeneralSettingsShowsAppInformation` 里「新手引导」入口的
///   断言会取决于**本机引导是否跑过**——干净 CI 机器上必然失败。
final class LumiUITests: LumiUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 先终止上一次运行残留的实例：Lumi 启动慢，若上一测试的进程未完全退出，
        // launch() 会复用处于 Background 的旧实例，导致 activation 失败。
        app.terminate()
        // Important: 必须调用 super —— 基类在此注入隔离存储等 launchArguments，
        // 漏掉会让本文件退化成读取用户真实数据的「手动测试」。
        try super.setUpWithError()
        // 禁用 macOS 窗口状态恢复，避免上一次运行的残留窗口干扰测试。
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // 隔离存储：等价全新安装，不依赖本机插件启用态 / 会话数据。
            "--lumi-ui-testing-isolated-storage",
        ]
        app.launch()
        // 注意：不要在 launch() 后立即 activate()。Lumi 启动较慢（240 个本地包），
        // 过早 activate 会遇到 "Running Background"，导致 activation 失败。
        // 各用例通过 root.main 等待内核就绪后再交互。
    }

    override func tearDownWithError() throws {
        // 等 App 真正退出：terminate() 是异步的，不等会让「上一个用例还在退出」
        // 漂移成「下一个用例偶发失败」。
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    @discardableResult
    func openSettings() -> XCUIElement {
        XCTAssertTrue(element(identifier: "root.main").waitForExistence(timeout: 20), "主窗口未就绪")
        // 隔离存储下引导会被标记为「未完成」，可能浮在窗口上，先关掉。
        dismissOnboardingIfPresent()
        // AppIconButton 的 AX label 是系统图标名 "Gear Shape"。
        let gear = app.buttons["Gear Shape"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "工具栏缺少设置按钮")
        gear.click()
        let settingsWindow = app.windows.matching(identifier: "lumi.settings").firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 15), "设置窗口没有出现")
        return settingsWindow
    }

    func testMainWindowShowsRootContent() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(element(identifier: "root.main").waitForExistence(timeout: 20), "主窗口根内容未出现")
    }

    func testSettingsWindowOpensFromToolbarButton() {
        _ = openSettings()
        XCTAssertTrue(app.windows.count >= 2, "打开设置后应有独立的设置窗口")
    }

    /// 侧边栏核心条目必须在英文环境下出现。
    ///
    /// - Important: 断言文案必须与 `setUp` 的 `-AppleLanguages (en)` 一致。
    ///   这三条曾经写成中文「通用」「插件管理」，但侧边栏实际渲染的是
    ///   `General` / `Plugin Manager`（实测 AX label），断言必然落空——
    ///   而且失败信息「设置侧边栏缺少条目：通用」会让人误以为是侧边栏没渲染，
    ///   实际是文案对不上。同一张列表里混着英文 `Appearance` 和中文两项，
    ///   也说明这几条断言是照着英文环境写的，中文项从未真正验证过。
    ///
    ///   中文环境的本地化验证由 `LumiChineseLocalizationUITests` 负责，
    ///   不在本文件重复。
    func testSettingsSidebarShowsCoreEntries() {
        _ = openSettings()
        for title in ["General", "Appearance", "Plugin Manager"] {
            XCTAssertTrue(
                element(anyLabelOf: [title]).waitForExistence(timeout: 5),
                "设置侧边栏缺少条目：\(title)"
            )
        }
    }

    /// 通用页必须能进入，并展示应用信息区与新手引导入口。
    ///
    /// - Important: 侧边栏条目用英文 `General`，与 `setUp` 的英文环境一致。
    ///   这里曾断言中文「通用」，该元素在英文环境下根本不存在。
    ///
    /// - Note: 这一页的中文文案（新手引导 / 说明书 / 占用空间…）是插件内硬编码的
    ///   字面量，不走 `String(localized:)`，因此不受 `-AppleLanguages` 影响。
    ///   这一点由上面的实测记录确认，不是猜测。
    func testGeneralSettingsShowsAppInformation() {
        _ = openSettings()
        // 打开设置不保证默认选中通用（可能恢复上次的条目），先点击「General」。
        let general = app.buttons.matching(NSPredicate(format: "label == %@", "General")).firstMatch
        XCTAssertTrue(general.waitForExistence(timeout: 5), "设置侧边栏缺少 General 条目")
        general.click()

        // Lumi 通用页包含应用信息区（Lumi / Bundle ID / Version / Build）。
        XCTAssertTrue(
            element(anyLabelOf: ["Lumi", "Bundle ID", "Version", "Build"]).waitForExistence(timeout: 8),
            "通用设置缺少应用信息区"
        )
        XCTAssertTrue(
            element(anyLabelOf: ["新手引导", "重新查看新手引导"]).exists,
            "通用设置缺少新手引导区"
        )
    }

    /// 外观页必须能进入，并提供主题搜索与主题筛选。
    ///
    /// - Important: 侧边栏条目用英文 `Appearance`，与 `setUp` 的英文环境一致
    ///   （此处曾断言中文「外观」，该元素在英文环境下不存在）。
    ///   失败信息也据此改为英文条目名，避免再指向不存在的元素。
    func testAppearanceSettingsShowsThemePreview() {
        _ = openSettings()
        let appearance = app.buttons.matching(NSPredicate(format: "label == %@", "Appearance")).firstMatch
        XCTAssertTrue(appearance.waitForExistence(timeout: 5), "设置侧边栏缺少 Appearance 条目")
        appearance.click()

        let search = app.textFields.matching(NSPredicate(format: "placeholderValue IN %@", ["Search Themes", "搜索主题"])).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8), "外观页缺少主题搜索入口")
        // 外观页提供主题筛选（全部/深色/浅色/跟随系统）与主题预览块。
        for filter in ["All", "Dark", "Light", "Follow System"] {
            XCTAssertTrue(
                app.buttons.matching(NSPredicate(format: "label == %@", filter)).firstMatch.exists,
                "外观页缺少主题筛选：\(filter)"
            )
        }
    }
}
