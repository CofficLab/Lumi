import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// 全屏截图服务
///
/// - macOS 15.2+:使用 `SCScreenshotManager.captureImage(in:completionHandler:)`
/// - macOS 14 ~ 15.1:降级到 `CGWindowListCreateImage(frame, .optionOnScreenOnly, ...)`
///
/// 所有屏幕 union 后一次抓取。
public enum ScreenCaptureService {

    public struct Result: Sendable {
        public let image: CGImage
        public let frame: CGRect
    }

    public enum ScreenshotError: Error {
        case noScreens
        case captureFailed
        case unsupportedOS
    }

    /// 抓取所有屏幕的 union 区域
    public static func captureAllScreens() async throws -> Result {
        let frame = NSScreen.screens.reduce(CGRect.null) { partial, screen in
            partial.union(screen.frame)
        }
        guard !frame.isNull else {
            throw ScreenshotError.noScreens
        }
        // 两个抓取 API 都按显示空间（主屏左上原点、y 向下）解释传入矩形，
        // 直接传 AppKit union 在多屏纵向偏移时会抓错区域（#646 / #829）。
        // 返回的 frame 保持 AppKit 坐标，供遮罩选区与裁剪继续使用。
        let captureRect = displaySpaceRect(
            fromAppKit: frame,
            primaryDisplayHeight: NSScreen.screens.first?.frame.height ?? frame.height
        )

        if #available(macOS 15.2, *) {
            let image: CGImage = try await withCheckedThrowingContinuation { continuation in
                SCScreenshotManager.captureImage(in: captureRect) { image, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: ScreenshotError.captureFailed)
                    }
                }
            }
            return Result(image: image, frame: frame)
        }

        // macOS 14 ~ 15.1 兜底
        guard let image = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            throw ScreenshotError.captureFailed
        }
        return Result(image: image, frame: frame)
    }

    /// AppKit（主屏左下原点、y 向上）→ 屏幕显示空间（主屏左上原点、y 向下）。
    ///
    /// `y_display = primaryHeight - y_appkit`，宽度与 x 区间不变。
    /// 纯函数单独暴露供单元测试覆盖多屏偏移换算（#646 / #829）。
    static func displaySpaceRect(
        fromAppKit rect: CGRect,
        primaryDisplayHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryDisplayHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}