import LumiKernel
import LumiUI
import os
import SuperLogKit
import PDFKit
import SwiftUI

/// PDF 文件预览视图。
///
/// 使用 PDFKit 的 PDFView 渲染 PDF，支持翻页和缩放。
public struct EditorPreviewPDFView: View, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.pdf-view"
    )
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = true

    @EnvironmentObject private var themeVM: AppThemeVM

    public let fileURL: URL

    public var body: some View {
        Group {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                fileNotFoundView
            } else {
                PDFViewWrapper(fileURL: fileURL)
            }
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    private var fileNotFoundView: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(String(
                format: LumiPluginLocalization.string("File not found: %@", bundle: .module),
                fileURL.lastPathComponent
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(24)
    }
}

// MARK: - PDFView Wrapper

private struct PDFViewWrapper: NSViewRepresentable {
    public let fileURL: URL

    public func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    public func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != fileURL {
            if let document = PDFDocument(url: fileURL) {
                pdfView.document = document
            }
        }
    }
}
