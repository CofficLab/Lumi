import MagicKit
import SwiftUI
import Foundation

actor RegistryManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔁"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id = "RegistryManager"
    static let navigationId: String = "registry_manager"
    static let displayName = String(localized: "Registry Manager", table: "RegistryManager")
    static let description = String(localized: "Manage Lumi registries", table: "RegistryManager")
    static let iconName = "arrow.triangle.2.circlepath"
    static let isConfigurable: Bool = false
    static var order: Int { 80 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RegistryManagerPlugin()

    // MARK: - UI

    /// 该面板不需要右侧栏

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(RegistryManagerView())
    }

    nonisolated func addPanelIcon() -> String? { Self.iconName }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
