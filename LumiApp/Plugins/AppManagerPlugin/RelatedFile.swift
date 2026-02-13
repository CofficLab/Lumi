import Foundation
import SwiftUI

struct RelatedFile: Identifiable, Hashable, Sendable {
    let id = UUID()
    let path: String
    let size: Int64
    let type: RelatedFileType

    var name: String {
        (path as NSString).lastPathComponent
    }

    enum RelatedFileType: String, Codable {
        case app
        case support
        case cache
        case preferences
        case state
        case container
        case log
        case other

        var displayName: String {
            switch self {
            case .app: return "Application"
            case .support: return "Application Support"
            case .cache: return "Caches"
            case .preferences: return "Preferences"
            case .state: return "Saved State"
            case .container: return "Containers"
            case .log: return "Logs"
            case .other: return "Other"
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
