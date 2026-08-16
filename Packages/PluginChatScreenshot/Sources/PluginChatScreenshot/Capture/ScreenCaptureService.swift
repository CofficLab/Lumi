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

        if #available(macOS 15.2, *) {
            let image: CGImage = try await withCheckedThrowingContinuation { continuation in
                SCScreenshotManager.captureImage(in: frame) { image, error in
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
            frame,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            throw ScreenshotError.captureFailed
        }
        return Result(image: image, frame: frame)
    }
}