import Foundation

/// Metadata and registration hook for editor kernel extension plugins (LSP, language support, etc.).
@MainActor
public protocol LumiEditorExtensionRegistering {
    static var extensionPluginInfo: LumiPluginInfo { get }
    static var extensionPluginPolicy: LumiPluginPolicy { get }

    @MainActor
    static func registerEditorExtensionsErased(into registry: AnyObject) async
}

public extension LumiEditorExtensionRegistering {
    static var extensionPluginPolicy: LumiPluginPolicy { .optIn }
}
