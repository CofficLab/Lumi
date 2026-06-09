import SwiftUI

// MARK: - Legacy plugin types (Editor extension packages)

public enum PluginCategory: String, Sendable, Codable, CaseIterable {
    case general
    case editor
    case agent
    case development
    case theme
    case llmProvider = "llm_provider"
}

public enum PluginPolicy: String, Sendable, Codable, CaseIterable {
    case alwaysOn
    case optIn
    case optOut
    case disabled
}

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

public struct BottomPanelTab: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let priority: Int

    public init(id: String, title: String, systemImage: String, priority: Int) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.priority = priority
    }
}

public struct RailItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let priority: Int
    public let makeView: @MainActor @Sendable () -> AnyView

    public init(
        id: String,
        title: String,
        systemImage: String,
        priority: Int,
        makeView: @escaping @MainActor @Sendable () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.priority = priority
        self.makeView = makeView
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

/// Legacy tool execution context retained for editor extension packages.
public struct ToolContext: Sendable {
    public var currentProjectPath: String?

    public init(currentProjectPath: String? = nil) {
        self.currentProjectPath = currentProjectPath
    }
}
