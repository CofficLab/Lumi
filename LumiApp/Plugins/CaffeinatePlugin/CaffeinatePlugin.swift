import MagicKit
import SwiftUI
import AppKit
import Combine
import Foundation
import OSLog

/// 防休眠插件：阻止系统休眠，支持定时和手动控制
/// 防休眠插件：阻止系统休眠，支持定时和手动控制
actor CaffeinatePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "☕️"

    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id: String = "Caffeinate"
    static let navigationId: String = "caffeinate_settings"
    static let displayName: String = String(localized: "Anti-Sleep", table: "Caffeinate")
    static let description: String = String(localized: "Prevent system sleep with timer and manual control", table: "Caffeinate")
    static let iconName: String = "bolt"
    static let isConfigurable: Bool = false
    static var order: Int { 7 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = CaffeinatePlugin()

    // MARK: - UI Contributions

    /// 添加状态栏弹窗视图
    /// - Returns: 要添加到状态栏弹窗的视图，如果不需要则返回nil
    @MainActor func addStatusBarPopupView() -> AnyView? {
        AnyView(CaffeinateStatusBarPopupView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(CaffeinatePlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
