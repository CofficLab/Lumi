import Foundation

/// 编辑器 decoration 样例插件：演示 git-like 与 custom gutter decoration 的接入方式。
actor SampleDecorationEditorPlugin: SuperPlugin {
    static let id = "SampleDecorationEditor"
    static let displayName = "Sample Decoration"
    static let description = "Demonstrates sample gutter decorations for the editor extension surface."
    static let iconName = "signpost.right.and.left"
    static let order = 90
    static let enable = true
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerDecorationContributor(SampleDecorationContributor())
    }
}
