// MARK: - Editor Extension Points Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供编辑器扩展能力
    nonisolated var providesEditorExtensions: Bool { false }

    /// 默认实现：不向编辑器扩展注册中心注入任何能力
    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {}
}
