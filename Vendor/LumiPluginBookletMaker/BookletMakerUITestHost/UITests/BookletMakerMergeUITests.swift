import XCTest

/// 合并（Merge）工具的队列行为。
///
/// 范围说明：macOS 上添加源文件走 `NSOpenPanel.runModal()`，面板运行在 App
/// 的 AX 树之外且文件列表依赖用户最近目录，XCTest 无法可靠驱动。因此这里只
/// 覆盖无需面板即可到达的状态：空队列、门控原因、汇总与本地化。队列的
/// 排序、页数与导出逻辑由 `LumiPluginBookletMaker` 的单元测试覆盖。
final class BookletMakerMergeUITests: BookletMakerUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        switchTool("overview.mergeTool", expecting: "merge.emptyState")
    }

    /// 空队列：显示空态、给出「至少两个文件」提示、导出禁用。
    func testEmptyQueueShowsHintAndBlocksExport() {
        XCTAssertTrue(
            element("merge.emptyState").waitForExistence(timeout: 10),
            "合并工具缺少空态视图。\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("merge.dropZone").exists,
            "合并工具缺少文件拖放区。\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("merge.insufficientHint").waitForExistence(timeout: 10),
            "缺少「至少选择两个文件」提示。\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("merge.fileList").exists,
            "空队列不应出现文件列表。\(app.debugDescription)"
        )

        let export = element("workspace.primaryAction")
        XCTAssertTrue(export.waitForExistence(timeout: 5), "缺少主操作按钮")
        XCTAssertFalse(
            export.isEnabled,
            "文件不足两个时导出按钮必须禁用。\(app.debugDescription)"
        )
    }

    /// 合并视图的标题与副标题。
    func testMergeWorkspaceHeaderIsRendered() {
        XCTAssertTrue(localizedText("Merge PDF Files").waitForExistence(timeout: 10), "缺少合并视图标题")
        XCTAssertTrue(
            localizedText("Arrange the files, then export one combined PDF.").exists,
            "缺少合并视图副标题。\(app.debugDescription)"
        )
    }

    /// 侧栏在合并工具下显示合并设置与小册子设置互斥。
    func testMergeSettingsCardReplacesBookletSettings() {
        XCTAssertTrue(
            element("merge.summary").waitForExistence(timeout: 5),
            "缺少合并结果卡片。\(app.debugDescription)"
        )
        XCTAssertTrue(localizedText("Merge Settings").exists, "侧栏缺少合并设置标题")
        XCTAssertFalse(
            localizedText("Booklet Settings").exists,
            "合并工具下不应残留小册子设置。\(app.debugDescription)"
        )
    }

    /// 汇总标签始终渲染，并如实反映队列规模（0 文件 / 0 页）。
    func testSummaryReflectsEmptyQueue() {
        let summary = element("merge.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "缺少合并统计标签")
        XCTAssertEqual(
            text(of: summary), "0 files · 0 pages",
            "空队列汇总应为 0 文件 0 页。\(app.debugDescription)"
        )
    }

    /// 合并界面随系统语言切换，且中文界面不残留英文。
    ///
    /// 这是「英文漏进中文界面」这类 bug 的回归防线：缺失的 key 会静默回退
    /// 到英文源串，正是本用例要捕获的现象。
    func testMergeInterfaceFollowsSystemLanguage() {
        XCTAssertTrue(localizedText("Merge Settings").waitForExistence(timeout: 10), app.debugDescription)

        app.terminate()
        launchApp(language: "zh-Hans", locale: "zh_CN")
        switchTool("overview.mergeTool", expecting: "merge.emptyState")

        XCTAssertTrue(localizedText("合并 PDF 文件").waitForExistence(timeout: 10), "合并视图标题未本地化")
        XCTAssertTrue(localizedText("合并设置").exists, "侧栏合并设置未本地化")
        XCTAssertFalse(
            localizedText("Merge Settings").exists,
            "中文界面错误显示英文「Merge Settings」。\(app.debugDescription)"
        )
    }
}
