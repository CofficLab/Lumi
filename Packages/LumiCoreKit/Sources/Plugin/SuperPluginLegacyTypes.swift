import SwiftUI

// MARK: - Legacy plugin types (Editor extension packages)

public struct PluginContext: Sendable {
    public var activeIcon: String
    public var showsRail: Bool
    public var showsBottomPanel: Bool

    public init(
        activeIcon: String = "chevron.left.forwardslash.chevron.right",
        showsRail: Bool = true,
        showsBottomPanel: Bool = true
    ) {
        self.activeIcon = activeIcon
        self.showsRail = showsRail
        self.showsBottomPanel = showsBottomPanel
    }
}

@MainActor
public final class PluginRuntimeContext {
    public var editorServiceProvider: @MainActor (PluginContext) -> AnyObject?
    public var currentProjectPath: @MainActor (PluginContext) -> String?
    public var editorThemeId: @MainActor () -> String = { "xcode-dark" }
    public var addToChat: @MainActor (String, PluginContext) -> Void = { _, _ in }
    public var openFile: @MainActor (URL, String?, PluginContext) async -> Void = { _, _, _ in }

    public init(
        editorServiceProvider: @escaping @MainActor (PluginContext) -> AnyObject? = { _ in nil },
        currentProjectPath: @escaping @MainActor (PluginContext) -> String? = { _ in nil }
    ) {
        self.editorServiceProvider = editorServiceProvider
        self.currentProjectPath = currentProjectPath
    }
}

/// Host hook for language editor plugins that need `PluginRuntimeContext` after the editor shell wires bridges.
@MainActor
public enum EditorLanguageRuntimeBridge {
    public static var configure: (@MainActor (PluginRuntimeContext) async -> Void)?
}