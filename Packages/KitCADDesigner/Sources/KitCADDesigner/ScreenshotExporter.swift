import AppKit
import Foundation
import SceneKit

/// 截图/PDF 导出（文档 Phase 3.1：视口截图 → PNG/PDF）。
///
/// SCNView 实现 SCNSceneRenderer 协议，通过 `snapshot(atTime:with:antialiasingOptions:)` 捕获画面。
public struct ScreenshotExporter {
    public init() {}

    /// 将 SCNView 当前画面导出为 PNG。
    @MainActor
    public func exportPNG(from scnView: SCNView, to url: URL) throws {
        guard let image = captureSnapshot(from: scnView) else {
            throw ScreenshotExporterError.snapshotFailed
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            throw ScreenshotExporterError.encodingFailed
        }
        try pngData.write(to: url, options: .atomic)
    }

    /// 将 SCNView 当前画面导出为单页 PDF。
    @MainActor
    public func exportPDF(from scnView: SCNView, to url: URL) throws {
        guard let image = captureSnapshot(from: scnView) else {
            throw ScreenshotExporterError.snapshotFailed
        }

        let pageSize = image.size
        let pageRect = NSRect(origin: .zero, size: pageSize)
        let mutableData = NSMutableData()
        guard let consumer = CGDataConsumer(data: mutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw ScreenshotExporterError.encodingFailed
        }

        context.beginPDFPage(nil)
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = graphicsContext
        image.draw(in: pageRect)
        NSGraphicsContext.current = nil
        context.endPDFPage()
        context.closePDF()

        try (mutableData as Data).write(to: url, options: .atomic)
    }

    @MainActor
    private func captureSnapshot(from scnView: SCNView) -> NSImage? {
        // 用 NSView 的缓存显示位图捕获当前画面（不依赖 snapshot 的 antialiasing 签名歧义）。
        let bounds = scnView.bounds
        guard bounds.width > 0, bounds.height > 0,
              let rep = scnView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }
        rep.size = bounds.size
        scnView.cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }
}

public enum ScreenshotExporterError: LocalizedError, Equatable {
    case snapshotFailed
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .snapshotFailed:
            return "Failed to capture viewport snapshot."
        case .encodingFailed:
            return "Failed to encode screenshot."
        }
    }
}
