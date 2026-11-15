import AppKit
import Foundation
import SceneKit

/// 截图/PDF 导出（文档 Phase 3.1：视口截图 → PNG/PDF）。
///
/// SCNView 实现 SCNSceneRenderer 协议，通过 `snapshot(atTime:with:antialiasingOptions:)` 捕获画面。
public struct ScreenshotExporter {
    public init() {}

    /// 将 SCNView 当前画面导出为 PNG。
    ///
    /// 只有 SCNView 捕获需要 UI 访问，留在主线程；TIFF/PNG 转换与原子写入
    /// 随视口像素与场景复杂度增长，移到后台线程（#1195）。
    @MainActor
    public func exportPNG(from scnView: SCNView, to url: URL) async throws {
        guard let image = captureSnapshot(from: scnView),
              let rep = image.representations.first as? NSBitmapImageRep else {
            throw ScreenshotExporterError.snapshotFailed
        }
        let captured = CapturedBitmap(rep)
        try await Task.detached(priority: .userInitiated) {
            try Self.encodePNG(captured.rep, to: url)
        }.value
    }

    /// 在后台线程把已捕获的位图转换为 PNG 并原子写入磁盘。
    nonisolated static func encodePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
        guard let tiff = rep.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
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

/// 捕获后的位图快照视为不可变，仅读取；包一层越过 Swift 6 的 Sendable 检查，
/// 让主线程捕获的位图能交给后台线程编码（#1195）。
private struct CapturedBitmap: @unchecked Sendable {
    let rep: NSBitmapImageRep
    init(_ rep: NSBitmapImageRep) { self.rep = rep }
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
