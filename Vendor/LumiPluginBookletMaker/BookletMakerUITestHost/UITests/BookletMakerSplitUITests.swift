import XCTest

/// 拆分（Split）工具的交互行为。
///
/// 覆盖要点：切分点的增删互为反选、结果随之重算、导出按钮的门控随
/// 切分点有效性变化。门控逻辑（`canExportSplit`）同时有单元测试，这里
/// 验证的是**门控在真实 UI 上确实生效**。
final class BookletMakerSplitUITests: BookletMakerUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // 以首个切分点作为「拆分工作区已就绪」信号：演示 PDF 有 8 页，
        // 至少存在 7 个可切分位置，这个锚点必然出现。
        switchTool("overview.splitTool", expecting: "split.cutPoint.1")
    }

    /// 未选择切分点时：提示可见、导出禁用。
    func testExportStaysDisabledUntilCutPointExists() {
        XCTAssertTrue(
            element("split.needsCutPoint").waitForExistence(timeout: 10),
            "缺少「至少一个切分点」提示。\(app.debugDescription)"
        )

        let export = element("workspace.primaryAction")
        XCTAssertTrue(export.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(
            export.isEnabled,
            "未选切分点时导出按钮必须禁用。\(app.debugDescription)"
        )
    }

    /// 点击切分点后：提示消失、按钮启用、结果数量重算。
    func testAddingCutPointEnablesExportAndUpdatesResults() {
        let cutPoint = element("split.cutPoint.1")
        XCTAssertTrue(cutPoint.waitForExistence(timeout: 10), "缺少第 1 页切分点。\(app.debugDescription)")
        XCTAssertTrue(hasValue(cutPoint, "unselected"), "切分点初始应为未选中")

        cutPoint.click()

        XCTAssertTrue(
            hasValue(cutPoint, "selected"),
            "点击后切分点未进入选中态。\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("split.needsCutPoint").exists,
            "已选切分点后不应继续显示提示"
        )

        let export = element("workspace.primaryAction")
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertTrue(export.isEnabled, "已选切分点后导出按钮应启用。\(app.debugDescription)")

        // 演示 PDF 为 8 页，在第 1 页后切分应得到 2 个结果文件。
        let summary = element("split.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "缺少拆分结果统计")
        XCTAssertEqual(
            text(of: summary), "2 PDF files",
            "8 页在第 1 页后切分应产生 2 个文件。\(app.debugDescription)"
        )
    }

    /// 再次点击同一页应取消选中，导出随之重新禁用——切分点是可反选的开关。
    func testTogglingCutPointTwiceDisablesExportAgain() {
        let cutPoint = element("split.cutPoint.1")
        XCTAssertTrue(cutPoint.waitForExistence(timeout: 10), app.debugDescription)

        cutPoint.click()
        XCTAssertTrue(hasValue(cutPoint, "selected"), "首次点击未选中")

        cutPoint.click()
        XCTAssertTrue(hasValue(cutPoint, "unselected"), "二次点击应回到未选中")

        XCTAssertTrue(
            element("split.needsCutPoint").waitForExistence(timeout: 5),
            "取消切分点后提示应重新出现"
        )
        let export = element("workspace.primaryAction")
        XCTAssertFalse(export.isEnabled, "取消切分点后导出应禁用。\(app.debugDescription)")
    }

    /// 两个切分点应互不影响，各自独立记录选中态。
    func testMultipleCutPointsAreIndependent() {
        let first = element("split.cutPoint.1")
        let second = element("split.cutPoint.2")
        XCTAssertTrue(first.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(second.waitForExistence(timeout: 5), "缺少第 2 页切分点")

        first.click()
        second.click()

        XCTAssertTrue(hasValue(first, "selected"), "第 1 处应保持选中")
        XCTAssertTrue(hasValue(second, "selected"), "第 2 处应独立选中")

        // 8 页切 2 处 → 3 段。
        let summary = element("split.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: summary), "3 PDF files", "2 个切分点应产生 3 个文件。\(app.debugDescription)")
    }

    /// 侧栏文本框输入的切分点应与页面点击等价地驱动结果重算。
    ///
    /// 两条输入路径共享同一状态，但各自绑定了不同的 UI 控件，需分别覆盖。
    func testTypingCutPointsInRailUpdatesResults() {
        let input = element("split.cutPointsInput")
        XCTAssertTrue(input.waitForExistence(timeout: 10), "侧栏缺少切分点输入框。\(app.debugDescription)")

        // 先清空：该字段与切分点集合双向绑定，页面点击会把它回填成
        // "1, 2" 这类形式，直接输入会与既有内容拼接。
        input.click()
        input.typeKey("a", modifierFlags: .command)
        input.typeText("1,3")

        XCTAssertTrue(
            hasValue(element("split.cutPoint.3"), "selected"),
            "输入的切分点 3 应同步到页面按钮。\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("split.cutPoint.2").value as? String == "selected",
            "清空后第 2 处不应仍处于选中态。\(app.debugDescription)"
        )
        let summary = element("split.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(
            text(of: summary), "3 PDF files",
            "输入 2 个切分点（1、3）应产生 3 个文件。\(app.debugDescription)"
        )
    }

    /// 非法输入应给出校验错误且不放行导出。
    func testInvalidCutPointsShowValidationAndBlockExport() {
        let input = element("split.cutPointsInput")
        XCTAssertTrue(input.waitForExistence(timeout: 10), app.debugDescription)

        input.click()
        input.typeText("0")

        XCTAssertTrue(
            element("split.validationError").waitForExistence(timeout: 5),
            "切分点 0 越界，应显示校验错误。\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("workspace.primaryAction").isEnabled,
            "校验未通过时导出必须禁用。\(app.debugDescription)"
        )
    }

    /// 选中切分点后，每个分段都可重命名其输出文件名。
    func testSegmentOutputFileNameIsEditable() {
        let cutPoint = element("split.cutPoint.1")
        XCTAssertTrue(cutPoint.waitForExistence(timeout: 10), app.debugDescription)
        cutPoint.click()
        XCTAssertTrue(hasValue(cutPoint, "selected"), "切分点未选中")

        let field = element("split.segment.1.fileName")
        XCTAssertTrue(field.waitForExistence(timeout: 5), "缺少分段文件名输入框")

        // 断言重命名前后输入框确有变化：先记录默认文件名再改写。
        let before = field.value as? String ?? field.label
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("renamed")

        let after = field.value as? String ?? field.label
        XCTAssertNotEqual(
            after, before,
            "重命名后输入框值应变化。\(app.debugDescription)"
        )
        XCTAssertTrue(
            after.contains("renamed"),
            "重命名后应回显新文件名，实际为 \(after)。\(app.debugDescription)"
        )
    }
}
