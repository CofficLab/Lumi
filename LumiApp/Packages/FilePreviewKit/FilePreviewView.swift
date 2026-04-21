import AppKit
import PDFKit
import QuickLookUI
import SwiftUI
import UniformTypeIdentifiers

/// 本地文件的 SwiftUI 预览（图片 / PDF / QuickLook 支持的其它类型）。
struct FilePreviewView: View {

    let fileURL: URL

    var body: some View {
        let ext = fileURL.pathExtension.lowercased()
        let utType = UTType(filenameExtension: ext)

        Group {
            if utType?.conforms(to: .image) == true {
                _ImageFilePreview(fileURL: fileURL)
            } else if utType?.conforms(to: .pdf) == true || ext == "pdf" {
                _PDFFilePreview(fileURL: fileURL)
            } else {
                _QuickLookFilePreview(fileURL: fileURL)
            }
        }
    }
}

// MARK: - QuickLook

/// 基于 macOS QuickLook 的通用预览（JSON、音视频等）；无法预览时由系统展示缩略或占位。
private struct _QuickLookFilePreview: NSViewRepresentable {

    let fileURL: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView()
        view.previewItem = fileURL as NSURL
        view.shouldCloseWithWindow = false
        return view
    }

    func updateNSView(_ qlPreviewView: QLPreviewView, context: Context) {
        qlPreviewView.previewItem = fileURL as NSURL
    }

    static func dismantleNSView(_ qlPreviewView: QLPreviewView, coordinator: ()) {
        qlPreviewView.close()
    }
}

// MARK: - PDF

private struct _PDFFilePreview: NSViewRepresentable {

    let fileURL: URL

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        attachDocument(to: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        attachDocument(to: pdfView)
    }

    @discardableResult
    private func attachDocument(to pdfView: PDFView) -> PDFView {
        guard let doc = PDFDocument(url: fileURL) else { return pdfView }
        pdfView.document = doc
        pdfView.backgroundColor = NSColor.textBackgroundColor
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        return pdfView
    }
}

// MARK: - Image

/// 小图不强行拉伸，大图限制在可用区域内；底层仍用 QuickLook 展示。
private struct _ImageFilePreview: View {

    let fileURL: URL

    var body: some View {
        if let nsImage = NSImage(contentsOf: fileURL),
           let rep = nsImage.representations.first {

            let pixelWidth = CGFloat(rep.pixelsWide)
            let pixelHeight = CGFloat(rep.pixelsHigh)

            GeometryReader { proxy in
                ZStack {
                    _QuickLookFilePreview(fileURL: fileURL)
                        .frame(
                            maxWidth: min(pixelWidth, proxy.size.width, nsImage.size.width),
                            maxHeight: min(pixelHeight, proxy.size.height, nsImage.size.height)
                        )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        } else {
            unsupported
        }
    }

    private var unsupported: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("Cannot preview image")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
