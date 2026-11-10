import XCTest

/// 三个 PDF 工具（booklet / split / merge）之间的切换行为。
///
/// 移动端的主线是「首页工具卡 → 全屏引导 → 直接进对应工具工作台」。
/// 概览页（`PDFDocumentOverviewView`）已经删除，因此这里没有「推入 / 弹出」
/// 这一层：每次切换都从首页重新进入，走一遍引导页。
///
/// 每条用例都从首页出发，因为工具工作台是导航栈的栈顶根页——工作台里
/// 只能通过「关闭文档」回到首页，无法直接跳到另一个工具。
final class BookletMakerMobileToolSwitchUITests: BookletMakerMobileUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // 停在首页：切换行为本身就是首页工具卡的职责。
        _ = element("welcome.bookletTool").waitForExistence(timeout: 20)
    }

    /// 通过导航栏「首页」按钮回到欢迎首页。
    ///
    /// 工具工作台是导航栈的栈顶根页，没有返回按钮；首页按钮是离开工作台
    /// 的唯一路径。
    private func closeDocument() {
        let homeButton = element("home.button")
        XCTAssertTrue(homeButton.waitForExistence(timeout: 10), app.debugDescription)
        homeButton.tap()

        XCTAssertTrue(
            element("welcome.bookletTool").waitForExistence(timeout: 10),
            "点首页按钮后未回到欢迎页。\(app.debugDescription)"
        )
    }

    /// 进入合并工具的工作台。
    ///
    /// 合并需要至少两个文件，引导页不提供「使用示例」。这里借用宿主的启动
    /// 参数注入队列：注入把工作区推进到 `.ready`，根视图随即渲染合并
    /// 工作台，**首页不会出现**——因此不能先走引导页。
    private func openMergeWorkspace(fileCount: Int = 3) {
        launchApp(
            language: "en",
            locale: "en_US",
            arguments: ["-SeedMergeQueue", String(fileCount)]
        )
        XCTAssertTrue(
            element("merge.summary").waitForExistence(timeout: 20),
            "注入队列后未进入合并工作台。\(app.debugDescription)"
        )
    }

    /// 三个工具入口都存在，且逐个进入后能看到各自工具页的专属锚点。
    ///
    /// 这条覆盖「工具入口与目标页的对应关系」——入口点得进去但落到错误的页，
    /// 或者某个入口缺失，都是真实的可用性缺陷。
    func testEveryToolEntryOpensItsOwnPage() {
        openSampleDocument(tool: "booklet")
        assertExists("booklet.stageTitle")
        assertExists("booklet.stepNext")

        backToWelcome()
        openSampleDocument(tool: "split")
        assertExists("split.export")
        assertNotExists("booklet.stageTitle")

        // 合并改用注入队列进入：引导页没有示例入口，且注入后首页不再出现。
        closeDocument()
        openMergeWorkspace()
        assertExists("merge.addPDFs")
        assertNotExists("split.export")
    }

    /// 每个工具页的主操作按钮文案跟随工具变化。
    ///
    /// 这条专门防「切到合并工具却仍显示『Make Booklet』」这类回归。
    func testPrimaryActionTitleFollowsTool() {
        openMergeWorkspace()
        XCTAssertTrue(
            localizedText("Merge").exists,
            "合并工具下主按钮应为「Merge」。\(app.debugDescription)"
        )
        XCTAssertFalse(
            localizedText("Make Booklet").exists,
            "合并工具下不应残留小册子导出文案。\(app.debugDescription)"
        )

        closeDocument()
        openSampleDocument(tool: "split")
        XCTAssertTrue(
            localizedText("Split").exists,
            "拆分工具下主按钮应为「Split」。\(app.debugDescription)"
        )
        XCTAssertFalse(
            localizedText("Merge").exists,
            "拆分工具下不应残留合并文案。\(app.debugDescription)"
        )

        backToWelcome()
        openSampleDocument(tool: "booklet")
        // 六步向导的主操作按钮在第 1 步是「下一步」，走到导出阶段才变成
        // 「制作小册子」。这里断言的是向导结构本身，不是某一个阶段的文案。
        XCTAssertTrue(
            localizedText("Next").exists,
            "小册子工具下主按钮应为「下一步」。\(app.debugDescription)"
        )
        XCTAssertFalse(
            localizedText("Merge").exists,
            "小册子工具下不应残留合并文案。\(app.debugDescription)"
        )
    }

    /// 内置示例文档使工具页在无需文件选择器的前提下即可用。
    ///
    /// 这条覆盖「工具页在有文档时确实可操作」，而非空文档下的门控：
    /// 空文档的禁用态由各工具自己的套件验证。
    ///
    /// 这是 UI 测试覆盖其余交互路径的前提：iOS 上文件导入走
    /// `fileImporter`，其 `UIDocumentPickerViewController` 在 App 的 AX 树
    /// 之外运行，XCUITest 无法驱动。
    func testSampleDocumentEnablesEveryTool() {
        openSampleDocument(tool: "booklet")
        // 六步向导的主操作按钮（走到导出阶段即变为「制作小册子」）。
        assertEnabled("booklet.stepNext")

        backToWelcome()
        openSampleDocument(tool: "split")
        // 拆分页本身可达，且页面结构完整。导出按钮此刻应为禁用——
        // 示例文档虽已打开，但还没有任何切分点。
        assertExists("split.export")
        assertDisabled("split.export")
    }

    /// 从工具页关闭文档回到首页后，首页仍然可用。
    ///
    /// 返回后若首页已损坏，用户就再也进不去其他工具——这是导航栈上的
    /// 单向故障，比「返回失败」本身更严重。
    func testReturningFromToolRestoresOverview() {
        openSampleDocument(tool: "split")
        backToWelcome()

        // 首页完好：三个入口都还在，且能再次进入。
        assertExists("welcome.bookletTool")
        assertExists("welcome.splitTool")
        assertExists("welcome.mergeTool")
        openMergeWorkspace()
    }

    /// 关闭当前文档回到欢迎首页。
    func testClosingDocumentReturnsToWelcome() {
        openSampleDocument(tool: "booklet")
        assertNotExists("welcome.bookletTool")

        closeDocument()
    }

    /// 导航栏右上角是「首页」按钮，而不是「更多」菜单。
    ///
    /// 回归重点：工具工作台是导航栈的栈顶根页，没有返回按钮——首页按钮
    /// 是离开工作台的唯一路径。因此它必须在工作台阶段出现；首页自己则
    /// 不需要（点了也没有可去的地方）。
    func testHomeButtonReplacesTheDocumentMenu() {
        // 首页：没有首页按钮，也没有「更多」菜单。
        XCTAssertFalse(
            element("home.button").exists,
            "首页不应出现首页按钮。\(app.debugDescription)"
        )
        XCTAssertFalse(
            app.navigationBars.buttons["Document menu"].exists,
            "首页不应残留「更多」菜单。\(app.debugDescription)"
        )

        openSampleDocument(tool: "booklet")
        assertExists("booklet.stageTitle")

        // 工作台：首页按钮出现，且没有「更多」菜单。
        let homeButton = element("home.button")
        XCTAssertTrue(
            homeButton.waitForExistence(timeout: 10),
            "工作台缺少首页按钮。\(app.debugDescription)"
        )
        XCTAssertFalse(
            app.navigationBars.buttons["Document menu"].exists,
            "工作台不应残留「更多」菜单。\(app.debugDescription)"
        )
    }
}
