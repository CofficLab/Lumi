import LumiCoreKit
import SuperLogKit
import Foundation
import SwiftUI
import os

/// 编辑器文件树 Rail 插件：提供 Explorer 标签页
public actor EditorRailFileTreePlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-rail-file-tree")

    public nonisolated static let emoji = "📁"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorRailFileTree"
    public static let displayName: String = String(localized: "Editor Rail File Tree", bundle: .module)
    public static let description: String = String(localized: "Editor sidebar explorer tab", bundle: .module)
    public static let iconName: String = "folder"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 78 }
    public static var policy: PluginPolicy { .alwaysOn }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorRailFileTreePlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor public func addRailTabs(context: PluginContext) -> [RailTab] {
        Self.logger.info("\(Self.t)addRailTabs: showsFileTree=\(context.showsFileTree), activeIcon=\(context.activeIcon ?? "<nil>")")
        guard context.showsFileTree else { return [] }
        return [RailTab(
            id: "explorer",
            title: String(localized: "Explorer", bundle: .module),
            systemImage: "folder",
            priority: 0
        )]
    }

    @MainActor public func addRailContentView(tabId: String, context: PluginContext) -> AnyView? {
        Self.logger.info("\(Self.t)addRailContentView: tabId=\(tabId), showsFileTree=\(context.showsFileTree)")
        guard tabId == "explorer", context.showsFileTree else { return nil }
        return AnyView(EditorFileTreeView())
    }
}
