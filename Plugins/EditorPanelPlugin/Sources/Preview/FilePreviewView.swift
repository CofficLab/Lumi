import AppKit
import Foundation
import PDFKit
import QuickLookUI
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// MARK: - Preview Kind

enum FilePreviewKind: Equatable {
    case image
    case pdf
    case quickLook
}

enum FilePreviewResolver {
    static func previewKind(for fileURL: URL) -> FilePreviewKind {
        let ext = fileURL.pathExtension.lowercased()
        let utType = ext.isEmpty ? nil : UTType(filenameExtension: ext)

        if utType?.conforms(to: .image) == true {
            return .image
        }
        if utType?.conforms(to: .pdf) == true || ext == "pdf" {
            return .pdf
        }
        return .quickLook
    }
}

// MARK: - FilePreviewView

/// 本地文件的 SwiftUI 预览（图片 / PDF / QuickLook 支持的其它类型）。
struct FilePreviewView: View {

    let fileURL: URL

    var body: some View {
        Group {
            switch FilePreviewResolver.previewKind(for: fileURL) {
            case .image:
                _ImageFilePreview(fileURL: fileURL)
            case .pdf:
                _PDFFilePreview(fileURL: fileURL)
            case .quickLook:
                _QuickLookFilePreview(fileURL: fileURL)
            }
        }
    }
}

// MARK: - QuickLook

/// 基于 macOS QuickLook 的通用预览（JSON、音视频等）；无法预览时由系统展示缩略或占位。
private struct _QuickLookFilePreview: NSViewRepresentable {

    let fileURL: URL

    func makeNSView(context: Context) -> _QuickLookPreviewHostView {
        let host = _QuickLookPreviewHostView()
        host.previewView.previewItem = fileURL as NSURL
        host.scheduleLayoutPasses()
        return host
    }

    func updateNSView(_ hostView: _QuickLookPreviewHostView, context: Context) {
        let currentURL = hostView.previewView.previewItem as? URL
        guard currentURL != fileURL else { return }
        hostView.previewView.previewItem = fileURL as NSURL
        hostView.scheduleLayoutPasses()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: _QuickLookPreviewHostView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }

    static func dismantleNSView(_ hostView: _QuickLookPreviewHostView, coordinator: ()) {
        hostView.previewView.close()
    }
}

/// 让 QLPreviewView 始终铺满 SwiftUI 分配区域，避免滚动条停在内容宽度处。
@MainActor
private final class _QuickLookPreviewHostView: NSView {
    let previewView: QLPreviewView = {
        let view = QLPreviewView()
        view.shouldCloseWithWindow = false
        view.autoresizingMask = [.width, .height]
        return view
    }()

    private var layoutPassToken = UUID()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(previewView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewView.frame = bounds
        _QuickLookPreviewLayoutExpander.expand(in: previewView)
    }

    /// QuickLook 异步生成预览后会重新居中内容，补几次 layout 覆盖初始加载阶段。
    func scheduleLayoutPasses() {
        layoutPassToken = UUID()
        let token = layoutPassToken
        let delays: [TimeInterval] = [0, 0.15, 0.5, 1.5]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.layoutPassToken == token else { return }
                self.needsLayout = true
            }
        }
    }
}

/// QuickLook 的 Office 预览会把 `QLWeb2View` 居中并限制宽度，导致滚动条不在面板最右侧。
@MainActor
private enum _QuickLookPreviewLayoutExpander {
    private static let officeCenteringStyleID = "lumi-quicklook-office-center"
    private static let officeCenteringCSS = """
    body { margin: 0 !important; }
    body > div { margin-left: auto !important; margin-right: auto !important; }
    """

    static func expand(in view: NSView) {
        for subview in view.subviews {
            if String(describing: type(of: subview)).contains("CenteringView") {
                for child in subview.subviews {
                    child.frame = subview.bounds
                    child.autoresizingMask = [.width, .height]
                }
            }
            if let webView = subview as? WKWebView {
                centerOfficePreviewContent(in: webView)
            }
            expand(in: subview)
        }
    }

    private static func centerOfficePreviewContent(in webView: WKWebView) {
        let script = """
        (function() {
            var style = document.getElementById('\(officeCenteringStyleID)');
            if (!style) {
                style = document.createElement('style');
                style.id = '\(officeCenteringStyleID)';
                document.head.appendChild(style);
            }
            style.textContent = `\(officeCenteringCSS.replacingOccurrences(of: "`", with: "\\`"))`;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
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
