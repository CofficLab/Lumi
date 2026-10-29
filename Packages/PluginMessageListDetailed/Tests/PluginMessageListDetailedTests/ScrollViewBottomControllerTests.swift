import AppKit
import Foundation
import Testing
@testable import PluginMessageListDetailed

/// 在无窗口环境下构造真实的 `NSScrollView` + `NSClipView` + `NSView` 文档视图，
/// 使「文档高度变化」这条路径在单元测试中可被精确驱动。
///
/// - Important: 无窗口时 `NSScrollView` 不会自行布局，clip view 尺寸会停在 0，
///   因此必须显式指定 frame，否则几何断言无从谈起。
@MainActor
final class ScrollViewHost {
    let scrollView = NSScrollView()
    let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 1_000))
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))

    init() {
        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        // 无窗口时 NSScrollView 不会自行布局，clip view 尺寸会停在 0。
        // 显式指定 frame 让几何可测，否则 pinToBottom 会因 visibleHeight == 0
        // 一律返回 nil。
        scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        scrollView.contentView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        container.addSubview(scrollView)
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    /// 调整文档高度，模拟 List 懒加载行陆续物化。
    func setDocumentHeight(_ height: CGFloat) {
        documentView.frame = NSRect(x: 0, y: 0, width: 400, height: height)
        // 布局可能把 clip 归零，这里强制复位保证几何可测。
        if scrollView.contentView.bounds.height == 0 {
            scrollView.contentView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        }
    }

    var snapshot: ScrollViewBottomController.Snapshot {
        ScrollViewBottomController.Snapshot(
            documentHeight: documentView.bounds.height,
            visibleHeight: scrollView.contentView.bounds.height,
            offsetY: scrollView.contentView.bounds.origin.y
        )
    }
}

