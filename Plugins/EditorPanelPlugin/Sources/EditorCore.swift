import EditorService
import Foundation
import LumiCoreKit

@MainActor
public final class EditorCore: LumiEditorServicing {
    public let extensionRegistry: EditorExtensionRegistry
    public let editorService: EditorService

    public var currentProjectPathProvider: (() -> String)?

    public init() {
        let registry = EditorExtensionRegistry()
        self.extensionRegistry = registry
        self.editorService = EditorService(editorExtensionRegistry: registry)
    }

    public func reinstallExtensions() {
        Task {
            await EditorExtensionsBootstrap.registerAll(into: extensionRegistry)
        }
    }
}
