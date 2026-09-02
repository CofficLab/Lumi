import Foundation

extension String {
    var normalizedASCPlatform: String {
        switch uppercased() {
        case "MAC_OS", "MACOS": return "MAC_OS"
        case "IOS": return "IOS"
        case "TV_OS", "TVOS": return "TV_OS"
        case "VISION_OS", "VISIONOS": return "VISION_OS"
        default: return uppercased()
        }
    }
}

extension AppStoreVersion {
    var normalizedPlatform: String {
        platform.normalizedASCPlatform
    }

    var sidebarSortPriority: Int {
        let state = appStoreState.uppercased()
        if state.contains("PREPARE") { return 100 }
        if state.contains("DEVELOPER_REJECTED") || state.contains("REJECTED") { return 90 }
        if state.contains("WAITING") || state.contains("REVIEW") { return 80 }
        if state.contains("PENDING") { return 70 }
        if state.contains("READY") { return 10 }
        return 50
    }

    static func sidebarVersions(from versions: [AppStoreVersion], appPlatform: String?) -> [AppStoreVersion] {
        // Do not filter by platform or deduplicate by versionString.
        // Apps often have versions across multiple platforms (iOS, macOS, visionOS),
        // and the same version number can exist on different platforms with
        // different states. Users need to see and manage all of them.
        let sorted = versions.sorted {
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
        }

        return sorted
    }
}
