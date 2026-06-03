import Foundation
import EditorService
import LumiCoreKit

/// 编辑器 decoration 样例插件：演示 git-like 与 custom gutter decoration 的接入方式。
public actor SampleDecorationEditorPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = SampleDecorationEditorPlugin()
    public static let id = "SampleDecorationEditor"
    public static let displayName = String(localized: "Sample Decoration", table: "SampleDecoration")
    public static let description = String(localized: "Demonstrates sample gutter decorations for the editor extension surface.", table: "SampleDecoration")
    public static let iconName = "signpost.right.and.left"
    public static let order = 90
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerDecorationContributor(SampleDecorationContributor())
    }
}
