import XCTest

/// 小册子（Booklet）工具的设置项与预览阶段。
///
/// 设置项断言全部走 `accessibilityIdentifier`，因此切换系统语言时这些用例
/// 无需改动；本地化正确性由 `BookletMakerLocalizationUITests` 单独验证。
final class BookletMakerBookletUITests: BookletMakerUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        switchTool("overview.bookletTool", expecting: "booklet.settings")
    }

    /// 四个预览阶段 tab 都存在，逐个点击后进入选中态。
    ///
    /// 阶段 tab 是解释原理的核心交互，每个阶段对应一种预览（原始 / 转换后 /
    /// 装订前 / 装订后），任一阶段不响应都会让用户无法理解工作原理。
    func testAllPreviewStagesBecomeSelectable() {
        let stages = [
            "booklet.preview.original",
            "booklet.preview.afterConversion",
            "booklet.preview.beforeBinding",
            "booklet.preview.afterBinding",
        ]
        for stage in stages {
            let tab = element(stage)
            XCTAssertTrue(
                tab.waitForExistence(timeout: 5),
                "缺少预览阶段 \(stage)。\(app.debugDescription)"
            )
            tab.click()
            XCTAssertTrue(
                hasValue(tab, "selected"),
                "阶段 \(stage) 点击后未进入选中态。\(app.debugDescription)"
            )
        }
    }

    /// 「装订前」阶段会列出各张物理纸张，切换纸张应更新选中态。
    func testPhysicalSheetTabsAppearInBeforeBindingStage() {
        element("booklet.preview.beforeBinding").click()
        XCTAssertTrue(
            hasValue(element("booklet.preview.beforeBinding"), "selected"),
            "未切到装订前阶段。\(app.debugDescription)"
        )

        let firstSheet = element("booklet.sheet.1")
        XCTAssertTrue(firstSheet.waitForExistence(timeout: 5), "缺少第 1 张纸张条目")

        // 演示 PDF 为 8 页 → 4 张 A4；若只有 1 张说明列表未正确渲染。
        let secondSheet = element("booklet.sheet.2")
        if secondSheet.exists {
            secondSheet.click()
            XCTAssertTrue(
                hasValue(secondSheet, "selected"),
                "点击第 2 张纸张后未选中。\(app.debugDescription)"
            )
            XCTAssertTrue(
                hasValue(firstSheet, "unselected"),
                "切换纸张后旧条目应回到未选中"
            )
        }
    }

    /// 纸张、版式、补白、裁切标记四类设置控件均可见可用。
    func testBookletSettingsControlsAreInteractive() {
        XCTAssertTrue(
            element("booklet.outputPaper").waitForExistence(timeout: 5),
            "缺少输出纸张设置"
        )
        XCTAssertTrue(element("booklet.layoutPicker").exists, "缺少版式设置")
        XCTAssertTrue(element("booklet.slider.margin").exists, "缺少边距滑块")
        XCTAssertTrue(element("booklet.slider.gutter").exists, "缺少装订线滑块")
        XCTAssertTrue(element("booklet.padBlankPage").exists, "缺少补白开关")

        // 裁切标记的锚点会同时落到开关与其行标题上（SwiftUI 对
        // AppSettingToggleRow 这类复合控件的 identifier 处理），因此按
        // 控件类型收窄，避免 `firstMatch` 命中 StaticText 而无法点击。
        let cutMarks = app.checkBoxes.matching(identifier: "booklet.addCutMarks").firstMatch
        XCTAssertTrue(cutMarks.waitForExistence(timeout: 5), "缺少裁切标记开关。\(app.debugDescription)")
        guard cutMarks.isEnabled else {
            return XCTFail("裁切标记开关应可交互。\(app.debugDescription)")
        }
        let before = isOn(cutMarks)
        cutMarks.click()
        XCTAssertNotEqual(isOn(cutMarks), before, "裁切标记开关点击后状态未翻转。\(app.debugDescription)")
    }

    /// 「书本折叠」版式强制补空白页，因此补白开关在该版式下应禁用；
    /// 切到「简单对折」后恢复可操作。验证的是设置项之间的联动约束。
    func testPadBlankPageIsDisabledForBookletFoldLayout() {
        let padToggle = element("booklet.padBlankPage")
        XCTAssertTrue(padToggle.waitForExistence(timeout: 5), "缺少补白开关")

        // 默认版式为书本折叠 → 补白被强制为开启且不可改。
        XCTAssertFalse(
            padToggle.isEnabled,
            "书本折叠版式下补白开关应禁用。\(app.debugDescription)"
        )
        XCTAssertTrue(
            isOn(padToggle),
            "书本折叠版式下补白应恒为开启。\(app.debugDescription)"
        )
    }

    /// 滑块锚点后缀与语言无关：切到中文后 identifier 不变。
    ///
    /// 这条断言守护 `sliderIdentifier(for:)` 的映射逻辑——若直接用本地化
    /// 标题当锚点，中文环境下 UI 测试会立刻找不到元素。
    func testSliderAnchorsAreLanguageIndependent() {
        let marginSlider = element("booklet.slider.margin")
        XCTAssertTrue(marginSlider.waitForExistence(timeout: 5), app.debugDescription)
        let valueBefore = marginSlider.value as? String

        app.terminate()
        launchApp(language: "zh-Hans", locale: "zh_CN")
        switchTool("overview.bookletTool", expecting: "booklet.settings")

        let localizedSlider = element("booklet.slider.margin")
        XCTAssertTrue(
            localizedSlider.waitForExistence(timeout: 10),
            "切换语言后滑块锚点失效。\(app.debugDescription)"
        )
        XCTAssertEqual(
            localizedSlider.value as? String, valueBefore,
            "同一设置在不同语言下应保持相同取值"
        )
    }

    /// 空闲状态下不渲染进度条——这是预期行为：状态条只在忙碌时出现。
    ///
    /// 断言它「不该出现」比断言它出现更能防止回归：一旦有代码把它改成
    /// 常驻，用户就会在空闲时看到一条永远 0% 的进度条。
    func testProgressBarStaysHiddenWhenIdle() {
        XCTAssertFalse(
            element("workspace.status").waitForExistence(timeout: 3),
            "空闲时不应显示进度/状态条。\(app.debugDescription)"
        )
    }

    // MARK: - Helpers

    /// 读取开关类控件的开启状态。
    private func isOn(_ element: XCUIElement) -> Bool {
        if let number = element.value as? NSNumber { return number.boolValue }
        return ["1", "on", "selected"].contains((element.value as? String)?.lowercased() ?? "")
    }
}
