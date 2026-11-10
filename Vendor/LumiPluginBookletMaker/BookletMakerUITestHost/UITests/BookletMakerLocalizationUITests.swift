import XCTest

/// 界面随系统语言切换的正确性。
///
/// 这些断言**必须用文案**（而非锚点）——目的正是验证文案本身被正确翻译。
/// 缺失的本地化 key 会静默回退到英文源串，因此「中文界面里出现英文」就是
/// 本套件要捕获的失败模式。
final class BookletMakerLocalizationUITests: BookletMakerUITestCase {

    /// 英文环境：界面显示英文文案。
    func testEnglishInterfaceUsesEnglishStrings() {
        XCTAssertTrue(
            localizedText("Booklet Settings").waitForExistence(timeout: 15),
            "英文环境缺少小册子设置标题。\(app.debugDescription)"
        )
        XCTAssertTrue(localizedText("Output paper").exists, "缺少输出纸张行标题")
        XCTAssertTrue(localizedText("Margin").exists, "缺少边距行标题")
        XCTAssertTrue(localizedText("Gutter").exists, "缺少装订线行标题")
        XCTAssertFalse(
            localizedText("小册子设置").exists,
            "英文环境错误显示中文文案"
        )
    }

    /// 中文环境：同一部位显示中文文案，且不残留英文。
    func testChineseInterfaceUsesChineseStrings() {
        app.terminate()
        launchApp(language: "zh-Hans", locale: "zh_CN")
        switchTool("overview.bookletTool", expecting: "booklet.settings")

        XCTAssertTrue(
            localizedText("小册子设置").waitForExistence(timeout: 15),
            "中文环境缺少小册子设置标题。\(app.debugDescription)"
        )
        XCTAssertTrue(localizedText("输出纸张").exists, "输出纸张未本地化")
        XCTAssertTrue(localizedText("边距").exists, "边距未本地化")
        XCTAssertTrue(localizedText("装订线间距").exists, "装订线未本地化")
        XCTAssertFalse(
            localizedText("Booklet Settings").exists,
            "中文环境错误显示英文「Booklet Settings」。\(app.debugDescription)"
        )
    }

    /// 拆分工具的文案随语言切换。
    func testSplitToolFollowsSystemLanguage() {
        switchTool("overview.splitTool", expecting: "split.cutPoint.1")
        XCTAssertTrue(localizedText("Page Sequence").waitForExistence(timeout: 10), "英文环境缺少页面序列")
        XCTAssertTrue(localizedText("Split Result").exists, "英文环境缺少拆分结果")

        app.terminate()
        launchApp(language: "zh-Hans", locale: "zh_CN")
        switchTool("overview.splitTool", expecting: "split.cutPoint.1")

        XCTAssertTrue(localizedText("页面序列").waitForExistence(timeout: 10), "页面序列未本地化")
        XCTAssertTrue(localizedText("拆分结果").exists, "拆分结果未本地化")
        XCTAssertFalse(
            localizedText("Split Result").exists,
            "中文环境错误显示英文「Split Result」。\(app.debugDescription)"
        )
    }

    /// 繁体中文同样可用，且不回落为英文或简体中文。
    func testTraditionalChineseIsFullyTranslated() {
        app.terminate()
        launchApp(language: "zh-Hant", locale: "zh_TW")
        switchTool("overview.bookletTool", expecting: "booklet.settings")

        XCTAssertTrue(
            localizedText("小冊子設置").waitForExistence(timeout: 15),
            "繁体环境缺少设置标题。\(app.debugDescription)"
        )
        XCTAssertTrue(localizedText("輸出紙張").exists, "繁体环境输出纸张未本地化")
        XCTAssertFalse(
            localizedText("Booklet Settings").exists,
            "繁体环境回落为英文。\(app.debugDescription)"
        )
    }

    /// 切换语言后，锚点结构不变——界面结构与语言解耦。
    ///
    /// 这条用例同时验证锚点的稳定性：若某处 identifier 误用了本地化文案，
    /// 切换语言后元素就会查找不到。
    func testAnchorsSurviveLanguageSwitch() {
        let before = [
            "booklet.settings",
            "booklet.outputPaper",
            "booklet.layoutPicker",
            "booklet.slider.margin",
            "booklet.padBlankPage",
            "workspace.primaryAction",
        ]
        for anchor in before {
            XCTAssertTrue(
                element(anchor).waitForExistence(timeout: 10),
                "英文环境缺少锚点 \(anchor)。\(app.debugDescription)"
            )
        }

        app.terminate()
        launchApp(language: "zh-Hans", locale: "zh_CN")
        switchTool("overview.bookletTool", expecting: "booklet.settings")

        for anchor in before {
            XCTAssertTrue(
                element(anchor).waitForExistence(timeout: 10),
                "切换到中文后锚点 \(anchor) 失效。\(app.debugDescription)"
            )
        }
    }
}
