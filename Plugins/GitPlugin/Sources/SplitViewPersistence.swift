import AppKit
import SwiftUI

struct SplitViewAutosaveConfigurator: NSViewRepresentable {
    let autosaveName: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            enclosingSplitView(from: nsView)?.autosaveName = autosaveName
        }
    }
}

struct SplitViewWidthPersistence: NSViewRepresentable {
    let storageKey: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
private func enclosingSplitView(from view: NSView) -> NSSplitView? {
    var current = view.superview
    while let view = current {
        if let splitView = view as? NSSplitView {
            return splitView
        }
        current = view.superview
    }
    return nil
}
