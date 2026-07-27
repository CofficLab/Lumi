import AppKit
import SwiftUI

/// 菜单栏 SwiftUI 宿主视图：点击穿透到 `NSStatusBarButton`。
final class MenuBarHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

enum MenuBarAppearance {
    @MainActor
    static func performAsCurrent<T>(for button: NSStatusBarButton, _ work: () -> T) -> T {
        let appearance = button.window?.effectiveAppearance ?? button.effectiveAppearance
        var result: T!
        appearance.performAsCurrentDrawingAppearance {
            result = work()
        }
        return result
    }
}
