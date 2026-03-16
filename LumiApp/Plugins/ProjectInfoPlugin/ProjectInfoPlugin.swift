import MagicKit
import SwiftUI
import Foundation
import OSLog

/// Project Info Plugin: Displays detailed information of the current project in a list view
actor ProjectInfoPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "📋"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id: String = "ProjectInfo"
    static let navigationId: String? = nil
    static let displayName: String = String(localized: "Project Info", table: "ProjectInfo")
    static let description: String = String(localized: "Displays detailed information of the current tab and project in a list view", table: "ProjectInfo")
    static let iconName: String = "info.bubble"
    static let isConfigurable: Bool = false
    static var order: Int { 3 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ProjectInfoPlugin()

    /// Initialization method
    init() {}

    // MARK: - UI Contributions

    /// Add list view
    /// - Parameters:
    ///   - tab: Tab name
    ///   - project: Project object
    /// - Returns: List view
    @MainActor func addListView(tab: String, project: Project?) -> AnyView? {
        return AnyView(ProjectInfoListView(tab: tab, project: project))
    }
}


