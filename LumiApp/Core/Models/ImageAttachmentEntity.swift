import Foundation
import SwiftData

/// 图片附件实体（独立存储表）
///
/// 与 ChatMessageEntity 为多对多关系：一条消息可包含多张图片，
/// 同一张图片可被多条消息引用。
@Model
final class ImageAttachmentEntity {
    @Attribute(.unique) var id: UUID
    var data: Data
    var mimeType: String
    var createdAt: Date

    /// 反向关系：哪些消息引用了此图片
    var messages: [ChatMessageEntity]?

    init(
        id: UUID = UUID(),
        data: Data,
        mimeType: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
        self.createdAt = createdAt
    }

    /// 转换为业务层模型
    func toImageAttachment() -> ImageAttachment {
        ImageAttachment(id: id, data: data, mimeType: mimeType)
    }

    /// 从业务层模型创建
    static func from(_ attachment: ImageAttachment) -> ImageAttachmentEntity {
        ImageAttachmentEntity(
            id: attachment.id,
            data: attachment.data,
            mimeType: attachment.mimeType
        )
    }
}
