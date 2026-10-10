import Foundation

/// App Store Connect Review Submissions：将版本提交 Apple 审核 / 撤回提交 / 查询提交状态。
///
/// 2026-10 对照官方 API 与实测验证：
/// - 旧资源 `appStoreVersionSubmissions` 的 CREATE 已随 API 移除（官方文档标记
///   Deprecated，Topics 仅剩 Delete 端点，Create 页面为 dead link），
///   POST /v1/appStoreVersionSubmissions 一律返回 403
///   "does not allow CREATE. Allowed operation is: DELETE"。
/// - 现行提交流 = Review Submissions（API 1.7+）：
///   ① POST /v1/reviewSubmissions 创建提交（201）
///   ② POST /v1/reviewSubmissionItems 把版本加入提交（服务器在此校验审核联系人、
///      构建类型等，缺失必填项返回 409 + associatedErrors 明细）
///   ③ PATCH /v1/reviewSubmissions/{id} attributes.submitted=true 触发提交
///   - 撤回 = PATCH /v1/reviewSubmissions/{id} attributes.canceled=true
///   - 查询某版本是否在途 = 列出 app 的 reviewSubmissions，检查条目是否包含该版本
///     （旧关系端点 /v1/appStoreVersions/{id}/relationships/appStoreVersionSubmission
///     已随资源移除返回 404）。
extension ConnectClient {
    /// 将 App Store 版本提交审核。
    /// 前置条件：已关联 build、元数据完整、（如需）截图已上传。
    /// - Returns: 新创建的 review submission id
    @discardableResult
    func submitForReview(versionID: String) async throws -> String {
        guard let appID = try await resolveAppID(versionID: versionID) else {
            throw AppStoreConnectClientError.requestFailed(
                AppStoreConnectLocalization.string("Could not resolve the app for version id=%@.", versionID)
            )
        }

        // ① 创建 review submission（201）
        let createBody = try Self.makeReviewSubmissionCreateBody(appID: appID)
        let created: AppStoreConnectSingleResponse<ReviewSubmissionResource> = try await request(
            path: "/v1/reviewSubmissions",
            method: "POST",
            body: createBody
        )
        let submissionID = created.data.id
        Self.logger.info("\(Self.t)submitForReview created reviewSubmission=\(submissionID) for version=\(versionID)")

        // ② 把版本加入提交（服务器在此校验审核信息 / 构建类型，失败返回 409 + 明细）
        let itemBody = try Self.makeReviewSubmissionItemBody(submissionID: submissionID, versionID: versionID)
        let _: AppStoreConnectSingleResponse<ReviewSubmissionItemResource> = try await request(
            path: "/v1/reviewSubmissionItems",
            method: "POST",
            body: itemBody
        )

        // ③ 触发提交
        let submitBody = try Self.makeReviewSubmissionSubmitBody(submissionID: submissionID)
        let _: AppStoreConnectSingleResponse<ReviewSubmissionResource> = try await request(
            path: "/v1/reviewSubmissions/\(submissionID)",
            method: "PATCH",
            body: submitBody
        )
        return submissionID
    }

    /// 读取版本当前在途的 review submission id；未提交时返回 nil。
    func readSubmissionID(versionID: String) async throws -> String? {
        guard let appID = try await resolveAppID(versionID: versionID) else {
            Self.logger.warning("\(Self.t)readSubmissionID could not resolve app for version=\(versionID)")
            return nil
        }
        let response: AppStoreConnectListResponse<ReviewSubmissionSummary> = try await request(
            path: "/v1/apps/\(appID)/reviewSubmissions",
            queryItems: [
                URLQueryItem(name: "limit", value: "200"),
                URLQueryItem(name: "fields[reviewSubmissions]", value: "state"),
            ]
        )
        for submission in response.data where Self.isActiveSubmissionState(submission.state) {
            let items: AppStoreConnectListResponse<ReviewSubmissionItemWithVersion> = try await request(
                path: "/v1/reviewSubmissions/\(submission.id)/items",
                queryItems: [
                    URLQueryItem(name: "limit", value: "200"),
                    URLQueryItem(name: "fields[reviewSubmissionItems]", value: "appStoreVersion"),
                    URLQueryItem(name: "include", value: "appStoreVersion"),
                    URLQueryItem(name: "fields[appStoreVersions]", value: "versionString"),
                ]
            )
            if items.data.contains(where: { $0.appStoreVersionID == versionID }) {
                Self.logger.info("\(Self.t)readSubmissionID found submission=\(submission.id) for version=\(versionID)")
                return submission.id
            }
        }
        Self.logger.info("\(Self.t)readSubmissionID no active submission for version=\(versionID)")
        return nil
    }

