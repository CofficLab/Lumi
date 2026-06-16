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
        let filtered: [AppStoreVersion]
        if let appPlatform {
            let platform = appPlatform.normalizedASCPlatform
            let platformMatched = versions.filter { $0.normalizedPlatform == platform }
            // Fallback: if no versions match the app's platform (e.g. iOS app with Mac Catalyst versions),
            // show all versions instead of an empty list.
            filtered = platformMatched.isEmpty ? versions : platformMatched
        } else {
            filtered = versions
        }

        let grouped = Dictionary(grouping: filtered, by: \.versionString)
        let representatives = grouped.values.compactMap { group in
            group.max { lhs, rhs in
                if lhs.sidebarSortPriority != rhs.sidebarSortPriority {
                    return lhs.sidebarSortPriority < rhs.sidebarSortPriority
                }
                return (lhs.createdDate ?? .distantPast) < (rhs.createdDate ?? .distantPast)
            }
        }

        return representatives.sorted {
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
        }
    }
}
