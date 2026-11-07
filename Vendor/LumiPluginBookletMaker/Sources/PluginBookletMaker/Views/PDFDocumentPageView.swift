import CoreGraphics
import PDFKit
import SwiftUI
import BookletMakerCore

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Resolution-independent rendering of one page from the current PDF.
///
/// 公共 API 与调用方保持不变；平台差异（AppKit 的 `NSView` / UIKit 的 `UIView`）
/// 收口在内部的 ``PDFPageCanvas`` 与 ``PDFPageRenderer``，macOS 与 iOS 各一份实现，
/// 共享同一段 CoreGraphics 绘制逻辑。
struct PDFDocumentPageView: View {
    let documentURL: URL
    let pageNumber: Int

    var body: some View {
        PDFPageCanvas(documentURL: documentURL, pageNumber: pageNumber)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.black.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

/// A non-dynamic paper surface. App themes may replace SwiftUI semantic
/// backgrounds, but a PDF sheet must remain physical white in every theme.
///
/// 用 SwiftUI `Color.white`（绝对白、不受主题影响）替代原 macOS 专属的
/// `NSView` 白底，两个平台一致。
struct FixedWhitePaperSurface: View {
    var body: some View {
        Color.white
    }
}

/// Shared CoreGraphics drawing for one PDF page, used by both the macOS
/// (`NSView`) and iOS (`UIView`) canvas implementations.
private enum PDFPageRenderer {
    static func drawPage(
        _ context: CGContext,
        bounds: CGRect,
        document: CGPDFDocument?,
        pageNumber: Int
    ) {
        // PDF pages represent physical paper. Keep transparent page regions
        // white regardless of the app's current light or dark appearance,
        // matching Preview.app's page canvas.
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(bounds)

        guard bounds.width > 0,
              bounds.height > 0,
              let page = document?.page(at: pageNumber) else {
            return
        }

        // Match PDFKit and Preview.app: the crop box is the page's intended
        // visible area. Some PDFs keep a full spread in the media box and use
        // the crop box to expose only the left or right page.
        let pageBox = page.getBoxRect(.cropBox)
        guard pageBox.width > 0, pageBox.height > 0 else { return }
        let target = BookletLayoutEngine.fitRect(
            aspectRatio: pageBox.width / pageBox.height,
            into: bounds
        )

        context.saveGState()
        context.clip(to: target)
        context.concatenate(
            page.getDrawingTransform(
                .cropBox,
                rect: target,
                rotate: 0,
                preserveAspectRatio: true
            )
        )
        context.drawPDFPage(page)
        context.restoreGState()
    }
}

// MARK: - macOS (NSView)

#if canImport(AppKit)
private struct PDFPageCanvas: NSViewRepresentable {
    let documentURL: URL
    let pageNumber: Int

    func makeNSView(context: Context) -> PDFPageNSView {
        PDFPageNSView(documentURL: documentURL, pageNumber: pageNumber)
    }

    func updateNSView(_ nsView: PDFPageNSView, context: Context) {
        nsView.update(documentURL: documentURL, pageNumber: pageNumber)
    }
}

private final class PDFPageNSView: NSView {
    private var documentURL: URL
    private var pageNumber: Int
    private var document: CGPDFDocument?

    init(documentURL: URL, pageNumber: Int) {
        self.documentURL = documentURL
        self.pageNumber = pageNumber
        self.document = CGPDFDocument(documentURL as CFURL)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { true }

    func update(documentURL: URL, pageNumber: Int) {
        layer?.backgroundColor = NSColor.white.cgColor
        if self.documentURL != documentURL {
            self.documentURL = documentURL
            document = CGPDFDocument(documentURL as CFURL)
        }
        if self.pageNumber != pageNumber {
            self.pageNumber = pageNumber
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        PDFPageRenderer.drawPage(context, bounds: bounds, document: document, pageNumber: pageNumber)
    }
}
#endif

// MARK: - iOS (UIView)

#if canImport(UIKit)
private final class PDFPreviewImage: @unchecked Sendable {
    let cgImage: CGImage

    init(_ cgImage: CGImage) {
        self.cgImage = cgImage
    }
}

/// Opens the source PDF once and renders page-sized thumbnails away from the
/// main thread. A bounded image cache lets recycled grid cells reuse work.
private actor PDFPagePreviewCache {
    static let shared = PDFPagePreviewCache()

    private let images = NSCache<NSString, PDFPreviewImage>()
    private var documentFingerprint: String?
    private var document: PDFDocument?

    private init() {
        images.totalCostLimit = 48 * 1024 * 1024
    }

    func image(
        for url: URL,
        pageNumber: Int,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> PDFPreviewImage? {
        guard !Task.isCancelled, pixelWidth > 0, pixelHeight > 0 else { return nil }

        let fileURL = url.standardizedFileURL
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let modified = values?.contentModificationDate?.timeIntervalSince1970.bitPattern ?? 0
        let fingerprint = "\(fileURL.path):\(values?.fileSize ?? -1):\(modified)"
        let cacheKey = "\(fingerprint):\(pageNumber):\(pixelWidth)x\(pixelHeight)" as NSString
        if let cached = images.object(forKey: cacheKey) {
            return cached
        }

        if documentFingerprint != fingerprint {
            documentFingerprint = fingerprint
            document = PDFDocument(url: fileURL)
        }
        guard let document,
              let page = document.page(at: pageNumber - 1) else {
            return nil
        }

        let thumbnail = page.thumbnail(
            of: CGSize(width: pixelWidth, height: pixelHeight),
            for: .cropBox
        )
        guard !Task.isCancelled, let cgImage = thumbnail.cgImage else { return nil }

        let preview = PDFPreviewImage(cgImage)
        images.setObject(preview, forKey: cacheKey, cost: pixelWidth * pixelHeight * 4)
        return preview
    }
}

private struct PDFPageCanvas: UIViewRepresentable {
    let documentURL: URL
    let pageNumber: Int

    func makeUIView(context: Context) -> PDFPageUIView {
        PDFPageUIView(documentURL: documentURL, pageNumber: pageNumber)
    }

    func updateUIView(_ uiView: PDFPageUIView, context: Context) {
        uiView.update(documentURL: documentURL, pageNumber: pageNumber)
    }

    static func dismantleUIView(_ uiView: PDFPageUIView, coordinator: ()) {
        uiView.cancelThumbnailRequest()
    }
}

private final class PDFPageUIView: UIView {
    private var documentURL: URL
    private var pageNumber: Int
    private let pageImageView = UIImageView()
    private var thumbnailTask: Task<Void, Never>?
    private var requestedPixelSize: CGSize?

    init(documentURL: URL, pageNumber: Int) {
        self.documentURL = documentURL
        self.pageNumber = pageNumber
        super.init(frame: .zero)
        backgroundColor = .white
        isOpaque = true
        contentMode = .redraw
        pageImageView.backgroundColor = .white
        pageImageView.contentMode = .scaleAspectFit
        pageImageView.isOpaque = true
        addSubview(pageImageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(documentURL: URL, pageNumber: Int) {
        var pageChanged = false
        var documentChanged = false
        if self.documentURL != documentURL {
            self.documentURL = documentURL
            pageChanged = true
            documentChanged = true
        }
        if self.pageNumber != pageNumber {
            self.pageNumber = pageNumber
            pageChanged = true
        }
        if pageChanged {
            thumbnailTask?.cancel()
            requestedPixelSize = nil
            // A new page can take noticeably longer to rasterize in a large
            // PDF. Keep the current bitmap visible until its replacement is
            // ready instead of exposing a white frame during the page turn.
            if documentChanged {
                pageImageView.image = nil
            }
            loadThumbnailIfNeeded()
        }
    }

    func cancelThumbnailRequest() {
        thumbnailTask?.cancel()
        thumbnailTask = nil
        requestedPixelSize = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pageImageView.frame = bounds
        loadThumbnailIfNeeded()
    }

    private func loadThumbnailIfNeeded() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        // These are small print-layout previews. Two pixels per point keeps
        // them crisp while avoiding full-resolution PDF drawing during scroll.
        let scale = min(contentScaleFactor, 2)
        let pixelSize = CGSize(
            width: (bounds.width * scale).rounded(.up),
            height: (bounds.height * scale).rounded(.up)
        )
        guard requestedPixelSize != pixelSize else { return }
        requestedPixelSize = pixelSize

        thumbnailTask?.cancel()
        let url = documentURL
        let page = pageNumber
        let pixelWidth = Int(pixelSize.width)
        let pixelHeight = Int(pixelSize.height)
        thumbnailTask = Task { [weak self] in
            guard let preview = await PDFPagePreviewCache.shared.image(
                for: url,
                pageNumber: page,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight
            ) else {
                return
            }
            guard !Task.isCancelled,
                  let self,
                  self.documentURL == url,
                  self.pageNumber == page,
                  self.requestedPixelSize == pixelSize else {
                return
            }
            self.pageImageView.image = UIImage(cgImage: preview.cgImage)
        }
    }
}
#endif
