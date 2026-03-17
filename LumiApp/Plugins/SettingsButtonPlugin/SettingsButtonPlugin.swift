import MagicKit
import SwiftUI
import Foundation
import OSLog

/// Settings Button Plugin: Displays a settings button on the right side of the status bar
actor SettingsButtonPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "⚙️"

    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id: String = "SettingsButton"
    static let navigationId: String? = nil
    static let displayName: String = String(localized: "Settings Button", table: "SettingsButton")
    static let description: String = String(localized: "Displays a settings button on the right side of the status bar, click to open the settings interface", table: "SettingsButton")
    static let iconName: String = "gearshape"
    static let isConfigurable: Bool = false
    static var order: Int { 100 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = SettingsButtonPlugin()
}


