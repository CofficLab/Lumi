import ProviderToast
import SwiftUI
import XCTest
@testable import PluginToast

/// 覆盖层渲染冒烟测试：三种状态（toast / loading / error）与空状态
/// 都能被 `ImageRenderer` 实际渲染出非空位图，防止视图体出现运行期崩溃。
@MainActor
final class ToastOverlayRenderingTests: XCTestCase {

    func testRendersToastState() {
        let center = ToastCenter()
        center.show(LumiToast(title: "Saved", style: .success))
        assertRenders(center, label: "toast")
    }

    func testRendersLoadingState() {
        let center = ToastCenter()
        center.showLoading(title: "Working", detail: "Preparing files")
        assertRenders(center, label: "loading")
    }

    func testRendersErrorState() {
        let center = ToastCenter()
        center.presentError(title: "Pull failed", message: "divergent branches")
        assertRenders(center, label: "error")
    }

    func testRendersEmptyState() {
        assertRenders(ToastCenter(), label: "empty")
    }

    // MARK: - Helpers

    private func assertRenders(_ center: ToastCenter, label: String) {
        let overlay = ToastOverlay(content: Color.clear, center: center)
        let renderer = ImageRenderer(content: overlay)

        guard let image = renderer.nsImage else {
            XCTFail("\(label): ImageRenderer 未能生成图像")
            return
        }
        XCTAssertGreaterThan(image.size.width, 0, "\(label): 渲染宽度为 0")
        XCTAssertGreaterThan(image.size.height, 0, "\(label): 渲染高度为 0")
    }
}
