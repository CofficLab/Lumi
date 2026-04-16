import SwiftUI
import PDFKit

/// PDF 文件预览视图
///
/// 使用 PDFKit.PDFView 渲染 PDF 文档。
/// 支持缩放、滚动、页面导航等 PDF 原生交互。
struct PDFFilePreviewView: NSViewRepresentable {

    private let fileURL: URL

    init(_ fileURL: URL) {
        self.fileURL = fileURL
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        attachPDFDocument(to: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        attachPDFDocument(to: pdfView)
    }

    /// 将 PDF 文档附加到 PDFView。
    /// 如果文件无法解析为 PDF，则不做任何修改。
    @discardableResult
    private func attachPDFDocument(to pdfView: PDFView) -> PDFView {
        guard let pdfDocument = PDFDocument(url: fileURL) else {
            return pdfView
        }
        pdfView.document = pdfDocument
        pdfView.backgroundColor = NSColor.textBackgroundColor
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        return pdfView
    }
}
