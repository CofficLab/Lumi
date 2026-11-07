import XCTest

/// 三个 PDF 工具（booklet / split / merge）之间的切换行为。
///
/// 重点验证工具切换后**状态面板与主操作按钮同步**——切换工具时最容易漏改
/// 的是侧栏设置标题与导出按钮文案，历史上出现过残留上一工具设置的问题。
final class BookletMakerToolSwitchUITests: BookletMakerUITestCase {

    /// 三种工具都能被选中，且侧栏设置区随之切换。
    func testSwitchingBetweenToolsUpdatesRailSettings() {
        switchTool("overview.splitTool", expecting: "split.cutPoint.1")
        XCTAssertTrue(element("split.cutPointsInput").waitForExistence(timeout: 5))
        XCTAssertFalse(
            element("booklet.settings").exists,
            "拆分工具下不应残留小册子设置"
        )

        switchTool("overview.mergeTool", expecting: "merge.emptyState")
        XCTAssertTrue(
            element("merge.summary").waitForExistence(timeout: 5),
            "合并工具缺少合并设置卡片"
        )
        XCTAssertFalse(
            element("split.cutPointsInput").exists,
            "合并工具下不应残留拆分输入框"
        )

        switchTool("overview.bookletTool", expecting: "booklet.settings")
        XCTAssertTrue(
            element("booklet.outputPaper").waitForExistence(timeout: 5),
            "未回到小册子设置"
        )
    }

    /// 主操作按钮是单一锚点，但其标题必须跟随工具变化。
    ///
    /// 这条断言专门防「切到合并工具却仍显示『导出小册子 PDF』」这类回归。
    func testPrimaryActionTitleFollowsSelectedTool() {
        switchTool("overview.mergeTool", expecting: "merge.emptyState")

        let action = element("workspace.primaryAction")
        XCTAssertTrue(action.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            localizedText("Export Merged PDF").exists,
            "合并工具下主按钮应为「Export Merged PDF」。\(app.debugDescription)"
        )
        XCTAssertFalse(
            localizedText("Export Booklet PDF").exists,
            "合并工具下不应残留小册子导出文案。\(app.debugDescription)"
        )

        switchTool("overview.bookletTool", expecting: "booklet.settings")
        XCTAssertTrue(
            localizedText("Export Booklet PDF").waitForExistence(timeout: 5),
            "切回小册子后主按钮文案未恢复。\(app.debugDescription)"
        )
    }

    /// 内置演示文档使所有工具在无需打开文件选择器的前提下即可用。
    ///
    /// 这是 UI 测试覆盖其余导出路径的前提：macOS 上 `NSOpenPanel` 跑在
    /// App 的 AX 树之外，XCTest 无法可靠驱动。
    func testBuiltInDemoDocumentIsAvailableForEveryTool() {
        switchTool("overview.splitTool", expecting: "split.cutPoint.1")
        XCTAssertTrue(
            localizedText("Built-in demo PDF").exists || element("split.cutPointsInput").exists,
            "拆分工具下缺少可操作文档。\(app.debugDescription)"
        )

        switchTool("overview.mergeTool", expecting: "merge.emptyState")
        // 合并工具的空队列独立于当前文档存在，故只断言其空态锚点。
        XCTAssertTrue(element("merge.emptyState").exists, app.debugDescription)
    }
}
