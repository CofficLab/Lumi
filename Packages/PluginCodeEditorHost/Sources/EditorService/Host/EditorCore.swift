import Foundation

@MainActor
public final class EditorCore: LumiEditorServicing {
    public let extensionRegistry: EditorExtensionRegistry
    public let editorService: EditorService

    public var currentProjectPathProvider: (() -> String)?

    public var extensionInstaller: (@MainActor (EditorExtensionRegistry) async -> Void)?

    public init() {
        let registry = EditorExtensionRegistry()
        self.extensionRegistry = registry
        self.editorService = EditorService(editorExtensionRegistry: registry)
    }

    public func reinstallExtensions() {
        guard let extensionInstaller else { return }
        Task {
            await extensionInstaller(extensionRegistry)
            editorService.state.refreshExtensionProviders()
        }
    }
}
