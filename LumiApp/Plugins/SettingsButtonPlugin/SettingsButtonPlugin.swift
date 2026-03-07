import Foundation
import MagicKit
import OSLog
import SwiftUI

/// Settings Button Plugin: Displays a settings button on the right side of the status bar
actor SettingsButtonPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "⚙️"

    /// Whether to enable this plugin
    static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = true

    /// Plugin unique identifier
    static let id: String = "SettingsButtonPlugin"

    /// Plugin display name
    static let displayName: String = "Settings Button"

    /// Plugin functional description
    static let description: String = "Displays a settings button on the right side of the status bar, click to open the settings interface"

    /// Plugin icon name
    static let iconName: String = "gearshape"

    /// Whether it is configurable
    static let isConfigurable: Bool = false
    
    /// Registration order
    static var order: Int { 100 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = SettingsButtonPlugin()

    /// Initialization method
    init() {}

    // MARK: - UI Contributions
}


