import SwiftUI
import os

actor PortManagerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.port-manager")
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔌"
    nonisolated static let verbose: Bool = true

    static let id = "PortManager"
    static let navigationId = "port_manager"
    static let displayName = String(localized: "Port Manager", table: "PortManager")
    static let description = String(localized: "View and manage port usage", table: "PortManager")
    static let iconName = "arrow.up.arrow.down.circle"
    static var category: PluginCategory { .system }
    static var order: Int { 20 }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }

    static let shared = PortManagerPlugin()

    init() {}

    // MARK: - UI Contributions

    @MainActor
    func addPosterViews() -> [AnyView] {
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
    func addViewContainer() -> ViewContainerItem? {
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
