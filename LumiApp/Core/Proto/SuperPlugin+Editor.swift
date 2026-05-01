// MARK: - Editor Extension Points Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供编辑器扩展能力
    nonisolated var providesEditorExtensions: Bool { false }

    /// 默认实现：不向编辑器扩展注册中心注入任何能力
    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {}

    /// 默认实现：不提供项目上下文能力
    @MainActor func editorProjectContextCapability() -> (any SuperEditorProjectContextCapability)? { nil }

    /// 默认实现：不提供语义可用性能力
    @MainActor func editorSemanticCapability() -> (any SuperEditorSemanticCapability)? { nil }

    /// 默认实现：不提供语言服务项目集成能力
    @MainActor func editorLanguageIntegrationCapabilities() -> [any SuperEditorLanguageIntegrationCapability] { [] }
}
