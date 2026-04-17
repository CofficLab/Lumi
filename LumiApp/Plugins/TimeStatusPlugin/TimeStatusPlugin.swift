import MagicKit
import SwiftUI
import Foundation
import Combine
import os

/// Time Status Plugin: Displays the current time in the status bar
actor TimeStatusPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🕐"

    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "TimeStatus"
    static let navigationId: String? = nil
    static let displayName: String = String(localized: "Time Status", table: "TimeStatus")
    static let description: String = String(localized: "Displays the current time in the status bar", table: "TimeStatus")
    static let iconName: String = "clock"
    static let isConfigurable: Bool = false
    static var order: Int { 6 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = TimeStatusPlugin()
}


