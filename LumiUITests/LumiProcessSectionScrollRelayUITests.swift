import AppKit
import XCTest

/// PluginMessageListBrief (V1) 过程折叠区的**滚轮** UI 测试。
///
/// ## 用户报告的症状
///
/// 「在 V1 的过程区域滚动，触发的是**外部的滚动条**，它自己根本不滚动。」
///
/// ## 根因
///
/// SwiftUI 的 `HostingScrollView` 自己的滚轮方向与原生 `NSScrollView`
/// **相反**（实测：`deltaY = -40` 让 offset 从 330.5 变成 370.5，
/// 即 `offset -= deltaY`；原生是 `offset += deltaY`）。
///
/// 过程折叠区展开时**自动钉在底部**（offset = 文档高 − 视口高）。
/// 用户「向上滑看更早的过程内容」（`deltaY < 0`）时：
///
/// - SwiftUI 语义要求 offset **增大** → 但已在最大值 → 没有空间 → 内层不动；
/// - 事件继续往下传 → 被外层**原生** List 消费 → 外层滚动条动。
///
/// 修复：`ProcessSectionScrollRelay` 命中内层时**主动驱动**它，
/// 方向用**原生**语义（`offset += deltaY`），不沿用 SwiftUI 的反向语义。
///
/// ## 判据：内层滚动视图的真实偏移量
///
/// 这个 bug 的所有外部观察都有歧义，所以判据必须落在**内层滚动视图
/// 自己的几何**上：
///
/// - AX 帧：未物化的行在列表坐标系里也有布局位置（实测 y≈3954），
///   拿它们当判据只会得到恒定的「没变化」；
/// - 合成滚轮事件：SwiftUI 的 `ScrollView` **不接受**投到窗口上的
///   合成事件（原生 `NSScrollView` 接受、SwiftUI 的 `HostingScrollView`
///   一律 Δ=0，无论是否带 phase、无论投到 `.cghidEventTap` 还是
///   `.cgSessionEventTap`）。
///
/// 因此折叠区在 DEBUG 下把内层几何（`offset/documentHeight/visibleHeight`）
/// 通过一个隐藏的 AX 元素暴露出来（见 `ProcessSectionGeometryProbe`），
/// 本测试直接断言这个值。
final class LumiProcessSectionScrollRelayUITests: LumiUITestCase {

    // MARK: - Constants

    /// 折叠区的可访问性标识符。
    private enum Section {
        /// 过程折叠区容器。
        static let container = "lumi.message-list-brief.process-section"

        /// 内层滚动视图的实时几何。
        static let geometry = "lumi.message-list-brief.process-section.geometry"
    }

    /// 长流程 turn 的用户消息文案。
    private static let longFlowAnchor = "执行长流程操作"

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            "--lumi-ui-testing-message-list-brief",
            "--lumi-ui-testing-isolated-storage",
        ])
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    // MARK: - Cases

    /// 向上滚（用户想看更早的过程内容）时，内层必须真的滚动。
    ///
    /// - Important: 这是用户报告场景的直接守卫。修复前内层偏移纹丝不动，
    ///   事件落到外层 List —— 表现为「外层滚动条动、内层不动」。
    func testScrollUpInsideProcessSectionMovesInnerOffset() throws {
        try expandLongFlowSection()

        let before = try readInnerOffset()
        print("🖱 [scroll-up] 滚动前内层偏移=\(before)")

        // 向上滚（deltaY < 0 = 看更早的内容）。
        scrollWheelAt(sectionFrame(), deltaY: -120)

        // 等滚动落定。
        Thread.sleep(forTimeInterval: 1.0)

        let after = try readInnerOffset()
        print("🖱 [scroll-up] 滚动后内层偏移=\(after)")

        XCTAssertLessThan(
            after,
            before,
            """
            向上滚必须让内层偏移减小（看更早的过程内容）。\
            before=\(before) after=\(after)\
            —— 内层没动，说明滚轮事件没作用到折叠区。
            """
        )
    }

    /// 向下滚且内层已在底部时，内层偏移不变（剩余增量接力给外层）。
    ///
    /// - Important: 这是「滚动链」的关键行为 —— 内层到底后继续向下滚，
    ///   外层列表应当跟着滚，否则用户会感觉「卡住了」。
    func testScrollDownAtBottomLeavesInnerOffsetUnchanged() throws {
        try expandLongFlowSection()

        let before = try readInnerOffset()
        print("🖱 [scroll-down] 滚动前内层偏移=\(before)")

        scrollWheelAt(sectionFrame(), deltaY: 120)

        Thread.sleep(forTimeInterval: 1.0)

        let after = try readInnerOffset()
        print("🖱 [scroll-down] 滚动后内层偏移=\(after)")

        XCTAssertEqual(
            before,
            after,
            accuracy: 1,
            """
            内层贴底时向下滚，内层偏移不应变化（剩余增量应接力给外层）。\
            before=\(before) after=\(after)
            """
        )
    }

    // MARK: - Helpers

    /// 展开长流程 turn 的过程折叠区。
    private func expandLongFlowSection() throws {
        XCTAssertTrue(
            element(identifier: "root.main").waitForExistence(timeout: 30),
            "主窗口未就绪"
        )
        let anchor = element(anyLabelOf: [Self.longFlowAnchor])
        XCTAssertTrue(
            anchor.waitForExistence(timeout: 25),
            "夹具长流程 turn 的用户消息未出现"
        )

        let disclosures = allElements(containingLabel: "执行了")
        XCTAssertFalse(disclosures.isEmpty, "过程折叠区折叠态未出现")
        let disclosure = try XCTUnwrap(
            disclosures.max(by: { $0.frame.maxY < $1.frame.maxY }),
            "找不到过程折叠区折叠态"
        )
        disclosure.click()
    }

    /// 折叠区容器的帧。
    private func sectionFrame() -> CGRect {
        let section = element(identifier: Section.container)
        XCTAssertTrue(section.waitForExistence(timeout: 10), "过程折叠区容器未出现")
        return section.frame
    }

    /// 读取折叠区内层滚动视图的当前偏移。
    private func readInnerOffset() throws -> Double {
        let probe = element(identifier: Section.geometry)
        XCTAssertTrue(probe.waitForExistence(timeout: 10), "几何探针元素未出现")

        var raw = probe.value as? String ?? ""
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            raw = probe.value as? String ?? ""
            if !raw.isEmpty && raw.contains("/") { break }
            usleep(200_000)
        }

        let parts = raw.split(separator: "/")
        guard parts.count == 3, let offset = Double(parts[0]) else {
            XCTFail("几何无法解析：\(raw)")
            return 0
        }
        return offset
    }

    /// 在给定屏幕区域中心派发一次滚轮事件。
    ///
    /// - Important: 垂直增量必须放在 `wheel1`。`wheel2` 是**水平**轴，
    ///   误用它会让 `scrollingDeltaY` 恒为 0 —— 那样测出来的
    ///   「滚不动」全是伪结论。
    private func scrollWheelAt(_ frame: CGRect, deltaY: Int) {
        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: 0,
            wheel3: 0
        ) else {
            XCTFail("无法合成滚轮事件")
            return
        }
        scrollEvent.location = CGPoint(x: frame.midX, y: frame.midY)
        scrollEvent.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
    }

    /// 全部 label / value **包含**指定片段的元素。
    private func allElements(containingLabel fragment: String) -> [XCUIElement] {
        app.descendants(matching: .any)
            .matching(
                NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", fragment, fragment)
            )
            .allElementsBoundByIndex
    }
}
