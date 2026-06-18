import Foundation

extension ConnectClient {
    func releaseVersion(versionID: String) async throws {
        let payload: [String: Any] = [
            "data": [
                "type": "appStoreVersionReleaseRequests",
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
        let body = try JSONSerialization.data(withJSONObject: payload)
        Self.logger.info("\(Self.t)releaseVersion versionID=\(versionID)")
        let _: AppStoreConnectSingleResponse<AppStoreVersionReleaseRequest> = try await request(
            path: "/v1/appStoreVersionReleaseRequests",
            method: "POST",
            body: body
        )
    }
}

private struct AppStoreVersionReleaseRequest: Decodable {
    let id: String
}
