import Foundation
import os

extension ConnectClient {
    private static let releaseLogger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-store-connect.client")

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
        Self.releaseLogger.info("[ConnectClient] releaseVersion(versionID: \(versionID))")
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
