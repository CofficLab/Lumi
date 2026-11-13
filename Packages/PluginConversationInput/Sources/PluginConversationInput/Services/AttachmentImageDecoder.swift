import AppKit
import Foundation
import ProviderMessage

/// 待发送图片附件的位图解码缓存。
///
/// 附件预览挂在输入框上方，而输入框的每次按键都会让
/// `ConversationInputViewModel` 发出失效广播，预览的 body 因此重跑。
/// 若在 body 里现算 `Data(base64Encoded:)` + `NSImage(data:)`，每一张待发图片
/// 都要在主线程重新做一次全量 Base64 解码与位图解码（见 issue #1298）。
///
/// 这里按附件 ID 缓存解码结果：附件在挂起池生命周期内 ID 稳定，
/// 因此每个附件只解码一次；附件被移除后条目随字典一起释放。
///
/// - Note: 全部访问都在主线程（`ConversationInputViewModel` 是 `@MainActor`），
///   因此无需加锁。
final class AttachmentImageDecoder {
    private var cache: [UUID: NSImage] = [:]

    /// 取附件的位图。首次调用时解码并缓存，之后直接命中。
    func image(for attachment: UserImageAttachment) -> NSImage? {
        if let cached = cache[attachment.id] {
            return cached
        }
        guard let data = Data(base64Encoded: attachment.base64Data),
              let image = NSImage(data: data) else {
            return nil
        }
        cache[attachment.id] = image
        return image
    }

    /// 丢弃已移除附件的缓存条目。
    func remove(id: UUID) {
        cache.removeValue(forKey: id)
    }

    /// 丢弃不再挂起的全部附件的缓存条目。
    func retainOnly(ids: Set<UUID>) {
        cache = cache.filter { ids.contains($0.key) }
    }
}
