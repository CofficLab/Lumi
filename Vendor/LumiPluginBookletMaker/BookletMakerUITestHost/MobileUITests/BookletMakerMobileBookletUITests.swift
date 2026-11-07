import XCTest

/// 小册子（Booklet）工具在移动端的六步向导。
///
/// 移动端是「拼版预览 → 纸张与版式 → 总览 → 导出」的六步向导，阶段由
/// 底部「上一步 / 下一步」线性推进，每一屏只回答一件事（产品原型
/// `03-print-layout` … `07-export-booklet`）。因此这里覆盖的是：阶段推进、
/// 每张纸的正反面切换、参数面板的绑定与门控、拼版页序正确性。
final class BookletMakerMobileBookletUITests: BookletMakerMobileUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // 主线是「首页工具卡 → 引导页 → 工作台」，没有概览页这一层。
        openSampleDocument(tool: "booklet")
    }

    /// 六步向导的阶段标题随步骤线性变化。
    ///
    /// 回归重点：阶段曾被换成「顶部一排标签页 + 两列缩略图网格」，
    /// 与产品原型的逐屏向导完全不符。这里断言阶段标题，确保线性推进结构
    /// 不再被悄悄改回标签页。
    func testStageTitleAdvancesWithEachStep() {
        let stageTitle = element("booklet.stageTitle")
        XCTAssertTrue(stageTitle.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertEqual(text(of: stageTitle), "Print Layout")

        let next = app.buttons["booklet.stepNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "缺少底部「下一步」按钮")

        next.tap()
        XCTAssertEqual(waitForText(of: stageTitle, toBe: "Paper and Layout"), "Paper and Layout")

        next.tap()
        XCTAssertEqual(waitForText(of: stageTitle, toBe: "Review"), "Review")

        next.tap()
        XCTAssertEqual(waitForText(of: stageTitle, toBe: "Export"), "Export")
    }

    /// 每张物理纸都能切到背面。
    ///
    /// 双面打印的背面此前被静默砍掉：预览只给正面，用户无从确认折起来
    /// 之后页序是否正确 —— 而这正是小册子最容易出错的地方。
    func testEverySheetOffersFrontAndBack() {
        // 示例文档 8 页 → 2 张纸，每张纸都有正反两面。
        //
        // 第 1 张纸在首屏，用 `scrollTo` 确认可点；第 2 张纸在下方，
        // 只断言存在 —— 它的可点性由纵向滚动负责，测试里强行把它滚进来
        // 会与滚动容器的方向判定打架，反而变得不稳定。
        XCTAssertTrue(
            scrollTo("booklet.side.0.back"),
            "第 1 张纸应提供「背面」切换。\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("booklet.side.1.back").waitForExistence(timeout: 10),
            "第 2 张纸应提供「背面」切换。\(app.debugDescription)"
        )

        // 切到背面后，页面配对应变成内侧的两页。
        element("booklet.side.0.back").tap()
        let back = text(of: element("booklet.side.0.back"))
        XCTAssertTrue(
            back.contains("2 + 7"),
            "第 1 张纸的背面应为页 2 与 7，实际为「\(back)」。\(app.debugDescription)"
        )
    }

    /// 拼版预览的页序正确。
    ///
    /// 直接读打印面预览图的 accessibilityLabel：它由代码拼成
    /// 「Print side N: pages X and Y」，其中的页码由 `BookletLayoutEngine`
    /// 决定，是拼版引擎输出最直接的体现。
    ///
    /// ## 为什么第 1 面是「8 和 1」而不是「1 和 8」
    ///
    /// 侧别与页序的对应由 `OutputSheet` 决定，`leftPage` 落在纸张左侧。
    /// 8 页书本折叠时，第 1 个打印面的左侧是末页 8、右侧是首页 1——这正是
    /// 对折后能顺读的原因（把第 1 面朝上折，末页落在外侧）。
    ///
    /// 预览一次只显示每张纸的**一面**（正面或背面，靠切换），所以 4 个
    /// 打印面要分两次才看得到：先看两张纸的正面，再切到背面看内侧。
    func testPrintSideLabelsCarryCorrectPagePairs() {
        // 两张纸的正面：(8,1) 与 (6,3)；切到背面后是内侧的 (2,7) 与 (4,5)。
        let sheets: [(front: (Int, Int), back: (Int, Int))] = [
            ((8, 1), (2, 7)),
            ((6, 3), (4, 5))
        ]

        for (index, sides) in sheets.enumerated() {
            let frontAnchor = "booklet.printSide.\(index * 2)"
            XCTAssertTrue(
                scrollTo(frontAnchor),
                "缺少第 \(index + 1) 张纸的正面。\(app.debugDescription)"
            )
            let front = text(of: element(frontAnchor))
            XCTAssertTrue(
                front.contains("\(sides.front.0)") && front.contains("\(sides.front.1)"),
                "第 \(index + 1) 张纸正面应为页 \(sides.front.0) 与 \(sides.front.1)，"
                    + "实际为「\(front)」。\(app.debugDescription)"
            )

            // 切到背面，内侧的两页才可见。
            let backToggle = "booklet.side.\(index).back"
            XCTAssertTrue(
                scrollTo(backToggle),
                "缺少第 \(index + 1) 张纸的「背面」切换。\(app.debugDescription)"
            )
            element(backToggle).tap()

            let backAnchor = "booklet.printSide.\(index * 2 + 1)"
            XCTAssertTrue(
                scrollTo(backAnchor),
                "缺少第 \(index + 1) 张纸的背面。\(app.debugDescription)"
            )
            let back = text(of: element(backAnchor))
            XCTAssertTrue(
                back.contains("\(sides.back.0)") && back.contains("\(sides.back.1)"),
                "第 \(index + 1) 张纸背面应为页 \(sides.back.0) 与 \(sides.back.1)，"
                    + "实际为「\(back)」。\(app.debugDescription)"
            )
        }
    }

    /// 参数面板的纸张、版式与间距控件均可见可用。
    func testParameterControlsArePresent() {
        // 第 2 步是「纸张与版式」。
        element("booklet.stepNext").tap()

        XCTAssertTrue(scrollTo("params.paper"), "缺少输出纸张设置")
        XCTAssertTrue(scrollTo("params.layout"), "缺少版式设置")
        XCTAssertTrue(scrollTo("params.margin"), "缺少边距滑块")
        XCTAssertTrue(scrollTo("params.gutter"), "缺少装订线滑块")
        XCTAssertTrue(scrollTo("params.cutMarks"), "缺少裁切标记开关")
        XCTAssertTrue(scrollTo("params.padBlank"), "缺少补白开关")
    }

    /// 分册版式可选，并提供「每册页数」。
    ///
    /// 回归重点：分册版式（`signatureFold`）在共享包迁移时被从参数面板里
    /// 删掉了，只剩折叠与简单并排两种，长文档无法拆成可独立装订的小册。
    func testSectionedBookletLayoutIsSelectable() {
        element("booklet.stepNext").tap()
        XCTAssertTrue(scrollTo("params.layout"), "缺少版式设置")

        element("params.layout").tap()
        let sectioned = app.buttons["Sectioned Booklet"]
        XCTAssertTrue(sectioned.waitForExistence(timeout: 10), app.debugDescription)
        sectioned.tap()

        XCTAssertTrue(
            scrollTo("params.signaturePages"),
            "分册版式应提供「每册页数」选择器。\(app.debugDescription)"
        )
    }

    /// 补白开关在书本折叠版式下强制禁用。
    ///
    /// 对应 ViewModel 的业务规则：bookletFold 本身已按 4 的倍数补页，
    /// 再叠加补白会产生重复空白。允许用户开启会导致页数与预览不一致。
    func testPadBlankDisabledUnderBookletFold() {
        element("booklet.stepNext").tap()
        assertDisabled("params.padBlank")

        // 切到简单对折版式后应可用。
        XCTAssertTrue(scrollTo("params.layout"))
        element("params.layout").tap()
        let simplePair = app.buttons["Simple Pair"]
        XCTAssertTrue(simplePair.waitForExistence(timeout: 10), app.debugDescription)
        simplePair.tap()

        XCTAssertTrue(
            scrollTo("params.padBlank"),
            "切换版式后补白开关消失。\(app.debugDescription)"
        )
        assertEnabled("params.padBlank")
    }

    /// 总览阶段保留翻页跨页预览。
    ///
    /// 这是「折起来能不能顺读」的唯一可视检查点。
    func testReviewStageKeepsTheFlipPreview() {
        element("booklet.stepNext").tap()  // 纸张与版式
        element("booklet.stepNext").tap()  // 总览

        // 先等阶段标题变成「总览」再断言预览：点完「下一步」到视图切换
        // 完成之间有一帧的延迟，直接查会偶尔扑空。
        let stageTitle = element("booklet.stageTitle")
        XCTAssertEqual(
            waitForText(of: stageTitle, toBe: "Review"),
            "Review",
            "第 3 步应为总览。\(app.debugDescription)"
        )
        XCTAssertTrue(
            app.staticTexts["Preview the booklet"].waitForExistence(timeout: 10),
            "总览页应保留翻页跨页预览。\(app.debugDescription)"
        )
    }

    /// 导出阶段提供分享与保存。
    func testExportStageOffersShareAndSave() {
        element("booklet.stepNext").tap()  // 纸张与版式
        element("booklet.stepNext").tap()  // 总览
        element("booklet.stepNext").tap()  // 导出

        XCTAssertTrue(
            app.buttons["Share"].waitForExistence(timeout: 30),
            "导出阶段应提供「分享」。\(app.debugDescription)"
        )
        XCTAssertTrue(app.buttons["Save to Files"].exists, "导出阶段应提供「保存到文件」")
    }

    /// 等待某个元素的文案变成期望值。
    private func waitForText(
        of element: XCUIElement,
        toBe expected: String,
        timeout: TimeInterval = 10
    ) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if text(of: element) == expected { return expected }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return text(of: element)
    }
}
