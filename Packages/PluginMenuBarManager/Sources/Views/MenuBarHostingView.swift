import AppKit
import SwiftUI

/// 承载状态栏图标视图的 `NSHostingView`,拦截命中测试使点击穿透到状态项按钮。
final class MenuBarHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
