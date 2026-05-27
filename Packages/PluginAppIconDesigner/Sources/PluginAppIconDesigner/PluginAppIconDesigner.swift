import Foundation
import LumiCoreKit
import SwiftUI

public actor AppIconDesignerPlugin: SuperPlugin {
    public static let id = "AppIconDesigner"
    public static let displayName = "App Icon Designer"
    public static let description = "Design vector app icons with manual drawing tools, layer controls, and Xcode icon set export."
    public static let iconName = "app.dashed"
    public static let isConfigurable = true
    public static let enable = true
    public static var order: Int { 79 }
    public static var category: PluginCategory { .general }

    public static let shared = AppIconDesignerPlugin()

    private init() {}

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(AppIconDesignerView())
        }
    }
}
