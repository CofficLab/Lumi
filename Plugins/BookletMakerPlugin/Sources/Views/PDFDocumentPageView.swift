import AppKit
import CoreGraphics
import SwiftUI

/// Resolution-independent rendering of one page from the current PDF.
struct PDFDocumentPageView: View {
    let documentURL: URL
    let pageNumber: Int

    var body: some View {
        PDFPageCanvas(documentURL: documentURL, pageNumber: pageNumber)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

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
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0,
              bounds.height > 0,
              let page = document?.page(at: pageNumber),
              let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let pageBox = page.getBoxRect(.mediaBox)
        guard pageBox.width > 0, pageBox.height > 0 else { return }
        let target = BookletLayoutEngine.fitRect(
            aspectRatio: pageBox.width / pageBox.height,
            into: bounds
        )

        context.saveGState()
        context.translateBy(x: target.minX, y: target.minY)
        context.scaleBy(
            x: target.width / pageBox.width,
            y: target.height / pageBox.height
        )
        context.translateBy(x: -pageBox.minX, y: -pageBox.minY)
        context.drawPDFPage(page)
        context.restoreGState()
    }
}
