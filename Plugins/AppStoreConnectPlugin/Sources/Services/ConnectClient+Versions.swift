import Foundation

extension ConnectClient {
    func listVersions(appID: String) async throws -> [AppStoreVersion] {
        let query = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(
                name: "fields[appStoreVersions]",
                value: "platform,versionString,appStoreState,appVersionState,createdDate"
            )
        ]
        let policy = fetchPolicy
        Self.logger.info("\(Self.t)listVersions appID=\(appID) fetchPolicy=\(String(describing: policy))")
        let response: AppStoreConnectListResponse<AppStoreVersion> = try await request(
            path: "/v1/apps/\(appID)/appStoreVersions",
            queryItems: query
        )
        Self.logger.info("\(Self.t)listVersions returned \(response.data.count) versions")
        if Self.verbose {
            for v in response.data.prefix(5) {
                Self.logger.info("\(Self.t)  - \(v.versionString) (state: \(v.appStoreState), platform: \(v.platform))")
            }
        }
        return response.data.sorted {
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
        }
    }

    func listLocalizations(versionID: String) async throws -> [AppStoreVersionLocalization] {
        let query = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(
                name: "fields[appStoreVersionLocalizations]",
                value: "locale,promotionalText,description,keywords,whatsNew,supportUrl,marketingUrl"
            )
        ]
        Self.logger.info("\(Self.t)listLocalizations versionID=\(versionID)")
        let response: AppStoreConnectListResponse<AppStoreVersionLocalization> = try await request(
            path: "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations",
            queryItems: query
        )
        Self.logger.info("\(Self.t)listLocalizations returned \(response.data.count) localizations")
        return response.data
    }

    func updateLocalization(_ localization: AppStoreVersionLocalization) async throws -> AppStoreVersionLocalization {
        let payload: [String: Any] = [
            "data": [
                "type": "appStoreVersionLocalizations",
                "id": localization.id,
                "attributes": [
                    "promotionalText": localization.promotionalText,
                    "description": localization.description,
                    "keywords": localization.keywords,
                    "whatsNew": localization.whatsNew,
                    "supportUrl": localization.supportURL,
                    "marketingUrl": localization.marketingURL
                ]
            ]
        ]

        let body = try JSONSerialization.data(withJSONObject: payload)
        Self.logger.info("\(Self.t)updateLocalization id=\(localization.id)")
        let response: AppStoreConnectSingleResponse<AppStoreVersionLocalization> = try await request(
            path: "/v1/appStoreVersionLocalizations/\(localization.id)",
            method: "PATCH",
            body: body
        )
        return response.data
    }

    func createVersion(
        appID: String,
        versionString: String,
        platform: String,
        releaseType: String = "AFTER_APPROVAL"
    ) async throws -> AppStoreVersion {
        let body = try Self.makeAppStoreVersionCreateBody(
            appID: appID,
            versionString: versionString,
            platform: platform,
            releaseType: releaseType
        )
        Self.logger.info("\(Self.t)createVersion appID=\(appID) version=\(versionString) platform=\(platform)")
        let response: AppStoreConnectSingleResponse<AppStoreVersion> = try await request(
            path: "/v1/appStoreVersions",
            method: "POST",
            body: body
        )
        return response.data
    }

    func createLocalization(
        versionID: String,
        locale: String,
        attributes: AppStoreVersionLocalization.CreateAttributes
    ) async throws -> AppStoreVersionLocalization {
        let body = try Self.makeAppStoreVersionLocalizationCreateBody(
            versionID: versionID,
            locale: locale,
            attributes: attributes
        )
        Self.logger.info("\(Self.t)createLocalization versionID=\(versionID) locale=\(locale)")
        let response: AppStoreConnectSingleResponse<AppStoreVersionLocalization> = try await request(
            path: "/v1/appStoreVersionLocalizations",
            method: "POST",
            body: body
        )
        return response.data
    }

    static func makeAppStoreVersionCreateBody(
        appID: String,
        versionString: String,
        platform: String,
        releaseType: String
    ) throws -> Data {
        let payload: [String: Any] = [
            "data": [
                "type": "appStoreVersions",
                "attributes": [
                    "versionString": versionString,
                    "platform": platform.normalizedASCPlatform,
                    "releaseType": releaseType
                ],
                "relationships": [
                    "app": [
                        "data": [
                            "type": "apps",
                            "id": appID
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    static func makeAppStoreVersionLocalizationCreateBody(
        versionID: String,
        locale: String,
        attributes: AppStoreVersionLocalization.CreateAttributes
    ) throws -> Data {
        let payload: [String: Any] = [
            "data": [
                "type": "appStoreVersionLocalizations",
                "attributes": [
                    "locale": locale,
                    "promotionalText": attributes.promotionalText,
                    "description": attributes.description,
                    "keywords": attributes.keywords,
                    "whatsNew": attributes.whatsNew,
                    "supportUrl": attributes.supportURL,
                    "marketingUrl": attributes.marketingURL
                ],
                "relationships": [
                    "appStoreVersion": [
                        "data": [
                            "type": "appStoreVersions",
                            "id": versionID
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }
}
