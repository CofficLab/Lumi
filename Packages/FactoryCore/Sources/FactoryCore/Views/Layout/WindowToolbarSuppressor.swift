import AppKit
import SwiftUI

/// Prevents nested SwiftUI toolbars from attaching an NSToolbar that overlaps
/// the app-level custom title toolbar.
struct WindowToolbarSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        clearToolbar(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        clearToolbar(from: nsView)
    }

    private func clearToolbar(from view: NSView) {
        DispatchQueue.main.async {
            view.window?.toolbar = nil
        }
    }
}
