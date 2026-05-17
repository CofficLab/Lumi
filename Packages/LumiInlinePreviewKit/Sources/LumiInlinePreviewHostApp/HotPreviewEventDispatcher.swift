import AppKit
import CoreGraphics
import Foundation
import LumiInlinePreviewKit

/// 把跨进程的 `PreviewInputEvent` 合成为本机 `NSEvent`，注入子进程离屏窗口。
///
/// 设计要点：
/// - 鼠标 / 键盘 走 `NSEvent.mouseEvent(...)` / `keyEvent(...)` 工厂，再 `window.sendEvent(_:)`。
/// - 滚轮没有 `NSEvent` 工厂，只能借 `CGEvent(scrollWheelEvent2Source:...)` 创建后包成 `NSEvent`。
/// - 所有事件用真实 `windowNumber`，让 first responder 链路正常工作。
@MainActor
final class HotPreviewEventDispatcher {

    // MARK: - 私有

    private weak var renderer: HotPreviewRenderer?
    private var lastEventNumber: Int = 0

    // MARK: - 初始化

    init(renderer: HotPreviewRenderer) {
        self.renderer = renderer
    }

    // MARK: - 公开方法

    /// 把跨进程事件分发到离屏窗口。
    func dispatch(_ event: LumiInlinePreviewFacade.PreviewInputEvent) {
        guard let window = renderer?.hostWindow else { return }

        switch event {
        case let .mouse(mouse):
            dispatchMouse(mouse, into: window)
        case let .scrollWheel(scroll):
            dispatchScroll(scroll, into: window)
        case let .key(key):
            dispatchKey(key, into: window)
        case let .flagsChanged(modifiers):
            dispatchFlagsChanged(modifiers: modifiers, into: window)
        }
    }

    // MARK: - 私有 — 鼠标

    private func dispatchMouse(
        _ event: LumiInlinePreviewFacade.MouseEvent,
        into window: NSWindow
    ) {
        let type: NSEvent.EventType
        switch (event.phase, event.button) {
        case (.down, .left):    type = .leftMouseDown
        case (.up, .left):      type = .leftMouseUp
        case (.dragged, .left): type = .leftMouseDragged
        case (.down, .right):   type = .rightMouseDown
        case (.up, .right):     type = .rightMouseUp
        case (.dragged, .right): type = .rightMouseDragged
        case (.down, .other):   type = .otherMouseDown
        case (.up, .other):     type = .otherMouseUp
        case (.dragged, .other): type = .otherMouseDragged
        case (.moved, _):       type = .mouseMoved
        }

        let location = NSPoint(x: event.x, y: event.y)
        lastEventNumber &+= 1

        guard let nsEvent = NSEvent.mouseEvent(
            with: type,
            location: location,
            modifierFlags: event.modifiers.toAppKit(),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: lastEventNumber,
            clickCount: max(0, event.clickCount),
            pressure: event.phase == .down ? 1.0 : 0.0
        ) else {
            return
        }

        window.sendEvent(nsEvent)
    }

    // MARK: - 私有 — 滚轮

    private func dispatchScroll(
        _ event: LumiInlinePreviewFacade.ScrollWheelEvent,
        into window: NSWindow
    ) {
        // CGEvent 的滚轮以"行/像素"为单位；点滚动用 pixel 单位精度更高。
        let units: CGScrollEventUnit = event.hasPreciseScrollingDeltas ? .pixel : .line
        let wheel1 = Int32(event.scrollingDeltaY.rounded())
        let wheel2 = Int32(event.scrollingDeltaX.rounded())
        guard let cgEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: units,
            wheelCount: 2,
            wheel1: wheel1,
            wheel2: wheel2,
            wheel3: 0
        ) else {
            return
        }
        guard let nsEvent = NSEvent(cgEvent: cgEvent) else { return }
        window.sendEvent(nsEvent)
    }

    // MARK: - 私有 — 键盘

    private func dispatchKey(
        _ event: LumiInlinePreviewFacade.KeyEvent,
        into window: NSWindow
    ) {
        let type: NSEvent.EventType = event.phase == .down ? .keyDown : .keyUp
        guard let nsEvent = NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: event.modifiers.toAppKit(),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: event.characters ?? "",
            charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? event.characters ?? "",
            isARepeat: event.isARepeat,
            keyCode: event.keyCode
        ) else {
            return
        }
        window.sendEvent(nsEvent)
    }

    private func dispatchFlagsChanged(
        modifiers: LumiInlinePreviewFacade.ModifierFlags,
        into window: NSWindow
    ) {
        // flagsChanged 也通过 NSEvent.keyEvent 工厂构造（type = .flagsChanged）。
        guard let nsEvent = NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: modifiers.toAppKit(),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 0
        ) else {
            return
        }
        window.sendEvent(nsEvent)
    }
}

// 注：`ModifierFlags.toAppKit()` 与 `ScrollWheelEvent.Phase.toAppKit()` 在 kit 中定义，
// 见 `Models/PreviewInputEvent+AppKit.swift`，子进程通过 `import LumiInlinePreviewKit` 引入。
