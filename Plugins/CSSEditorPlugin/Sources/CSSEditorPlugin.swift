import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// CSS 语言编辑器插件：提供 CSS 补全和悬浮提示
public actor CSSEditorPlugin: SuperPlugin {
    public static let shared = CSSEditorPlugin()
    public static let id = "CSSEditor"
    public static let displayName = "CSS Language Tools"
    public static let description = "Provides CSS completions and hover help for common properties and values."
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
