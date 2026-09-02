import Foundation

enum ConnectCachePolicyResolver {
    static func resolve(
        method: String,
        path: String,
        versionStateIndex: VersionStateIndex
    ) -> ConnectCachePolicy {
        guard method == "GET" else {
            return ConnectCachePolicy(retention: .volatile, tags: [])
        }

        if isXcodeCloudPath(path) {
            return ConnectCachePolicy(retention: .volatile, tags: xcodeCloudTags(path: path))
        }

        if path == "/v1/apps" {
            return ConnectCachePolicy(retention: .standard, tags: [])
        }

        if let appID = extractAppID(fromVersionsListPath: path) {
            return ConnectCachePolicy(retention: .standard, tags: [.app(appID)])
        }

        if let versionID = extractVersionID(from: path) {
            let retention = versionStateIndex.retention(forVersionID: versionID)
            var tags: [ConnectCacheTag] = [.version(versionID)]
            if let appID = extractAppID(fromVersionDetailPath: path) {
                tags.append(.app(appID))
            }
            return ConnectCachePolicy(retention: retention, tags: tags)
        }

        if let localizationID = extractLocalizationID(from: path) {
            return ConnectCachePolicy(
                retention: .standard,
                tags: [.localization(localizationID)]
            )
        }

        if let screenshotSetID = extractScreenshotSetID(from: path) {
            return ConnectCachePolicy(
                retention: .standard,
                tags: [.screenshotSet(screenshotSetID)]
            )
        }

        return ConnectCachePolicy(retention: .standard, tags: [])
    }

    private static func isXcodeCloudPath(_ path: String) -> Bool {
        path.contains("/ciProducts")
            || path.contains("/ciWorkflows")
            || path.contains("/ciBuildRuns")
    }

    private static func xcodeCloudTags(path: String) -> [ConnectCacheTag] {
        if let productID = extractID(after: "/ciProducts/", in: path) {
            return [.app(productID)]
        }
        return []
    }

    private static func extractAppID(fromVersionsListPath path: String) -> String? {
        let prefix = "/v1/apps/"
        let suffix = "/appStoreVersions"
        guard path.hasPrefix(prefix), path.hasSuffix(suffix) else { return nil }
        let appID = String(path.dropFirst(prefix.count).dropLast(suffix.count))
        return appID.isEmpty ? nil : appID
    }

    private static func extractAppID(fromVersionDetailPath path: String) -> String? {
        nil
    }

    private static func extractVersionID(from path: String) -> String? {
        if let id = extractID(after: "/v1/appStoreVersions/", in: path) {
            return id.split(separator: "/").first.map(String.init)
        }
        return nil
    }

    private static func extractLocalizationID(from path: String) -> String? {
        if let id = extractID(after: "/v1/appStoreVersionLocalizations/", in: path) {
            return id.split(separator: "/").first.map(String.init)
        }
        if path == "/v1/appStoreVersionLocalizations" {
            return nil
        }
        return nil
    }

    private static func extractScreenshotSetID(from path: String) -> String? {
        if let id = extractID(after: "/v1/appScreenshotSets/", in: path) {
            return id.split(separator: "/").first.map(String.init)
        }
        return nil
    }

    private static func extractID(after prefix: String, in path: String) -> String? {
        guard path.hasPrefix(prefix) else { return nil }
        let remainder = String(path.dropFirst(prefix.count))
        guard !remainder.isEmpty else { return nil }
        return String(remainder.split(separator: "/").first ?? Substring(remainder))
    }
}
