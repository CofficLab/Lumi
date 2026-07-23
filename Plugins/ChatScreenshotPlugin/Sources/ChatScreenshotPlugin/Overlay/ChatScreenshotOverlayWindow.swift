import AppKit
import Foundation

/// 单个屏幕上的截图遮罩窗口
///
/// 关键属性:
/// - `borderless` + 透明背景 — 只显示 view 绘制的内容
/// - `level = .screenSaver` — 高于普通应用窗口,跨全屏也能浮在最上层
/// - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`
///   — 跨 Space、随全屏应用显现、不被 Dock 触发隐藏
@MainActor
final class ChatScreenshotOverlayWindow: NSPanel {
    init(screenFrame: CGRect, view: NSView) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}