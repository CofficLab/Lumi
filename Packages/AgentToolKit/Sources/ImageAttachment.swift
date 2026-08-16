import Foundation

/// 图片附件
public struct ImageAttachment: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let data: Data
    public let mimeType: String  // image/jpeg, image/png, etc.

    /// 建议的文件名（用于结果附件展示 / 落盘）。
    public let fileName: String?

    public init(id: UUID = UUID(), data: Data, mimeType: String, fileName: String? = nil) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
    }

    public static func == (lhs: ImageAttachment, rhs: ImageAttachment) -> Bool {
        lhs.id == rhs.id && lhs.mimeType == rhs.mimeType
    }

    private enum CodingKeys: String, CodingKey {
        case id, data, mimeType, fileName
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        data = try c.decode(Data.self, forKey: .data)
        mimeType = try c.decode(String.self, forKey: .mimeType)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(data, forKey: .data)
        try c.encode(mimeType, forKey: .mimeType)
        try c.encodeIfPresent(fileName, forKey: .fileName)
    }
}
