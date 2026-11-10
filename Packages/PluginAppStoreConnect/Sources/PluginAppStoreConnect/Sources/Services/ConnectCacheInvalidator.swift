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
                    (entry.path.contains("/appStoreVersionLocalizations/\(localizationID)")
                        || entry.path.contains("/appScreenshotSets"))
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

        case ("DELETE", let deletePath) where deletePath.hasPrefix("/v1/appStoreVersions/"):
            if let versionID = extractTrailingID(from: deletePath) {
                cache.invalidate(tags: [.version(versionID)])
                cache.invalidate(accountKey: accountKey) { entry in
                    entry.tags.contains(.version(versionID))
                        || entry.path.contains("/appStoreVersions")
                }
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

        // 年龄分级声明挂在 appInfo 上，读路径是 /v1/appInfos/{id}/ageRatingDeclaration。
        // PATCH 成功后必须失效该读缓存，否则紧接着的读取仍返回旧声明。
        case ("PATCH", let patchPath) where patchPath.hasPrefix("/v1/ageRatingDeclarations/"):
            cache.invalidate(accountKey: accountKey) { entry in
                entry.path.contains("/ageRatingDeclaration")
            }

        // 关联 / 更换 build：PATCH /v1/appStoreVersions/{id}/relationships/build。
        // 读取同一关系的 GET 走 .version(id) 标签，但它的路径既不是版本详情、
        // 也不以 /appStoreVersions 结尾，所以必须显式失效；否则 build 已关联后
        // 提交前置检查仍会读到关联前的 {"data": null}。
        case ("PATCH", let patchPath) where patchPath.hasPrefix("/v1/appStoreVersions/")
            && patchPath.hasSuffix("/relationships/build"):
            guard let versionID = extractID(after: "/v1/appStoreVersions/", in: patchPath) else { break }
            cache.invalidate(tags: [.version(versionID)])
            cache.invalidate(accountKey: accountKey) { entry in
                entry.path == "/v1/appStoreVersions/\(versionID)/relationships/build"
            }

        // 版本属性（copyright / releaseType / downloadable / earliestReleaseDate）更新。
        // 版本详情与所属 app 的版本列表都读同一批数据，两者都要失效。
        case ("PATCH", let patchPath) where patchPath.hasPrefix("/v1/appStoreVersions/"):
            guard let versionID = extractID(after: "/v1/appStoreVersions/", in: patchPath) else { break }
            cache.invalidate(tags: [.version(versionID)])
            cache.invalidate(accountKey: accountKey) { entry in
                entry.path == "/v1/appStoreVersions/\(versionID)"
                    || entry.path.hasSuffix("/appStoreVersions")
            }

        // 截图变更（预约上传 / 上传完成 / 删除）。
        // 受影响的读取有三处：截图集实例、截图集关系列表、/v1/appScreenshots 过滤列表。
        case ("POST", "/v1/appScreenshots"):
            if let setID = extractRelationshipID(from: body, relationship: "appScreenshotSet") {
                cache.invalidate(tags: [.screenshotSet(setID)])
            }
            invalidateScreenshotCaches(cache: cache, accountKey: accountKey)

        case ("PATCH", let patchPath) where patchPath.hasPrefix("/v1/appScreenshots/"):
            invalidateScreenshotCaches(cache: cache, accountKey: accountKey)

        case ("DELETE", let deletePath) where deletePath.hasPrefix("/v1/appScreenshots/"):
            invalidateScreenshotCaches(cache: cache, accountKey: accountKey)

        // 审核提交（创建 / 加入版本 / 触发提交 / 撤回）。
        // 受影响的读取：app 的 reviewSubmissions 列表、submission 的 items 列表。
        case ("POST", "/v1/reviewSubmissions"), ("POST", "/v1/reviewSubmissionItems"):
            invalidateSubmissionCaches(cache: cache, accountKey: accountKey)

        case ("PATCH", let patchPath) where patchPath.hasPrefix("/v1/reviewSubmissions/"):
            invalidateSubmissionCaches(cache: cache, accountKey: accountKey)

        default:
            break
        }
    }

    private static func invalidateScreenshotCaches(cache: ConnectAPICache, accountKey: String) {
        cache.invalidate(accountKey: accountKey) { entry in
            entry.path.contains("/appScreenshots") || entry.path.contains("/appScreenshotSets")
        }
    }

    private static func invalidateSubmissionCaches(cache: ConnectAPICache, accountKey: String) {
        cache.invalidate(accountKey: accountKey) { entry in
            entry.path.contains("/reviewSubmissions")
                || entry.path.contains("/reviewSubmissionItems")
        }
    }

    private static func extractTrailingID(from path: String) -> String? {
        path.split(separator: "/").last.map(String.init)
    }

    /// 取路径中某前缀之后的第一段 id（不含后续的子路径）。
    private static func extractID(after prefix: String, in path: String) -> String? {
        guard path.hasPrefix(prefix) else { return nil }
        let remainder = String(path.dropFirst(prefix.count))
        guard !remainder.isEmpty else { return nil }
        return String(remainder.split(separator: "/").first ?? Substring(remainder))
    }

    /// 从请求体的 `data.relationships.<relationship>.data.id` 取出关联资源 id。
    private static func extractRelationshipID(from body: Data?, relationship: String) -> String? {
        guard let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let relationships = data["relationships"] as? [String: Any],
              let relation = relationships[relationship] as? [String: Any],
              let relationData = relation["data"] as? [String: Any],
              let id = relationData["id"] as? String else {
            return nil
        }
        return id
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
