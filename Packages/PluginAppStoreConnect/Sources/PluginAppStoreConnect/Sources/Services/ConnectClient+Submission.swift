import Foundation

/// App Store Version Submissions：将版本提交给 Apple 审核 / 撤回提交。
extension ConnectClient {
    /// 将 App Store 版本提交审核。
    /// 前置条件：已关联 build、元数据完整、（如需）截图已上传。
    /// - Returns: 新创建的 submission id
    @discardableResult
    func submitForReview(versionID: String) async throws -> String {
        let payload: [String: Any] = [
            "data": [
                "type": "appStoreVersionSubmissions",
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
        Self.logger.info("\(Self.t)submitForReview versionID=\(versionID)")
        let response: AppStoreConnectSingleResponse<AppStoreVersionSubmission> = try await request(
            path: "/v1/appStoreVersionSubmissions",
            method: "POST",
            body: body
        )
        return response.data.id
    }

    /// 读取版本当前的审核提交 id；未提交时返回 nil。
    /// 使用 relationships 端点，未提交时 Apple 返回 200 + {"data": null}。
    func readSubmissionID(versionID: String) async throws -> String? {
        Self.logger.info("\(Self.t)readSubmissionID versionID=\(versionID)")
        let response: AppStoreConnectOptionalSubmissionResponse = try await request(
            path: "/v1/appStoreVersions/\(versionID)/relationships/appStoreVersionSubmission"
        )
        return response.data?.id
    }

    /// 撤回待审核的提交（仅 WAITING_FOR_REVIEW 状态可撤回）。
    func withdrawSubmission(submissionID: String) async throws {
        Self.logger.info("\(Self.t)withdrawSubmission submissionID=\(submissionID)")
        try await requestWithoutResponse(
            path: "/v1/appStoreVersionSubmissions/\(submissionID)",
            method: "DELETE"
        )
    }
}

/// App Store Connect `appStoreVersionSubmissions` 资源。
struct AppStoreVersionSubmission: Decodable {
    let id: String
}

/// relationships 端点在未提交时返回 200 + {"data": null}
private struct AppStoreConnectOptionalSubmissionResponse: Decodable {
    let data: AppStoreConnectResourceIdentifier?
}
