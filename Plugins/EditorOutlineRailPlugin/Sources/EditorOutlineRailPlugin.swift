import LumiCoreKit
import SuperLogKit
import Foundation
import SwiftUI
import os

/// 编辑器大纲 Rail 插件：提供 Outline 标签页
public actor EditorOutlineRailPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-outline-rail")

    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = false
    public static let id: String = "EditorOutlineRail"
    public static let displayName: String = String(localized: "Editor Outline Rail", bundle: .module)
    public static let description: String = String(localized: "Editor sidebar outline tab", bundle: .module)
    public static let iconName: String = "list.bullet.indent"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 78 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorOutlineRailPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor public func addRailItems(context: PluginContext) -> [RailItem] {
        []
    }
}
