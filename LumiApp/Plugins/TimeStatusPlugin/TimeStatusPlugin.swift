import Foundation
import MagicKit
import SwiftUI
import Combine
import MagicKit
import OSLog

/// Time Status Plugin: Displays the current time in the status bar
actor TimeStatusPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "🕐"

    /// Whether to enable this plugin
    static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = true

    /// Plugin unique identifier
    static let id: String = "TimeStatusPlugin"

    /// Plugin display name
    static let displayName: String = "Time Status"

    /// Plugin functional description
    static let description: String = "Displays the current time in the status bar"

    /// Plugin icon name
    static let iconName: String = "clock"

    /// Whether it is configurable
    static let isConfigurable: Bool = true
    
    /// Registration order
    static var order: Int { 6 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = TimeStatusPlugin()

    /// Initialization method
    init() {}

    // MARK: - UI Contributions
}


