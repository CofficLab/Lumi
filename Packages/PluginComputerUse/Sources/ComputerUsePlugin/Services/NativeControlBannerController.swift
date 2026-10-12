import AppKit
import SwiftUI

@MainActor
final class NativeControlBannerController {
    private let panel: NSPanel
    private var shortcut: Any?
    private var localShortcut: Any?

    init(state: NativeControlCoordinator) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 210),
                        styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "Lumi"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: NativeControlStatusView(state: state).padding(18).frame(width: 380))
        localShortcut = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak state] event in
            if event.keyCode == 53 && event.modifierFlags.contains([.command, .shift]) {
                MainActor.assumeIsolated { state?.stop() }
            }
            return event
        }
        shortcut = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak state] event in
            if event.keyCode == 53 && event.modifierFlags.contains([.command, .shift]) {
                MainActor.assumeIsolated { state?.stop() }
            }
        }
    }

    func show() {
        if let screen = NSScreen.main {
            panel.setFrameTopLeftPoint(NSPoint(x: screen.visibleFrame.maxX - 400, y: screen.visibleFrame.maxY - 20))
        }
        panel.orderFrontRegardless()
    }

    func avoid(_ screenPoint: CGPoint) {
        guard let screen = NSScreen.screens.first, let mainHeight = NSScreen.screens.first?.frame.height else { return }
        let point = NSPoint(x: screenPoint.x, y: mainHeight - screenPoint.y)
        if panel.frame.insetBy(dx: -20, dy: -20).contains(point) {
            let x = panel.frame.midX > screen.visibleFrame.midX ? screen.visibleFrame.minX + 20 : screen.visibleFrame.maxX - 400
            panel.setFrameTopLeftPoint(NSPoint(x: x, y: screen.visibleFrame.maxY - 20))
        }
    }

    func close() {
        if let shortcut { NSEvent.removeMonitor(shortcut) }
        shortcut = nil
        if let localShortcut { NSEvent.removeMonitor(localShortcut) }
        localShortcut = nil
        panel.close()
    }
}
