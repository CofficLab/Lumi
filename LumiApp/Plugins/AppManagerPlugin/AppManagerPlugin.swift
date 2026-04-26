import Foundation
import MagicKit
import SwiftUI
import os

/// 应用管理插件
actor AppManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")

    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "📱"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    
    static let id = "AppManager"
    static let navigationId = "app_manager"
    static let displayName = String(localized: "App Manager", table: "AppManager")
    static let description = String(localized: "Manage installed applications", table: "AppManager")
    static let iconName = "apps.ipad"
    static var order: Int { 40 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppManagerPlugin()

    // MARK: - UI

    /// 该面板不需要右侧栏
    nonisolated var panelNeedsSidebar: Bool { false }

    @MainActor
    func addPanelView() -> AnyView? {
        AnyView(AppManagerView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
