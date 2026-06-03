import EditorService
import LumiCoreKit
import SuperLogKit
import Foundation
import SwiftUI
import os

@MainActor
public enum EditorRailWorkspaceSymbolsBridge {
    public static var editorServiceProvider: ((PluginContext) -> EditorService?)?
}

/// 编辑器工作区符号 Rail 插件：提供 Symbols 标签页
public actor EditorRailWorkspaceSymbolsPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-rail-workspace-symbols")

    public nonisolated static let emoji = "🔣"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorRailWorkspaceSymbols"
    public static let displayName: String = String(localized: "Editor Rail Workspace Symbols", bundle: .module)
    public static let description: String = String(localized: "Editor sidebar workspace symbols tab", bundle: .module)
    public static let iconName: String = "text.magnifyingglass"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 78 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorRailWorkspaceSymbolsPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor public func addRailTabs(context: PluginContext) -> [RailTab] {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return [] }
        return [RailTab(id: "workspaceSymbols", title: String(localized: "Symbols", bundle: .module), systemImage: "text.magnifyingglass", priority: 13)]
    }

    @MainActor public func addRailContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard tabId == "workspaceSymbols", context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        guard let service = EditorRailWorkspaceSymbolsBridge.editorServiceProvider?(context) else { return nil }
        return AnyView(EditorWorkspaceSymbolsRailContentView(service: service))
    }
}

/// Symbols 标签页内容视图
public struct EditorWorkspaceSymbolsRailContentView: View {
    @ObservedObject private var service: EditorService

    public init(service: EditorService) {
        self._service = ObservedObject(wrappedValue: service)
    }

    public var body: some View {
        EditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
    }
}
