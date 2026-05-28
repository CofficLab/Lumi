import Foundation

/// 编辑器 decoration 样例插件：演示 git-like 与 custom gutter decoration 的接入方式。
actor SampleDecorationEditorPlugin: SuperPlugin {
    static let shared = SampleDecorationEditorPlugin()
    static let id = "SampleDecorationEditor"
    static let displayName = String(localized: "Sample Decoration", table: "SampleDecoration")
    static let description = String(localized: "Demonstrates sample gutter decorations for the editor extension surface.", table: "SampleDecoration")
    static let iconName = "signpost.right.and.left"
    static let order = 90
    static var category: PluginCategory { .editor }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerDecorationContributor(SampleDecorationContributor())
    }
}
