import Foundation

extension ConnectClient {
    /// 按 Bundle ID 查找 ASC App。
    ///
    /// 使用 Apple 的 `filter[bundleId]`；命中 0 条时返回 `nil`，
    /// 命中多条时取第一条（同一账号下 bundle ID 唯一）。
    func findApp(bundleID: String) async throws -> AppStoreApp? {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let query = [
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "filter[bundleId]", value: trimmed),
            URLQueryItem(name: "fields[apps]", value: "name,bundleId,sku,primaryLocale,appStoreIcon"),
            URLQueryItem(name: "include", value: "appStoreIcon"),
            URLQueryItem(name: "fields[buildIcons]", value: "iconAsset")
        ]

        let response: AppStoreConnectListResponseWithIncluded<AppStoreApp, BuildIconResource> = try await request(
            path: "/v1/apps",
            queryItems: query
        )
        let iconsByID = Dictionary(
            (response.included ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard let app = response.data.first else { return nil }
        return app.withIconURL(app.appStoreIconID.flatMap { iconsByID[$0]?.iconAsset?.url(width: 64, height: 64) })
    }

    /// 按 ASC App ID 读取单个 App。
    func readApp(id: String) async throws -> AppStoreApp {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppStoreConnectClientError.resourceNotFound(
                AppStoreConnectLocalization.string("The App Store Connect app identifier is empty.")
            )
        }

        let query = [
            URLQueryItem(name: "fields[apps]", value: "name,bundleId,sku,primaryLocale,appStoreIcon"),
            URLQueryItem(name: "include", value: "appStoreIcon"),
            URLQueryItem(name: "fields[buildIcons]", value: "iconAsset")
        ]
        let response: AppStoreConnectAppResponse = try await request(
            path: "/v1/apps/\(trimmed)",
            queryItems: query
        )
        let iconsByID = Dictionary(
            (response.included ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let app = response.data
        return app.withIconURL(app.appStoreIconID.flatMap { iconsByID[$0]?.iconAsset?.url(width: 64, height: 64) })
    }
}

/// 单个 App 资源 + included 图标资源。
private struct AppStoreConnectAppResponse: Decodable {
    let data: AppStoreApp
    let included: [BuildIconResource]?
}
