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

    func readVersion(id: String) async throws -> AppStoreVersion {
        let query = [
            URLQueryItem(
                name: "fields[appStoreVersions]",
                value: "platform,versionString,appStoreState,appVersionState,createdDate"
            )
        ]
        Self.logger.info("\(Self.t)readVersion id=\(id)")
        let response: AppStoreConnectSingleResponse<AppStoreVersion> = try await request(
            path: "/v1/appStoreVersions/\(id)",
            queryItems: query
        )
        return response.data
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
        try await updateLocalization(
            id: localization.id,
            promotionalText: localization.promotionalText,
            description: localization.description,
            keywords: localization.keywords,
            whatsNew: localization.whatsNew,
            supportURL: localization.supportURL,
            marketingURL: localization.marketingURL
        )
    }

    /// Partial update: only the provided (non-nil) fields are sent in the PATCH body.
    /// Empty URL strings are sent as JSON null so Apple clears the value instead of
    /// rejecting it as an invalid RFC 3986 URI.
    func updateLocalization(
        id: String,
        promotionalText: String? = nil,
        description: String? = nil,
        keywords: String? = nil,
        whatsNew: String? = nil,
        supportURL: String? = nil,
        marketingURL: String? = nil
    ) async throws -> AppStoreVersionLocalization {
        var attributes: [String: Any] = [:]
        if let promotionalText { attributes["promotionalText"] = promotionalText }
        if let description { attributes["description"] = description }
        if let keywords { attributes["keywords"] = keywords }
        if let whatsNew { attributes["whatsNew"] = whatsNew }
        if let supportURL { attributes["supportUrl"] = supportURL.isEmpty ? NSNull() : supportURL }
        if let marketingURL { attributes["marketingUrl"] = marketingURL.isEmpty ? NSNull() : marketingURL }

        let payload: [String: Any] = [
            "data": [
                "type": "appStoreVersionLocalizations",
                "id": id,
                "attributes": attributes
            ]
        ]

        let body = try JSONSerialization.data(withJSONObject: payload)
        Self.logger.info("\(Self.t)updateLocalization id=\(id)")
        let response: AppStoreConnectSingleResponse<AppStoreVersionLocalization> = try await request(
            path: "/v1/appStoreVersionLocalizations/\(id)",
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
        // URL fields are validated as RFC 3986 URIs by Apple, so omit them when empty
        // instead of sending "" (which is rejected) or null.
        var attributePayload: [String: Any] = [
            "locale": locale,
            "promotionalText": attributes.promotionalText,
            "description": attributes.description,
            "keywords": attributes.keywords,
            "whatsNew": attributes.whatsNew
        ]
        if !attributes.supportURL.isEmpty {
            attributePayload["supportUrl"] = attributes.supportURL
        }
        if !attributes.marketingURL.isEmpty {
            attributePayload["marketingUrl"] = attributes.marketingURL
        }

        let payload: [String: Any] = [
            "data": [
                "type": "appStoreVersionLocalizations",
                "attributes": attributePayload,
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
