//
//  TextView+Menu.swift
//  EditorTextView
//
//  Created by Khan Winter on 8/21/23.
//

import AppKit
import LumiCoreKit

extension TextView {
    override public func menu(for event: NSEvent) -> NSMenu? {
        guard event.type == .rightMouseDown else { return nil }

        let menu = NSMenu()

        menu.items = [
            NSMenuItem(title: LumiPluginLocalization.string("Cut", bundle: .module), action: #selector(cut(_:)), keyEquivalent: "x"),
            NSMenuItem(title: LumiPluginLocalization.string("Copy", bundle: .module), action: #selector(copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: LumiPluginLocalization.string("Paste", bundle: .module), action: #selector(paste(_:)), keyEquivalent: "v")
        ]

        return menu
    }
}
