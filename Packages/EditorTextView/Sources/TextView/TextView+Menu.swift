//
//  TextView+Menu.swift
//  EditorTextView
//
//  Created by Khan Winter on 8/21/23.
//

import AppKit

extension TextView {
    override public func menu(for event: NSEvent) -> NSMenu? {
        guard event.type == .rightMouseDown else { return nil }

        let menu = NSMenu()

        menu.items = [
            NSMenuItem(title: String(localized: "Cut", bundle: .module), action: #selector(cut(_:)), keyEquivalent: "x"),
            NSMenuItem(title: String(localized: "Copy", bundle: .module), action: #selector(copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: String(localized: "Paste", bundle: .module), action: #selector(paste(_:)), keyEquivalent: "v")
        ]

        return menu
    }
}