    /// 撤回在途的审核提交（review submission 置为 canceled）。
    func withdrawSubmission(submissionID: String) async throws {
        let body = try Self.makeReviewSubmissionCancelBody(submissionID: submissionID)
        let _: AppStoreConnectSingleResponse<ReviewSubmissionResource> = try await request(
            path: "/v1/reviewSubmissions/\(submissionID)",
            method: "PATCH",
            body: body
        )
        Self.logger.info("\(Self.t)withdrawSubmission canceled reviewSubmission=\(submissionID)")
    }

    // MARK: - Payload builders

    private static func makeReviewSubmissionCreateBody(appID: String) throws -> Data {
        let payload: [String: Any] = [
            "data": [
                "type": "reviewSubmissions",
                "relationships": [
                    "app": ["data": ["type": "apps", "id": appID]],
                ],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    private static func makeReviewSubmissionItemBody(submissionID: String, versionID: String) throws -> Data {
        let payload: [String: Any] = [
            "data": [
                "type": "reviewSubmissionItems",
                "relationships": [
                    "reviewSubmission": ["data": ["type": "reviewSubmissions", "id": submissionID]],
                    "appStoreVersion": ["data": ["type": "appStoreVersions", "id": versionID]],
                ],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    private static func makeReviewSubmissionSubmitBody(submissionID: String) throws -> Data {
        let payload: [String: Any] = [
            "data": [
                "type": "reviewSubmissions",
                "id": submissionID,
                "attributes": ["submitted": true],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    private static func makeReviewSubmissionCancelBody(submissionID: String) throws -> Data {
        let payload: [String: Any] = [
            "data": [
                "type": "reviewSubmissions",
                "id": submissionID,
                "attributes": ["canceled": true],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// 视为"在途"的 review submission 状态：已创建未提交、等待审核、审核中、
    /// 存在问题、正在完成。终态 COMPLETE / CANCELING 不算。
    private static func isActiveSubmissionState(_ state: String?) -> Bool {
        guard let state else { return false }
        return [
            "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW",
            "UNRESOLVED_ISSUES", "COMPLETING",
        ].contains(state)
    }
}

/// reviewSubmissions 资源（轻量，仅需 id / state）。
private struct ReviewSubmissionResource: Decodable {
    let id: String
}

/// reviewSubmissionItems 资源（轻量，仅需 id）。
private struct ReviewSubmissionItemResource: Decodable {
    let id: String
}

/// reviewSubmissions 列表条目：id + state。
private struct ReviewSubmissionSummary: Decodable {
    let id: String
    let state: String?

    enum CodingKeys: String, CodingKey { case id, attributes }
    enum AttributeKeys: String, CodingKey { case state }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if let attrs = try? container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes) {
            state = try? attrs.decode(String.self, forKey: .state)
        } else {
            state = nil
        }
    }
}

/// reviewSubmissionItems 条目：解析 appStoreVersion 关系 id。
/// 条目资源是扁平 JSON（含 id 与 relationships），无 attributes 包装。
private struct ReviewSubmissionItemWithVersion: Decodable {
    let id: String
    let appStoreVersionID: String?

    enum CodingKeys: String, CodingKey { case id, relationships }
    enum RelKeys: String, CodingKey { case appStoreVersion }
    enum DataKeys: String, CodingKey { case data }
    enum InnerKeys: String, CodingKey { case id }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if let rels = try? container.nestedContainer(keyedBy: RelKeys.self, forKey: .relationships),
           let data = try? rels.nestedContainer(keyedBy: DataKeys.self, forKey: .appStoreVersion),
           let inner = try? data.nestedContainer(keyedBy: InnerKeys.self, forKey: .data) {
            appStoreVersionID = try? inner.decode(String.self, forKey: .id)
        } else {
            appStoreVersionID = nil
        }
    }
}
