import Foundation

/// 图片附件
public struct ImageAttachment: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let data: Data
    public let mimeType: String  // image/jpeg, image/png, etc.

    public init(id: UUID = UUID(), data: Data, mimeType: String) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
    }

    public static func == (lhs: ImageAttachment, rhs: ImageAttachment) -> Bool {
        lhs.id == rhs.id && lhs.mimeType == rhs.mimeType
    }
}
