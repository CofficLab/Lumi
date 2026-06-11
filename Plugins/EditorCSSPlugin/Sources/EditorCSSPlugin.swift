import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// CSS 语言编辑器插件：提供 CSS 补全和悬浮提示
public actor EditorCSSPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = EditorCSSPlugin()
    public static let id = "CSSEditor"
    public static let displayName = String(localized: "CSS Language Tools", bundle: .module)
    public static let description = String(localized: "Provides CSS completions and hover help for common properties and values.", bundle: .module)
    public static let iconName = "paintpalette"
    public static let order = 32
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCompletionContributor(CSSCompletionContributor())
        registry.registerHoverContributor(CSSHoverContributor())
    }
}
