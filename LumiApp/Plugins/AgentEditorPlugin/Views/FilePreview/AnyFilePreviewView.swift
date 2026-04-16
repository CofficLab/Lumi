import SwiftUI
import QuickLookUI

/// 通用文件预览视图（基于 macOS QuickLook）
///
/// 使用 QLPreviewView 预览任何 macOS 支持的文件类型（JSON、CSV、XML、plist、视频、音频等）。
/// 如果文件无法预览，则显示文件图标缩略图。
struct AnyFilePreviewView: NSViewRepresentable {

    private let fileURL: URL

    init(_ fileURL: URL) {
        self.fileURL = fileURL
    }

    func makeNSView(context: Context) -> QLPreviewView {
        let qlPreviewView = QLPreviewView()
        qlPreviewView.previewItem = fileURL as NSURL
        qlPreviewView.shouldCloseWithWindow = false
        return qlPreviewView
    }

    func updateNSView(_ qlPreviewView: QLPreviewView, context: Context) {
        qlPreviewView.previewItem = fileURL as NSURL
    }

    static func dismantleNSView(_ qlPreviewView: QLPreviewView, coordinator: ()) {
        qlPreviewView.close()
    }
}
