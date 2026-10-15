import XCTest

final class LumiUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 先终止上一次运行残留的实例：Lumi 启动慢，若上一测试的进程未完全退出，
        // launch() 会复用处于 Background 的旧实例，导致 activation 失败。
        app.terminate()
        // 禁用 macOS 窗口状态恢复，避免上一次运行的残留窗口干扰测试。
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()
        // 注意：不要在 launch() 后立即 activate()。Lumi 启动较慢（240 个本地包），
        // 过早 activate 会遇到 "Running Background"，导致 activation 失败。
        // 各用例通过 root.main 等待内核就绪后再交互。
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        try super.tearDownWithError()
    }

    func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func element(anyLabelOf labels: [String]) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@ OR value IN %@", labels, labels))
            .firstMatch
    }

    @discardableResult
    func openSettings() -> XCUIElement {
        XCTAssertTrue(element(identifier: "root.main").waitForExistence(timeout: 20), "主窗口未就绪")
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

    func testSettingsSidebarShowsCoreEntries() {
        _ = openSettings()
        for title in ["通用", "Appearance", "插件管理"] {
            XCTAssertTrue(
                element(anyLabelOf: [title]).waitForExistence(timeout: 5),
                "设置侧边栏缺少条目：\(title)"
            )
        }
    }

    func testGeneralSettingsShowsAppInformation() {
        _ = openSettings()
        // 打开设置不保证默认选中通用（可能恢复上次的条目），先点击「通用」。
        let general = app.buttons.matching(NSPredicate(format: "label == %@", "通用")).firstMatch
        XCTAssertTrue(general.waitForExistence(timeout: 5), "设置侧边栏缺少通用条目")
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

    func testAppearanceSettingsShowsThemePreview() {
        _ = openSettings()
        let appearance = app.buttons.matching(NSPredicate(format: "label == %@", "Appearance")).firstMatch
        XCTAssertTrue(appearance.waitForExistence(timeout: 5), "设置侧边栏缺少外观条目")
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
