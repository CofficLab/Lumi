import AppKit
import CoreGraphics
import Testing
@testable import PluginChatScreenshot

// MARK: - 遮罩视图引用环

@Suite("Chat Screenshot 遮罩视图引用环")
@MainActor
struct ChatScreenshotOverlayRetainCycleTests {

    /// 遮罩视图强持有三个回调；若 `onSelectionChanged` 再强捕获该视图，就构成
    /// `view → closure → view` 环，`finish()` 清空数组后视图仍无法释放。
    @Test("装配回调后遮罩视图可被释放，不与回调形成引用环")
    func overlayViewDeallocatesAfterCallbacksAreWired() {
        weak var weakView: ChatScreenshotOverlayView?

        autoreleasepool {
            let controller = makeController()
            let view = ChatScreenshotOverlayView(
                screenFrame: CGRect(x: 0, y: 0, width: 120, height: 80)
            )
            controller.wireCallbacks(on: view)
            weakView = view
        }

        #expect(weakView == nil)
    }

    private func makeController() -> ChatScreenshotOverlayController {
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let image = context!.makeImage()!
        return ChatScreenshotOverlayController(
            image: image,
            captureFrame: .zero,
            onComplete: { _ in }
        )
    }
}
