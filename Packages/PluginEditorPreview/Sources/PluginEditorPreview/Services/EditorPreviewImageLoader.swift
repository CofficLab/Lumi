import AppKit
import Foundation

/// 预览图片的后台加载（#1194）。
///
/// 原先 `EditorPreviewView.content` 在视图求值时同步 `NSImage(contentsOf:)`：
/// 选中大图或慢盘文件会阻塞渲染，且每次 body 重新求值都重复打开同一 URL。
enum EditorPreviewImageLoader {

    /// `NSImage` 非 Sendable，装箱后跨线程传递；创建后只读，跨线程安全。
    struct Box: @unchecked Sendable {
        let image: NSImage
    }

    /// 同步打开图片，便于在后台线程调用与单元测试。
    nonisolated static func loadBox(at url: URL) -> Box? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return Box(image: image)
    }

    /// 在后台线程打开图片；打不开时返回 nil，由调用方决定失败态。
    nonisolated static func load(at url: URL) async -> Box? {
        await Task.detached(priority: .userInitiated) {
            loadBox(at: url)
        }.value
    }
}