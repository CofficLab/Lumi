import Foundation

extension ConnectClient {
    /// 列出 App 的构建版本（按上传时间倒序），并注入预发布版本号便于展示。
    /// - Parameters:
    ///   - appID: App Store Connect app id
    ///   - platform: 平台过滤（IOS / MAC_OS / TV_OS / VISION_OS），nil 表示不过滤
    ///   - includeExpired: 是否包含已过期的构建
    func listBuilds(
        appID: String,
        platform: String? = nil,
        includeExpired: Bool = false,
        limit: Int = 50
    ) async throws -> [ConnectBuild] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "filter[app]", value: appID),
            URLQueryItem(name: "sort", value: "-uploadedDate"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(
                name: "fields[builds]",
                value: "version,uploadedDate,expirationDate,expired,minOsVersion,processingState,usesNonExemptEncryption,preReleaseVersion"
            ),
            URLQueryItem(name: "include", value: "preReleaseVersion"),
            URLQueryItem(name: "fields[preReleaseVersions]", value: "version,platform"),
            URLQueryItem(name: "limit[preReleaseVersions]", value: "1")
        ]
        if let platform, !platform.isEmpty {
            query.append(URLQueryItem(name: "filter[preReleaseVersion.platform]", value: platform.normalizedASCPlatform))
        }
        if !includeExpired {
            query.append(URLQueryItem(name: "filter[expired]", value: "false"))
        }

        Self.logger.info("\(Self.t)listBuilds appID=\(appID) platform=\(platform ?? "nil")")
        let response: AppStoreConnectListResponseWithIncluded<ConnectBuild, PreReleaseVersionResource> = try await request(
            path: "/v1/builds",
            queryItems: query
        )
        let preReleaseVersionsByID = Dictionary(
            (response.included ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return response.data.map { build in
            let preReleaseVersion = build.preReleaseVersionID.flatMap { preReleaseVersionsByID[$0] }
            return build.withPreReleaseVersionString(preReleaseVersion?.version)
        }
    }

    /// 读取版本当前已关联的 build id；未关联时返回 nil。
    func readAssignedBuildID(versionID: String) async throws -> String? {
        Self.logger.info("\(Self.t)readAssignedBuildID versionID=\(versionID)")
        let response: AppStoreConnectOptionalRelationshipResponse = try await request(
            path: "/v1/appStoreVersions/\(versionID)/relationships/build"
        )
        return response.data?.id
    }

    /// 将构建版本关联到 App Store 版本（提交审核前的必需步骤）。
    func assignBuild(versionID: String, buildID: String) async throws {
        let payload: [String: Any] = [
            "data": [
                "type": "builds",
                "id": buildID
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        Self.logger.info("\(Self.t)assignBuild versionID=\(versionID) buildID=\(buildID)")
        try await requestWithoutResponse(
            path: "/v1/appStoreVersions/\(versionID)/relationships/build",
            method: "PATCH",
            body: body
        )
    }

    /// 更新构建的出口合规声明（是否使用非豁免加密）。
    func updateBuildEncryption(buildID: String, usesNonExemptEncryption: Bool) async throws {
        let payload: [String: Any] = [
            "data": [
                "type": "builds",
                "id": buildID,
                "attributes": [
                    "usesNonExemptEncryption": usesNonExemptEncryption
                ]
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        Self.logger.info("\(Self.t)updateBuildEncryption buildID=\(buildID) usesNonExemptEncryption=\(usesNonExemptEncryption)")
        let _: AppStoreConnectSingleResponse<ConnectBuild> = try await request(
            path: "/v1/builds/\(buildID)",
            method: "PATCH",
            body: body
        )
    }
}

/// relationships 端点在未关联时返回 200 + {"data": null}
private struct AppStoreConnectOptionalRelationshipResponse: Decodable {
    let data: AppStoreConnectResourceIdentifier?
}
