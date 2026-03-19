import MagicKit
import SwiftUI

actor AgentModePersistencePlugin: SuperPlugin {
    static let id = "AgentModePersistence"
    static let displayName = "Mode Persistence"
    static let description = "Persist and restore app mode in plugin-owned storage"
    static let iconName = "rectangle.2.swap"
    static var order: Int { 12 }
    static let enable: Bool = true
    static var isConfigurable: Bool { true }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ModePersistenceOverlay(content: content()))
    }

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}
}
