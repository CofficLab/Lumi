import Foundation

enum ConnectCacheInvalidator {
    static func invalidateAfterMutation(
        method: String,
        path: String,
        body: Data?,
        accountKey: String,
        cache: ConnectAPICache
    ) {
        switch (method, path) {
        case ("PATCH", let patchPath) where patchPath.hasPrefix("/v1/appStoreVersionLocalizations/"):
            if let localizationID = extractTrailingID(from: patchPath) {
                cache.invalidate(tags: [.localization(localizationID)])
                cache.invalidate(accountKey: accountKey) { entry in
                    entry.path.contains("/appStoreVersionLocalizations/\(localizationID)")
                        || entry.path.contains("/appScreenshotSets")
                        && entry.path.contains(localizationID)
                }
            }

        case ("POST", "/v1/appScreenshotSets"):
            if let localizationID = extractLocalizationID(fromScreenshotSetBody: body) {
                cache.invalidate(tags: [.localization(localizationID)])
                cache.invalidate(accountKey: accountKey) { entry in
                    entry.path.contains("/appScreenshotSets")
                        || entry.path.contains("/appScreenshots")
                        || entry.path.contains("/appStoreVersionLocalizations/\(localizationID)")
                }
            } else {
                cache.invalidate(accountKey: accountKey) { $0.path.contains("/appScreenshotSets") }
            }

        case ("POST", "/v1/appStoreVersionReleaseRequests"):
            if let versionID = extractVersionID(fromReleaseBody: body) {
                cache.invalidate(tags: [.version(versionID)])
                cache.invalidate(accountKey: accountKey) { entry in
                    entry.tags.contains(.version(versionID))
                        || entry.path.contains("/appStoreVersions/\(versionID)")
                        || entry.path.contains("/appStoreVersions")
                }
            }

        case ("POST", "/v1/appStoreVersions"):
            if let appID = extractAppID(fromVersionCreateBody: body) {
                cache.invalidate(tags: [.app(appID)])
                cache.invalidate(accountKey: accountKey) { entry in
                    entry.path.contains("/appStoreVersions")
                        || entry.path.contains("/v1/apps/\(appID)/")
                }
            } else {
                cache.invalidate(accountKey: accountKey) { $0.path.contains("/appStoreVersions") }
            }

        case ("POST", "/v1/appStoreVersionLocalizations"):
            if let versionID = extractVersionID(fromLocalizationCreateBody: body) {
                cache.invalidate(tags: [.version(versionID)])
                cache.invalidate(accountKey: accountKey) { entry in
                    entry.tags.contains(.version(versionID))
                        || entry.path.contains("/appStoreVersions/\(versionID)/appStoreVersionLocalizations")
                        || entry.path.contains("/appStoreVersionLocalizations")
                }
            }

        case ("PATCH", let patchPath) where patchPath.hasPrefix("/v1/ciWorkflows/"):
            cache.invalidate(accountKey: accountKey) { entry in
                entry.path.contains("/ciWorkflows") || entry.path.contains("/ciBuildRuns")
            }

        case ("POST", let postPath) where postPath.contains("/ciBuildRuns"):
            cache.invalidate(accountKey: accountKey) { entry in
                entry.path.contains("/ciBuildRuns")
            }

        default:
            break
        }
    }

    private static func extractTrailingID(from path: String) -> String? {
        path.split(separator: "/").last.map(String.init)
    }

    private static func extractLocalizationID(fromScreenshotSetBody body: Data?) -> String? {
        guard let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let relationships = data["relationships"] as? [String: Any],
              let localization = relationships["appStoreVersionLocalization"] as? [String: Any],
              let localizationData = localization["data"] as? [String: Any],
              let id = localizationData["id"] as? String else {
            return nil
        }
        return id
    }

    private static func extractVersionID(fromReleaseBody body: Data?) -> String? {
        guard let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let relationships = data["relationships"] as? [String: Any],
              let version = relationships["appStoreVersion"] as? [String: Any],
              let versionData = version["data"] as? [String: Any],
              let id = versionData["id"] as? String else {
            return nil
        }
        return id
    }

    private static func extractAppID(fromVersionCreateBody body: Data?) -> String? {
        guard let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let relationships = data["relationships"] as? [String: Any],
              let app = relationships["app"] as? [String: Any],
              let appData = app["data"] as? [String: Any],
              let id = appData["id"] as? String else {
            return nil
        }
        return id
    }

    private static func extractVersionID(fromLocalizationCreateBody body: Data?) -> String? {
        guard let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let relationships = data["relationships"] as? [String: Any],
              let version = relationships["appStoreVersion"] as? [String: Any],
              let versionData = version["data"] as? [String: Any],
              let id = versionData["id"] as? String else {
            return nil
        }
        return id
    }
}
