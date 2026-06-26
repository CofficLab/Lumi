import AppKit
import SwiftUI

/// 将 SwiftUI 菜单栏内容渲染为 template `NSImage`，供 `NSStatusBarButton.image` 使用。
///
/// `ImageRenderer` 会随当前 `NSAppearance` 把前景渲成白/黑，直接设 `isTemplate` 无法被系统重新着色。
/// 因此渲染后须用 alpha 通道提取形状，强制转为「黑 + 透明」掩模（见 `docs/macos-menu-bar-appearance.md`）。
enum MenuBarTemplateImageRenderer {
    @MainActor
    static func render<V: View>(_ view: V) -> NSImage? {
        let content = view
            .environment(\.colorScheme, .light)
            .fixedSize()

        let renderer = ImageRenderer(content: content)
        renderer.isOpaque = false
        if let screen = NSScreen.main {
            renderer.scale = screen.backingScaleFactor
        }

        guard let image = renderer.nsImage else {
            return nil
        }

        return makeTemplateMask(from: image)
    }

    /// 从任意颜色的渲染结果提取 alpha，生成仅含黑色与透明的 template 掩模。
    private static func makeTemplateMask(from image: NSImage) -> NSImage {
        let size = image.size
        let mask = NSImage(size: size, flipped: false) { rect in
            NSColor.black.set()
            rect.fill()
            image.draw(
                in: rect,
                from: NSRect(origin: .zero, size: size),
                operation: .destinationIn,
                fraction: 1
            )
            return true
        }
        mask.isTemplate = true
        return mask
    }
}
