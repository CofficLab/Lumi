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
@MainActor
class LumiLocalizationUITestCase: XCTestCase {
    var app: XCUIApplication!
    var language: String { "en" }
    var locale: String { "en_US" }
    var expected: LumiSidebarExpectation { fatalError("Override per language") }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.terminate()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
        ]
        app.launch()
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

    func button(label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func testSettingsSidebarFollowsLanguage() {
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
