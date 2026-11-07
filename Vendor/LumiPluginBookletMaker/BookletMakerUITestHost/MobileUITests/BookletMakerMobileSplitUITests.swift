import XCTest

/// 拆分（Split）工具在移动端的计划编辑与导出门控。
///
/// iOS 的拆分页是「左右滑动浏览相邻两页 → 点中间的剪刀标记切分点」
/// （产品原型 `08-split-plan` / `08-split-plan-swipe`）。切分点标在两页
/// **之间**，因此标识符是 `split.boundary.<页码>`，含义是「在此页之后切」。
///
/// 重点覆盖切分点的选中与反选、滑动翻页、导出门控的双向行为。
final class BookletMakerMobileSplitUITests: BookletMakerMobileUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // 主线是「首页工具卡 → 引导页 → 工作台」，没有概览页这一层。
        openSampleDocument(tool: "split")
    }

    /// 没有切分点时导出按钮禁用。
    ///
    /// 门控是这一层最重要的行为：按钮一直在那里，真正要验证的是
    /// 「还没给出有效切分点时导不出来」。
    func testExportDisabledWithoutCutPoints() {
        assertDisabled("split.export")
    }

    /// 点剪刀标记可在该页之后添加切分点。
    ///
    /// 8 页示例文档在第 2 页之后切分，应产生两个分段（1-2 / 3-8）。
    func testTappingScissorsAddsCutPoint() {
        XCTAssertTrue(scrollTo("split.boundary.1"), app.debugDescription)
        element("split.boundary.1").tap()
        assertSplitAfter("split.boundary.1")

        // 一个切分点把文档分成两段，导出门控应打开。
        assertEnabled("split.export")
    }

    /// 再次点击同一处应取消切分点。
    ///
    /// 反选能力是切分点交互的核心：用户改主意时必须能把标记撤掉，
    /// 否则只能重新载入文档。
    func testTappingSameScissorsTogglesCutPointOff() {
        XCTAssertTrue(scrollTo("split.boundary.1"), app.debugDescription)
        element("split.boundary.1").tap()
        assertSplitAfter("split.boundary.1")

        // 每次都重新查询元素：切分点变化会触发视图重排，此前缓存的
        // `XCUIElement` 指向旧快照，第二次 tap 会落空——这正是本条最初
        // 稳定失败的原因。
        XCTAssertTrue(scrollTo("split.boundary.1"), app.debugDescription)
        element("split.boundary.1").tap()
        assertNotSplitAfter("split.boundary.1")

        // 切分点撤掉后导出应重新禁用。
        assertDisabled("split.export")
    }

    /// 多个切分点彼此独立。
    ///
    /// 只记「最后一次点击」的实现会让前面的切分点被静默丢弃，用户会拿到
    /// 与预览不符的输出。
    ///
    /// 切分点标在两页之间，一次只显示当前这一对页面，因此第二个切分点
    /// 需要先翻到第 3、4 页那对。
    func testMultipleCutPointsAreIndependent() {
        XCTAssertTrue(scrollTo("split.boundary.1"), "缺少第 1 页后的切分点")
        element("split.boundary.1").tap()
        assertSplitAfter("split.boundary.1")

        // 翻到第 3、4 页那对，在第 3 页之后加第二个切分点。
        navigateToPair(startingAt: 3)
        XCTAssertTrue(scrollTo("split.boundary.3"), "缺少第 3 页后的切分点")
        element("split.boundary.3").tap()
        assertSplitAfter("split.boundary.3")

        // 翻回第一对，第一个切分点仍在。
        navigateToPair(startingAt: 1)
        assertSplitAfter("split.boundary.1")
    }

    /// 最后一页之后没有切分点。
    ///
    /// 在第 8 页之后切分会产出一个空文件，因此翻到最后一对时，第 8 页
    /// 后面必须没有剪刀可用。
    func testNoSplitPointAfterTheLastPage() {
        // 8 页文档，最后一对是第 7、8 页。
        navigateToPair(startingAt: 7)
        XCTAssertTrue(scrollTo("split.boundary.7"), app.debugDescription)

        // 第 7 页后的切分点合法（第 8 页单独成文件）。
        assertEnabled("split.boundary.7")

        // 但「下一页」已到尽头：翻不动了，也就没有第 8 页之后的切分点。
        assertDisabled("split.pageNext")
        XCTAssertFalse(
            element("split.boundary.8").exists,
            "最后一页之后不应有切分点。\(app.debugDescription)"
        )
    }

    /// 分段摘要随切分点变化，如实反映分段结构。
    func testSummaryReflectsSegmentCount() {
        XCTAssertTrue(
            element("split.summary").waitForExistence(timeout: 10),
            "拆分页缺少结果摘要。\(app.debugDescription)"
        )

        // 初始状态：0 个切分点 → 1 个文件。
        XCTAssertTrue(
            waitForSummary(to: "0 split points · 1 files"),
            "初始摘要应为「0 split points · 1 files」，"
                + "实际为「\(text(of: element("split.summary")))」。\(app.debugDescription)"
        )

        XCTAssertTrue(scrollTo("split.boundary.1"))
        element("split.boundary.1").tap()

        XCTAssertTrue(
            waitForSummary(to: "1 split points · 2 files"),
            "一个切分点后摘要应为「1 split points · 2 files」，"
                + "实际为「\(text(of: element("split.summary")))」。\(app.debugDescription)"
        )
        assertEnabled("split.export")
    }

    // MARK: - Helpers

    /// 滑动到从 `page` 开始的那一对页面。
    ///
    /// 拆分页一次只显示相邻两页，切分点标在它们之间，所以要看第 N 页
    /// 之后的切分点，得先把视图滑到第 N 页。
    private func navigateToPair(startingAt page: Int) {
        let target = "split.boundary.\(page)"
        // 一次只显示当前这一对页面，切分点标在两页之间，所以要看第 N 页
        // 之后的切分点，得先把视图翻到第 N 页。
        //
        // 翻页用「下一页 / 上一页」两个按钮：目标可能在当前这一对的右边，
        // 也可能在左边，方向不能想当然。页码范围文案（`split.pageRange`，
        // 形如 "Pages 3–4"）用来判断当前停在哪。
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if element(target).waitForExistence(timeout: 0.5) {
                return
            }

            let range = element("split.pageRange")
            let current = currentPairStart(from: range)
            if let current {
                if current < page {
                    let next = app.buttons["split.pageNext"]
                    guard next.exists, next.isHittable else { break }
                    next.tap()
                } else {
                    let previous = app.buttons["split.pagePrevious"]
                    guard previous.exists, previous.isHittable else { break }
                    previous.tap()
                }
            } else {
                // 读不到页码文案时先试试「下一页」。
                let next = app.buttons["split.pageNext"]
                guard next.exists, next.isHittable else { break }
                next.tap()
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        _ = scrollTo(target)
    }

    /// 从页码范围文案里解析当前这一对的起始页。
    ///
    /// 文案形如 "Pages 3–4"（本地化后可能是别的措辞），取第一个数字即可。
    private func currentPairStart(from range: XCUIElement) -> Int? {
        let label = range.label
        let digits = label.compactMap { $0.wholeNumberValue }
        guard let first = digits.first else { return nil }
        return first
    }

    /// 判断某处是否处于「在此页之后切分」状态。
    ///
    /// 读 accessibilityLabel：它由 `PDFSplitPlanEditorView` 显式拼成
    /// 「Split after page N」/「Remove split after page N」。
    ///
    /// 注意语义方向：label 描述的是**点击后将发生的动作**，不是当前状态 ——
    /// 已经切分的地方显示「Remove split after page N」（点了会取消），
    /// 没切的地方显示「Split after page N」（点了会切）。因此「已切分」
    /// 对应的是带 `remove` 的那个 label。
    ///
    /// 必须把「期望状态」显式传进来：只等一个关键词的话，取消切分点的
    /// 用例会立刻误判——`remove split after page` 本身就包含
    /// `split after page`，两条路径会同时命中。
    private func waitForSplitState(
        of identifier: String,
        equals expected: Bool,
        timeout: TimeInterval = 5
    ) -> Bool {
        // 先滚动定位：页面预览是横向滑动的，目标切分点可能不在视口内，
        // 不滚动就读不到 label。滚动只在轮询之外做，避免两者互相打断。
        _ = scrollTo(identifier, timeout: timeout)

        let deadline = Date().addingTimeInterval(timeout)
        let removeLabel = "remove split after page"
        while Date() < deadline {
            let label = element(identifier).label.lowercased()
            // 已切分 ⇔ label 带 `remove`。
            if label.contains(removeLabel) {
                if expected { return true }
            } else if label.contains("split after page") {
                if !expected { return true }
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    /// 便捷断言：某处应处于「在此页之后切分」状态。
    private func assertSplitAfter(
        _ identifier: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitForSplitState(of: identifier, equals: true),
            "切分状态不符，实际 label 为「\(element(identifier).label)」。\(app.debugDescription)",
            file: file, line: line
        )
    }

    /// 便捷断言：某处不应处于切分状态。
    private func assertNotSplitAfter(
        _ identifier: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitForSplitState(of: identifier, equals: false),
            "切分状态不符，实际 label 为「\(element(identifier).label)」。\(app.debugDescription)",
            file: file, line: line
        )
    }

    /// 等待摘要文本变成期望值。
    private func waitForSummary(
        to expected: String,
        timeout: TimeInterval = 8
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if text(of: element("split.summary")) == expected { return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }
}
