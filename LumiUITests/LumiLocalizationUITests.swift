import XCTest

struct LumiSidebarExpectation {
    let general: String
    let pluginManager: String
    let cloudProviders: String
    let localProviders: String
    let memories: String
}

/// 语言 UI 测试基类：以 `-AppleLanguages` / `-AppleLocale` 启动 Lumi，
/// 打开设置窗口后断言侧边栏条目跟随目标语言，且不出现其他语言的残留标题。
/// 参考 GitOKLocalizationUITests 的「Expectation + en/zh 子类」模式。
///
/// - Important: 本基类继承 `XCTestCase` 且自带测试方法，因此 XCTest 会把它
///   当作**具体测试类**自动发现并运行一次；而 `expected` 在基类里没有可用值，
///   一旦运行就直接 `fatalError` 崩溃，表现为一条与断言无关的
///   `Fatal error: Override per language`，极具误导性。
///
///   修法是在测试方法开头检测「是否仍是基类」，是则 `XCTSkip`。
///   比改成 `abstract class` 可靠——Swift 没有 `abstract class` 关键字，
///   而让基类脱离 `XCTestCase` 又会丢掉 `setUp`/`tearDown` 的调度能力。
@MainActor
class LumiLocalizationUITestCase: LumiUITestCase {
    var language: String { "en" }
    var locale: String { "en_US" }
    /// 本类是否被具体子类覆盖了 `expected`。
    ///
    /// 子类一律覆盖它，因此这个判断等价于「当前实例的动态类型就是基类」。
    private var isBaseClass: Bool { type(of: self) == LumiLocalizationUITestCase.self }
    var expected: LumiSidebarExpectation { fatalError("Override per language") }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        app.terminate()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            // 隔离存储：等价全新安装，断言结果不取决于本机插件启用态。
            "--lumi-ui-testing-isolated-storage",
        ]
        app.launch()
        // 隔离存储下引导会重新出现，可能盖住设置窗口，先关掉。
        // 走基类的 `waitForMainWindow`：它会先等主窗口出现再关引导 ——
        // 直接查一次引导按钮会在浮层画出来之前返回，浮层随后才盖上来。
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    func button(label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func testSettingsSidebarFollowsLanguage() throws {
        // 基类没有可用的 `expected`，被 XCTest 自动发现运行时跳过，
        // 而不是撞上 `fatalError` 崩溃。
        try XCTSkipIf(
            isBaseClass,
            "LumiLocalizationUITestCase 是抽象基类，请由 LumiEnglishLocalizationUITests / LumiChineseLocalizationUITests 等子类运行"
        )
        XCTAssertTrue(element(identifier: "root.main").waitForExistence(timeout: 25), "主窗口未就绪")
        let gear = app.buttons.matching(
            NSPredicate(format: "label IN %@ OR value IN %@", ["Gear Shape", "齿轮形状"], ["Gear Shape", "齿轮形状"])
        ).firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "工具栏缺少设置按钮")
        gear.click()
        let settingsWindow = app.windows.matching(identifier: "lumi.settings").firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 15), "设置窗口没有出现")

        for text in [expected.general, expected.pluginManager, expected.cloudProviders, expected.localProviders, expected.memories] {
            let entry = settingsWindow.buttons.matching(NSPredicate(format: "label == %@", text)).firstMatch
            XCTAssertTrue(
                entry.waitForExistence(timeout: 10),
                "侧边栏缺少本地化条目「\(text)」（语言=\(language)）"
            )
        }

        // 反断言：设置窗口内不应出现其他语言的残留标题。
        for stale in staleTitles(for: language) {
            let staleButton = settingsWindow.buttons.matching(NSPredicate(format: "label == %@", stale)).firstMatch
            XCTAssertFalse(staleButton.exists, "设置窗口错误显示残留标题「\(stale)」（语言=\(language)）")
        }
    }

    private func staleTitles(for language: String) -> [String] {
        if language == "en" {
            ["通用", "插件管理", "云端供应商", "本地供应商", "记忆"]
        } else {
            ["General", "Plugin Manager", "Cloud Providers", "Local Providers", "Memories"]
        }
    }
}

final class LumiEnglishLocalizationUITests: LumiLocalizationUITestCase {
    override var language: String { "en" }
    override var locale: String { "en_US" }
    override var expected: LumiSidebarExpectation {
        LumiSidebarExpectation(
            general: "General",
            pluginManager: "Plugin Manager",
            cloudProviders: "Cloud Providers",
            localProviders: "Local Providers",
            memories: "Memories"
        )
    }
}

final class LumiChineseLocalizationUITests: LumiLocalizationUITestCase {
    override var language: String { "zh-Hans" }
    override var locale: String { "zh_CN" }
    override var expected: LumiSidebarExpectation {
        LumiSidebarExpectation(
            general: "通用",
            pluginManager: "插件管理",
            cloudProviders: "云端供应商",
            localProviders: "本地供应商",
            memories: "记忆"
        )
    }
}
