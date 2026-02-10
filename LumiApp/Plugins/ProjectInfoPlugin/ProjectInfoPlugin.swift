import Foundation
import MagicKit
import OSLog
import SwiftUI

/// Project Info Plugin: Displays detailed information of the current project in a list view
actor ProjectInfoPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "📋"

    /// Whether to enable this plugin
    static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = true

    /// Plugin unique identifier
    static let id: String = "ProjectInfoPlugin"

    /// Plugin display name
    static let displayName: String = "Project Info"

    /// Plugin functional description
    static let description: String = "Displays detailed information of the current tab and project in a list view"

    /// Plugin icon name
    static let iconName: String = "info.bubble"

    /// Whether it is configurable
    static let isConfigurable: Bool = true
    
    /// Registration order
    static var order: Int { 3 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
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


