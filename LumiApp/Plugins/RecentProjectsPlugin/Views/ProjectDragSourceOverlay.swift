import AppKit
import SwiftUI

/// 基于 AppKit 原生拖拽的透明 overlay，将项目路径写入粘贴板。
/// 拖到输入框时，会自动填充项目的路径字符串。
struct ProjectDragSourceOverlay: NSViewRepresentable {
    let projectPath: String
    let projectName: String

    func makeNSView(context: Context) -> ProjectDragSourceView {
        let view = ProjectDragSourceView(projectPath: projectPath, projectName: projectName)
        return view
    }

    func updateNSView(_ nsView: ProjectDragSourceView, context: Context) {
        nsView.projectPath = projectPath
        nsView.projectName = projectName
    }
}

/// 支持 AppKit 原生拖拽的透明 NSView，用于项目拖拽
final class ProjectDragSourceView: NSView, NSDraggingSource {
    var projectPath: String
    var projectName: String

    init(projectPath: String, projectName: String) {
        self.projectPath = projectPath
        self.projectName = projectName
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        // 不拦截 mouseDown，让事件穿透到下层 SwiftUI 视图处理点击
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        // 构建拖拽粘贴板
        let pasteboardItem = NSPasteboardItem()
        // 写入文件 URL（项目目录也是文件 URL）
        let fileURL = URL(fileURLWithPath: projectPath)
        pasteboardItem.setString(fileURL.absoluteString, forType: .fileURL)
        // 写入纯文本路径（拖到输入框时使用）
        pasteboardItem.setString(projectPath, forType: .string)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

        // 设置拖拽预览
        let previewImage = dragPreviewImage()
        let startPoint = convert(convert(event.locationInWindow, from: nil), to: nil)
        draggingItem.setDraggingFrame(
            NSRect(x: startPoint.x - previewImage.size.width / 2,
                   y: startPoint.y - previewImage.size.height / 2,
                   width: previewImage.size.width,
                   height: previewImage.size.height),
            contents: previewImage
        )

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    // MARK: - Preview

    private func dragPreviewImage() -> NSImage {
        let icon = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)!
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]
        let text = NSAttributedString(string: projectName, attributes: textAttrs)
        let textSize = text.size()
        let iconSize = NSSize(width: 14, height: 14)
        let hSpacing: CGFloat = 6
        let hPadding: CGFloat = 10
        let vPadding: CGFloat = 6

        let totalWidth = hPadding + iconSize.width + hSpacing + textSize.width + hPadding
        let totalHeight = max(iconSize.height, textSize.height) + vPadding * 2

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        image.lockFocus()

        // 背景圆角矩形
        let bgRect = NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 8, yRadius: 8)
        NSColor.controlAccentColor.withAlphaComponent(0.95).setFill()
        bgPath.fill()

        // 图标
        let iconY = (totalHeight - iconSize.height) / 2
        icon.draw(in: NSRect(x: hPadding, y: iconY, width: iconSize.width, height: iconSize.height))

        // 文本
        let textY = (totalHeight - textSize.height) / 2
        text.draw(at: NSPoint(x: hPadding + iconSize.width + hSpacing, y: textY))

        image.unlockFocus()
        return image
    }
}
