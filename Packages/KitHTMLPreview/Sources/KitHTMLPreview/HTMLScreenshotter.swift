import AppKit
import PDFKit
import WebKit

/// HTML WebView 全页截图工具。
///
/// 使用 `WKWebView.createPDF` 生成完整页面 PDF，再用 CoreGraphics 逐页渲染到 `NSImage`。
/// 完全绕开 `takeSnapshot` 的 tile-based 渲染限制，不会出现黑色未渲染区域。
@MainActor
public struct HTMLScreenshotter {

    /// 截取 WebView 完整页面内容，返回 `NSImage`。
    ///
    /// - Parameters:
    ///   - webView: 已加载 HTML 内容的 `WKWebView` 实例
    ///   - timeout: 等待 WebKit 生成 PDF 的最长时间（秒）。超时抛 `HTMLError.renderTimedOut`。
    /// - Returns: 包含完整页面内容的 `NSImage`
    ///
    /// - Note: `WKWebView.createPDF` 的完成回调**不保证**一定送达。若 WebKit 进程
    ///   状态异常或页面始终无法完成布局，回调可能永不到达，此时 continuation 永不恢复，
    ///   调用方（以及 `swift test` 进程）会永久挂起。因此这里必须带超时保护。
    public static func capture(
        _ webView: WKWebView,
        timeout: TimeInterval = 30,
        limits: HTMLScreenshotLimits = .standard
    ) async throws -> NSImage {
        let pdfData = try await createPDF(from: webView, timeout: timeout)

        guard let pdfDocument = PDFDocument(data: pdfData) else {
            throw HTMLError.pdfCreationFailed
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw HTMLError.emptyDocument
        }

        // 计算所有页面的总尺寸
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        var pageBounds: [CGRect] = []

        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            pageBounds.append(bounds)
            totalHeight += bounds.height
            maxWidth = max(maxWidth, bounds.width)
        }

        let geometry = HTMLScreenshotGeometry(
            pageCount: pageCount,
            width: maxWidth,
            height: totalHeight
        )
        guard !geometry.isEmpty else {
            throw HTMLError.emptyDocument
        }
        // CSS 文档高度不受画布尺寸约束：先按页数与总像素拒绝，
        // 再分配位图，避免超长页面驱动无界的内存分配与主线程栅格化。
        guard !geometry.exceeds(limits) else {
            throw HTMLError.snapshotTooLarge(
                pageCount: geometry.pageCount,
                width: geometry.width,
                height: geometry.height
            )
        }

        let imageSize = NSSize(width: maxWidth, height: totalHeight)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        // 填充白色背景
        NSColor.white.set()
        NSRect(origin: .zero, size: imageSize).fill()

        guard let context = NSGraphicsContext.current else {
            image.unlockFocus()
            throw HTMLError.renderingFailed("Failed to get graphics context")
        }

        let cgContext = context.cgContext

        // NSImage.lockFocus() 创建的 CGContext 原点位于左下角，Y 轴向上，
        // 与 PDF 坐标系一致。PDFPage.draw() 内部会自行处理坐标映射，
        // 所以不需要额外翻转。
        // 但页面需要反向绘制：先画最后一页到图像底部，再画第一页到图像顶部。
        // 这样用户在左上角原点的图像中看到的就是正确从上到下的 HTML 内容。
        var currentY: CGFloat = 0
        for (index, bounds) in pageBounds.enumerated().reversed() {
            guard let page = pdfDocument.page(at: index) else { continue }

            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: currentY)

            page.draw(with: .mediaBox, to: cgContext)

