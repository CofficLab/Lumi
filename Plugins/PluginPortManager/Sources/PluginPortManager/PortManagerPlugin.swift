import SwiftUI
import LumiUI
import LumiCoreKit
import SuperLogKit
import os

public actor PortManagerPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.port-manager")
    // MARK: - Plugin Properties

    public nonisolated static let emoji = "🔌"
    public nonisolated static let verbose: Bool = true

    public static let id = "PortManager"
    public static let navigationId = "port_manager"
    public static let displayName = String(localized: "Port Manager", table: "PortManager")
    public static let description = String(localized: "View and manage port usage", table: "PortManager")
    public static let iconName = "arrow.up.arrow.down.circle"
    public static var category: PluginCategory { .system }
    public static var order: Int { 20 }
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public nonisolated var instanceLabel: String { Self.id }

    public static let shared = PortManagerPlugin()

    public init() {}

    // MARK: - UI Contributions

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "端口占用管理",
                subtitle: "查看本机端口监听和进程占用，定位开发服务冲突。",
                icon: Self.iconName,
                accent: .orange,
                metrics: [
                    PluginPosterSupport.metric(":3000", "端口"),
                    PluginPosterSupport.metric("PID", "进程"),
                ],
                rows: ["监听端口", "占用进程", "终止操作"],
                chips: ["系统", "端口", "开发"]
            ),
        ]
    }

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(PortManagerView())
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
