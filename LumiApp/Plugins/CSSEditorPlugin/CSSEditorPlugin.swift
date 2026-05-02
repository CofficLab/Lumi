import Foundation
import SwiftUI

/// CSS 语言编辑器插件：提供 CSS 补全和悬浮提示
actor CSSEditorPlugin: SuperPlugin {
    static let id = "CSSEditor"
    static let displayName = "CSS Language Tools"
    static let description = "Provides CSS completions and hover help for common properties and values."
    static let iconName = "paintpalette"
    static let order = 32
    static let enable = true
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerCompletionContributor(CSSCompletionContributor())
        registry.registerHoverContributor(CSSHoverContributor())
    }
}
