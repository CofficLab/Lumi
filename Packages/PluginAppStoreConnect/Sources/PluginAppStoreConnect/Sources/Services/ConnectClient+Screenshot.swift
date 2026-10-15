import Foundation

extension ConnectClient {
    func loadScreenshotSets(localizationID: String) async throws -> ScreenshotSetsPayload {
        // Some ASC accounts reject GET_COLLECTION on appScreenshotSets.
        // Use relationships + GET_INSTANCE only to avoid collection permission issues.
        try await listScreenshotSetsViaRelationshipInstances(localizationID: localizationID)
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

    private func listScreenshotSetsViaRelationshipInstances(localizationID: String) async throws -> ScreenshotSetsPayload {
        let relationshipResponse: AppStoreConnectRelationshipIdentifiersResponse = try await request(
            path: "/v1/appStoreVersionLocalizations/\(localizationID)/relationships/appScreenshotSets",
            queryItems: [
                URLQueryItem(name: "limit", value: "100")
            ]
        )
        let ids = relationshipResponse.data.map(\.id)
        guard !ids.isEmpty else {
            return ScreenshotSetsPayload(sets: [], screenshotsBySetID: [:])
        }

        var sets: [ScreenshotSet] = []
        var screenshotsBySetID: [String: [AppScreenshot]] = [:]
        for id in ids {
            // NOTE (2026-10-11 实测): 该端点带 fields[...] 时，Apple 会清空
            // data.relationships.appScreenshots.data 指针（included 里仍返回完整
            // 截图对象），导致 set.screenshotIDs 为空、按指针匹配落空、截图集被
            // 误报为 0 张。因此这里不带 fields，并且兜底：单次请求的 included
            // 截图必属于该 set，指针为空时直接全部归属。
            let response: AppStoreConnectSingleResponseWithIncluded<ScreenshotSet, AppScreenshot> = try await request(
                path: "/v1/appScreenshotSets/\(id)",
                queryItems: [
                    URLQueryItem(name: "include", value: "appScreenshots"),
                    URLQueryItem(name: "limit[appScreenshots]", value: "10"),
                ]
            )
            let set = response.data
            sets.append(set)
            let included = response.included ?? []
            let pointedIDs = Set(set.screenshotIDs)
            let matched = included.filter { pointedIDs.contains($0.id) }
            screenshotsBySetID[set.id] = matched.isEmpty ? included : matched
        }

        return ScreenshotSetsPayload(sets: sets, screenshotsBySetID: screenshotsBySetID)
    }
}

private struct AppStoreConnectRelationshipIdentifiersResponse: Decodable {
    let data: [AppStoreConnectResourceIdentifier]
}

private struct AppStoreConnectSingleResponseWithIncluded<T: Decodable, Included: Decodable>: Decodable {
    let data: T
    let included: [Included]?
}
