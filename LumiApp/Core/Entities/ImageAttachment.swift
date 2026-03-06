import Foundation

/// 图片附件
struct ImageAttachment: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let data: Data
    let mimeType: String  // image/jpeg, image/png, etc.

    init(id: UUID = UUID(), data: Data, mimeType: String) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
    }

    static func == (lhs: ImageAttachment, rhs: ImageAttachment) -> Bool {
        lhs.id == rhs.id && lhs.mimeType == rhs.mimeType
    }
}
