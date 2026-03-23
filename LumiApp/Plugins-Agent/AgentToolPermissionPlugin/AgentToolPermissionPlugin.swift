import SwiftUI

/// 工具执行授权浮层：在根视图上叠加 `PermissionRequestView`，与聊天区域解耦。
actor AgentToolPermissionPlugin: SuperPlugin {
    nonisolated static let emoji = "🔐"
    nonisolated static let verbose = false

    static let id = "AgentToolPermission"
    static let displayName = String(localized: "Tool Permission", table: "AgentToolPermission")
    static let description = String(localized: "Tool permission overlay at root", table: "AgentToolPermission")
    static let iconName = "lock.shield"
    static var order: Int { 95 }
    static let enable: Bool = true

    static let shared = AgentToolPermissionPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ToolPermissionRootOverlay(content: content()))
    }
}