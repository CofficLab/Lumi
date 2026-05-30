import LumiCoreKit
import SuperLogKit
import Foundation
import SwiftUI
import os

/// 编辑器引用 Rail 插件：提供 References 标签页
public actor EditorRailReferencesPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-rail-references")

    public nonisolated static let emoji = "🔗"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorRailReferences"
    public static let displayName: String = String(
        localized: "Editor Rail References", table: "EditorRailReferences")
    public static let description: String = String(
        localized: "Editor sidebar references tab",
        table: "EditorRailReferences")
    public static let iconName: String = "arrow.triangle.branch"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 78 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorRailReferencesPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor public func addRailTabs(context: PluginContext) -> [RailTab] {
        []
    }

    @MainActor public func addRailContentView(tabId: String, context: PluginContext) -> AnyView? {
        nil
    }
}
