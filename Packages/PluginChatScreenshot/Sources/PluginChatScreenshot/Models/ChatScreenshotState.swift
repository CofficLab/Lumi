import AppKit
import CoreGraphics
import Foundation
import os
import SuperLogKit

/// 截图状态机 + 选区裁剪纯函数
///
/// 流程:
/// 1. `startSelection(image:captureFrame:onComplete:)` 接收一次截图抓取结果
/// 2. 创建 overlay controller 显示在所有屏幕上
/// 3. 用户拖选 → 松手 → callback 收到归一化选区(CGRect,屏幕坐标,原点在左下)
/// 4. 调 `crop(image:captureFrame:selection:)` 静态函数裁剪 → 返回 CGImage
/// 5. 经 `ScreenCaptureImageProcessor` 编码为 JPEG attachment
/// 6. onComplete(Data?) 回调给插件主类
@MainActor
public final class ChatScreenshotState {

    public static let shared = ChatScreenshotState()

    private var overlayController: ChatScreenshotOverlayController?

    private init() {}

    /// 启动一次选区流程
    ///
    /// - Note: 同一时刻只允许一次截图流程;若已有进行中的 controller,本次调用忽略。
    public func startSelection(
        image: CGImage,
        captureFrame: CGRect,
        onComplete: @escaping @MainActor (CGImage?) -> Void
    ) {
        guard overlayController == nil else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)已有进行中的截图,忽略本次")
            }
            return
        }

        let controller = ChatScreenshotOverlayController(
            image: image,
            captureFrame: captureFrame,
            onComplete: { [weak self] selection in
                guard let self else { return }
                self.overlayController = nil
                let cropped = self.handleCompletion(
                    image: image,
                    captureFrame: captureFrame,
                    selection: selection
                )
                onComplete(cropped)
            }
        )
        overlayController = controller
        controller.show()
    }

    /// 取消当前截图(供按钮 Esc 等场景)
    public func cancel() {
        overlayController?.cancel()
        overlayController = nil
    }

    // MARK: - 私有

    /// 选区完成后裁剪出 CGImage(由主类负责 downscale + JPEG 编码)
    private func handleCompletion(
        image: CGImage,
        captureFrame: CGRect,
        selection: CGRect?
    ) -> CGImage? {
        guard let selection, selection.width >= 10, selection.height >= 10 else {
            return nil
        }
        return Self.crop(
            image: image,
            captureFrame: captureFrame,
            selection: selection
        )
    }

    // MARK: - 纯函数:选区裁剪(供单元测试)

    /// 把屏幕坐标的 `selection` 映射到 image 坐标并裁剪
    ///
    /// 坐标约定:
    /// - `captureFrame` 与 `selection` 都是**屏幕坐标**,原点在**左下**(NSEvent.mouseLocation 风格)
    /// - `image` 是 `CGImage`,原点在**左上**
    ///
    /// 因此 y 轴需要翻转:
    /// `cropY = (captureFrame.height - (selection.minY - captureFrame.minY) - selection.height) * scaleY`
    ///
    /// - Returns: 裁剪后的 CGImage;若选区与 image 无交集(小于 1px),返回 nil
    public nonisolated static func crop(
        image: CGImage,
        captureFrame: CGRect,
        selection: CGRect
    ) -> CGImage? {
        guard captureFrame.width > 0, captureFrame.height > 0 else { return nil }

        let scaleX = CGFloat(image.width) / captureFrame.width
        let scaleY = CGFloat(image.height) / captureFrame.height
        let relativeX = selection.minX - captureFrame.minX
        let relativeY = selection.minY - captureFrame.minY

        let cropRect = CGRect(
            x: relativeX * scaleX,
            y: (captureFrame.height - relativeY - selection.height) * scaleY,
            width: selection.width * scaleX,
            height: selection.height * scaleY
        )
        .integral
        .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard cropRect.width >= 1, cropRect.height >= 1 else { return nil }
        return image.cropping(to: cropRect)
    }

    // MARK: - 日志

    private static let verbose = false
}

// MARK: - Logger (与主类共用 SuperLog 风格)

extension ChatScreenshotState: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.chat-screenshot.state"
    )
    public nonisolated static let emoji = "📸"
}