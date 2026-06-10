import AppKit
import SwiftUI

/// Prevents SwiftUI `.toolbar` or other editor chrome from attaching an NSToolbar
/// that overlaps the app-level custom title toolbar.
public struct EditorWindowToolbarSuppressor: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        clearToolbar(from: view)
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        clearToolbar(from: nsView)
    }

    private func clearToolbar(from view: NSView) {
        DispatchQueue.main.async {
            view.window?.toolbar = nil
        }
    }
}
