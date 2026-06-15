import Foundation

extension ConnectClient {
    func loadScreenshotSets(localizationID: String) async throws -> ScreenshotSetsPayload {
        let nested = try await listScreenshotSets(
            localizationID: localizationID,
            useRelationshipEndpoint: true
        )
        if !nested.sets.isEmpty {
            return nested
        }
        return try await listScreenshotSets(
            localizationID: localizationID,
            useRelationshipEndpoint: false
        )
    }

    func listScreenshots(screenshotSetID: String) async throws -> [AppScreenshot] {
        let nested = try await listScreenshots(
            screenshotSetID: screenshotSetID,
            useRelationshipEndpoint: true
        )
        if !nested.isEmpty {
            return nested
        }
        return try await listScreenshots(
            screenshotSetID: screenshotSetID,
            useRelationshipEndpoint: false
        )
    }

    func createScreenshotSet(localizationID: String, displayType: String) async throws -> ScreenshotSet {
        let payload: [String: Any] = [
            "data": [
                "type": "appScreenshotSets",
                "attributes": [
                    "screenshotDisplayType": displayType
                ],
                "relationships": [
                    "appStoreVersionLocalization": [
                        "data": [
                            "type": "appStoreVersionLocalizations",
                            "id": localizationID
                        ]
                    ]
                ]
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let response: AppStoreConnectSingleResponse<ScreenshotSet> = try await request(
            path: "/v1/appScreenshotSets",
            method: "POST",
            body: body
        )
        return response.data
    }

    private func listScreenshotSets(
        localizationID: String,
        useRelationshipEndpoint: Bool
    ) async throws -> ScreenshotSetsPayload {
        var query = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "fields[appScreenshotSets]", value: "screenshotDisplayType"),
            URLQueryItem(name: "include", value: "appScreenshots"),
            URLQueryItem(name: "fields[appScreenshots]", value: "fileName,fileSize,imageAsset"),
            URLQueryItem(name: "limit[appScreenshots]", value: "10")
        ]

        let path: String
        if useRelationshipEndpoint {
            path = "/v1/appStoreVersionLocalizations/\(localizationID)/appScreenshotSets"
        } else {
            path = "/v1/appScreenshotSets"
            query.append(URLQueryItem(name: "filter[appStoreVersionLocalization]", value: localizationID))
        }

        let response: AppStoreConnectListResponseWithIncluded<ScreenshotSet, AppScreenshot> = try await request(
            path: path,
            queryItems: query
        )
        return makeScreenshotSetsPayload(
            sets: response.data,
            includedScreenshots: response.included ?? []
        )
    }

    private func listScreenshots(
        screenshotSetID: String,
        useRelationshipEndpoint: Bool
    ) async throws -> [AppScreenshot] {
        let query = [
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "fields[appScreenshots]", value: "fileName,fileSize,imageAsset")
        ]

        if useRelationshipEndpoint {
            let response: AppStoreConnectListResponse<AppScreenshot> = try await request(
                path: "/v1/appScreenshotSets/\(screenshotSetID)/appScreenshots",
                queryItems: query
            )
            return response.data
        }

        var filterQuery = query
        filterQuery.append(URLQueryItem(name: "filter[appScreenshotSet]", value: screenshotSetID))
        let response: AppStoreConnectListResponse<AppScreenshot> = try await request(
            path: "/v1/appScreenshots",
            queryItems: filterQuery
        )
        return response.data
    }

    private func makeScreenshotSetsPayload(
        sets: [ScreenshotSet],
        includedScreenshots: [AppScreenshot]
    ) -> ScreenshotSetsPayload {
        let screenshotsByID = Dictionary(uniqueKeysWithValues: includedScreenshots.map { ($0.id, $0) })
        var screenshotsBySetID: [String: [AppScreenshot]] = [:]

        for set in sets {
            let screenshots = set.screenshotIDs.compactMap { screenshotsByID[$0] }
            if !screenshots.isEmpty {
                screenshotsBySetID[set.id] = screenshots
            }
        }

        return ScreenshotSetsPayload(sets: sets, screenshotsBySetID: screenshotsBySetID)
    }
}
