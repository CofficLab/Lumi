import CoreGraphics
import SwiftUI

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
private struct PDFPageCanvas: UIViewRepresentable {
    let documentURL: URL
    let pageNumber: Int

    func makeUIView(context: Context) -> PDFPageUIView {
        PDFPageUIView(documentURL: documentURL, pageNumber: pageNumber)
    }

    func updateUIView(_ uiView: PDFPageUIView, context: Context) {
        uiView.update(documentURL: documentURL, pageNumber: pageNumber)
    }
}

private final class PDFPageUIView: UIView {
    private var documentURL: URL
    private var pageNumber: Int
    private var document: CGPDFDocument?

    init(documentURL: URL, pageNumber: Int) {
        self.documentURL = documentURL
        self.pageNumber = pageNumber
        self.document = CGPDFDocument(documentURL as CFURL)
        super.init(frame: .zero)
        backgroundColor = .white
        isOpaque = true
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(documentURL: URL, pageNumber: Int) {
        if self.documentURL != documentURL {
            self.documentURL = documentURL
            document = CGPDFDocument(documentURL as CFURL)
        }
        if self.pageNumber != pageNumber {
            self.pageNumber = pageNumber
        }
        setNeedsDisplay(bounds)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        PDFPageRenderer.drawPage(context, bounds: bounds, document: document, pageNumber: pageNumber)
    }
}
#endif
