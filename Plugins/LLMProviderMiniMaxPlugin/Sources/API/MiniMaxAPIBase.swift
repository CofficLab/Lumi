import Foundation

// MARK: - Shared API Models
//
// MiniMax 所有 API 服务共享的基础模型。
// 定义在这里供 Image、Video、Music 子模块共用。

// MARK: - Base Response Envelope

/// 所有 MiniMax API 响应的通用包络字段。
public struct MiniMaxBaseResp: Decodable, Equatable, Sendable {
    public let statusCode: Int
    public let statusMessage: String

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMessage = "status_msg"
    }

    public var isSuccess: Bool { statusCode == 0 }

    public var errorDescription: String {
        statusMessage.isEmpty ? "MiniMax API error (status_code=\(statusCode))" : statusMessage
    }

    public init(statusCode: Int, statusMessage: String) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
    }
}
