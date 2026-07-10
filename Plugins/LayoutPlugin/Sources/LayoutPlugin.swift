import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// 布局持久化插件
///
/// 负责监听内核 `LumiLayoutState` 发出的事件通知，
/// 将布局变化持久化到磁盘，并在 App 启动时从磁盘恢复。
///
/// 内核只提供状态和发出事件，不感知插件存在。
/// 插件通过 `NotificationCenter` 监听事件并执行持久化。
public enum LayoutPlugin: LumiPlugin, SuperLog {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "sidebar.left"
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    public nonisolated static let emoji = "📐"
    public nonisolated static let verbose = false

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.layout",
        displayName: LumiPluginLocalization.string("Layout Persistence", bundle: .module),
        description: LumiPluginLocalization.string("Persist and restore layout state across app launches", bundle: .module),
        order: 99
    )

    // MARK: - LumiPlugin Lifecycle

    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle) {
        switch event {
        case .didRegister:
            break
        case .appDidLaunch:
            if Self.verbose {
                Self.logger.info("\(Self.t)appDidLaunch，开始恢复布局")
            }
            LayoutPersistenceCoordinator.shared.restore()
        case .projectDidOpen:
            break
        case .projectDidClose:
            break
        }
    }

    // MARK: - LumiPlugin Implementation

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: info.id, order: info.order) { content in
                LayoutRootView(content: content)
            }
        ]
    }

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(info.id).layout-menu",
                title: LumiPluginLocalization.string("Layout", bundle: .module),
                placement: .trailing
            ) {
                LayoutMenuButton()
            }
        ]
    }
}
