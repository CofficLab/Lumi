import LumiCoreKit
import EditorService
import SuperLogKit
import Foundation
import SwiftUI
import os

@MainActor
public enum BreadcrumbNavBridge {
    public static var editorServiceProvider: ((PluginContext) -> EditorService?)?
}

/// 面包屑导航插件：在编辑器面板头部显示当前文件路径的面包屑导航
///
/// 类似 VS Code 的面包屑导航，提供可点击的文件路径段，支持快速导航到同级文件/文件夹。
public actor BreadcrumbNavPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .optOut
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.breadcrumb-nav")

    public nonisolated static let emoji = "🧭"
    public nonisolated static let verbose: Bool = false
    public static let id: String = "BreadcrumbNav"
    public static let displayName: String = String(localized: "Breadcrumb Navigation", bundle: .module)
    public static let description: String = String(localized: "File path breadcrumb navigation below editor tabs", bundle: .module)
    public static let iconName: String = "point.topleft.down.curvedto.point.bottomright.up"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 70 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = BreadcrumbNavPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        BreadcrumbNavBridge.editorServiceProvider = { pluginContext in
            context.editorServiceProvider(pluginContext) as? EditorService
        }
    }

    // MARK: - UI Contributions

    /// 在编辑器面板头部显示面包屑导航（Tab 栏下方）
    @MainActor
    public func addPanelHeaderView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        guard let service = BreadcrumbNavBridge.editorServiceProvider?(context) else { return nil }
        return AnyView(BreadcrumbNavHeaderView(service: service))
    }
}
