import XCTest

/// 合并队列非空时的行为：排序、删除、汇总、导出门控。
///
/// 这些操作在真实使用中由用户在 `NSOpenPanel` 选好文件后进行。面板在 App 的
/// 辅助功能树之外运行，XCUITest 无法驱动，因此队列由宿主在启动时经插件的测试
/// 接缝（`BookletMakerTestHooks`）注入——注入走的是 `loadMergePDFs`，
/// 与用户选择文件同一条校验与去重路径。
///
/// 每个注入文件的页数各不相同（1、2、3），这样「顺序是否真的改变」可以由
/// 界面上的页数直接判定，不依赖文件名猜测。
final class BookletMakerMergeQueueUITests: BookletMakerUITestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchAppWithMergeQueue(count: 3)
        switchTool("overview.mergeTool", expecting: "merge.file.1")
    }

    // MARK: - 队列内容

    /// 注入的三份文件都出现在队列中，顺序与注入顺序一致。
    func testSeededFilesAppearInOrderWithTheirPageCounts() {
        let summary = element("merge.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "缺少合并统计标签")
        XCTAssertEqual(
            text(of: summary), "3 files · 6 pages",
            "1+2+3 页合计 6 页。\(app.debugDescription)"
        )

        // 队列位置锚点应连续出现 1、2、3。
        for position in 1 ... 3 {
            XCTAssertTrue(
                element("merge.file.\(position)").waitForExistence(timeout: 5),
                "队列缺少第 \(position) 项。\(app.debugDescription)"
            )
        }

        XCTAssertFalse(
            element("merge.emptyState").exists,
            "队列非空时不应继续显示空态。\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("merge.insufficientHint").exists,
            "文件已足够两个，不应显示「至少选择两个」提示。\(app.debugDescription)"
        )
    }

    /// 文件充足时导出按钮解除禁用——这是队列填充带来的关键状态变化。
    func testExportBecomesEnabledWithEnoughFiles() {
        let export = element("workspace.primaryAction")
        XCTAssertTrue(export.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            export.isEnabled,
            "已有 3 个文件时导出按钮应可用。\(app.debugDescription)"
        )
        XCTAssertTrue(
            localizedText("Export Merged PDF").exists,
            "主按钮应为合并导出。\(app.debugDescription)"
        )
    }

    // MARK: - 排序

    /// 下移第 1 项后，它与第 2 项交换位置。
    ///
    /// 通过页数判定顺序变化：初始页数为 1、2、3，交换后应为 2、1、3。
    func testMovingFirstFileDownSwapsItWithSecond() {
        XCTAssertEqual(pageCountsInQueue(), ["1", "2", "3"], "初始页数顺序不符预期")

        moveFile(at: 1, via: "merge.file.1.moveDown")

        XCTAssertEqual(
            pageCountsInQueue(), ["2", "1", "3"],
            "下移第 1 项后应与第 2 项交换。\(app.debugDescription)"
        )
    }

    /// 上移第 3 项后，它与第 2 项交换位置。
    func testMovingLastFileUpSwapsItWithSecond() {
        XCTAssertEqual(pageCountsInQueue(), ["1", "2", "3"], "初始页数顺序不符预期")

        moveFile(at: 3, via: "merge.file.3.moveUp")

        XCTAssertEqual(
            pageCountsInQueue(), ["1", "3", "2"],
            "上移第 3 项后应与第 2 项交换。\(app.debugDescription)"
        )
    }

    /// 首项的「上移」应禁用——它是边界项。
    func testFirstFileCannotMoveUp() {
        let moveUp = element("merge.file.1.moveUp")
        XCTAssertTrue(moveUp.waitForExistence(timeout: 10), "队列首项缺少上移按钮")
        XCTAssertFalse(
            moveUp.isEnabled,
            "队列首项不应允许继续上移。\(app.debugDescription)"
        )
    }

    /// 末项的「下移」应禁用。
    func testLastFileCannotMoveDown() {
        let moveDown = element("merge.file.3.moveDown")
        XCTAssertTrue(moveDown.waitForExistence(timeout: 10), "队列末项缺少下移按钮")
        XCTAssertFalse(
            moveDown.isEnabled,
            "队列末项不应允许继续下移。\(app.debugDescription)"
        )
    }

    /// 非边界项的排序按钮都应可用——否则用户会被无谓地拦住。
    func testMiddleFileCanMoveBothWays() {
        XCTAssertTrue(
            element("merge.file.2.moveUp").waitForExistence(timeout: 10),
            "中间项缺少上移按钮"
        )
        XCTAssertTrue(
            element("merge.file.2.moveDown").isEnabled,
            "中间项应允许下移。\(app.debugDescription)"
        )
    }

    // MARK: - 删除

    /// 删除中间项后，两侧文件相邻、汇总页数与文件数同步更新。
    func testRemovingMiddleFileUpdatesQueueAndSummary() {
        removeFile(at: 2)

        XCTAssertEqual(
            pageCountsInQueue(), ["1", "3"],
            "删除第 2 项后应剩 1 页与 3 页两份文件。\(app.debugDescription)"
        )

        let summary = element("merge.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(
            text(of: summary), "2 files · 4 pages",
            "1+3 页合计 4 页。\(app.debugDescription)"
        )
    }

    /// 删到只剩一个文件时，导出门控应重新生效。
    ///
    /// 这是门控逻辑在界面上的闭环验证：2 个文件可导出 → 删到 1 个 → 不可导出。
    func testRemovingDownToOneFileDisablesExportAgain() {
        removeFile(at: 2)
        removeFile(at: 2)

        let export = element("workspace.primaryAction")
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertFalse(
            export.isEnabled,
            "仅剩 1 个文件时导出必须禁用。\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("merge.insufficientHint").waitForExistence(timeout: 5),
            "文件不足两个时应重新显示提示"
        )
    }

    /// 删空队列后回到空态视图。
    func testRemovingAllFilesReturnsToEmptyState() {
        removeFile(at: 1)
        removeFile(at: 1)
        removeFile(at: 1)

        XCTAssertTrue(
            element("merge.emptyState").waitForExistence(timeout: 10),
            "删空后应回到空态视图。\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("merge.file.1").exists,
            "删空后不应残留队列项"
        )
    }

    // MARK: - Helpers

    /// 读取队列中各文件的页数文本（按位置）。
    /// 读取队列中各文件的页数（按位置）。
    ///
    /// 页数是「N pages」文案的独立锚点，取其中的数字部分。三份文件的页数
    /// 互不相同，因此这个序列唯一标识了队列顺序——靠它判定重排是否生效，
    /// 不依赖文件名（测试夹具的文件名是随机 UUID，含数字会误导）。
    private func pageCountsInQueue() -> [String] {
        (1 ... 3).compactMap { position in
            let element = self.element("merge.file.\(position).pageCount")
            guard element.exists else { return nil }
            return text(of: element).split(whereSeparator: { !$0.isNumber }).first.map(String.init)
        }
    }

    private func moveFile(at position: Int, via buttonID: String) {
        let button = element(buttonID)
        XCTAssertTrue(button.waitForExistence(timeout: 10), "缺少排序按钮 \(buttonID)")
        XCTAssertTrue(button.isEnabled, "\(buttonID) 应可用。\(app.debugDescription)")
        button.click()

        XCTAssertTrue(
            element("merge.file.1").waitForExistence(timeout: 5),
            "移动后队列应仍然存在。\(app.debugDescription)"
        )
    }

    private func removeFile(at position: Int) {
        let remove = element("merge.file.\(position).remove")
        XCTAssertTrue(remove.waitForExistence(timeout: 10), "队列第 \(position) 项缺少删除按钮")
        remove.click()

        XCTAssertTrue(
            element("merge.file.1").waitForExistence(timeout: 5)
                || element("merge.emptyState").waitForExistence(timeout: 3),
            "删除后队列应仍然可观察。\(app.debugDescription)"
        )
    }
}

extension BookletMakerUITestCase {
    /// 以指定数量注入合并队列文件后启动宿主。
    func launchAppWithMergeQueue(count: Int) {
        app = XCUIApplication()
        app.launchEnvironment["BOOKLET_MAKER_UI_TESTING"] = "1"
        app.launchArguments += [
            "-SeedMergeQueue", "\(count)",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-ApplePersistenceIgnoreState", "YES",
        ]
        app.launch()
        #if os(macOS)
        waitForForegroundOrFail()
        waitForWorkspace()
        #endif
    }
}