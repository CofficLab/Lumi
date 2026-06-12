/// Metadata and registration hook for editor kernel extension plugins (LSP, language support, etc.).
public protocol LumiEditorExtensionRegistering {
    static var extensionPluginInfo: LumiPluginInfo { get }
    static var extensionPluginPolicy: LumiPluginPolicy { get }

    @MainActor
    static func registerEditorExtensionsErased(into registry: AnyObject) async
}

public extension PluginPolicy {
    var lumiPluginPolicy: LumiPluginPolicy {
        switch self {
        case .alwaysOn: .alwaysOn
        case .optIn: .optIn
        case .optOut: .optOut
        case .disabled: .disabled
        }
    }
}
