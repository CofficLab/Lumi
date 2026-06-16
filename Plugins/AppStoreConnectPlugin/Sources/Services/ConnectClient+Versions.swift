import Foundation
import os

extension ConnectClient {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-store-connect.client")

    func listVersions(appID: String) async throws -> [AppStoreVersion] {
        let query = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(
                name: "fields[appStoreVersions]",
                value: "platform,versionString,appStoreState,appVersionState,createdDate"
            )
        ]
        let policy = fetchPolicy
        Self.logger.info("[ConnectClient] listVersions(appID: \(appID)) - fetchPolicy: \(String(describing: policy))")
        let response: AppStoreConnectListResponse<AppStoreVersion> = try await request(
            path: "/v1/apps/\(appID)/appStoreVersions",
            queryItems: query
        )
        Self.logger.info("[ConnectClient] listVersions returned \(response.data.count) raw versions")
        if !response.data.isEmpty, Self.verboseLogging {
            for v in response.data.prefix(5) {
                Self.logger.info("[ConnectClient]   - version: \(v.versionString), platform: \(v.platform), state: \(v.appStoreState), created: \(v.createdDate?.description ?? "nil")")
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
        Self.logger.info("[ConnectClient] listLocalizations(versionID: \(versionID))")
        let response: AppStoreConnectListResponse<AppStoreVersionLocalization> = try await request(
            path: "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations",
            queryItems: query
        )
        Self.logger.info("[ConnectClient] listLocalizations returned \(response.data.count) localizations")
        return response.data
    }

    /// Toggle for verbose logging of API responses.
    static let verboseLogging = true

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
        Self.logger.info("[ConnectClient] updateLocalization(id: \(localization.id))")
        let response: AppStoreConnectSingleResponse<AppStoreVersionLocalization> = try await request(
            path: "/v1/appStoreVersionLocalizations/\(localization.id)",
            method: "PATCH",
            body: body
        )
        return response.data
    }
}
