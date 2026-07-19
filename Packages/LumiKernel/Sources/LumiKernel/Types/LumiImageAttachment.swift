import Foundation

/// 图片附件。
///
/// 用于工具执行结果中携带图片。
public struct LumiImageAttachment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let mimeType: String
    public let base64Data: String
    public let fileName: String?

    public init(
        id: UUID = UUID(),
        mimeType: String,
        base64Data: String,
        fileName: String? = nil
    ) {
        self.id = id
        self.mimeType = mimeType
        self.base64Data = base64Data
        self.fileName = fileName
    }
}