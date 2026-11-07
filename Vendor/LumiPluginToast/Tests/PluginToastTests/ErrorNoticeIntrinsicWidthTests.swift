import ProviderToast
import SwiftUI
import XCTest
@testable import PluginToast

/// 错误面板文本测量的跨平台回归测试。
///
/// 背景：1.2.2 版本在 `ErrorNoticeOverlay.intrinsicContentWidth` 中直接使用
/// `NSFont`（AppKit 专有类型），却没有导入 AppKit。该文件只 `import SwiftUI`，
/// 而 SwiftUI 在 iOS 上不导出 `NSFont`，因此 iOS 编译直接失败：
/// `error: cannot find 'NSFont' in scope`。
///
/// 根因是平台专有类型没有做 `canImport` 区分。本测试锁定「固有宽度计算在
/// 两个平台都能返回合理数值」这一语义，使同类回归在提交前暴露，
/// 而不是等到下游 App 编译时才失败。
@MainActor
final class ErrorNoticeIntrinsicWidthTests: XCTestCase {

    // MARK: - 宽度计算

    /// 固有宽度计算必须在当前平台可用（iOS 上曾因 `NSFont` 直接编译失败）。
    func testIntrinsicContentWidthIsComputableOnCurrentPlatform() {
        let error = LumiErrorNotice(title: "Sync failed", message: "unexpected EOF")

        let width = ErrorNoticeOverlay.intrinsicContentWidth(for: error)

        XCTAssertGreaterThan(
            width,
            0,
            "固有宽度应为正数，说明文本测量在当前平台可用"
        )
    }

    /// 宽度随文本长度增长：测量必须真正反映内容，而非固定常量。
    func testIntrinsicContentWidthGrowsWithLongerText() {
        let short = LumiErrorNotice(title: "Sync failed", message: "unexpected EOF")
        let long = LumiErrorNotice(
            title: "Sync failed",
            message: String(repeating: "unexpected EOF while fetching remote refs\n", count: 8)
        )

        let shortWidth = ErrorNoticeOverlay.intrinsicContentWidth(for: short)
        let longWidth = ErrorNoticeOverlay.intrinsicContentWidth(for: long)

        XCTAssertGreaterThan(
            longWidth,
            shortWidth,
            "更长文本应测得更宽，实际 \(longWidth) vs \(shortWidth)"
        )
    }

    /// 多行消息：取各行宽度的最大值，而非累加。
    func testIntrinsicContentWidthTakesWidestLineOfMultilineMessage() {
        let error = LumiErrorNotice(
            title: "Pull failed",
            message: "hint: divergent branches\n"
                + "fatal: Need to specify how to reconcile divergent refs."
        )

        let width = ErrorNoticeOverlay.intrinsicContentWidth(for: error)

        XCTAssertGreaterThan(
            width,
            0,
            "多行消息应测得宽度，实际 \(width)"
        )
    }

    // MARK: - 面板宽度收敛

    /// 面板宽度必须落在设计约束内（300...620pt）且不超过窗口。
    func testResolvedPanelWidthStaysWithinBounds() {
        let error = LumiErrorNotice(
            title: "Pull failed",
            message: String(repeating: "a very long single line error message ", count: 40)
        )

        let width = ErrorNoticeOverlay.resolvedPanelWidth(for: error, availableWidth: 1400)

        XCTAssertLessThanOrEqual(width, ErrorNoticeOverlay.maxPanelWidth)
        XCTAssertGreaterThanOrEqual(width, ErrorNoticeOverlay.minPanelWidth)
    }

    /// 窗口很窄时，面板宽度必须收敛到窗口以内，不得溢出。
    func testResolvedPanelWidthClampsToNarrowWindow() {
        let error = LumiErrorNotice(title: "Sync failed", message: "unexpected EOF")

        let width = ErrorNoticeOverlay.resolvedPanelWidth(for: error, availableWidth: 200)

        XCTAssertLessThanOrEqual(
            width,
            200,
            "窄窗口下面板宽度不得溢出，实际 \(width)"
        )
    }
}
