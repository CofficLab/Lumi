import LumiCoreKit
import SuperLogKit
import Foundation
import SwiftUI
import os

/// 编辑器调用层级 Rail 插件：提供 Call Hierarchy 标签页
public actor EditorCallHierarchyRailPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-call-hierarchy-rail")

    public nonisolated static let emoji = "📞"
    public nonisolated static let verbose: Bool = false
    public static let id: String = "EditorCallHierarchyRail"
    public static let displayName: String = String(localized: "Editor Call Hierarchy Rail", bundle: .module)
    public static let description: String = String(localized: "Editor sidebar call hierarchy tab", bundle: .module)
    public static let iconName: String = "point.3.connected.trianglepath.dotted"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 78 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorCallHierarchyRailPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor public func addRailItems(context: PluginContext) -> [RailItem] {
        []
    }
}
