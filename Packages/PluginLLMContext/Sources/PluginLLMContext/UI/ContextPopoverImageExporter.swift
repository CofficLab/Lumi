#if os(macOS)
import LumiLoggingKit
import SwiftUI
import UniformTypeIdentifiers

/// 上下文弹窗的 PNG 导出能力。
///
/// 负责「渲染视图 → 弹出保存面板 → 写入 PNG」这条固定流程，
/// 让 `ContextPopover` 只负责提供要导出的内容。
///
/// 仅 macOS：`NSSavePanel` 与 `NSBitmapImageRep` 是 AppKit API，
/// iOS 没有等价的「另存为」交互。
@MainActor
enum ContextPopoverImageExporter {
    /// 导出倍率；2 倍兼顾清晰度与文件体积。
    private static let exportScale: CGFloat = 2.0

    /// 渲染并保存为 PNG。
    ///
    /// 用户取消保存时不视为错误；渲染或写入失败则记录日志。
    /// 导出是附加功能，不应以弹窗打断用户正在查看的上下文数据。
    ///
    /// 渲染（`ImageRenderer`）与保存面板必须留在主线程，
    /// PNG 编码与写盘则交给后台执行，避免大图导出时卡住主线程。
    static func export(content: some View, suggestedFileName: String) async {
        guard let image = render(content: content) else {
            LLMContextPlugin.logger.error("\(LLMContextPlugin.t)上下文弹窗导出失败：视图渲染为空")
            return
        }
        guard let url = chooseDestination(suggestedFileName: suggestedFileName) else { return }
        await write(image, to: url)
    }

    /// 把视图渲染为位图。
    ///
    /// 传入的内容必须自行决定高度：`ImageRenderer` 会把 `ScrollView`
    /// 展开到完整内容高度，但会遵守 `.frame(maxHeight:)` 这类高度上限。
    static func render(content: some View) -> CGImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = exportScale
        return renderer.cgImage
    }

    /// 弹出保存面板；用户取消时返回 `nil`。
    static func chooseDestination(suggestedFileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFileName
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// 把位图写成 PNG 文件。
    ///
    /// PNG 编码与写盘都不需要主线程，而导出图的高度随压缩历史线性增长
    /// （可达数百万像素），因此整体放到后台任务执行，避免卡住界面。
    static func write(_ image: CGImage, to url: URL) async {
        await Task.detached(priority: .userInitiated) {
            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                LLMContextPlugin.logger.error("\(LLMContextPlugin.t)上下文弹窗导出失败：无法编码 PNG")
                return
            }
            do {
                try data.write(to: url)
            } catch {
                LLMContextPlugin.logger.error(
                    "\(LLMContextPlugin.t)上下文弹窗导出失败：写入出错 \(error.localizedDescription, privacy: .public)"
                )
            }
        }.value
    }
}
#endif
