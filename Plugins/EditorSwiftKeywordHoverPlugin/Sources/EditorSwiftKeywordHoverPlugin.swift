import Foundation
import EditorService
import LumiCoreKit

/// Swift 关键字悬浮提示编辑器插件：显示常见 Swift 关键字的文档
public actor EditorSwiftKeywordHoverPlugin: SuperPlugin {
    public static let shared = EditorSwiftKeywordHoverPlugin()
    public static let id = "EditorSwiftKeywordHover"
    public static let displayName = String(localized: "Editor Swift Keyword Hover", bundle: .module)
    public static let description = String(localized: "Shows inline hover documentation for common Swift keywords.", bundle: .module)
    public static let iconName = "swift"
    public static let order = 20
    public static var category: PluginCategory { .general }
    public nonisolated static let policy: PluginPolicy = .disabled

    /// 插件注册策略：开发中，暂不注册

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerHoverContributor(EditorSwiftKeywordHoverContributor())
    }
}
