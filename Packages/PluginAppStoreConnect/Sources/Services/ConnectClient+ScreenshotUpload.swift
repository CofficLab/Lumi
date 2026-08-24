import CryptoKit
import Foundation

/// 截图上传流水线：预约（reserve）→ 按 uploadOperations 分片 PUT → 完成确认（complete）。
/// 预签名 URL 上传不带 Authorization 头，使用 Apple 返回的 requestHeaders。
extension ConnectClient {
    /// 完整上传一张截图到指定截图集。
    /// - Parameters:
    ///   - setID: appScreenshotSet id
    ///   - fileURL: 本地截图文件（PNG/JPEG）
    /// - Returns: 上传完成后的 appScreenshot id
    @discardableResult
    func uploadScreenshot(setID: String, fileURL: URL) async throws -> String {
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        Self.logger.info("\(Self.t)uploadScreenshot setID=\(setID) file=\(fileName) size=\(fileData.count)")

        // 1. 预约上传，获取预签名 uploadOperations
        let reservation = try await reserveScreenshot(setID: setID, fileName: fileName, fileSize: fileData.count)
        guard !reservation.uploadOperations.isEmpty else {
            throw AppStoreConnectClientError.requestFailed(
                AppStoreConnectLocalization.string("App Store Connect did not return upload operations for the screenshot reservation.")
            )
        }

        // 2. 分片 PUT 到预签名 URL
        for operation in reservation.uploadOperations {
            try await performUploadOperation(operation, fileData: fileData)
        }

        // 3. 提交 MD5 校验，确认上传完成
        let checksum = Insecure.MD5.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
        try await completeScreenshotUpload(id: reservation.id, sourceFileChecksum: checksum)
        Self.logger.info("\(Self.t)uploadScreenshot completed id=\(reservation.id)")
        return reservation.id
    }

    /// 删除一张远端截图。
    func deleteScreenshot(id: String) async throws {
        Self.logger.info("\(Self.t)deleteScreenshot id=\(id)")
        try await requestWithoutResponse(
            path: "/v1/appScreenshots/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - Private

    private func reserveScreenshot(setID: String, fileName: String, fileSize: Int) async throws -> AppScreenshotReservation {
        let payload: [String: Any] = [
            "data": [
                "type": "appScreenshots",
                "attributes": [
                    "fileName": fileName,
                    "fileSize": fileSize
                ],
                "relationships": [
                    "appScreenshotSet": [
                        "data": [
                            "type": "appScreenshotSets",
                            "id": setID
                        ]
                    ]
                ]
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let response: AppStoreConnectSingleResponse<AppScreenshotReservation> = try await request(
            path: "/v1/appScreenshots",
            method: "POST",
            body: body
        )
        return response.data
    }

    private func performUploadOperation(_ operation: AppScreenshotUploadOperation, fileData: Data) async throws {
        guard let url = URL(string: operation.url) else {
            throw AppStoreConnectClientError.invalidURL
        }
        let lower = operation.offset
        let upper = min(operation.offset + operation.length, fileData.count)
        guard lower >= 0, upper > lower else {
            throw AppStoreConnectClientError.requestFailed(
                AppStoreConnectLocalization.string("Invalid upload operation range for screenshot upload.")
            )
        }
        let chunk = fileData.subdata(in: lower ..< upper)

        var request = URLRequest(url: url)
        request.httpMethod = operation.method
        for header in operation.requestHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        request.httpBody = chunk

        let (_, statusCode) = try await send(request)
        guard (200 ..< 300).contains(statusCode) else {
            throw AppStoreConnectClientError.requestFailed(
                AppStoreConnectLocalization.string("Screenshot chunk upload failed with HTTP %d.", statusCode)
            )
        }
    }

    private func completeScreenshotUpload(id: String, sourceFileChecksum: String) async throws {
        let payload: [String: Any] = [
            "data": [
                "type": "appScreenshots",
                "id": id,
                "attributes": [
                    "sourceFileChecksum": sourceFileChecksum,
                    "uploaded": true
                ]
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let _: AppStoreConnectSingleResponse<AppScreenshotReservation> = try await request(
            path: "/v1/appScreenshots/\(id)",
            method: "PATCH",
            body: body
        )
    }
}

// MARK: - Models

/// 截图上传预约响应（包含预签名上传操作）。
struct AppScreenshotReservation: Decodable {
    let id: String
    let uploadOperations: [AppScreenshotUploadOperation]

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }

    enum AttributeKeys: String, CodingKey {
        case uploadOperations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        uploadOperations = try attributes.decodeIfPresent([AppScreenshotUploadOperation].self, forKey: .uploadOperations) ?? []
    }
}

struct AppScreenshotUploadOperation: Decodable {
    let method: String
    let url: String
    let length: Int
    let offset: Int
    let requestHeaders: [AppScreenshotUploadHeader]
}

struct AppScreenshotUploadHeader: Decodable {
    let name: String
    let value: String
}
