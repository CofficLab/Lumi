import ProviderToast
import SwiftUI
import XCTest
@testable import PluginToast

/// 错误面板尺寸回归测试。
///
/// 背景：旧版 `ErrorNoticeOverlay` 把消息区设为 `maxHeight: .infinity`，
/// 该视图成为 VStack 中唯一可伸展的子项，会贪婪吸收外层给定的全部剩余高度。
/// 结果是一行短错误（如 `unexpected EOF`）也会被撑成接近整窗高的空白面板。
///
/// 本测试锁定三条不变量：
/// 1. 短消息面板高度由内容决定，不得接近窗口高度；
/// 2. 长消息面板被消息区上限截断，仍在窗口内可滚动；
/// 3. 面板宽度按内容自适应，短消息不占用整窗宽度。
@MainActor
final class ErrorNoticePanelSizingTests: XCTestCase {

    /// 模拟主窗口的常用尺寸：足够宽、足够高。
    private static let windowSize = CGSize(width: 1400, height: 900)

    // MARK: - 短消息

    func testShortMessagePanelStaysCompact() {
        let panel = measurePanel(
            title: "Sync failed",
            message: "unexpected EOF"
        )

        // 旧实现下高度接近窗口高度（≈900）。修复后应显著更小。
        XCTAssertLessThan(
            panel.height,
            400,
            "短错误面板高度应远小于窗口高度，实际 \(panel.height)"
        )
        XCTAssertGreaterThan(
            panel.height,
            80,
            "短错误面板不应塌缩到不可见，实际 \(panel.height)"
        )
    }

    func testShortMessagePanelHeightGrowsWithContent() {
        let short = measurePanel(title: "Sync failed", message: "unexpected EOF")
        let longer = measurePanel(
            title: "Sync failed",
            message: String(repeating: "fatal: could not read from remote repository\n", count: 6)
        )

        XCTAssertGreaterThan(
            longer.height,
            short.height,
            "更长错误的面板应更高，实际 \(longer.height) vs \(short.height)"
        )
        // 即使是多行错误，也不得回到「整窗高」的旧行为。
        XCTAssertLessThan(
            longer.height,
            Self.windowSize.height,
            "多行错误面板不应撑满窗口高度"
        )
    }

    // MARK: - 长消息

    func testLongMessagePanelIsCappedAndScrollable() {
        let panel = measurePanel(
            title: "Pull failed",
            message: String(repeating: "fatal: Need to specify how to reconcile divergent branches.\n", count: 200)
        )

        // 消息区有固定上限（240pt），加上面板自身的头部/详情/底部操作栏，
        // 面板总高必须显著低于窗口高度。
        XCTAssertLessThan(
            panel.height,
            Self.windowSize.height,
            "长错误面板必须被上限截断，不得超出窗口"
        )
        XCTAssertLessThan(
            panel.height,
            Self.windowSize.height * 0.6,
            "长错误面板应被消息区上限截断，实际 \(panel.height)"
        )
    }

    func testVeryLongMessagePanelDoesNotExceedWindow() {
        let panel = measurePanel(
            title: "Pull failed",
            message: String(repeating: "hint: You have divergent branches.\n", count: 2000)
        )

        XCTAssertLessThanOrEqual(
            panel.height,
            Self.windowSize.height,
            "极长错误面板不得超出窗口高度，实际 \(panel.height)"
        )
    }

    // MARK: - 宽度

    func testShortMessagePanelIsNarrowerThanWindow() {
        let panel = measurePanel(title: "Sync failed", message: "unexpected EOF")

        XCTAssertLessThan(
            panel.width,
            Self.windowSize.width * 0.5,
            "短错误面板宽度应远小于窗口宽度，实际 \(panel.width)"
        )
        XCTAssertGreaterThanOrEqual(
            panel.width,
            ErrorNoticeOverlay.minPanelWidth,
            "短错误面板宽度不应低于下限"
        )
    }

    func testLongMessagePanelWidthIsCapped() {
        let panel = measurePanel(
            title: "Pull failed",
            message: String(repeating: "fatal: Need to specify how to reconcile divergent branches.\n", count: 200)
        )

        XCTAssertLessThanOrEqual(
            panel.width,
            ErrorNoticeOverlay.maxPanelWidth,
            "长错误面板宽度不应超过上限，实际 \(panel.width)"
        )
    }

    // MARK: - Helpers

    /// 渲染错误面板本体并返回其实际尺寸。
    ///
    /// 直接测量 `ErrorNoticePanel`（而非整个覆盖层），这样得到的尺寸就是
    /// 内容驱动的高度，不受窗口高度约束影响。
    private func measurePanel(title: String, message: String) -> CGSize {
        let error = LumiErrorNotice(title: title, message: message)
        let width = ErrorNoticeOverlay.resolvedPanelWidth(
            for: error,
            availableWidth: Self.windowSize.width - ErrorNoticeOverlay.windowMargin * 2
        )
        let view = ErrorNoticePanel(error: error, width: width) {}

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        guard let image = renderer.nsImage else {
            XCTFail("ImageRenderer 未能生成图像")
            return .zero
        }

        return image.size
    }
}
