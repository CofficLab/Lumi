import EditorService
import LumiCoreKit

extension EditorXcodePlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        LumiPluginInfo(
            id: id,
            displayName: displayName,
            description: description,
            order: order
        )
    }

    public static var extensionPluginPolicy: LumiPluginPolicy {
        policy.lumiPluginPolicy
    }

    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        await shared.registerEditorExtensions(into: registry)
    }
}

extension LSPServiceEditorPlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        LumiPluginInfo(
            id: id,
            displayName: displayName,
            description: description,
            order: order
        )
    }

    public static var extensionPluginPolicy: LumiPluginPolicy {
        policy.lumiPluginPolicy
    }

    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        await shared.registerEditorExtensions(into: registry)
    }
}

extension JSEditorPlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        LumiPluginInfo(
            id: id,
            displayName: displayName,
            description: description,
            order: order
        )
    }

    public static var extensionPluginPolicy: LumiPluginPolicy {
        policy.lumiPluginPolicy
    }

    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        await shared.registerEditorExtensions(into: registry)
    }
}

extension GoEditorPlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        LumiPluginInfo(
            id: id,
            displayName: displayName,
            description: description,
            order: order
        )
    }

    public static var extensionPluginPolicy: LumiPluginPolicy {
        policy.lumiPluginPolicy
    }

    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        await shared.registerEditorExtensions(into: registry)
    }
}

extension LSPDocumentHighlightEditorPlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        LumiPluginInfo(
            id: id,
            displayName: displayName,
            description: description,
            order: order
        )
    }

    public static var extensionPluginPolicy: LumiPluginPolicy {
        policy.lumiPluginPolicy
    }

    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        await shared.registerEditorExtensions(into: registry)
    }
}

extension LSPSignatureHelpEditorPlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        LumiPluginInfo(
            id: id,
            displayName: displayName,
            description: description,
            order: order
        )
    }

    public static var extensionPluginPolicy: LumiPluginPolicy {
        policy.lumiPluginPolicy
    }

    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        await shared.registerEditorExtensions(into: registry)
    }
}

extension LSPRealtimeSignalsEditorPlugin: LumiEditorExtensionRegistering {
    public static var extensionPluginInfo: LumiPluginInfo {
        LumiPluginInfo(
            id: id,
            displayName: displayName,
            description: description,
            order: order
        )
    }

    public static var extensionPluginPolicy: LumiPluginPolicy {
        policy.lumiPluginPolicy
    }

    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        await shared.registerEditorExtensions(into: registry)
    }
}
