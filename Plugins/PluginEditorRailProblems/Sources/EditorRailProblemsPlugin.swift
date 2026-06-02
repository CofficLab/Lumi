import LumiCoreKit
import SuperLogKit
import Foundation
import SwiftUI
import os

/// 编辑器问题面板 Rail 插件：提供 Problems 标签页
public actor EditorRailProblemsPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-rail-problems")

    public nonisolated static let emoji = "⚠️"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorRailProblems"
    public static let displayName: String = String(
        localized: "Editor Rail Problems", table: "EditorRailProblems")
    public static let description: String = String(
        localized: "Editor sidebar problems tab",
        table: "EditorRailProblems")
    public static let iconName: String = "exclamationmark.bubble"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 78 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorRailProblemsPlugin()

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