            cgContext.restoreGState()
            currentY += bounds.height
        }

        image.unlockFocus()
        return image
    }

    /// 调用 `WKWebView.createPDF` 并等待结果，带超时保护。
    ///
    /// WebKit 的完成回调不保证送达；没有超时的话，未送达时 continuation 永不恢复，
    /// 调用方会永久挂起（见 Issue #127）。
    private static func createPDF(from webView: WKWebView, timeout: TimeInterval) async throws -> Data {
        let state = PDFRequestState()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            state.attach(continuation)

            webView.createPDF { result in
                switch result {
                case .success(let data):
                    state.finish(.success(data))
                case .failure(let error):
                    state.finish(.failure(error))
                }
            }

            // 超时兜底：回调永不到达时也要恢复 continuation，否则调用方永久挂起。
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                state.finish(.failure(HTMLError.renderTimedOut))
            }
        }
    }

    /// `createPDF` 的一次性完成状态。
    ///
    /// WebKit 回调与超时任务都可能先到，用一次性 `finish` 保证 continuation 只被恢复一次。
    @MainActor
    final class PDFRequestState {
        private var continuation: CheckedContinuation<Data, Error>?
        private var completed = false

        /// 是否已经完成（用于断言「continuation 只被恢复一次」）。
        var isCompleted: Bool { completed }

        func attach(_ continuation: CheckedContinuation<Data, Error>) {
            self.continuation = continuation
        }

        func finish(_ result: Result<Data, Error>) {
            guard !completed else { return }
            completed = true
            let pending = continuation
            continuation = nil
            switch result {
            case .success(let data): pending?.resume(returning: data)
            case .failure(let error): pending?.resume(throwing: error)
            }
        }
    }
}

// MARK: - Limits

/// 全页快照的独立资源上限。
///
/// `createPDF` 会按页面高度把文档切成任意多页，合成图片的尺寸由 PDF 的
/// 页数与页面高度决定，而不是调用方传入的画布尺寸。没有独立上限时，
/// 一段正常的 HTML 就能通过 CSS 高度驱动大量页面、同步栅格化与位图分配。
public struct HTMLScreenshotLimits: Sendable, Equatable {
    public var maxPageCount: Int
    public var maxPixels: CGFloat
    public var maxDimension: CGFloat

    public init(
        maxPageCount: Int = 64,
        maxPixels: CGFloat = 16_000_000,
        maxDimension: CGFloat = 16_000
    ) {
        self.maxPageCount = maxPageCount
        self.maxPixels = maxPixels
        self.maxDimension = maxDimension
    }

    public static let standard = HTMLScreenshotLimits()
}

/// 由 PDF 页面推导出的合成图片尺寸，用于在分配位图前校验资源上限。
struct HTMLScreenshotGeometry: Equatable {
    let pageCount: Int
    let width: CGFloat
    let height: CGFloat

    var isEmpty: Bool {
        pageCount <= 0 || width <= 0 || height <= 0
    }

    func exceeds(_ limits: HTMLScreenshotLimits) -> Bool {
        pageCount > limits.maxPageCount
            || width > limits.maxDimension
            || height > limits.maxDimension
            || width * height > limits.maxPixels
    }
}

// MARK: - Error

extension HTMLScreenshotter {
    public enum HTMLError: Error, LocalizedError {
        case pdfCreationFailed
        case emptyDocument
        case renderingFailed(String)
        /// 等待 WebKit 渲染结果超时。
        case renderTimedOut
        /// 页面页数或像素数超出快照上限。
        case snapshotTooLarge(pageCount: Int, width: CGFloat, height: CGFloat)

        public var errorDescription: String? {
            switch self {
            case .pdfCreationFailed:
                return "Failed to create PDF from HTML content"
            case .emptyDocument:
                return "PDF document is empty"
            case .renderingFailed(let msg):
                return "Rendering failed: \(msg)"
            case .renderTimedOut:
                return "Timed out while rendering HTML content"
            case .snapshotTooLarge(let pageCount, let width, let height):
                return "The HTML page is too large to snapshot "
                    + "(\(pageCount) pages, \(Int(width))x\(Int(height))). "
                    + "Reduce the document height."
            }
        }
    }
}
