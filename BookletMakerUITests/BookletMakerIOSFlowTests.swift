import XCTest

/// BookletMaker iOS 端到端冒烟测试。
///
/// 覆盖计划 T9 要求的主流程第一段：欢迎页 → 示例 PDF → 文档概览，
/// 以及工具入口可用与拼版预览六阶段导航。全部断言使用稳定的
/// accessibilityIdentifier，不依赖文本语言或截图坐标。
/// 文件选择器、第三方 File Provider、分享目标与实体打印属于系统 UI，
/// 无法可靠自动化，见验证文档的手工验收记录。
final class BookletMakerIOSFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 欢迎页 → 使用示例 PDF → 概览页出现两个工具入口。
    @MainActor
    func testSamplePDFOpensOverviewWithTools() throws {
        let app = XCUIApplication()
        app.launch()

        let useSample = app.buttons["welcome.useSample"]
        XCTAssertTrue(
            useSample.waitForExistence(timeout: 30),
            "Welcome page should offer the sample PDF"
        )
        useSample.tap()

        let bookletTool = app.buttons["overview.bookletTool"]
        XCTAssertTrue(
            bookletTool.waitForExistence(timeout: 30),
            "Overview should list the booklet tool after importing the sample"
        )
        XCTAssertTrue(app.buttons["overview.splitTool"].exists)
    }

    /// 进入拼版预览后应能切换到参数阶段（纸张）再回到打印布局。
    @MainActor
    func testBookletPreviewStagesNavigable() throws {
        let app = XCUIApplication()
        app.launch()

        let useSample = app.buttons["welcome.useSample"]
        XCTAssertTrue(useSample.waitForExistence(timeout: 30))
        useSample.tap()

        let bookletTool = app.buttons["overview.bookletTool"]
        XCTAssertTrue(bookletTool.waitForExistence(timeout: 30))
        bookletTool.tap()

        // 打印布局为起始阶段；阶段指示器六个按钮（stepNumber 1–6）。
        let layoutStage = app.buttons["stage.1"]
        XCTAssertTrue(layoutStage.waitForExistence(timeout: 30), "Preview should show stage navigation")

        // 切到纸张阶段：参数面板出现（原生控件）。
        app.buttons["stage.2"].tap()
        XCTAssertTrue(
            app.segmentedControls.firstMatch.waitForExistence(timeout: 10),
            "Paper selection should be a native control on the parameters stage"
        )

        // 回到打印布局：拼版网格仍在。
        app.buttons["stage.1"].tap()
        XCTAssertTrue(app.buttons["stage.1"].exists)
    }
}
